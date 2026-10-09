<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Copertura;

use CiaspoLink\Gestionale\Offerte\CatalogoRepository;
use CiaspoLink\Gestionale\Offerte\Tecnologia;
use DateTimeImmutable;

/**
 * Verifica di copertura per indirizzo: la tecnologia migliore disponibile
 * (fibra prima della radio, poi la velocità più alta) e le offerte vendibili.
 */
final class VerificaCopertura
{
    public function __construct(
        private readonly CoperturaRepository $copertura,
        private readonly CatalogoRepository $catalogo,
    ) {
    }

    public function verifica(
        string $comune,
        string $via,
        string $civico,
        string $scala = '',
        ?DateTimeImmutable $alGiorno = null,
    ): EsitoCopertura {
        $indirizzo = IndirizzoNormalizzato::da($via, $civico, $scala);
        $giorno = ($alGiorno ?? new DateTimeImmutable())->format('Y-m-d');

        $disponibili = [];
        $pianificata = null;
        foreach ($this->copertura->perIndirizzo($comune, $indirizzo) as $riga) {
            if ($riga['disponibile_dal'] !== null && $riga['disponibile_dal'] <= $giorno) {
                $disponibili[] = $riga;
            } else {
                $pianificata ??= Tecnologia::from($riga['tecnologia'])->etichetta();
            }
        }
        if ($disponibili === []) {
            return EsitoCopertura::nonCoperto($pianificata);
        }

        usort($disponibili, static fn (array $a, array $b): int => [
            Tecnologia::from($a['tecnologia'])->priorita(),
            -$a['velocita_max_mbps'],
        ] <=> [
            Tecnologia::from($b['tecnologia'])->priorita(),
            -$b['velocita_max_mbps'],
        ]);
        $migliore = $disponibili[0];
        $tecnologia = Tecnologia::from($migliore['tecnologia']);

        return new EsitoCopertura(
            true,
            $tecnologia,
            $migliore['velocita_max_mbps'],
            $migliore['apparato_id'],
            null,
            $this->catalogo->vendibili($tecnologia, $migliore['velocita_max_mbps']),
        );
    }

    /**
     * @return list<string>
     */
    public function comuni(): array
    {
        return $this->copertura->comuni();
    }
}
