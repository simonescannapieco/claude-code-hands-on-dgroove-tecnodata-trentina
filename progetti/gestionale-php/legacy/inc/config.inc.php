<?php
/*
 * config.inc.php - configurazione del vecchio gestionale
 *
 * Incluso da tutte le pagine di legacy/ e dagli script di fine mese.
 * ATTENZIONE: questi file vengono inclusi anche da dentro funzioni e metodi
 * (vedi src/Legacy): le variabili vanno dichiarate global, altrimenti restano locali.
 */

global $DB_FILE, $NOME_AZIENDA, $IVA, $GG_SCADENZA, $SOGLIA_MOROSITA, $DEBUG, $MESI;

// TODO: leggere il percorso da config/config.php come fa la parte nuova
$DB_FILE = dirname(__FILE__) . '/../../var/gestionale.sqlite';

$NOME_AZIENDA = 'CiaspoLink S.r.l.';
$IVA = 22;               // percentuale
$GG_SCADENZA = 30;       // giorni per pagare
$SOGLIA_MOROSITA = 2;    // fatture scadute oltre le quali si sospende la linea
$DEBUG = false;          // true = stampa le query

$MESI = array(1 => 'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio',
              'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre');

if (!ini_get('date.timezone')) {
    date_default_timezone_set('Europe/Rome');
}
