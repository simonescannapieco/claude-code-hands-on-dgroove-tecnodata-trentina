<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

/**
 * Criteri dell'elenco ticket; i campi a null non filtrano.
 */
final class FiltroTicket
{
    public const CATEGORIE = [
        'guasto', 'lentezza', 'voce', 'wifi', 'amministrativo', 'attivazione', 'disservizio', 'manutenzione',
    ];

    public function __construct(
        public readonly ?StatoTicket $stato = null,
        public readonly ?PrioritaTicket $priorita = null,
        public readonly ?string $categoria = null,
        public readonly ?string $clienteId = null,
        public readonly bool $soloAperti = false,
    ) {
    }

    /**
     * Costruisce il filtro dai parametri della pagina; i valori non validi
     * vengono ignorati.
     *
     * @param array<string, mixed> $parametri
     */
    public static function daParametri(array $parametri): self
    {
        $categoria = (string) ($parametri['categoria'] ?? '');
        $cliente = strtoupper(trim((string) ($parametri['cliente'] ?? '')));

        return new self(
            StatoTicket::tryFrom((string) ($parametri['stato'] ?? '')),
            PrioritaTicket::tryFrom((string) ($parametri['priorita'] ?? '')),
            in_array($categoria, self::CATEGORIE, true) ? $categoria : null,
            preg_match('/^CL-\d{6}$/', $cliente) === 1 ? $cliente : null,
            ($parametri['aperti'] ?? '') === '1',
        );
    }
}
