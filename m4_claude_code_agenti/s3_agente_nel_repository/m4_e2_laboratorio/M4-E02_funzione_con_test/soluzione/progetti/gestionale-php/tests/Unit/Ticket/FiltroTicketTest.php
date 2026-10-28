<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Unit\Ticket;

use CiaspoLink\Gestionale\Ticket\FiltroTicket;
use DateTimeImmutable;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class FiltroTicketTest extends TestCase
{
    public function testUnIntervalloRovesciatoERifiutato(): void
    {
        $this->expectException(InvalidArgumentException::class);

        new FiltroTicket(dal: new DateTimeImmutable('2026-09-13'), al: new DateTimeImmutable('2026-09-07'));
    }

    public function testUnSoloGiornoEUnIntervalloValido(): void
    {
        $giorno = new DateTimeImmutable('2026-09-08');

        $filtro = new FiltroTicket(dal: $giorno, al: $giorno);

        self::assertSame($giorno, $filtro->dal);
        self::assertSame($giorno, $filtro->al);
    }

    public function testLaPaginaLeggeApparatoEDate(): void
    {
        $filtro = FiltroTicket::daParametri([
            'apparato' => ' OLT-Pergine-01 ',
            'dal' => '2026-09-08',
            'al' => '2026-02-30',
        ]);

        self::assertSame('olt-pergine-01', $filtro->apparatoId);
        self::assertSame('2026-09-08', $filtro->dal?->format('Y-m-d'));
        self::assertNull($filtro->al);
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function apparatiNonValidi(): iterable
    {
        yield 'spazi nel mezzo' => ['olt pergine 01'];
        yield 'senza numero' => ['olt-pergine'];
        yield 'una cifra sola' => ['olt-pergine-1'];
        yield 'un pezzo di SQL' => ["olt-pergine-01' OR '1'='1"];
    }

    #[DataProvider('apparatiNonValidi')]
    public function testUnApparatoNonValidoSiIgnora(string $apparato): void
    {
        self::assertNull(FiltroTicket::daParametri(['apparato' => $apparato])->apparatoId);
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function dateNonValide(): iterable
    {
        yield 'un giorno che non esiste' => ['2026-02-30'];
        yield 'la forma italiana' => ['08/09/2026'];
        yield 'un nome' => ['martedì'];
    }

    #[DataProvider('dateNonValide')]
    public function testUnaDataNonValidaSiIgnora(string $data): void
    {
        $filtro = FiltroTicket::daParametri(['dal' => $data, 'al' => $data]);

        self::assertNull($filtro->dal);
        self::assertNull($filtro->al);
    }

    public function testUnIntervalloRovesciatoDallaPaginaSiIgnora(): void
    {
        $filtro = FiltroTicket::daParametri(['dal' => '2026-09-13', 'al' => '2026-09-07']);

        self::assertNull($filtro->dal);
        self::assertNull($filtro->al);
    }
}
