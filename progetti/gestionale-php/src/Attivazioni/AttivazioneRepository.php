<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Attivazioni;

use PDO;

final class AttivazioneRepository
{
    private const SELECT = <<<'SQL'
        SELECT a.*, l.cliente_id, co.nome AS comune,
               COALESCE(c.ragione_sociale, c.nome || ' ' || c.cognome) AS cliente_nome
          FROM attivazioni a
          JOIN linee l ON l.id = a.linea_id
          JOIN clienti c ON c.id = l.cliente_id
          JOIN comuni co ON co.id = c.comune_id
        SQL;

    public function __construct(private readonly PDO $pdo)
    {
    }

    public function trova(string $id): ?Attivazione
    {
        $stmt = $this->pdo->prepare(self::SELECT . ' WHERE a.id = :id');
        $stmt->execute(['id' => $id]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Attivazione::daRiga($riga);
    }

    /**
     * Attivazioni non ancora concluse, dalla richiesta più vecchia.
     *
     * @return list<Attivazione>
     */
    public function aperte(): array
    {
        $stmt = $this->pdo->query(
            self::SELECT . " WHERE a.stato NOT IN ('completata', 'annullata') ORDER BY a.richiesta_il",
        );

        return array_map(Attivazione::daRiga(...), $stmt->fetchAll());
    }

    /**
     * Attivazioni completate nel giorno indicato (AAAA-MM-GG).
     *
     * @return list<Attivazione>
     */
    public function completateIl(string $giorno): array
    {
        $stmt = $this->pdo->prepare(
            self::SELECT . " WHERE a.stato = 'completata' AND date(a.completata_il) = :giorno ORDER BY a.completata_il",
        );
        $stmt->execute(['giorno' => $giorno]);

        return array_map(Attivazione::daRiga(...), $stmt->fetchAll());
    }

    public function aggiornaStato(string $id, StatoAttivazione $stato, string $quando, ?string $tecnico = null): void
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            UPDATE attivazioni
               SET stato = :stato,
                   aggiornata_il = :quando,
                   completata_il = COALESCE(:completata_il, completata_il),
                   tecnico = COALESCE(:tecnico, tecnico)
             WHERE id = :id
            SQL);
        $stmt->execute([
            'id' => $id,
            'stato' => $stato->value,
            'quando' => $quando,
            'completata_il' => $stato === StatoAttivazione::Completata ? $quando : null,
            'tecnico' => $tecnico,
        ]);
    }

    public function registraEvento(
        string $id,
        StatoAttivazione $da,
        StatoAttivazione $a,
        string $quando,
        string $operatore,
    ): void {
        $stmt = $this->pdo->prepare(<<<'SQL'
            INSERT INTO attivazioni_eventi (attivazione_id, da_stato, a_stato, avvenuto_il, operatore)
            VALUES (:id, :da, :a, :quando, :operatore)
            SQL);
        $stmt->execute([
            'id' => $id,
            'da' => $da->value,
            'a' => $a->value,
            'quando' => $quando,
            'operatore' => $operatore,
        ]);
    }

    /**
     * @return list<array{da_stato: ?string, a_stato: string, avvenuto_il: string, operatore: string}>
     */
    public function eventi(string $id): array
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            SELECT da_stato, a_stato, avvenuto_il, operatore
              FROM attivazioni_eventi
             WHERE attivazione_id = :id
             ORDER BY avvenuto_il, id
            SQL);
        $stmt->execute(['id' => $id]);

        /** @var list<array{da_stato: ?string, a_stato: string, avvenuto_il: string, operatore: string}> */
        return $stmt->fetchAll();
    }
}
