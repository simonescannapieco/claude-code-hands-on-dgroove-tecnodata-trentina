<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Clienti;

enum TipoCliente: string
{
    case Privato = 'privato';
    case Azienda = 'azienda';
    case Associazione = 'associazione';

    public function etichetta(): string
    {
        return match ($this) {
            self::Privato => 'Privato',
            self::Azienda => 'Azienda',
            self::Associazione => 'Associazione',
        };
    }
}
