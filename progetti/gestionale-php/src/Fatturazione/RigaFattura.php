<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

final class RigaFattura
{
    public function __construct(
        /** canone, rateo, servizio, attivazione, sconto, indennizzo o storno */
        public readonly string $voce,
        public readonly string $descrizione,
        public readonly int $quantita,
        public readonly int $prezzoUnitarioCent,
        public readonly int $importoCent,
        public readonly ?string $lineaId = null,
    ) {
    }

    /**
     * @param array<string, mixed> $riga
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['voce'],
            (string) $riga['descrizione'],
            (int) $riga['quantita'],
            (int) $riga['prezzo_unitario_cent'],
            (int) $riga['importo_cent'],
            $riga['linea_id'] === null ? null : (string) $riga['linea_id'],
        );
    }
}
