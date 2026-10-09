<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale;

use CiaspoLink\Gestionale\Attivazioni\AttivazioneRepository;
use CiaspoLink\Gestionale\Attivazioni\WorkflowAttivazioni;
use CiaspoLink\Gestionale\Clienti\ClienteRepository;
use CiaspoLink\Gestionale\Copertura\CoperturaRepository;
use CiaspoLink\Gestionale\Copertura\VerificaCopertura;
use CiaspoLink\Gestionale\Database\Connessione;
use CiaspoLink\Gestionale\Esportazione\EsportatoreAttivazioni;
use CiaspoLink\Gestionale\Fatturazione\CalcoloTotali;
use CiaspoLink\Gestionale\Fatturazione\FatturaRepository;
use CiaspoLink\Gestionale\Fatturazione\GeneratoreFatture;
use CiaspoLink\Gestionale\Fatturazione\NumeratoreFatture;
use CiaspoLink\Gestionale\Legacy\PonteListino;
use CiaspoLink\Gestionale\Linee\LineaRepository;
use CiaspoLink\Gestionale\Offerte\CatalogoRepository;
use CiaspoLink\Gestionale\Report\ReportFatturato;
use CiaspoLink\Gestionale\Rivenditori\CalcoloProvvigioni;
use CiaspoLink\Gestionale\Ticket\TicketRepository;
use PDO;

/**
 * Punto di composizione dell'applicazione: legge config/config.php, apre il
 * database e costruisce i servizi. Gli script di bin/ e public/index.php
 * partono tutti da qui.
 */
final class Applicazione
{
    private ?PDO $pdo = null;

    /**
     * @param array<string, mixed> $config
     */
    private function __construct(private readonly array $config)
    {
    }

    /**
     * @param array<string, mixed> $sostituzioni valori che prevalgono su config/config.php
     */
    public static function avvia(array $sostituzioni = []): self
    {
        /** @var array<string, mixed> $config */
        $config = array_replace(require __DIR__ . '/../config/config.php', $sostituzioni);
        date_default_timezone_set((string) $config['timezone']);

        return new self($config);
    }

    /**
     * Applicazione su una connessione già aperta: la usano i test.
     */
    public static function conConnessione(PDO $pdo): self
    {
        $applicazione = self::avvia();
        $applicazione->pdo = $pdo;

        return $applicazione;
    }

    public function percorsoDatabase(): string
    {
        return (string) $this->config['db_path'];
    }

    public function cartellaEsportazioni(): string
    {
        return (string) $this->config['esportazioni_dir'];
    }

    /**
     * @return array<string, string>
     */
    public function azienda(): array
    {
        /** @var array<string, string> $azienda */
        $azienda = $this->config['azienda'];

        return $azienda;
    }

    public function pdo(): PDO
    {
        return $this->pdo ??= Connessione::apri($this->percorsoDatabase());
    }

    public function clienti(): ClienteRepository
    {
        return new ClienteRepository($this->pdo());
    }

    public function catalogo(): CatalogoRepository
    {
        return new CatalogoRepository($this->pdo());
    }

    public function linee(): LineaRepository
    {
        return new LineaRepository($this->pdo());
    }

    public function verificaCopertura(): VerificaCopertura
    {
        return new VerificaCopertura(new CoperturaRepository($this->pdo()), $this->catalogo());
    }

    public function attivazioni(): AttivazioneRepository
    {
        return new AttivazioneRepository($this->pdo());
    }

    public function workflowAttivazioni(): WorkflowAttivazioni
    {
        return new WorkflowAttivazioni($this->pdo(), $this->attivazioni(), $this->linee());
    }

    public function ticket(): TicketRepository
    {
        return new TicketRepository($this->pdo());
    }

    public function fatture(): FatturaRepository
    {
        return new FatturaRepository($this->pdo());
    }

    public function generatoreFatture(): GeneratoreFatture
    {
        return new GeneratoreFatture(
            $this->pdo(),
            $this->linee(),
            new PonteListino($this->pdo()),
            new CalcoloTotali(),
            new NumeratoreFatture($this->pdo()),
            $this->fatture(),
        );
    }

    public function provvigioni(): CalcoloProvvigioni
    {
        return new CalcoloProvvigioni($this->pdo());
    }

    public function reportFatturato(): ReportFatturato
    {
        return new ReportFatturato($this->clienti(), $this->fatture());
    }

    public function esportatoreAttivazioni(): EsportatoreAttivazioni
    {
        return new EsportatoreAttivazioni($this->attivazioni());
    }
}
