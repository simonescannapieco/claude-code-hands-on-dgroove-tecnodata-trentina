<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Clienti;

/**
 * Anagrafica di un cliente, con comune e zona già risolti.
 */
final class Cliente
{
    public function __construct(
        public readonly string $id,
        public readonly TipoCliente $tipo,
        public readonly ?string $nome,
        public readonly ?string $cognome,
        public readonly ?string $ragioneSociale,
        public readonly ?string $partitaIva,
        public readonly string $email,
        public readonly string $telefono,
        public readonly string $indirizzo,
        public readonly string $comune,
        public readonly string $zona,
        public readonly ?string $rivenditoreId,
        /** attivo, sospeso o cessato */
        public readonly string $stato,
        public readonly string $clienteDal,
    ) {
    }

    /**
     * @param array<string, mixed> $riga riga di clienti unita a comuni (colonne comune e zona)
     */
    public static function daRiga(array $riga): self
    {
        return new self(
            (string) $riga['id'],
            TipoCliente::from((string) $riga['tipo']),
            self::testo($riga['nome']),
            self::testo($riga['cognome']),
            self::testo($riga['ragione_sociale']),
            self::testo($riga['partita_iva']),
            (string) $riga['email'],
            (string) $riga['telefono'],
            $riga['via'] . ' ' . $riga['civico'],
            (string) $riga['comune'],
            (string) $riga['zona'],
            self::testo($riga['rivenditore_id']),
            (string) $riga['stato'],
            (string) $riga['cliente_dal'],
        );
    }

    public function nomeVisualizzato(): string
    {
        return $this->ragioneSociale ?? trim($this->nome . ' ' . $this->cognome);
    }

    private static function testo(mixed $valore): ?string
    {
        return $valore === null ? null : (string) $valore;
    }
}
