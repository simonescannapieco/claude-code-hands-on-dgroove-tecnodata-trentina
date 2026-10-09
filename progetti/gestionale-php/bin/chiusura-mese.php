<?php

declare(strict_types=1);

/*
 * Chiusura di fine mese con il modulo del vecchio gestionale
 * (legacy/chiusura_mese.inc.php): fatture scadute, sospensioni per morosità,
 * riattivazioni, indennizzi, provvigioni e report in var/report/. Gira il
 * giorno 2 di ogni mese per il mese precedente.
 *
 * Uso: php bin/chiusura-mese.php [--periodo=AAAA-MM] [--oggi=AAAA-MM-GG] [--simula]
 * Uscita: 0 fatto; 2 errore.
 */

use CiaspoLink\Gestionale\Support\Periodo;

require __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../legacy/chiusura_mese.inc.php';

$opzioni = getopt('', ['periodo:', 'oggi:', 'simula']);
try {
    $periodo = isset($opzioni['periodo'])
        ? Periodo::da((string) $opzioni['periodo'])
        : Periodo::di(new DateTimeImmutable('first day of last month'));
} catch (InvalidArgumentException $errore) {
    fwrite(STDERR, $errore->getMessage() . "\n");
    exit(2);
}
$oggi = (string) ($opzioni['oggi'] ?? date('Y-m-d'));
if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $oggi) !== 1) {
    fwrite(STDERR, "Data non valida: {$oggi} (atteso AAAA-MM-GG)\n");
    exit(2);
}

$esito = chiusura_mese($periodo->anno, $periodo->mese, ['simula' => isset($opzioni['simula']), 'oggi' => $oggi]);
exit($esito === false ? 2 : 0);
