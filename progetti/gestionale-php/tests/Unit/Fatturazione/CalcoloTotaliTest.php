<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Unit\Fatturazione;

use CiaspoLink\Gestionale\Fatturazione\CalcoloTotali;
use CiaspoLink\Gestionale\Fatturazione\RigaFattura;
use PHPUnit\Framework\TestCase;

final class CalcoloTotaliTest extends TestCase
{
    public function testDocumentoSenzaRighe(): void
    {
        $totali = (new CalcoloTotali())->calcola([]);

        self::assertSame(0, $totali->imponibileCent);
        self::assertSame(0, $totali->ivaCent);
        self::assertSame(0, $totali->totaleCent);
    }

    public function testCanoneConIva(): void
    {
        $totali = (new CalcoloTotali())->calcola([
            new RigaFattura('canone', 'Canone', 1, 10000, 10000),
        ]);

        self::assertSame(10000, $totali->imponibileCent);
        self::assertSame(2200, $totali->ivaCent);
        self::assertSame(12200, $totali->totaleCent);
    }

    public function testSommaLeRighe(): void
    {
        $totali = (new CalcoloTotali())->calcola([
            new RigaFattura('canone', 'Business Fibra 1 Giga', 1, 4900, 4900),
            new RigaFattura('servizio', 'IP statico', 1, 500, 500),
            new RigaFattura('servizio', 'Hotspot Wi-Fi', 1, 2600, 2600),
        ]);

        self::assertSame(8000, $totali->imponibileCent);
        self::assertSame(1760, $totali->ivaCent);
        self::assertSame(9760, $totali->totaleCent);
    }

    public function testNotaDiCreditoNegativa(): void
    {
        $totali = (new CalcoloTotali())->calcola([
            new RigaFattura('indennizzo', 'Indennizzo', 1, -1000, -1000),
            new RigaFattura('indennizzo', 'Indennizzo', 1, -1000, -1000),
        ]);

        self::assertSame(-2000, $totali->imponibileCent);
        self::assertSame(-440, $totali->ivaCent);
        self::assertSame(-2440, $totali->totaleCent);
    }
}
