<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Integrazione;

use CiaspoLink\Gestionale\Tests\Support\DatabaseDiProva;
use CiaspoLink\Gestionale\Ticket\FiltroTicket;
use CiaspoLink\Gestionale\Ticket\PrioritaTicket;
use CiaspoLink\Gestionale\Ticket\StatoTicket;
use CiaspoLink\Gestionale\Ticket\Ticket;
use CiaspoLink\Gestionale\Ticket\TicketRepository;
use DateTimeImmutable;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class TicketRepositoryTest extends TestCase
{
    private TicketRepository $ticket;

    protected function setUp(): void
    {
        $this->ticket = new TicketRepository(DatabaseDiProva::conDati());
    }

    public function testFiltraPerCategoria(): void
    {
        $trovati = $this->ticket->cerca(new FiltroTicket(categoria: 'disservizio'));

        self::assertNotEmpty($trovati);
        foreach ($trovati as $ticket) {
            self::assertSame('disservizio', $ticket->categoria);
        }
    }

    public function testFiltraPerClienteEPriorita(): void
    {
        $trovati = $this->ticket->cerca(new FiltroTicket(priorita: PrioritaTicket::Alta, clienteId: 'CL-000103'));

        self::assertNotEmpty($trovati);
        foreach ($trovati as $ticket) {
            self::assertSame('CL-000103', $ticket->clienteId);
            self::assertSame(PrioritaTicket::Alta, $ticket->priorita);
        }
    }

    public function testSoloApertiEscludeRisoltiEChiusi(): void
    {
        $aperti = $this->ticket->cerca(new FiltroTicket(soloAperti: true));

        self::assertCount($this->ticket->conteggioAperti(), $aperti);
        foreach ($aperti as $ticket) {
            self::assertTrue($ticket->stato->isAperto());
        }
    }

    public function testIlDisservizioDiPergineRaccoglieITicketDeiClienti(): void
    {
        $disservizio = $this->disservizio('olt-pergine-01', '2026-09-08');
        $figli = $this->ticket->figli($disservizio->id);

        self::assertCount(8, $figli);
        self::assertContains('LN-000201', array_map(static fn (Ticket $ticket): ?string => $ticket->lineaId, $figli));
    }

    public function testChiudereUnTicketNeRegistraLaChiusura(): void
    {
        $ticket = $this->ticket->cerca(new FiltroTicket(stato: StatoTicket::InLavorazione), 1)[0];

        $this->ticket->aggiornaStato(
            $ticket->id,
            StatoTicket::Chiuso,
            new DateTimeImmutable('2026-09-14T09:30:00+02:00'),
            'Elena Modello',
        );

        $chiuso = $this->ticket->trova($ticket->id);
        self::assertNotNull($chiuso);
        self::assertSame(StatoTicket::Chiuso, $chiuso->stato);
        self::assertSame('2026-09-14T09:30:00+02:00', $chiuso->chiusoIl);
        self::assertSame('Elena Modello', $chiuso->assegnatoA);
    }

    /**
     * I casi di accettazione di SPECIFICA.md che danno un elenco: i ticket
     * attesi, in ordine di codice.
     *
     * @return iterable<string, array{FiltroTicket, list<string>}>
     */
    public static function casiDiAccettazione(): iterable
    {
        $lunedi = new DateTimeImmutable('2026-09-07');
        $martedi = new DateTimeImmutable('2026-09-08');
        $domenica = new DateTimeImmutable('2026-09-13');

        yield '1: olt-pergine-01, martedì 8' => [
            new FiltroTicket(apparatoId: 'olt-pergine-01', dal: $martedi, al: $martedi),
            self::codiciTicket(...range(210, 218)),
        ];
        yield '2: olt-pergine-01, la settimana' => [
            new FiltroTicket(apparatoId: 'olt-pergine-01', dal: $lunedi, al: $domenica),
            self::codiciTicket(...range(210, 218), ...[228, 245, 246, 247, 248]),
        ];
        yield '3: ptp-cles-01, la settimana' => [
            new FiltroTicket(apparatoId: 'ptp-cles-01', dal: $lunedi, al: $domenica),
            self::codiciTicket(...range(221, 225)),
        ];
        yield '4: bts-cles-01, la settimana' => [
            new FiltroTicket(apparatoId: 'bts-cles-01', dal: $lunedi, al: $domenica),
            self::codiciTicket(222, 223, 224, 225, 235, 236, 240, 243),
        ];
        yield '5: bng-trento-01, senza date' => [
            new FiltroTicket(apparatoId: 'bng-trento-01'),
            self::codiciTicket(201, 227, 228),
        ];
        yield '7: olt-pergine-01, la settimana, disservizio' => [
            new FiltroTicket(categoria: 'disservizio', apparatoId: 'olt-pergine-01', dal: $lunedi, al: $domenica),
            self::codiciTicket(210),
        ];
        yield '8: un apparato che non esiste' => [
            new FiltroTicket(apparatoId: 'olt-inesistente-01'),
            [],
        ];
    }

    /**
     * @param list<string> $attesi
     */
    #[DataProvider('casiDiAccettazione')]
    public function testFiltraPerApparatoEPerDate(FiltroTicket $filtro, array $attesi): void
    {
        self::assertSame($attesi, self::codici($this->ticket->cerca($filtro)));
    }

    public function testConUnGiornoSoloEsconoITicketApertiQuelGiorno(): void
    {
        $martedi = new DateTimeImmutable('2026-09-08');

        $trovati = $this->ticket->cerca(new FiltroTicket(dal: $martedi, al: $martedi));

        self::assertCount(11, $trovati);
        foreach ($trovati as $ticket) {
            self::assertStringStartsWith('2026-09-08', $ticket->apertoIl);
        }
    }

    public function testConIlSoloInizioLIntervalloRestaAperto(): void
    {
        $trovati = $this->ticket->cerca(new FiltroTicket(dal: new DateTimeImmutable('2026-09-12')));

        self::assertCount(10, $trovati);
        foreach ($trovati as $ticket) {
            self::assertGreaterThanOrEqual('2026-09-12', substr($ticket->apertoIl, 0, 10));
        }
    }

    public function testIlFiltroPerApparatoTieneLOrdineDalPiuRecente(): void
    {
        $trovati = $this->ticket->cerca(new FiltroTicket(apparatoId: 'olt-pergine-01'));
        $aperture = array_map(static fn (Ticket $ticket): string => $ticket->apertoIl, $trovati);
        $ordinate = $aperture;
        rsort($ordinate, SORT_STRING);

        self::assertNotEmpty($aperture);
        self::assertSame($ordinate, $aperture);
    }

    private function disservizio(string $apparato, string $giorno): Ticket
    {
        foreach ($this->ticket->cerca(new FiltroTicket(categoria: 'disservizio')) as $ticket) {
            if ($ticket->apparatoId === $apparato && str_starts_with($ticket->apertoIl, $giorno)) {
                return $ticket;
            }
        }
        self::fail("Nessun disservizio su {$apparato} il {$giorno}");
    }

    /**
     * @param list<Ticket> $trovati
     * @return list<string> i codici, in ordine
     */
    private static function codici(array $trovati): array
    {
        $codici = array_map(static fn (Ticket $ticket): string => $ticket->id, $trovati);
        sort($codici, SORT_STRING);

        return $codici;
    }

    /**
     * @return list<string> i codici TK-2026-… dei numeri dati
     */
    private static function codiciTicket(int ...$numeri): array
    {
        return array_map(static fn (int $numero): string => sprintf('TK-2026-%05d', $numero), $numeri);
    }
}
