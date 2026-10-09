<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Web;

use CiaspoLink\Gestionale\Applicazione;
use CiaspoLink\Gestionale\Attivazioni\StatoAttivazione;
use DateTimeImmutable;
use DomainException;

final class AttivazioniController
{
    public function __construct(
        private readonly Applicazione $applicazione,
        private readonly Vista $vista,
    ) {
    }

    /**
     * Elenco delle attivazioni in corso; con un POST fa avanzare quella indicata.
     *
     * @param array<string, mixed> $inviati campi del form (POST)
     */
    public function elenco(array $inviati, string $metodo): string
    {
        $messaggio = null;
        $errore = null;
        if ($metodo === 'POST') {
            $nuovo = StatoAttivazione::tryFrom((string) ($inviati['stato'] ?? ''));
            $operatore = trim((string) ($inviati['operatore'] ?? ''));
            if ($nuovo === null || $operatore === '') {
                $errore = 'Indicare il nuovo stato e chi registra il passaggio.';
            } else {
                try {
                    $attivazione = $this->applicazione->workflowAttivazioni()->avanza(
                        (string) ($inviati['id'] ?? ''),
                        $nuovo,
                        $operatore,
                        new DateTimeImmutable(),
                    );
                    $messaggio = sprintf('%s: ora «%s».', $attivazione->id, $attivazione->stato->etichetta());
                } catch (DomainException $eccezione) {
                    $errore = $eccezione->getMessage();
                }
            }
        }

        return $this->vista->mostra('attivazioni', [
            'titolo' => 'Attivazioni in corso',
            'attivazioni' => $this->applicazione->attivazioni()->aperte(),
            'messaggio' => $messaggio,
            'errore' => $errore,
        ]);
    }
}
