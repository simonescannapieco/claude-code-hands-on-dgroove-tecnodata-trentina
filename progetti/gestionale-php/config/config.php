<?php

declare(strict_types=1);

/*
 * Configurazione del gestionale, letta da src/Applicazione.php. I percorsi
 * partono dalla cartella del progetto; var/ non va nel repository.
 */

return [
    'db_path' => dirname(__DIR__) . '/var/gestionale.sqlite',
    'timezone' => 'Europe/Rome',
    'esportazioni_dir' => dirname(__DIR__) . '/var/esportazioni',
    'azienda' => [
        'ragione_sociale' => 'CiaspoLink S.r.l.',
        'indirizzo' => "Via dell'Esempio 1, 38051 Borgo Valsugana (TN)",
        'partita_iva' => '00000000001',
        'email' => 'amministrazione@example.org',
        'telefono' => '+39 000 000 0001',
    ],
];
