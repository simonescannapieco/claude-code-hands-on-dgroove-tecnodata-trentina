<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Rivenditori;

use CiaspoLink\Gestionale\Support\Periodo;
use PDO;

/**
 * Provvigioni dei rivenditori secondo la convenzione in vigore dal 2023: per
 * ogni nuova attivazione completata nel mese, l'importo Casa o Business
 * previsto dalla convenzione del singolo rivenditore.
 */
final class CalcoloProvvigioni
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @return list<Provvigione>
     */
    public function perPeriodo(Periodo $periodo): array
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            SELECT r.id, r.ragione_sociale, r.provvigione_casa_cent, r.provvigione_business_cent,
                   SUM(CASE WHEN o.famiglia = 'Casa' THEN 1 ELSE 0 END) AS casa,
                   SUM(CASE WHEN o.famiglia = 'Business' THEN 1 ELSE 0 END) AS business
              FROM attivazioni a
              JOIN rivenditori r ON r.id = a.rivenditore_id
              JOIN offerte o ON o.codice = a.offerta_codice
             WHERE a.tipo = 'nuova'
               AND a.stato = 'completata'
               AND substr(a.completata_il, 1, 7) = :periodo
             GROUP BY r.id, r.ragione_sociale, r.provvigione_casa_cent, r.provvigione_business_cent
             ORDER BY r.id
            SQL);
        $stmt->execute(['periodo' => (string) $periodo]);

        $provvigioni = [];
        foreach ($stmt->fetchAll() as $riga) {
            $casa = (int) $riga['casa'];
            $business = (int) $riga['business'];
            $provvigioni[] = new Provvigione(
                (string) $riga['id'],
                (string) $riga['ragione_sociale'],
                (string) $periodo,
                $casa,
                $business,
                $casa * (int) $riga['provvigione_casa_cent'] + $business * (int) $riga['provvigione_business_cent'],
            );
        }

        return $provvigioni;
    }

    /**
     * Importi già registrati in tabella per il periodo, per rivenditore.
     *
     * @return array<string, int>
     */
    public function registrate(Periodo $periodo): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT rivenditore_id, importo_cent FROM provvigioni WHERE periodo = :periodo ORDER BY rivenditore_id',
        );
        $stmt->execute(['periodo' => (string) $periodo]);
        $importi = [];
        foreach ($stmt->fetchAll() as $riga) {
            $importi[(string) $riga['rivenditore_id']] = (int) $riga['importo_cent'];
        }

        return $importi;
    }
}
