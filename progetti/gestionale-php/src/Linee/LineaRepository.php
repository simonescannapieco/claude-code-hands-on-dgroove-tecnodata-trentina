<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Linee;

use CiaspoLink\Gestionale\Support\Periodo;
use PDO;

final class LineaRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function trova(string $id): ?Linea
    {
        $stmt = $this->pdo->prepare('SELECT * FROM linee WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Linea::daRiga($riga);
    }

    /**
     * @return list<Linea>
     */
    public function perCliente(string $clienteId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM linee WHERE cliente_id = :cliente ORDER BY id');
        $stmt->execute(['cliente' => $clienteId]);

        return array_map(Linea::daRiga(...), $stmt->fetchAll());
    }

    /**
     * Linee in servizio per almeno un giorno del periodo, per cliente e codice.
     *
     * @return list<Linea>
     */
    public function fatturabiliNelPeriodo(Periodo $periodo): array
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            SELECT * FROM linee
             WHERE attiva_dal IS NOT NULL
               AND attiva_dal <= :fine
               AND (cessata_il IS NULL OR cessata_il >= :inizio)
             ORDER BY cliente_id, id
            SQL);
        $stmt->execute([
            'inizio' => $periodo->primoGiorno()->format('Y-m-d'),
            'fine' => $periodo->ultimoGiorno()->format('Y-m-d'),
        ]);

        return array_map(Linea::daRiga(...), $stmt->fetchAll());
    }

    /**
     * Porta la linea in servizio dal giorno indicato (attivazione completata).
     */
    public function attiva(string $id, string $dal): void
    {
        $stmt = $this->pdo->prepare(
            "UPDATE linee SET stato = 'attiva', attiva_dal = :dal WHERE id = :id AND stato = 'in_attivazione'",
        );
        $stmt->execute(['id' => $id, 'dal' => $dal]);
    }

    /**
     * @return array<string, int> numero di linee per stato
     */
    public function conteggioPerStato(): array
    {
        $conteggi = [];
        foreach ($this->pdo->query('SELECT stato, COUNT(*) AS n FROM linee GROUP BY stato')->fetchAll() as $riga) {
            $conteggi[(string) $riga['stato']] = (int) $riga['n'];
        }

        return $conteggi;
    }
}
