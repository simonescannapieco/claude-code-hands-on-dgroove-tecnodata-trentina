<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Copertura;

use CiaspoLink\Gestionale\Offerte\Offerta;
use CiaspoLink\Gestionale\Offerte\Tecnologia;

final class EsitoCopertura
{
    /**
     * @param list<Offerta> $offerte offerte vendibili all'indirizzo
     */
    public function __construct(
        public readonly bool $coperto,
        public readonly ?Tecnologia $tecnologia,
        public readonly int $velocitaMaxMbps,
        public readonly ?string $apparatoId,
        public readonly ?string $pianificataTecnologia,
        public readonly array $offerte,
    ) {
    }

    public static function nonCoperto(?string $pianificataTecnologia = null): self
    {
        return new self(false, null, 0, null, $pianificataTecnologia, []);
    }

    public function messaggio(): string
    {
        if ($this->coperto && $this->tecnologia !== null) {
            return sprintf(
                'Indirizzo coperto: %s fino a %s.',
                $this->tecnologia->etichetta(),
                $this->velocitaMaxMbps >= 1000
                    ? str_replace('.', ',', (string) ($this->velocitaMaxMbps / 1000)) . ' Gbit/s'
                    : $this->velocitaMaxMbps . ' Mbit/s',
            );
        }
        if ($this->pianificataTecnologia !== null) {
            return sprintf('Indirizzo non ancora coperto: %s pianificata.', $this->pianificataTecnologia);
        }

        return 'Indirizzo non coperto.';
    }
}
