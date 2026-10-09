<?php

declare(strict_types=1);

/*
 * Crea il database SQLite da database/schema.sql e dai dati di database/dati/.
 *
 * Uso: php bin/inizializza-db.php [--db=percorso] [--forza] [--senza-dati]
 * Uscita: 0 database creato; 1 il file esiste già (usa --forza); 2 errore.
 */

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Database\Connessione;

require __DIR__ . '/../vendor/autoload.php';

$opzioni = getopt('', ['db:', 'forza', 'senza-dati']);
$percorso = (string) ($opzioni['db'] ?? Applicazione::avvia()->percorsoDatabase());

if (is_file($percorso)) {
    if (!isset($opzioni['forza'])) {
        fwrite(STDERR, "Il database esiste già: {$percorso} (usa --forza per ricrearlo)\n");
        exit(1);
    }
    unlink($percorso);
}
$cartella = dirname($percorso);
if (!is_dir($cartella) && !mkdir($cartella, 0775, true)) {
    fwrite(STDERR, "Impossibile creare la cartella {$cartella}\n");
    exit(2);
}

try {
    $pdo = Connessione::crea($percorso);
    Connessione::inizializza($pdo, __DIR__ . '/../database', !isset($opzioni['senza-dati']));
} catch (Throwable $errore) {
    if (is_file($percorso)) {
        unlink($percorso);
    }
    fwrite(STDERR, 'Database non creato: ' . $errore->getMessage() . "\n");
    exit(2);
}

$conteggi = [];
foreach (['clienti', 'linee', 'attivazioni', 'ticket', 'fatture'] as $tabella) {
    $conteggi[] = $tabella . ' ' . $pdo->query('SELECT COUNT(*) FROM ' . $tabella)->fetchColumn();
}
fwrite(STDOUT, "Database creato: {$percorso}\n" . implode(', ', $conteggi) . "\n");
exit(0);
