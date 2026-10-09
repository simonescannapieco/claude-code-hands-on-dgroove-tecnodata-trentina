<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Linee;

enum StatoLinea: string
{
    case InAttivazione = 'in_attivazione';
    case Attiva = 'attiva';
    case Sospesa = 'sospesa';
    case Cessata = 'cessata';
}
