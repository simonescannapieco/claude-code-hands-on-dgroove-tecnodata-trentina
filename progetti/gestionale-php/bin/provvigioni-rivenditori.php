<?php

declare(strict_types=1);

/*
 * Calcola e registra le provvigioni dei rivenditori per un mese (di norma il
 * precedente) con il modulo del vecchio gestionale, legacy/provvigioni.inc.php.
 * Usa il database di var/gestionale.sqlite (il percorso è scritto nel modulo).
 *
 * Uso: php bin/provvigioni-rivenditori.php [--periodo=AAAA-MM] [--simula]
 * Uscita: 0 fatto; 1 mese già liquidato; 2 errore.
 */

use CiaspoLink\Gestionale\Support\Periodo;

require __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../legacy/provvigioni.inc.php';

$opzioni = getopt('', ['periodo:', 'simula']);
try {
    $periodo = isset($opzioni['periodo'])
        ? Periodo::da((string) $opzioni['periodo'])
        : Periodo::di(new DateTimeImmutable('first day of last month'));
} catch (InvalidArgumentException $errore) {
    fwrite(STDERR, $errore->getMessage() . "\n");
    exit(2);
}

$risultato = calcola_provvigioni_mese($periodo->anno, $periodo->mese, !isset($opzioni['simula']));
if ($risultato === false) {
    exit(1);
}
foreach ($risultato as $rivenditore => $riga) {
    fwrite(STDOUT, sprintf(
        "%s  Casa %2d  Business %2d  %6d euro\n",
        $rivenditore,
        $riga['casa'],
        $riga['business'],
        $riga['importo'],
    ));
}
fwrite(STDOUT, sprintf(
    "%d rivenditori per %s%s\n",
    count($risultato),
    $periodo,
    isset($opzioni['simula']) ? ' (simulazione)' : '',
));
exit(0);
