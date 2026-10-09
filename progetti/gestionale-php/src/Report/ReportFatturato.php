<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Report;

use CiaspoLink\Gestionale\Clienti\ClienteRepository;
use CiaspoLink\Gestionale\Fatturazione\FatturaRepository;
use CiaspoLink\Gestionale\Support\Periodo;

/**
 * Fatturato per zona commerciale in un intervallo di mesi, note di credito
 * comprese (con importi negativi).
 */
final class ReportFatturato
{
    public function __construct(
        private readonly ClienteRepository $clienti,
        private readonly FatturaRepository $fatture,
    ) {
    }

    /**
     * @return list<array{zona: string, clienti: int, documenti: int, imponibile: int, iva: int, totale: int}>
     */
    public function perZona(Periodo $dal, Periodo $al): array
    {
        $righe = [];
        foreach ($this->clienti->tutti() as $cliente) {
            $fatturato = false;
            foreach ($this->fatture->perCliente($cliente->id) as $fattura) {
                $periodo = $fattura->periodo;
                if ($periodo === null || $periodo < (string) $dal || $periodo > (string) $al) {
                    continue;
                }
                $riga = $righe[$cliente->zona] ?? [
                    'zona' => $cliente->zona,
                    'clienti' => 0,
                    'documenti' => 0,
                    'imponibile' => 0,
                    'iva' => 0,
                    'totale' => 0,
                ];
                $riga['clienti'] += $fatturato ? 0 : 1;
                $riga['documenti']++;
                $riga['imponibile'] += $fattura->totali->imponibileCent;
                $riga['iva'] += $fattura->totali->ivaCent;
                $riga['totale'] += $fattura->totali->totaleCent;
                $righe[$cliente->zona] = $riga;
                $fatturato = true;
            }
        }
        ksort($righe);

        return array_values($righe);
    }
}
