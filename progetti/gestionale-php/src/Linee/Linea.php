<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Linee;

final class Linea
{
    public function __construct(
        public readonly string $id,
        public readonly string $clienteId,
        public readonly string $offertaCodice,
        public readonly int $coperturaId,
        public readonly ?string $apparatoId,
        public readonly ?string $porta,
        /** pppoe o dhcp */
        public readonly string $accesso,
        public readonly StatoLinea $stato,
        public readonly ?string $attivaDal,
        public readonly ?string $cessataIl,
    ) {
    }

    /**
     * @param array<string, mixed> $riga
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['id'],
            (string) $riga['cliente_id'],
            (string) $riga['offerta_codice'],
            (int) $riga['copertura_id'],
            $riga['apparato_id'] === null ? null : (string) $riga['apparato_id'],
            $riga['porta'] === null ? null : (string) $riga['porta'],
            (string) $riga['accesso'],
            StatoLinea::from((string) $riga['stato']),
            $riga['attiva_dal'] === null ? null : (string) $riga['attiva_dal'],
            $riga['cessata_il'] === null ? null : (string) $riga['cessata_il'],
        );
    }
}
