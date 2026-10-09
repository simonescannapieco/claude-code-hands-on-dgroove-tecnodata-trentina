<?php
/*
 * db.inc.php - accesso al database
 *
 * Nato con le funzioni mysql_*, convertito a PDO + SQLite nel 2019 tenendo gli
 * stessi nomi di funzione per non dover toccare tutte le pagine.
 */

require_once dirname(__FILE__) . '/config.inc.php';

global $db;

function db()
{
    global $db, $DB_FILE;
    if (!$db) {
        // connessione pigra (2021): la parte nuova imposta $db prima di chiamarci
        if (!file_exists($DB_FILE)) {
            die("Database non trovato: " . $DB_FILE . "\n");
        }
        $db = new PDO('sqlite:' . $DB_FILE);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_SILENT);
        $db->exec('PRAGMA foreign_keys = ON');
    }
    return $db;
}

function db_query($sql)
{
    global $DEBUG;
    if ($DEBUG) {
        echo "<pre>" . $sql . "</pre>";
    }
    $res = db()->query($sql);
    if ($res === false) {
        $err = db()->errorInfo();
        die("Errore nella query: " . $sql . "<br>\n" . $err[2]);
    }
    return $res;
}

function db_exec($sql)
{
    global $DEBUG;
    if ($DEBUG) {
        echo "<pre>" . $sql . "</pre>";
    }
    $n = db()->exec($sql);
    if ($n === false) {
        $err = db()->errorInfo();
        die("Errore nella query: " . $sql . "<br>\n" . $err[2]);
    }
    return $n;
}

function db_fetch($res)
{
    return $res->fetch(PDO::FETCH_ASSOC);
}

function db_fetch_all($res)
{
    return $res->fetchAll(PDO::FETCH_ASSOC);
}

// primo campo della prima riga, o null
function db_value($sql)
{
    $res = db_query($sql);
    $row = $res->fetch(PDO::FETCH_NUM);
    if (!$row) {
        return null;
    }
    return $row[0];
}

// per i valori da mettere nelle query (era mysql_escape_string)
function db_escape($s)
{
    return addslashes($s);
}

function log_operazione($modulo, $msg)
{
    db_exec("INSERT INTO registro_operazioni (quando, modulo, messaggio) VALUES ('" . date('Y-m-d H:i:s')
        . "', '" . db_escape($modulo) . "', '" . db_escape($msg) . "')");
}
