<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Attivazioni;

use CiaspoLink\Gestionale\Linee\LineaRepository;
use DateTimeImmutable;
use DateTimeInterface;
use DomainException;
use PDO;
use Throwable;

/**
 * Avanzamento di un'attivazione: controlla il passaggio di stato, lo
 * registra nello storico e, a lavoro completato, mette in servizio la linea.
 */
final class WorkflowAttivazioni
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly AttivazioneRepository $attivazioni,
        private readonly LineaRepository $linee,
    ) {
    }

    /**
     * @throws DomainException se l'attivazione non esiste
     * @throws TransizioneNonConsentita se il passaggio non è tra quelli previsti
     */
    public function avanza(
        string $id,
        StatoAttivazione $nuovo,
        string $operatore,
        DateTimeImmutable $quando,
        ?string $tecnico = null,
    ): Attivazione {
        $attivazione = $this->attivazioni->trova($id);
        if ($attivazione === null) {
            throw new DomainException('Attivazione inesistente: ' . $id);
        }
        if (!$attivazione->stato->puoPassareA($nuovo)) {
            throw new TransizioneNonConsentita($attivazione->stato, $nuovo);
        }

        $istante = $quando->format(DateTimeInterface::ATOM);
        $this->pdo->beginTransaction();
        try {
            $this->attivazioni->aggiornaStato($id, $nuovo, $istante, $tecnico);
            $this->attivazioni->registraEvento($id, $attivazione->stato, $nuovo, $istante, $operatore);
            if ($nuovo === StatoAttivazione::Completata) {
                $this->linee->attiva($attivazione->lineaId, $quando->format('Y-m-d'));
            }
            $this->pdo->commit();
        } catch (Throwable $errore) {
            $this->pdo->rollBack();
            throw $errore;
        }

        return $this->attivazioni->trova($id) ?? $attivazione;
    }
}
