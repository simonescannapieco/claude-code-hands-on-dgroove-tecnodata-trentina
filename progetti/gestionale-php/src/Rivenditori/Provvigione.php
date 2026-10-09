<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Rivenditori;

final class Provvigione
{
    public function __construct(
        public readonly string $rivenditoreId,
        public readonly string $ragioneSociale,
        public readonly string $periodo,
        public readonly int $attivazioniCasa,
        public readonly int $attivazioniBusiness,
        public readonly int $importoCent,
    ) {
    }
}
