<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Copertura;

use PDO;

final class CoperturaRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * Righe di copertura del civico; se la scala non è indicata valgono tutte
     * le scale dell'edificio.
     *
     * @return list<array{tecnologia: string, velocita_max_mbps: int, apparato_id: ?string,
     *                    disponibile_dal: ?string}>
     */
    public function perIndirizzo(string $comune, IndirizzoNormalizzato $indirizzo): array
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            SELECT cp.tecnologia, cp.velocita_max_mbps, cp.apparato_id, cp.disponibile_dal
              FROM copertura cp
              JOIN comuni co ON co.id = cp.comune_id
             WHERE co.nome = :comune
               AND lower(cp.via) = :via
               AND cp.civico = :civico
               AND (cp.scala = :scala OR :senza_scala = 1)
             ORDER BY cp.tecnologia, cp.velocita_max_mbps DESC
            SQL);
        $stmt->execute([
            'comune' => $comune,
            'via' => $indirizzo->chiaveVia(),
            'civico' => $indirizzo->civico,
            'scala' => $indirizzo->scala,
            'senza_scala' => $indirizzo->scala === '' ? 1 : 0,
        ]);

        return array_map(
            static fn (array $riga): array => [
                'tecnologia' => (string) $riga['tecnologia'],
                'velocita_max_mbps' => (int) $riga['velocita_max_mbps'],
                'apparato_id' => $riga['apparato_id'] === null ? null : (string) $riga['apparato_id'],
                'disponibile_dal' => $riga['disponibile_dal'] === null ? null : (string) $riga['disponibile_dal'],
            ],
            $stmt->fetchAll(),
        );
    }

    /**
     * @return list<string> nomi dei comuni, in ordine alfabetico
     */
    public function comuni(): array
    {
        return array_map(
            static fn (array $riga): string => (string) $riga['nome'],
            $this->pdo->query('SELECT nome FROM comuni ORDER BY nome')->fetchAll(),
        );
    }
}
