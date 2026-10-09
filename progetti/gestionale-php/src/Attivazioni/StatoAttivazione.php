<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Attivazioni;

/**
 * Stati di un'attivazione e passaggi consentiti tra uno stato e l'altro.
 */
enum StatoAttivazione: string
{
    case Richiesta = 'richiesta';
    case VerificaTecnica = 'verifica_tecnica';
    case Pianificata = 'pianificata';
    case Installazione = 'installazione';
    case Completata = 'completata';
    case Annullata = 'annullata';

    /**
     * @return list<self>
     */
    public function successivi(): array
    {
        return match ($this) {
            self::Richiesta => [self::VerificaTecnica, self::Annullata],
            self::VerificaTecnica => [self::Pianificata, self::Annullata],
            self::Pianificata => [self::Installazione, self::Annullata],
            self::Installazione => [self::Completata, self::Pianificata, self::Annullata],
            self::Completata, self::Annullata => [],
        };
    }

    public function puoPassareA(self $nuovo): bool
    {
        return in_array($nuovo, $this->successivi(), true);
    }

    public function isFinale(): bool
    {
        return $this->successivi() === [];
    }

    public function etichetta(): string
    {
        return match ($this) {
            self::Richiesta => 'Richiesta',
            self::VerificaTecnica => 'Verifica tecnica',
            self::Pianificata => 'Pianificata',
            self::Installazione => 'Installazione',
            self::Completata => 'Completata',
            self::Annullata => 'Annullata',
        };
    }
}
