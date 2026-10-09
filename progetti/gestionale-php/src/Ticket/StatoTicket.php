<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

enum StatoTicket: string
{
    case Aperto = 'aperto';
    case InLavorazione = 'in_lavorazione';
    case InAttesaCliente = 'in_attesa_cliente';
    case Risolto = 'risolto';
    case Chiuso = 'chiuso';

    public function isAperto(): bool
    {
        return $this !== self::Risolto && $this !== self::Chiuso;
    }

    public function etichetta(): string
    {
        return match ($this) {
            self::Aperto => 'Aperto',
            self::InLavorazione => 'In lavorazione',
            self::InAttesaCliente => 'In attesa del cliente',
            self::Risolto => 'Risolto',
            self::Chiuso => 'Chiuso',
        };
    }
}
