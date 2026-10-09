<?php

declare(strict_types=1);

/*
 * Fatturazione mensile: una fattura per cliente con le linee in servizio nel
 * mese. Gira il giorno 1 di ogni mese per il mese precedente.
 *
 * Uso: php bin/fatturazione-mensile.php [--periodo=AAAA-MM] [--simula] [--dettaglio] [--db=percorso]
 * Uscita: 0 fatto; 2 errore (periodo non valido, database mancante).
 */

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Support\Periodo;

require __DIR__ . '/../vendor/autoload.php';

$opzioni = getopt('', ['periodo:', 'simula', 'dettaglio', 'db:']);
$applicazione = Applicazione::avvia(isset($opzioni['db']) ? ['db_path' => (string) $opzioni['db']] : []);
$simulazione = isset($opzioni['simula']);

try {
    $periodo = isset($opzioni['periodo'])
        ? Periodo::da((string) $opzioni['periodo'])
        : Periodo::di(new DateTimeImmutable('first day of last month'));
    $fatture = $applicazione->generatoreFatture()->emetti($periodo, $simulazione);
} catch (InvalidArgumentException | RuntimeException $errore) {
    fwrite(STDERR, 'Fatturazione non eseguita: ' . $errore->getMessage() . "\n");
    exit(2);
}

$euro = static fn (int $centesimi): string => number_format($centesimi / 100, 2, ',', '.');
$somma = ['imponibile' => 0, 'iva' => 0, 'totale' => 0];
foreach ($fatture as $fattura) {
    $somma['imponibile'] += $fattura->totali->imponibileCent;
    $somma['iva'] += $fattura->totali->ivaCent;
    $somma['totale'] += $fattura->totali->totaleCent;
    if (isset($opzioni['dettaglio'])) {
        fwrite(STDOUT, sprintf(
            "%s %s %10s %10s %10s\n",
            $fattura->id,
            $fattura->clienteId,
            $euro($fattura->totali->imponibileCent),
            $euro($fattura->totali->ivaCent),
            $euro($fattura->totali->totaleCent),
        ));
    }
}
fwrite(STDOUT, sprintf(
    "%s %d fatture per %s: imponibile %s, IVA %s, totale %s euro\n",
    $simulazione ? 'Simulazione:' : 'Emesse',
    count($fatture),
    $periodo,
    $euro($somma['imponibile']),
    $euro($somma['iva']),
    $euro($somma['totale']),
));
exit(0);
