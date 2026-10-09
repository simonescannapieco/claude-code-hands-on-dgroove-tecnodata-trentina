<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Offerte;

final class Offerta
{
    public function __construct(
        public readonly string $codice,
        public readonly string $nome,
        public readonly Famiglia $famiglia,
        public readonly Tecnologia $tecnologia,
        public readonly int $downloadMbps,
        public readonly int $uploadMbps,
        public readonly int $canoneCent,
        public readonly int $attivazioneCent,
        public readonly bool $inListino,
    ) {
    }

    /**
     * @param array<string, mixed> $riga
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['codice'],
            (string) $riga['nome'],
            Famiglia::from((string) $riga['famiglia']),
            Tecnologia::from((string) $riga['tecnologia']),
            (int) $riga['download_mbps'],
            (int) $riga['upload_mbps'],
            (int) $riga['canone_cent'],
            (int) $riga['attivazione_cent'],
            (bool) $riga['in_listino'],
        );
    }
}
