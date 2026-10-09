<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Clienti;

use PDO;

final class ClienteRepository
{
    private const SELECT = 'SELECT c.*, co.nome AS comune, co.zona'
        . ' FROM clienti c JOIN comuni co ON co.id = c.comune_id';

    public function __construct(private readonly PDO $pdo)
    {
    }

    public function trova(string $id): ?Cliente
    {
        $stmt = $this->pdo->prepare(self::SELECT . ' WHERE c.id = :id');
        $stmt->execute(['id' => $id]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Cliente::daRiga($riga);
    }

    /**
     * Cerca per codice cliente, cognome, ragione sociale o e-mail.
     *
     * @return list<Cliente>
     */
    public function cerca(string $testo, int $limite = 50): array
    {
        $testo = trim($testo);
        if ($testo === '') {
            return [];
        }
        $sql = self::SELECT . <<<'SQL'
             WHERE c.id = :id
                OR c.cognome LIKE :cognome ESCAPE '\'
                OR c.ragione_sociale LIKE :ragione ESCAPE '\'
                OR c.email LIKE :email ESCAPE '\'
             ORDER BY c.id
             LIMIT :limite
            SQL;
        $modello = '%' . addcslashes($testo, '%_\\') . '%';
        $stmt = $this->pdo->prepare($sql);
        $stmt->bindValue('id', $testo);
        $stmt->bindValue('cognome', $modello);
        $stmt->bindValue('ragione', $modello);
        $stmt->bindValue('email', $modello);
        $stmt->bindValue('limite', $limite, PDO::PARAM_INT);
        $stmt->execute();

        return array_map(Cliente::daRiga(...), $stmt->fetchAll());
    }

    /**
     * @return list<Cliente>
     */
    public function tutti(): array
    {
        $stmt = $this->pdo->query(self::SELECT . ' ORDER BY c.id');

        return array_map(Cliente::daRiga(...), $stmt->fetchAll());
    }

    /**
     * @return array<string, int> numero di clienti per stato
     */
    public function conteggioPerStato(): array
    {
        $stmt = $this->pdo->query('SELECT stato, COUNT(*) AS n FROM clienti GROUP BY stato ORDER BY stato');
        $conteggi = [];
        foreach ($stmt->fetchAll() as $riga) {
            $conteggi[(string) $riga['stato']] = (int) $riga['n'];
        }

        return $conteggi;
    }
}
