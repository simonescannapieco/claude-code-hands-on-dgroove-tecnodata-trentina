<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Ticket;

use DateTimeImmutable;
use InvalidArgumentException;

/**
 * Criteri dell'elenco ticket; i campi a null non filtrano.
 */
final class FiltroTicket
{
    public const CATEGORIE = [
        'guasto', 'lentezza', 'voce', 'wifi', 'amministrativo', 'attivazione', 'disservizio', 'manutenzione',
    ];

    /**
     * @param ?string $apparatoId apparato del ticket, del suo ticket padre o della sua linea
     * @param ?DateTimeImmutable $dal primo giorno di apertura, compreso (conta solo la data)
     * @param ?DateTimeImmutable $al ultimo giorno di apertura, compreso (conta solo la data)
     *
     * @throws InvalidArgumentException se dal viene dopo al
     */
    public function __construct(
        public readonly ?StatoTicket $stato = null,
        public readonly ?PrioritaTicket $priorita = null,
        public readonly ?string $categoria = null,
        public readonly ?string $clienteId = null,
        public readonly bool $soloAperti = false,
        public readonly ?string $apparatoId = null,
        public readonly ?DateTimeImmutable $dal = null,
        public readonly ?DateTimeImmutable $al = null,
    ) {
        if ($dal !== null && $al !== null && $dal->format('Y-m-d') > $al->format('Y-m-d')) {
            throw new InvalidArgumentException(sprintf(
                'Intervallo di date rovesciato: dal %s al %s.',
                $dal->format('Y-m-d'),
                $al->format('Y-m-d'),
            ));
        }
    }

    /**
     * Costruisce il filtro dai parametri della pagina; i valori non validi
     * vengono ignorati, e così un intervallo di date rovesciato.
     *
     * @param array<string, mixed> $parametri
     */
    public static function daParametri(array $parametri): self
    {
        $categoria = (string) ($parametri['categoria'] ?? '');
        $cliente = strtoupper(trim((string) ($parametri['cliente'] ?? '')));
        $apparato = strtolower(trim(self::testo($parametri['apparato'] ?? null)));
        $dal = self::data($parametri['dal'] ?? null);
        $al = self::data($parametri['al'] ?? null);
        if ($dal !== null && $al !== null && $dal > $al) {
            $dal = null;
            $al = null;
        }

        return new self(
            StatoTicket::tryFrom((string) ($parametri['stato'] ?? '')),
            PrioritaTicket::tryFrom((string) ($parametri['priorita'] ?? '')),
            in_array($categoria, self::CATEGORIE, true) ? $categoria : null,
            preg_match('/^CL-\d{6}$/', $cliente) === 1 ? $cliente : null,
            ($parametri['aperti'] ?? '') === '1',
            preg_match('/^[a-z]+-[a-z]+-\d{2}$/', $apparato) === 1 ? $apparato : null,
            $dal,
            $al,
        );
    }

    /**
     * Una data AAAA-MM-GG che esiste, oppure null.
     */
    private static function data(mixed $valore): ?DateTimeImmutable
    {
        $testo = trim(self::testo($valore));
        $data = DateTimeImmutable::createFromFormat('!Y-m-d', $testo);

        return $data !== false && $data->format('Y-m-d') === $testo ? $data : null;
    }

    /**
     * Il valore di un parametro come testo; '' se non è una stringa.
     */
    private static function testo(mixed $valore): string
    {
        return is_string($valore) ? $valore : '';
    }
}
