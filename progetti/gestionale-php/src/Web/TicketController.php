<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Web;

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Ticket\FiltroTicket;
use CiaspoLink\Gestionale\Ticket\PrioritaTicket;
use CiaspoLink\Gestionale\Ticket\StatoTicket;
use DateTimeImmutable;

final class TicketController
{
    public function __construct(
        private readonly Applicazione $applicazione,
        private readonly Vista $vista,
    ) {
    }

    /**
     * @param array<string, mixed> $parametri
     */
    public function elenco(array $parametri): string
    {
        $filtro = FiltroTicket::daParametri($parametri);

        return $this->vista->mostra('ticket_elenco', [
            'titolo' => 'Ticket',
            'filtro' => $filtro,
            'ticket' => $this->applicazione->ticket()->cerca($filtro),
            'stati' => StatoTicket::cases(),
            'priorita' => PrioritaTicket::cases(),
            'categorie' => FiltroTicket::CATEGORIE,
        ]);
    }

    /**
     * @param array<string, mixed> $parametri
     * @param array<string, mixed> $inviati campi del form (POST)
     */
    public function dettaglio(array $parametri, array $inviati, string $metodo): string
    {
        $id = (string) ($parametri['id'] ?? '');
        $repository = $this->applicazione->ticket();
        $messaggio = null;
        if ($metodo === 'POST') {
            $stato = StatoTicket::tryFrom((string) ($inviati['stato'] ?? ''));
            $operatore = trim((string) ($inviati['operatore'] ?? ''));
            if ($stato !== null) {
                $repository->aggiornaStato($id, $stato, new DateTimeImmutable(), $operatore === '' ? null : $operatore);
                $messaggio = 'Stato aggiornato: ' . $stato->etichetta();
            }
        }

        $ticket = $repository->trova($id);
        if ($ticket === null) {
            http_response_code(404);

            return $this->vista->mostra('errore', [
                'titolo' => 'Ticket inesistente',
                'messaggio' => 'Nessun ticket con codice ' . $id . '.',
            ]);
        }

        return $this->vista->mostra('ticket_dettaglio', [
            'titolo' => 'Ticket ' . $ticket->id,
            'ticket' => $ticket,
            'padre' => $ticket->padreId === null ? null : $repository->trova($ticket->padreId),
            'figli' => $repository->figli($ticket->id),
            'stati' => StatoTicket::cases(),
            'messaggio' => $messaggio,
        ]);
    }
}
