<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

enum PrioritaTicket: string
{
    case Bassa = 'bassa';
    case Media = 'media';
    case Alta = 'alta';
    case Critica = 'critica';

    /**
     * Ore entro cui prendere in carico il ticket.
     */
    public function orePresaInCarico(): int
    {
        return match ($this) {
            self::Critica => 1,
            self::Alta => 4,
            self::Media => 8,
            self::Bassa => 24,
        };
    }
}
