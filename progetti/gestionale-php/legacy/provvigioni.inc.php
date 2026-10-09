<?php
/*
 * provvigioni.inc.php - provvigioni mensili dei rivenditori
 *
 * Accordo con i rivenditori del 2016: 40 euro per ogni attivazione Casa e
 * 80 euro per ogni attivazione Business, contate sulle richieste del mese.
 * Lanciato da bin/provvigioni-rivenditori.php e dalla chiusura del mese.
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';

/*
 * Ritorna array(rivenditore => array('casa', 'business', 'importo' in euro))
 * oppure false se il mese e' gia stato liquidato. Con $salva scrive la tabella provvigioni.
 */
function calcola_provvigioni_mese($anno, $mese, $salva = true)
{
    $periodo = sprintf('%04d-%02d', $anno, $mese);

    // gia liquidate: non si ricalcola niente
    $liquidate = db_value("SELECT COUNT(*) FROM provvigioni WHERE periodo = '$periodo' AND stato = 'liquidata'");
    if ($liquidate > 0) {
        echo "Provvigioni di $periodo gia liquidate: nessun ricalcolo.\n";
        return false;
    }

    $res = db_query("SELECT a.rivenditore_id, o.famiglia, COUNT(*) AS n
                       FROM attivazioni a
                       JOIN linee l ON l.id = a.linea_id
                       JOIN offerte o ON o.codice = l.offerta_codice
                      WHERE a.rivenditore_id IS NOT NULL
                        AND a.stato <> 'annullata'
                        AND substr(a.richiesta_il, 1, 7) = '$periodo'
                      GROUP BY a.rivenditore_id, o.famiglia
                      ORDER BY a.rivenditore_id");
    $tot = array();
    while ($r = db_fetch($res)) {
        $rv = $r['rivenditore_id'];
        if (!isset($tot[$rv])) {
            $tot[$rv] = array('casa' => 0, 'business' => 0);
        }
        if ($r['famiglia'] == 'Business') {
            $tot[$rv]['business'] += $r['n'];
        } else {
            $tot[$rv]['casa'] += $r['n'];
        }
    }

    $risultato = array();
    foreach ($tot as $rv => $t) {
        $importo = $t['casa'] * 40 + $t['business'] * 80;
        $risultato[$rv] = array('casa' => $t['casa'], 'business' => $t['business'], 'importo' => $importo);
        if ($salva) {
            db_exec("DELETE FROM provvigioni WHERE rivenditore_id = '$rv' AND periodo = '$periodo'");
            db_exec("INSERT INTO provvigioni (rivenditore_id, periodo, attivazioni_casa, attivazioni_business,
                                              importo_cent, calcolata_il, stato)
                     VALUES ('$rv', '$periodo', " . $t['casa'] . ", " . $t['business'] . ", " . ($importo * 100)
                     . ", '" . date('Y-m-d H:i:s') . "', 'calcolata')");
        }
    }
    if ($salva) {
        log_operazione('provvigioni', 'provvigioni ' . $periodo . ' calcolate per ' . count($risultato) . ' rivenditori');
    }
    return $risultato;
}
