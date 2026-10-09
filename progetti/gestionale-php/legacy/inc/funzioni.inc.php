<?php
/*
 * funzioni.inc.php - funzioni di utilita usate un po' ovunque
 */

require_once dirname(__FILE__) . '/config.inc.php';
require_once dirname(__FILE__) . '/db.inc.php';

// importo in centesimi -> "1.234,56 €"
function euro($cent)
{
    return number_format($cent / 100, 2, ',', '.') . ' &euro;';
}

// importo in euro (float) -> "1.234,56" (usata dalla stampa fattura)
function formatta_euro($valore)
{
    return number_format($valore, 2, ',', '.');
}

// 2026-09-08 o 2026-09-08T10:12:00+02:00 -> 08/09/2026
function data_it($d)
{
    if ($d == '') {
        return '';
    }
    return date('d/m/Y', strtotime($d));
}

function data_ora_it($d)
{
    if ($d == '') {
        return '';
    }
    return date('d/m/Y H:i', strtotime($d));
}

function mese_italiano($m)
{
    global $MESI;
    return $MESI[(int)$m];
}

// nome da mostrare: ragione sociale per le aziende, nome e cognome per i privati
function nome_cliente($r)
{
    if (isset($r['ragione_sociale']) && $r['ragione_sociale'] != '') {
        return $r['ragione_sociale'];
    }
    return trim($r['nome'] . ' ' . $r['cognome']);
}

function stato_badge($stato)
{
    $colori = array(
        'attivo' => 'green', 'attiva' => 'green', 'pagata' => 'green', 'chiuso' => 'gray',
        'sospeso' => 'orange', 'sospesa' => 'orange', 'emessa' => 'blue', 'aperto' => 'red',
        'scaduta' => 'red', 'cessato' => 'gray', 'cessata' => 'gray',
    );
    $c = isset($colori[$stato]) ? $colori[$stato] : 'black';
    return "<span style='color:" . $c . ";font-weight:bold'>" . $stato . "</span>";
}

// iva di una riga, in euro arrotondata al centesimo
function calcola_iva($imponibile)
{
    global $IVA;
    return round($imponibile * $IVA / 100, 2);
}

function giorni_tra($d1, $d2)
{
    return (int)floor((strtotime($d2) - strtotime($d1)) / 86400);
}

function pulisci($s)
{
    return trim(strip_tags($s));
}

function redirect($url)
{
    header('Location: ' . $url);
    exit;
}

// moroso = almeno una fattura scaduta
function is_moroso($cliente_id)
{
    $n = db_value("SELECT COUNT(*) FROM fatture WHERE cliente_id = '" . db_escape($cliente_id)
        . "' AND stato = 'scaduta' AND tipo = 'fattura'");
    return $n >= 1;
}

function nome_servizio($cod)
{
    $nome = db_value("SELECT nome FROM servizi WHERE codice = '" . db_escape($cod) . "'");
    return $nome ? $nome : $cod;
}

function nome_offerta($cod)
{
    $nome = db_value("SELECT nome FROM offerte WHERE codice = '" . db_escape($cod) . "'");
    return $nome ? $nome : $cod;
}

// FT-2026-000123: prossimo numero dell'anno
function prossimo_numero_fattura($anno)
{
    $ultimo = db_value("SELECT id FROM fatture WHERE id LIKE 'FT-" . $anno . "-%' ORDER BY id DESC LIMIT 1");
    $n = $ultimo ? (int)substr($ultimo, 8) + 1 : 1;
    return 'FT-' . $anno . '-' . str_pad($n, 6, '0', STR_PAD_LEFT);
}

// TK-2026-00123: stessa cosa per i ticket
function prossimo_numero_ticket($anno)
{
    $ultimo = db_value("SELECT id FROM ticket WHERE id LIKE 'TK-" . $anno . "-%' ORDER BY id DESC LIMIT 1");
    $n = $ultimo ? (int)substr($ultimo, 8) + 1 : 1;
    return 'TK-' . $anno . '-' . str_pad($n, 5, '0', STR_PAD_LEFT);
}

// tabella html veloce: $colonne = array('campo' => 'Intestazione')
function tabella_html($righe, $colonne)
{
    $h = "<table border='1' cellpadding='3' cellspacing='0'><tr>";
    foreach ($colonne as $campo => $titolo) {
        $h .= "<th>" . $titolo . "</th>";
    }
    $h .= "</tr>\n";
    foreach ($righe as $r) {
        $h .= "<tr>";
        foreach ($colonne as $campo => $titolo) {
            $h .= "<td>" . (isset($r[$campo]) ? $r[$campo] : '') . "</td>";
        }
        $h .= "</tr>\n";
    }
    return $h . "</table>\n";
}
