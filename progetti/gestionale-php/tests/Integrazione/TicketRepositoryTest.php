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

    private function disservizio(string $apparato, string $giorno): Ticket
    {
        foreach ($this->ticket->cerca(new FiltroTicket(categoria: 'disservizio')) as $ticket) {
            if ($ticket->apparatoId === $apparato && str_starts_with($ticket->apertoIl, $giorno)) {
                return $ticket;
            }
        }
        self::fail("Nessun disservizio su {$apparato} il {$giorno}");
    }
}
