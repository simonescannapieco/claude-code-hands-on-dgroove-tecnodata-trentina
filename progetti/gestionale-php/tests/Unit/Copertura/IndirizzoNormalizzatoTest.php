<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Unit\Copertura;

use CiaspoLink\Gestionale\Copertura\IndirizzoNormalizzato;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class IndirizzoNormalizzatoTest extends TestCase
{
    /**
     * @return iterable<string, array{string, string}>
     */
    public static function vie(): iterable
    {
        yield 'spazi in più' => ['  Via   delle  Prove ', 'Via delle Prove'];
        yield 'apostrofo tipografico' => ['Via dell’ Esempio', "Via dell'Esempio"];
        yield 'viale abbreviato' => ['V.le Ipotetico', 'Viale Ipotetico'];
        yield 'via abbreviata' => ['V. Fittizia', 'Via Fittizia'];
        yield 'piazza abbreviata' => ['P.zza Immaginaria', 'Piazza Immaginaria'];
    }

    #[DataProvider('vie')]
    public function testUniformaLaVia(string $scritta, string $attesa): void
    {
        self::assertSame($attesa, IndirizzoNormalizzato::da($scritta, '1')->via);
    }

    public function testCivicoEScalaInMaiuscolo(): void
    {
        $indirizzo = IndirizzoNormalizzato::da('Via Fittizia', ' 12 a ', 'b');

        self::assertSame('12A', $indirizzo->civico);
        self::assertSame('B', $indirizzo->scala);
        self::assertSame('Via Fittizia 12A, scala B', (string) $indirizzo);
    }

    public function testViaECivicoSonoObbligatori(): void
    {
        $this->expectException(InvalidArgumentException::class);

        IndirizzoNormalizzato::da('Via Fittizia', '  ');
    }
}
