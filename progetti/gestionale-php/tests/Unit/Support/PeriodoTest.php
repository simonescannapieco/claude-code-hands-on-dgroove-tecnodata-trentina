<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Unit\Support;

use CiaspoLink\Gestionale\Support\Periodo;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class PeriodoTest extends TestCase
{
    public function testLeggeIlFormatoAnnoMese(): void
    {
        $periodo = Periodo::da('2026-02');

        self::assertSame(2026, $periodo->anno);
        self::assertSame(2, $periodo->mese);
        self::assertSame('2026-02', (string) $periodo);
    }

    /**
     * @return iterable<string, array{string, int}>
     */
    public static function mesi(): iterable
    {
        yield 'febbraio' => ['2026-02', 28];
        yield 'febbraio bisestile' => ['2024-02', 29];
        yield 'agosto' => ['2026-08', 31];
        yield 'settembre' => ['2026-09', 30];
    }

    #[DataProvider('mesi')]
    public function testContaIGiorniDelMese(string $periodo, int $giorni): void
    {
        self::assertSame($giorni, Periodo::da($periodo)->giorni());
    }

    public function testPrimoEUltimoGiorno(): void
    {
        $periodo = Periodo::da('2026-02');

        self::assertSame('2026-02-01', $periodo->primoGiorno()->format('Y-m-d'));
        self::assertSame('2026-02-28', $periodo->ultimoGiorno()->format('Y-m-d'));
    }

    public function testPrecedenteESuccessivoAttraversanoLAnno(): void
    {
        self::assertSame('2025-12', (string) Periodo::da('2026-01')->precedente());
        self::assertSame('2026-01', (string) Periodo::da('2025-12')->successivo());
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function nonValidi(): iterable
    {
        yield 'mese 13' => ['2026-13'];
        yield 'mese senza zero' => ['2026-1'];
        yield 'anno corto' => ['26-01'];
        yield 'data completa' => ['2026-01-15'];
    }

    #[DataProvider('nonValidi')]
    public function testRifiutaUnFormatoNonValido(string $testo): void
    {
        $this->expectException(InvalidArgumentException::class);

        Periodo::da($testo);
    }
}
