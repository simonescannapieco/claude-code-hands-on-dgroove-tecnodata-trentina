<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Support;

use DateTimeImmutable;
use InvalidArgumentException;
use Stringable;

/**
 * Un mese di calendario, scritto AAAA-MM: il periodo di fatturazione e di
 * calcolo delle provvigioni.
 */
final class Periodo implements Stringable
{
    private function __construct(
        public readonly int $anno,
        public readonly int $mese,
    ) {
    }

    /**
     * @throws InvalidArgumentException se il testo non è nel formato AAAA-MM
     */
    public static function da(string $periodo): self
    {
        if (preg_match('/^(\d{4})-(0[1-9]|1[0-2])$/', $periodo, $parti) !== 1) {
            throw new InvalidArgumentException(sprintf('Periodo non valido: «%s» (atteso AAAA-MM)', $periodo));
        }

        return new self((int) $parti[1], (int) $parti[2]);
    }

    public static function di(DateTimeImmutable $giorno): self
    {
        return new self((int) $giorno->format('Y'), (int) $giorno->format('n'));
    }

    public function primoGiorno(): DateTimeImmutable
    {
        return new DateTimeImmutable(sprintf('%04d-%02d-01 00:00:00', $this->anno, $this->mese));
    }

    public function ultimoGiorno(): DateTimeImmutable
    {
        return $this->primoGiorno()->modify('last day of this month');
    }

    public function giorni(): int
    {
        return (int) $this->primoGiorno()->format('t');
    }

    public function precedente(): self
    {
        return self::di($this->primoGiorno()->modify('-1 month'));
    }

    public function successivo(): self
    {
        return self::di($this->primoGiorno()->modify('+1 month'));
    }

    public function __toString(): string
    {
        return sprintf('%04d-%02d', $this->anno, $this->mese);
    }
}
