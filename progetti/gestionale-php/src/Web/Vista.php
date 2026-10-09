<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Web;

use DateTimeImmutable;
use RuntimeException;

/**
 * Rende i template PHP di templates/ dentro templates/layout.php. Nei
 * template ogni valore va stampato con $this->e().
 */
final class Vista
{
    public function __construct(private readonly string $cartellaTemplate)
    {
    }

    /**
     * @param array<string, mixed> $dati variabili per il template; «titolo» va anche al layout
     */
    public function mostra(string $template, array $dati = []): string
    {
        $contenuto = $this->includi($template, $dati);

        return $this->includi('layout', [
            'titolo' => (string) ($dati['titolo'] ?? 'Gestionale'),
            'contenuto' => $contenuto,
        ]);
    }

    public function e(mixed $valore): string
    {
        return htmlspecialchars((string) $valore, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    public function euro(int $centesimi): string
    {
        return number_format($centesimi / 100, 2, ',', '.') . ' €';
    }

    /**
     * Data (o data e ora ISO 8601) nella forma gg/mm/aaaa, con l'ora se presente.
     */
    public function data(?string $valore): string
    {
        if ($valore === null || $valore === '') {
            return '';
        }
        $formato = strlen($valore) > 10 ? 'd/m/Y H:i' : 'd/m/Y';

        return (new DateTimeImmutable($valore))->format($formato);
    }

    /**
     * @param array<string, mixed> $dati
     */
    private function includi(string $template, array $dati): string
    {
        $file = $this->cartellaTemplate . '/' . $template . '.php';
        if (!is_file($file)) {
            throw new RuntimeException('Template inesistente: ' . $template);
        }
        extract($dati, EXTR_SKIP);
        ob_start();
        require $file;

        return (string) ob_get_clean();
    }
}
