<?php

declare(strict_types=1);

/*
 * Ingresso unico del gestionale web: index.php?pagina=...
 * Avvio in locale: tools/php.sh serve public 8080
 */

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Web\AttivazioniController;
use CiaspoLink\Gestionale\Web\CruscottoController;
use CiaspoLink\Gestionale\Web\TicketController;
use CiaspoLink\Gestionale\Web\Vista;

require __DIR__ . '/../vendor/autoload.php';

// pagine servite ancora dal vecchio gestionale (cartella legacy/)
$pagineLegacy = [
    'clienti' => 'clienti_lista.php',
    'cliente' => 'cliente_scheda.php',
    'fattura' => 'fattura_stampa.php',
    'nuovo-ticket' => 'ticket_nuovo.php',
];

$pagina = (string) ($_GET['pagina'] ?? 'cruscotto');
if (isset($pagineLegacy[$pagina])) {
    require __DIR__ . '/../legacy/' . $pagineLegacy[$pagina];
    return;
}

$applicazione = Applicazione::avvia();
$vista = new Vista(__DIR__ . '/../templates');
$metodo = (string) ($_SERVER['REQUEST_METHOD'] ?? 'GET');

$rotte = [
    'cruscotto' => static fn (): string => (new CruscottoController($applicazione, $vista))->home(),
    'copertura' => static fn (): string => (new CruscottoController($applicazione, $vista))->copertura($_GET),
    'report-fatturato' => static fn (): string => (new CruscottoController($applicazione, $vista))
        ->reportFatturato($_GET),
    'provvigioni' => static fn (): string => (new CruscottoController($applicazione, $vista))->provvigioni($_GET),
    'ticket' => static fn (): string => (new TicketController($applicazione, $vista))->elenco($_GET),
    'ticket-dettaglio' => static fn (): string => (new TicketController($applicazione, $vista))
        ->dettaglio($_GET, $_POST, $metodo),
    'attivazioni' => static fn (): string => (new AttivazioniController($applicazione, $vista))
        ->elenco($_POST, $metodo),
];

if (!isset($rotte[$pagina])) {
    http_response_code(404);
    echo $vista->mostra('errore', ['titolo' => 'Pagina inesistente', 'messaggio' => 'La pagina richiesta non esiste.']);
    return;
}

try {
    echo $rotte[$pagina]();
} catch (RuntimeException $errore) {
    http_response_code(500);
    echo $vista->mostra('errore', ['titolo' => 'Errore', 'messaggio' => $errore->getMessage()]);
}
