<?php

declare(strict_types=1);

/*
 * Esporta in CSV le attivazioni completate in un giorno (di norma ieri): il
 * file che ogni notte va al magazzino e ai rivenditori.
 *
 * Uso: php bin/esporta-attivazioni.php [--giorno=AAAA-MM-GG] [--uscita=file.csv] [--db=percorso]
 * Uscita: 0 fatto (anche con zero attivazioni); 2 errore.
 */

use CiaspoLink\Gestionale\Applicazione;

require __DIR__ . '/../vendor/autoload.php';

$opzioni = getopt('', ['giorno:', 'uscita:', 'db:']);
$applicazione = Applicazione::avvia(isset($opzioni['db']) ? ['db_path' => (string) $opzioni['db']] : []);

$giorno = (string) ($opzioni['giorno'] ?? (new DateTimeImmutable('yesterday'))->format('Y-m-d'));
if (
    preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $giorno, $parti) !== 1
    || !checkdate((int) $parti[2], (int) $parti[3], (int) $parti[1])
) {
    fwrite(STDERR, "Giorno non valido: {$giorno} (atteso AAAA-MM-GG)\n");
    exit(2);
}

$uscita = (string) ($opzioni['uscita'] ?? $applicazione->cartellaEsportazioni() . "/attivazioni-{$giorno}.csv");
$cartella = dirname($uscita);
if (!is_dir($cartella) && !mkdir($cartella, 0775, true)) {
    fwrite(STDERR, "Impossibile creare la cartella {$cartella}\n");
    exit(2);
}

try {
    $quante = $applicazione->esportatoreAttivazioni()->esporta($giorno, $uscita);
} catch (RuntimeException $errore) {
    fwrite(STDERR, 'Esportazione non eseguita: ' . $errore->getMessage() . "\n");
    exit(2);
}
fwrite(STDOUT, "{$quante} attivazioni completate il {$giorno} esportate in {$uscita}\n");
exit(0);
