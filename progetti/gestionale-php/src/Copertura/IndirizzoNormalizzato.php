<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Copertura;

use InvalidArgumentException;

/**
 * Indirizzo scritto come lo scrivono gli operatori o i clienti, ricondotto
 * alla forma della tabella copertura: spazi e apostrofi uniformati,
 * abbreviazioni sciolte, civico e scala in maiuscolo.
 */
final class IndirizzoNormalizzato
{
    private const ABBREVIAZIONI = [
        '/^v\.\s*le\s+/iu' => 'Viale ',
        '/^p\.\s*zza\s+/iu' => 'Piazza ',
        '/^loc\.\s*/iu' => 'Località ',
        '/^v\.\s*/iu' => 'Via ',
    ];

    private function __construct(
        public readonly string $via,
        public readonly string $civico,
        public readonly string $scala,
    ) {
    }

    /**
     * @throws InvalidArgumentException se via o civico mancano
     */
    public static function da(string $via, string $civico, string $scala = ''): self
    {
        $via = str_replace(['’', '‘', '`'], "'", trim($via));
        $via = (string) preg_replace(['/\s+/u', "/'\s+/u"], [' ', "'"], $via);
        foreach (self::ABBREVIAZIONI as $modello => $esteso) {
            $via = (string) preg_replace($modello, $esteso, $via);
        }
        $civico = mb_strtoupper((string) preg_replace('/\s+/u', '', $civico));
        if ($via === '' || $civico === '') {
            throw new InvalidArgumentException('Indicare via e numero civico');
        }

        return new self($via, $civico, mb_strtoupper(trim($scala)));
    }

    /**
     * Forma della via usata nei confronti: minuscola, come lower() di SQLite.
     */
    public function chiaveVia(): string
    {
        return mb_strtolower($this->via);
    }

    public function __toString(): string
    {
        return $this->via . ' ' . $this->civico . ($this->scala === '' ? '' : ', scala ' . $this->scala);
    }
}
