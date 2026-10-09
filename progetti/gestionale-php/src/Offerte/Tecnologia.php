<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Offerte;

enum Tecnologia: string
{
    case Ftth = 'FTTH';
    case Fwa = 'FWA';

    public function etichetta(): string
    {
        return match ($this) {
            self::Ftth => 'Fibra fino a casa (FTTH)',
            self::Fwa => 'Radio (FWA)',
        };
    }

    /**
     * A parità di indirizzo si propone la fibra prima della radio.
     */
    public function priorita(): int
    {
        return match ($this) {
            self::Ftth => 1,
            self::Fwa => 2,
        };
    }
}
