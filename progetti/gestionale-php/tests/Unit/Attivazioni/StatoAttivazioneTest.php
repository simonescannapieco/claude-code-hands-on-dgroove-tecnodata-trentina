<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Unit\Attivazioni;

use CiaspoLink\Gestionale\Attivazioni\StatoAttivazione;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class StatoAttivazioneTest extends TestCase
{
    public function testIlPercorsoNormaleEConsentito(): void
    {
        $percorso = [
            StatoAttivazione::Richiesta,
            StatoAttivazione::VerificaTecnica,
            StatoAttivazione::Pianificata,
            StatoAttivazione::Installazione,
            StatoAttivazione::Completata,
        ];

        for ($i = 1; $i < count($percorso); $i++) {
            self::assertTrue($percorso[$i - 1]->puoPassareA($percorso[$i]));
        }
    }

    public function testNonSiSaltanoPassaggi(): void
    {
        self::assertFalse(StatoAttivazione::Richiesta->puoPassareA(StatoAttivazione::Completata));
        self::assertFalse(StatoAttivazione::VerificaTecnica->puoPassareA(StatoAttivazione::Installazione));
    }

    public function testUnInstallazioneSiPuoRipianificare(): void
    {
        self::assertTrue(StatoAttivazione::Installazione->puoPassareA(StatoAttivazione::Pianificata));
    }

    /**
     * @return iterable<string, array{StatoAttivazione}>
     */
    public static function statiAperti(): iterable
    {
        yield 'richiesta' => [StatoAttivazione::Richiesta];
        yield 'verifica tecnica' => [StatoAttivazione::VerificaTecnica];
        yield 'pianificata' => [StatoAttivazione::Pianificata];
        yield 'installazione' => [StatoAttivazione::Installazione];
    }

    #[DataProvider('statiAperti')]
    public function testSiPuoAnnullarePrimaDellaFine(StatoAttivazione $stato): void
    {
        self::assertTrue($stato->puoPassareA(StatoAttivazione::Annullata));
        self::assertFalse($stato->isFinale());
    }

    public function testCompletataEAnnullataSonoFinali(): void
    {
        self::assertTrue(StatoAttivazione::Completata->isFinale());
        self::assertTrue(StatoAttivazione::Annullata->isFinale());
        self::assertSame([], StatoAttivazione::Completata->successivi());
    }
}
