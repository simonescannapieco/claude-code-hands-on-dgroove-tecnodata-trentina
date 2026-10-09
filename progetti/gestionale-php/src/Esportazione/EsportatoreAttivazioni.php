<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Esportazione;

use CiaspoLink\Gestionale\Attivazioni\AttivazioneRepository;
use RuntimeException;

/**
 * Esporta in CSV (separatore «;») le attivazioni completate in un giorno:
 * il file che ogni notte va al magazzino e ai rivenditori.
 */
final class EsportatoreAttivazioni
{
    private const INTESTAZIONE = [
        'attivazione', 'linea', 'cliente', 'offerta', 'comune', 'completata_il', 'tecnico', 'rivenditore',
    ];

    public function __construct(private readonly AttivazioneRepository $attivazioni)
    {
    }

    /**
     * @return int numero di attivazioni esportate
     *
     * @throws RuntimeException se il file non si può scrivere
     */
    public function esporta(string $giorno, string $fileCsv): int
    {
        $attivazioni = $this->attivazioni->completateIl($giorno);
        $file = @fopen($fileCsv, 'wb');
        if ($file === false) {
            throw new RuntimeException('Impossibile scrivere ' . $fileCsv);
        }
        try {
            fputcsv($file, self::INTESTAZIONE, ';', '"', '');
            foreach ($attivazioni as $attivazione) {
                fputcsv($file, [
                    $attivazione->id,
                    $attivazione->lineaId,
                    $attivazione->clienteId,
                    $attivazione->offertaCodice,
                    $attivazione->comune,
                    $attivazione->completataIl,
                    $attivazione->tecnico,
                    $attivazione->rivenditoreId,
                ], ';', '"', '');
            }
        } finally {
            fclose($file);
        }

        return count($attivazioni);
    }
}
