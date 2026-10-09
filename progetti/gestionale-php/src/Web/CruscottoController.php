<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Web;

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Support\Periodo;
use CiaspoLink\Gestionale\Ticket\FiltroTicket;
use DateTimeImmutable;
use InvalidArgumentException;

/**
 * Cruscotto, verifica di copertura, fatturato per zona e provvigioni.
 */
final class CruscottoController
{
    public function __construct(
        private readonly Applicazione $applicazione,
        private readonly Vista $vista,
    ) {
    }

    public function home(): string
    {
        return $this->vista->mostra('cruscotto', [
            'titolo' => 'Cruscotto',
            'clienti' => $this->applicazione->clienti()->conteggioPerStato(),
            'linee' => $this->applicazione->linee()->conteggioPerStato(),
            'ticketAperti' => $this->applicazione->ticket()->conteggioAperti(),
            'attivazioniInCorso' => count($this->applicazione->attivazioni()->aperte()),
            'disservizi' => $this->applicazione->ticket()->cerca(new FiltroTicket(categoria: 'disservizio'), 5),
        ]);
    }

    /**
     * @param array<string, mixed> $parametri
     */
    public function copertura(array $parametri): string
    {
        $verifica = $this->applicazione->verificaCopertura();
        $richiesta = [];
        foreach (['comune', 'via', 'civico', 'scala'] as $campo) {
            $richiesta[$campo] = trim((string) ($parametri[$campo] ?? ''));
        }

        $esito = null;
        $errore = null;
        if ($richiesta['comune'] !== '') {
            try {
                $esito = $verifica->verifica(
                    $richiesta['comune'],
                    $richiesta['via'],
                    $richiesta['civico'],
                    $richiesta['scala'],
                );
            } catch (InvalidArgumentException $eccezione) {
                $errore = $eccezione->getMessage();
            }
        }

        return $this->vista->mostra('copertura', [
            'titolo' => 'Verifica di copertura',
            'comuni' => $verifica->comuni(),
            'richiesta' => $richiesta,
            'esito' => $esito,
            'errore' => $errore,
        ]);
    }

    /**
     * @param array<string, mixed> $parametri
     */
    public function reportFatturato(array $parametri): string
    {
        $errore = null;
        $al = Periodo::di(new DateTimeImmutable('first day of last month'));
        $dal = Periodo::di($al->primoGiorno()->modify('-11 months'));
        try {
            $dal = isset($parametri['dal']) ? Periodo::da((string) $parametri['dal']) : $dal;
            $al = isset($parametri['al']) ? Periodo::da((string) $parametri['al']) : $al;
        } catch (InvalidArgumentException $eccezione) {
            $errore = $eccezione->getMessage();
        }

        return $this->vista->mostra('report_fatturato', [
            'titolo' => 'Fatturato per zona',
            'dal' => $dal,
            'al' => $al,
            'righe' => $errore === null ? $this->applicazione->reportFatturato()->perZona($dal, $al) : [],
            'errore' => $errore,
        ]);
    }

    /**
     * @param array<string, mixed> $parametri
     */
    public function provvigioni(array $parametri): string
    {
        $errore = null;
        $periodo = Periodo::di(new DateTimeImmutable('first day of last month'));
        try {
            $periodo = isset($parametri['periodo']) ? Periodo::da((string) $parametri['periodo']) : $periodo;
        } catch (InvalidArgumentException $eccezione) {
            $errore = $eccezione->getMessage();
        }
        $calcolo = $this->applicazione->provvigioni();

        return $this->vista->mostra('provvigioni', [
            'titolo' => 'Provvigioni dei rivenditori',
            'periodo' => $periodo,
            'provvigioni' => $calcolo->perPeriodo($periodo),
            'registrate' => $calcolo->registrate($periodo),
            'errore' => $errore,
        ]);
    }
}
