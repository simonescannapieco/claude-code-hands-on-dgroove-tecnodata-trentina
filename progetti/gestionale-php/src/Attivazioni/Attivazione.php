<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Attivazioni;

final class Attivazione
{
    public function __construct(
        public readonly string $id,
        public readonly string $lineaId,
        public readonly string $clienteId,
        public readonly string $clienteNome,
        public readonly string $comune,
        /** nuova, cambio_offerta o trasloco */
        public readonly string $tipo,
        public readonly string $offertaCodice,
        public readonly ?string $rivenditoreId,
        public readonly StatoAttivazione $stato,
        public readonly string $richiestaIl,
        public readonly ?string $pianificataPer,
        public readonly ?string $completataIl,
        public readonly string $aggiornataIl,
        public readonly ?string $tecnico,
        public readonly ?string $note,
    ) {
    }

    /**
     * @param array<string, mixed> $riga riga di attivazioni con cliente_id, cliente_nome e comune
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['id'],
            (string) $riga['linea_id'],
            (string) $riga['cliente_id'],
            (string) $riga['cliente_nome'],
            (string) $riga['comune'],
            (string) $riga['tipo'],
            (string) $riga['offerta_codice'],
            self::testo($riga['rivenditore_id']),
            StatoAttivazione::from((string) $riga['stato']),
            (string) $riga['richiesta_il'],
            self::testo($riga['pianificata_per']),
            self::testo($riga['completata_il']),
            (string) $riga['aggiornata_il'],
            self::testo($riga['tecnico']),
            self::testo($riga['note']),
        );
    }

    private static function testo(mixed $valore): ?string
    {
        return $valore === null ? null : (string) $valore;
    }
}
