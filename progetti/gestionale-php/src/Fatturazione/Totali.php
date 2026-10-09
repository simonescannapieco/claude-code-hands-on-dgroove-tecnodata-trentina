<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

final class Totali
{
    public function __construct(
        public readonly int $imponibileCent,
        public readonly int $ivaCent,
        public readonly int $totaleCent,
    ) {
    }
}
