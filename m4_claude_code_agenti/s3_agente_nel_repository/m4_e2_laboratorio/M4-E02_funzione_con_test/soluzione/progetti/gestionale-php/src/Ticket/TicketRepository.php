<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

use DateTimeImmutable;
use DateTimeInterface;
use PDO;

final class TicketRepository
{
    private const SELECT = <<<'SQL'
        SELECT t.*, COALESCE(c.ragione_sociale, c.nome || ' ' || c.cognome) AS cliente_nome
          FROM ticket t
          LEFT JOIN clienti c ON c.id = t.cliente_id
        SQL;

    /**
     * Il ticket padre e la linea, per arrivare all'apparato dei ticket dei clienti.
     */
    private const COLLEGAMENTI = ' LEFT JOIN ticket p ON p.id = t.padre_id LEFT JOIN linee l ON l.id = t.linea_id';

    public function __construct(private readonly PDO $pdo)
    {
    }

    public function trova(string $id): ?Ticket
    {
        $stmt = $this->pdo->prepare(self::SELECT . ' WHERE t.id = :id');
        $stmt->execute(['id' => $id]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Ticket::daRiga($riga);
    }

    /**
     * Ticket che rispettano il filtro, dal più recente.
     *
     * @return list<Ticket>
     */
    public function cerca(FiltroTicket $filtro, int $limite = 100): array
    {
        $condizioni = [];
        $parametri = [];
        if ($filtro->stato !== null) {
            $condizioni[] = 't.stato = :stato';
            $parametri['stato'] = $filtro->stato->value;
        }
        if ($filtro->soloAperti) {
            $condizioni[] = "t.stato NOT IN ('risolto', 'chiuso')";
        }
        if ($filtro->priorita !== null) {
            $condizioni[] = 't.priorita = :priorita';
            $parametri['priorita'] = $filtro->priorita->value;
        }
        if ($filtro->categoria !== null) {
            $condizioni[] = 't.categoria = :categoria';
            $parametri['categoria'] = $filtro->categoria;
        }
        if ($filtro->clienteId !== null) {
            $condizioni[] = 't.cliente_id = :cliente';
            $parametri['cliente'] = $filtro->clienteId;
        }
        if ($filtro->apparatoId !== null) {
            $condizioni[] = ':apparato IN (t.apparato_id, p.apparato_id, l.apparato_id)';
            $parametri['apparato'] = $filtro->apparatoId;
        }
        if ($filtro->dal !== null) {
            $condizioni[] = 'substr(t.aperto_il, 1, 10) >= :dal';
            $parametri['dal'] = $filtro->dal->format('Y-m-d');
        }
        if ($filtro->al !== null) {
            $condizioni[] = 'substr(t.aperto_il, 1, 10) <= :al';
            $parametri['al'] = $filtro->al->format('Y-m-d');
        }
        $sql = self::SELECT
            . ($filtro->apparatoId === null ? '' : self::COLLEGAMENTI)
            . ($condizioni === [] ? '' : ' WHERE ' . implode(' AND ', $condizioni))
            . ' ORDER BY t.aperto_il DESC LIMIT :limite';

        $stmt = $this->pdo->prepare($sql);
        foreach ($parametri as $nome => $valore) {
            $stmt->bindValue($nome, $valore);
        }
        $stmt->bindValue('limite', $limite, PDO::PARAM_INT);
        $stmt->execute();

        return array_map(Ticket::daRiga(...), $stmt->fetchAll());
    }

    /**
     * Ticket dei clienti collegati a un ticket di disservizio.
     *
     * @return list<Ticket>
     */
    public function figli(string $padreId): array
    {
        $stmt = $this->pdo->prepare(self::SELECT . ' WHERE t.padre_id = :padre ORDER BY t.aperto_il');
        $stmt->execute(['padre' => $padreId]);

        return array_map(Ticket::daRiga(...), $stmt->fetchAll());
    }

    public function aggiornaStato(string $id, StatoTicket $stato, DateTimeImmutable $quando, ?string $operatore): void
    {
        $istante = $quando->format(DateTimeInterface::ATOM);
        $stmt = $this->pdo->prepare(<<<'SQL'
            UPDATE ticket
               SET stato = :stato,
                   aggiornato_il = :quando,
                   chiuso_il = :chiuso_il,
                   assegnato_a = COALESCE(:operatore, assegnato_a)
             WHERE id = :id
            SQL);
        $stmt->execute([
            'id' => $id,
            'stato' => $stato->value,
            'quando' => $istante,
            'chiuso_il' => $stato === StatoTicket::Chiuso ? $istante : null,
            'operatore' => $operatore,
        ]);
    }

    public function conteggioAperti(): int
    {
        return (int) $this->pdo
            ->query("SELECT COUNT(*) FROM ticket WHERE stato NOT IN ('risolto', 'chiuso')")
            ->fetchColumn();
    }
}
