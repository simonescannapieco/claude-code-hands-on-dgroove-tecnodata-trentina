<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

final class Ticket
{
    public function __construct(
        public readonly string $id,
        public readonly ?string $clienteId,
        public readonly ?string $clienteNome,
        public readonly ?string $lineaId,
        public readonly ?string $apparatoId,
        public readonly ?string $padreId,
        public readonly string $categoria,
        public readonly PrioritaTicket $priorita,
        public readonly StatoTicket $stato,
        public readonly string $canale,
        public readonly string $oggetto,
        public readonly string $descrizione,
        public readonly string $apertoIl,
        public readonly string $aggiornatoIl,
        public readonly ?string $chiusoIl,
        public readonly ?string $assegnatoA,
    ) {
    }

    /**
     * @param array<string, mixed> $riga riga di ticket con la colonna cliente_nome
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['id'],
            self::testo($riga['cliente_id']),
            self::testo($riga['cliente_nome']),
            self::testo($riga['linea_id']),
            self::testo($riga['apparato_id']),
            self::testo($riga['padre_id']),
            (string) $riga['categoria'],
            PrioritaTicket::from((string) $riga['priorita']),
            StatoTicket::from((string) $riga['stato']),
            (string) $riga['canale'],
            (string) $riga['oggetto'],
            (string) $riga['descrizione'],
            (string) $riga['aperto_il'],
            (string) $riga['aggiornato_il'],
            self::testo($riga['chiuso_il']),
            self::testo($riga['assegnato_a']),
        );
    }

    private static function testo(mixed $valore): ?string
    {
        return $valore === null ? null : (string) $valore;
    }
}
