<?php
/*
 * chiusura_mese.inc.php - operazioni di fine mese
 *
 * Da lanciare il 2 di ogni mese, dopo la fatturazione del giorno 1
 * (bin/chiusura-mese.php). In ordine:
 *   1. fatture non pagate oltre la scadenza -> scadute
 *   2. clienti morosi -> linee sospese
 *   3. clienti tornati in regola -> linee riattivate
 *   4. indennizzi ai clienti business per i guasti lunghi -> note di credito
 *   5. provvigioni dei rivenditori
 *   6. report html in var/report/
 *
 * 2016 prima versione (scadute e morosi) - 2018 indennizzi - 2019 provvigioni
 * 2021 report html - 2023 opzione simula per le prove
 * NB: non spezzare in piu funzioni, il vecchio script di backup la chiama per nome
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';
require_once dirname(__FILE__) . '/provvigioni.inc.php';

function chiusura_mese($anno, $mese, $opzioni = array())
{
    global $IVA, $GG_SCADENZA, $SOGLIA_MOROSITA, $NOME_AZIENDA, $MESI, $DEBUG;

    $periodo = sprintf('%04d-%02d', $anno, $mese);
    $simula = !empty($opzioni['simula']);
    $oggi = isset($opzioni['oggi']) ? $opzioni['oggi'] : date('Y-m-d');
    $verbose = isset($opzioni['verbose']) ? $opzioni['verbose'] : true;
    $tot_count = 0;
    $num_scadute = 0;
    $tot_scaduto = 0;
    $clienti_suspended = array();
    $clienti_riattivati = array();
    $num_nc = 0;
    $tot_indennizzi = 0;
    $lista_nc = array();
    $righe_report = array();
    $warning = array();
    $html = '';

    if ($mese < 1 || $mese > 12) {
        echo "Mese non valido: $mese\n";
        return false;
    }
    if ($verbose) {
        echo "Chiusura del mese $periodo (data di riferimento $oggi)" . ($simula ? " - SIMULAZIONE" : "") . "\n";
    }
    if ($periodo >= substr($oggi, 0, 7)) {
        $warning[] = "il mese $periodo non e' ancora finito";
    }

    if (!$simula) {
        db()->beginTransaction();
    }

    // ------------------------------------------------------------------
    // 1. FATTURE SCADUTE
    // ------------------------------------------------------------------
    $res = db_query("SELECT f.id, f.cliente_id, f.scade_il, f.totale_cent, c.ragione_sociale, c.nome, c.cognome
                       FROM fatture f JOIN clienti c ON c.id = f.cliente_id
                      WHERE f.tipo = 'fattura' AND f.stato = 'emessa' AND f.scade_il < '$oggi'
                      ORDER BY f.id");
    while ($r = db_fetch($res)) {
        $num_scadute++;
        $tot_count++;
        $tot_scaduto += $r['totale_cent'];
        $righe_report[] = array(
            'cosa' => 'fattura scaduta',
            'rif' => $r['id'],
            'cliente' => $r['cliente_id'] . ' ' . nome_cliente($r),
            'dettaglio' => 'scaduta il ' . data_it($r['scade_il']) . ', ' . euro($r['totale_cent']),
        );
        if (!$simula) {
            db_exec("UPDATE fatture SET stato = 'scaduta' WHERE id = '" . $r['id'] . "'");
        }
    }
    if ($verbose) {
        echo "  fatture scadute: $num_scadute (" . strip_tags(euro($tot_scaduto)) . ")\n";
    }

    // ------------------------------------------------------------------
    // 2. MOROSI: almeno SOGLIA fatture scadute -> sospensione delle linee
    // ------------------------------------------------------------------
    $res = db_query("SELECT c.id, c.ragione_sociale, c.nome, c.cognome, COUNT(f.id) AS n
                       FROM clienti c JOIN fatture f ON f.cliente_id = c.id
                      WHERE c.stato = 'attivo' AND f.stato = 'scaduta' AND f.tipo = 'fattura'
                      GROUP BY c.id, c.ragione_sociale, c.nome, c.cognome
                      ORDER BY c.id");
    while ($r = db_fetch($res)) {
        if ($r['n'] < $SOGLIA_MOROSITA) {
            continue;
        }
        $clienti_suspended[] = $r['id'];
        $tot_count++;
        $righe_report[] = array(
            'cosa' => 'sospensione',
            'rif' => $r['id'],
            'cliente' => $r['id'] . ' ' . nome_cliente($r),
            'dettaglio' => $r['n'] . ' fatture scadute',
        );
        if (!$simula) {
            db_exec("UPDATE linee SET stato = 'sospesa' WHERE cliente_id = '" . $r['id'] . "' AND stato = 'attiva'");
            db_exec("UPDATE clienti SET stato = 'sospeso', note = 'Linea sospesa per morosità il "
                . date('d/m/Y', strtotime($oggi)) . ".' WHERE id = '" . $r['id'] . "'");
        }
    }
    if ($verbose) {
        echo "  clienti sospesi: " . count($clienti_suspended) . "\n";
    }

    // ------------------------------------------------------------------
    // 3. RIATTIVAZIONI: sospesi che non hanno piu fatture scadute
    // ------------------------------------------------------------------
    $res = db_query("SELECT c.id, c.ragione_sociale, c.nome, c.cognome FROM clienti c
                      WHERE c.stato = 'sospeso'
                        AND NOT EXISTS (SELECT 1 FROM fatture f WHERE f.cliente_id = c.id AND f.stato = 'scaduta')
                      ORDER BY c.id");
    while ($r = db_fetch($res)) {
        $clienti_riattivati[] = $r['id'];
        $tot_count++;
        $righe_report[] = array(
            'cosa' => 'riattivazione',
            'rif' => $r['id'],
            'cliente' => $r['id'] . ' ' . nome_cliente($r),
            'dettaglio' => 'nessuna fattura scaduta',
        );
        if (!$simula) {
            db_exec("UPDATE linee SET stato = 'attiva' WHERE cliente_id = '" . $r['id'] . "' AND stato = 'sospesa'");
            db_exec("UPDATE clienti SET stato = 'attivo', note = NULL WHERE id = '" . $r['id'] . "'");
        }
    }
    if ($verbose) {
        echo "  clienti riattivati: " . count($clienti_riattivati) . "\n";
    }

    // ------------------------------------------------------------------
    // 4. INDENNIZZI (clienti business): guasti chiusi nel mese durati piu di 24 ore.
    //    10 euro per ogni giorno, o frazione, oltre il primo; al massimo 100 euro.
    // ------------------------------------------------------------------
    $res = db_query("SELECT t.id, t.cliente_id, t.linea_id, t.aperto_il, t.chiuso_il
                       FROM ticket t JOIN clienti c ON c.id = t.cliente_id
                      WHERE c.tipo = 'azienda' AND t.categoria = 'guasto' AND t.stato = 'chiuso'
                        AND substr(t.chiuso_il, 1, 7) = '$periodo'
                      ORDER BY t.cliente_id, t.id");
    $indennizzi = array();
    while ($r = db_fetch($res)) {
        $ore = (strtotime($r['chiuso_il']) - strtotime($r['aperto_il'])) / 3600;
        if ($ore <= 24) {
            continue;
        }
        $gg = ceil(($ore - 24) / 24);
        $imp = $gg * 1000;
        if ($imp > 10000) {
            $imp = 10000;
        }
        $indennizzi[$r['cliente_id']][] = array('ticket' => $r['id'], 'linea' => $r['linea_id'], 'gg' => $gg,
                                                'importo' => (int)$imp, 'ore' => round($ore, 1));
    }
    foreach ($indennizzi as $cli => $lista) {
        // gia emessa per questo mese? (succede se si rilancia la chiusura)
        $gia = db_value("SELECT COUNT(*) FROM fatture WHERE cliente_id = '$cli' AND tipo = 'nota_credito'
                          AND periodo = '$periodo'");
        if ($gia > 0) {
            $warning[] = "nota di credito per $cli gia emessa per $periodo";
            continue;
        }
        $imponibile = 0;
        $descr_ticket = array();
        foreach ($lista as $x) {
            $imponibile -= $x['importo'];
            $descr_ticket[] = $x['ticket'] . ' (' . $x['ore'] . ' ore)';
        }
        $iva = (int)round($imponibile * $IVA / 100);
        $totale = $imponibile + $iva;
        $rif = db_value("SELECT id FROM fatture WHERE cliente_id = '$cli' AND periodo = '$periodo'
                          AND tipo = 'fattura'");
        $num_nc++;
        $tot_count++;
        $tot_indennizzi += -$totale;
        $id_nc = $simula ? '(simulazione)' : prossimo_numero_fattura(date('Y', strtotime($oggi)));
        $lista_nc[] = $id_nc;
        $righe_report[] = array(
            'cosa' => 'nota di credito',
            'rif' => $id_nc,
            'cliente' => $cli,
            'dettaglio' => implode(', ', $descr_ticket) . ': ' . euro($totale),
        );
        if ($simula) {
            continue;
        }
        $scade = date('Y-m-d', strtotime($oggi . ' +' . $GG_SCADENZA . ' days'));
        db_exec("INSERT INTO fatture (id, cliente_id, tipo, periodo, emessa_il, scade_il, imponibile_cent, iva_cent,
                                      totale_cent, stato, pagata_il, rif_fattura_id)
                 VALUES ('$id_nc', '$cli', 'nota_credito', '$periodo', '$oggi', '$scade', $imponibile, $iva, $totale,
                         'emessa', NULL, " . ($rif ? "'" . $rif . "'" : "NULL") . ")");
        foreach ($lista as $x) {
            db_exec("INSERT INTO righe_fattura (fattura_id, linea_id, voce, descrizione, quantita,
                                                prezzo_unitario_cent, importo_cent)
                     VALUES ('$id_nc', " . ($x['linea'] ? "'" . $x['linea'] . "'" : "NULL") . ", 'indennizzo',
                             'Indennizzo disservizio " . $x['ticket'] . " (" . $x['gg'] . " gg)', 1, "
                     . (-$x['importo']) . ", " . (-$x['importo']) . ")");
        }
        // vecchio calcolo (2018): una nota per ticket, non usare
        // foreach ($lista as $x) { crea_nota_credito($cli, $x['ticket'], $x['importo']); }
    }
    if ($verbose) {
        echo "  note di credito per indennizzi: $num_nc (" . strip_tags(euro(-$tot_indennizzi)) . ")\n";
    }

    // ------------------------------------------------------------------
    // 5. PROVVIGIONI RIVENDITORI
    // ------------------------------------------------------------------
    $provv = calcola_provvigioni_mese($anno, $mese, !$simula);
    $tot_provv = 0;
    if (is_array($provv)) {
        foreach ($provv as $rv => $p) {
            $tot_provv += $p['importo'];
            $righe_report[] = array(
                'cosa' => 'provvigione',
                'rif' => $rv,
                'cliente' => '',
                'dettaglio' => $p['casa'] . ' Casa, ' . $p['business'] . ' Business: ' . $p['importo'] . ' euro',
            );
        }
    } else {
        $warning[] = 'provvigioni non ricalcolate (mese gia liquidato)';
    }
    if ($verbose) {
        echo "  provvigioni: " . (is_array($provv) ? count($provv) . " rivenditori, $tot_provv euro" : "nessun ricalcolo")
            . "\n";
    }

    // ------------------------------------------------------------------
    // 6. REPORT HTML
    // ------------------------------------------------------------------
    $html = "<!DOCTYPE html>\n<html lang='it'><head><meta charset='utf-8'><title>Chiusura " . $periodo
        . "</title></head><body>\n";
    $html .= "<h1>" . $NOME_AZIENDA . " - chiusura di " . $MESI[(int)$mese] . " " . $anno . "</h1>\n";
    $html .= "<p>Data di riferimento: " . data_it($oggi) . ($simula ? " <b>(simulazione)</b>" : "") . "</p>\n";
    $html .= "<table border='1' cellpadding='4' cellspacing='0'>\n";
    $html .= "<tr><th>Fatture scadute</th><td>" . $num_scadute . "</td><td>" . euro($tot_scaduto) . "</td></tr>\n";
    $html .= "<tr><th>Clienti sospesi</th><td>" . count($clienti_suspended) . "</td><td>"
        . implode(', ', $clienti_suspended) . "</td></tr>\n";
    $html .= "<tr><th>Clienti riattivati</th><td>" . count($clienti_riattivati) . "</td><td>"
        . implode(', ', $clienti_riattivati) . "</td></tr>\n";
    $html .= "<tr><th>Note di credito</th><td>" . $num_nc . "</td><td>" . euro(-$tot_indennizzi) . "</td></tr>\n";
    $html .= "<tr><th>Provvigioni</th><td>" . (is_array($provv) ? count($provv) : '-') . "</td><td>" . $tot_provv
        . " &euro;</td></tr>\n";
    $html .= "</table>\n";
    if (count($warning) > 0) {
        $html .= "<h3 style='color:orange'>Avvisi</h3><ul>";
        foreach ($warning as $w) {
            $html .= "<li>" . $w . "</li>";
        }
        $html .= "</ul>\n";
    }
    $html .= "<h2>Dettaglio (" . $tot_count . " operazioni)</h2>\n";
    $html .= tabella_html($righe_report, array('cosa' => 'Operazione', 'rif' => 'Riferimento',
                                               'cliente' => 'Cliente', 'dettaglio' => 'Dettaglio'));
    $html .= "<p><small>generato il " . date('d/m/Y H:i') . "</small></p>\n</body></html>\n";

    if ($simula) {
        if ($DEBUG) {
            echo $html;
        }
    } else {
        $cartella = dirname(__FILE__) . '/../var/report';
        if (!is_dir($cartella)) {
            @mkdir($cartella, 0775, true);
        }
        $file = $cartella . '/chiusura-' . $periodo . '.html';
        if (@file_put_contents($file, $html) === false) {
            $warning[] = 'report non scritto: ' . $file;
        } elseif ($verbose) {
            echo "  report: " . $file . "\n";
        }
        log_operazione('chiusura', 'chiusura ' . $periodo . ': ' . $num_scadute . ' scadute, '
            . count($clienti_suspended) . ' sospesi, ' . count($clienti_riattivati) . ' riattivati, '
            . $num_nc . ' note di credito');
        db()->commit();
    }

    foreach ($warning as $w) {
        if ($verbose) {
            echo "  ATTENZIONE: " . $w . "\n";
        }
    }

    return array(
        'periodo' => $periodo,
        'scadute' => $num_scadute,
        'sospesi' => $clienti_suspended,
        'riattivati' => $clienti_riattivati,
        'note_credito' => $lista_nc,
        'provvigioni' => $provv,
        'operazioni' => $tot_count,
    );
}
