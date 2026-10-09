<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

/**
 * Fattura o nota di credito, con le sue righe.
 */
final class Fattura
{
    /**
     * @param list<RigaFattura> $righe
     */
    public function __construct(
        public readonly string $id,
        public readonly string $clienteId,
        /** fattura o nota_credito */
        public readonly string $tipo,
        public readonly ?string $periodo,
        public readonly string $emessaIl,
        public readonly string $scadeIl,
        public readonly Totali $totali,
        /** emessa, pagata, scaduta o annullata */
        public readonly string $stato,
        public readonly ?string $pagataIl,
        public readonly array $righe,
    ) {
    }

    /**
     * @param array<string, mixed> $riga
     * @param list<RigaFattura> $righe
     */
    public static function daRiga(array $riga, array $righe): self
    {
        return new self(
            (string) $riga['id'],
            (string) $riga['cliente_id'],
            (string) $riga['tipo'],
            $riga['periodo'] === null ? null : (string) $riga['periodo'],
            (string) $riga['emessa_il'],
            (string) $riga['scade_il'],
            new Totali((int) $riga['imponibile_cent'], (int) $riga['iva_cent'], (int) $riga['totale_cent']),
            (string) $riga['stato'],
            $riga['pagata_il'] === null ? null : (string) $riga['pagata_il'],
            $righe,
        );
    }
}
