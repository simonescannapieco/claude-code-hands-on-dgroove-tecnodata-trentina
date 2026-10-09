<?php
/*
 * listino.inc.php - importi mensili di una linea
 *
 *  v1.0 2014  canone e contributo di attivazione
 *  v2.0 2017  servizi aggiuntivi (ip statico, linea voce)
 *  v2.3 2019  hotspot wi-fi; importi in centesimi
 *  v2.4 2021  interni voip a quantita
 *  v2.5 2025  promo radio 2025
 *
 * Lo usa la fatturazione mensile: src/Fatturazione/GeneratoreFatture.php passa
 * da src/Legacy/PonteListino.php.
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';

global $PREZZI_SERVIZI;

// prezzi dei servizi aggiuntivi, euro iva esclusa (TODO: leggerli dalla tabella servizi)
$PREZZI_SERVIZI = array(
    'IP_STATICO'   => 5.00,
    'LINEA_VOCE'   => 3.00,
    'VOIP_INTERNO' => 3.90,
    'HOTSPOT_WIFI' => 19.00,
);

/*
 * Voci da fatturare per una linea in un mese. Ritorna un array di
 * array('voce', 'descrizione', 'quantita', 'prezzo', 'importo'), importi in centesimi.
 */
function calcola_importo_linea($linea_id, $mese, $anno)
{
    global $PREZZI_SERVIZI, $MESI;

    $voci = array();
    $periodo = sprintf('%04d-%02d', $anno, $mese);
    $res = db_query("SELECT l.*, o.nome AS nome_offerta, o.canone_cent, o.attivazione_cent, o.famiglia
                       FROM linee l JOIN offerte o ON o.codice = l.offerta_codice
                      WHERE l.id = '" . db_escape($linea_id) . "'");
    $l = db_fetch($res);
    if (!$l) {
        return $voci;
    }

    $canone = (int)$l['canone_cent'];
    $gg_mese = 30; // mese commerciale
    $gg = $gg_mese;
    $tipo = 'canone';
    $descr = $l['nome_offerta'] . ' - canone ' . $MESI[(int)$mese] . ' ' . $anno;

    // attivata nel mese: rateo dal giorno di attivazione
    if ($l['attiva_dal'] != '' && substr($l['attiva_dal'], 0, 7) == $periodo) {
        $g = (int)substr($l['attiva_dal'], 8, 2);
        $gg = $gg_mese - $g + 1;
        $tipo = 'rateo';
        $descr = $l['nome_offerta'] . ' - canone dal ' . data_it($l['attiva_dal']) . ' (' . $gg . ' gg)';
    }
    // cessata nel mese: rateo fino al giorno di cessazione
    if ($l['cessata_il'] != '' && substr($l['cessata_il'], 0, 7) == $periodo) {
        $g = (int)substr($l['cessata_il'], 8, 2);
        $gg = $g;
        $tipo = 'rateo';
        $descr = $l['nome_offerta'] . ' - canone fino al ' . data_it($l['cessata_il']) . ' (' . $gg . ' gg)';
    }
    $importo = intdiv($canone * $gg, $gg_mese);
    $voci[] = array('voce' => $tipo, 'descrizione' => $descr, 'quantita' => 1, 'prezzo' => $importo,
                    'importo' => $importo);

    // contributo di attivazione, una volta sola
    if ($l['attiva_dal'] != '' && substr($l['attiva_dal'], 0, 7) == $periodo) {
        $voci[] = array('voce' => 'attivazione', 'descrizione' => 'Contributo di attivazione ' . $l['nome_offerta'],
                        'quantita' => 1, 'prezzo' => (int)$l['attivazione_cent'],
                        'importo' => (int)$l['attivazione_cent']);
    }

    // servizi aggiuntivi attivi nel mese: si paga il mese intero
    $res2 = db_query("SELECT * FROM linee_servizi
                       WHERE linea_id = '" . db_escape($linea_id) . "'
                         AND dal <= '" . $periodo . "-31' AND (al IS NULL OR al >= '" . $periodo . "-01')
                       ORDER BY servizio_codice");
    while ($s = db_fetch($res2)) {
        $cod = $s['servizio_codice'];
        if (!isset($PREZZI_SERVIZI[$cod])) {
            continue; // servizio nuovo, non ancora a listino
        }
        $prezzo = (int)round($PREZZI_SERVIZI[$cod] * 100);
        $q = (int)$s['quantita'];
        $voci[] = array('voce' => 'servizio', 'descrizione' => nome_servizio($cod) . ($q > 1 ? ' x' . $q : ''),
                        'quantita' => $q, 'prezzo' => $prezzo, 'importo' => $prezzo * $q);
    }

    // PROMO RADIO 2025: 5 euro al mese di sconto per 12 mesi sulle Casa Radio attivate nel 2025
    if ($l['offerta_codice'] == 'CASA_RADIO' && substr((string)$l['attiva_dal'], 0, 4) == '2025') {
        $mesi = ($anno - (int)substr($l['attiva_dal'], 0, 4)) * 12 + ($mese - (int)substr($l['attiva_dal'], 5, 2));
        if ($mesi >= 1 && $mesi <= 12) {
            $voci[] = array('voce' => 'sconto', 'descrizione' => 'Promo Radio 2025 (' . $mesi . '/12)',
                            'quantita' => 1, 'prezzo' => -500, 'importo' => -500);
        }
    }

    return $voci;
}

// prezzo mensile di un'offerta in euro (usata dalle vecchie pagine)
function prezzo_offerta($codice)
{
    $c = db_value("SELECT canone_cent FROM offerte WHERE codice = '" . db_escape($codice) . "'");
    return $c / 100;
}
