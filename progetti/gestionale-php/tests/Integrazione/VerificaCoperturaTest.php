<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Integrazione;

use CiaspoLink\Gestionale\Copertura\CoperturaRepository;
use CiaspoLink\Gestionale\Copertura\VerificaCopertura;
use CiaspoLink\Gestionale\Offerte\CatalogoRepository;
use CiaspoLink\Gestionale\Offerte\Offerta;
use CiaspoLink\Gestionale\Offerte\Tecnologia;
use CiaspoLink\Gestionale\Tests\Support\DatabaseDiProva;
use DateTimeImmutable;
use PHPUnit\Framework\TestCase;

final class VerificaCoperturaTest extends TestCase
{
    private static VerificaCopertura $verifica;

    public static function setUpBeforeClass(): void
    {
        $pdo = DatabaseDiProva::conDati();
        self::$verifica = new VerificaCopertura(new CoperturaRepository($pdo), new CatalogoRepository($pdo));
    }

    public function testIndirizzoServitoInFibra(): void
    {
        $esito = self::$verifica->verifica('Pergine Valsugana', "Via dell'Esempio", '12', '', self::giorno());

        self::assertTrue($esito->coperto);
        self::assertSame(Tecnologia::Ftth, $esito->tecnologia);
        self::assertSame(1000, $esito->velocitaMaxMbps);
        self::assertSame('olt-pergine-01', $esito->apparatoId);
        self::assertContains('CASA_FIBRA_1G', self::codici($esito->offerte));
        self::assertNotContains('CASA_FIBRA_25G', self::codici($esito->offerte));
    }

    public function testIndirizzoScrittoInModoDiverso(): void
    {
        $esito = self::$verifica->verifica('Pergine Valsugana', 'via dell’ esempio', ' 12 ', '', self::giorno());

        self::assertTrue($esito->coperto);
    }

    public function testIndirizzoServitoViaRadio(): void
    {
        $esito = self::$verifica->verifica('Cles', 'Via del Campione', '8', '', self::giorno());

        self::assertTrue($esito->coperto);
        self::assertSame(Tecnologia::Fwa, $esito->tecnologia);
        self::assertSame('bts-cles-01', $esito->apparatoId);
        self::assertSame(['CASA_RADIO'], self::codici($esito->offerte));
    }

    public function testFibraPianificata(): void
    {
        $esito = self::$verifica->verifica('Levico Terme', 'Via della Fantasia', '103', '', self::giorno());

        self::assertFalse($esito->coperto);
        self::assertSame(Tecnologia::Ftth->etichetta(), $esito->pianificataTecnologia);
    }

    public function testComuneNonServito(): void
    {
        $esito = self::$verifica->verifica('Malé', 'Via Inventata', '1', '', self::giorno());

        self::assertFalse($esito->coperto);
        self::assertNull($esito->pianificataTecnologia);
        self::assertSame('Indirizzo non coperto.', $esito->messaggio());
    }

    private static function giorno(): DateTimeImmutable
    {
        return new DateTimeImmutable('2026-09-13');
    }

    /**
     * @param list<Offerta> $offerte
     * @return list<string>
     */
    private static function codici(array $offerte): array
    {
        return array_map(static fn (Offerta $offerta): string => $offerta->codice, $offerte);
    }
}
