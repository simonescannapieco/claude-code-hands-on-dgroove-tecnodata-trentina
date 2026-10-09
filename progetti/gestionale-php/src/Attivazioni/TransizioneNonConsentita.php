<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Attivazioni;

use DomainException;

final class TransizioneNonConsentita extends DomainException
{
    public function __construct(
        public readonly StatoAttivazione $da,
        public readonly StatoAttivazione $a,
    ) {
        parent::__construct(sprintf(
            'Passaggio non consentito: da «%s» a «%s»',
            $da->etichetta(),
            $a->etichetta(),
        ));
    }
}
