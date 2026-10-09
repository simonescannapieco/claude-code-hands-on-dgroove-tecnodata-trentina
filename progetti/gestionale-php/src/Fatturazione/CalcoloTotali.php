<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

/**
 * Totali di un documento: imponibile, IVA al 22 % e totale, in centesimi.
 */
final class CalcoloTotali
{
    public const ALIQUOTA_IVA = 22;

    /**
     * @param list<RigaFattura> $righe
     */
    public function calcola(array $righe): Totali
    {
        $imponibile = 0;
        foreach ($righe as $riga) {
            $imponibile += $riga->importoCent;
        }
        $iva = (int) ($imponibile * self::ALIQUOTA_IVA / 100);

        return new Totali($imponibile, $iva, $imponibile + $iva);
    }
}
