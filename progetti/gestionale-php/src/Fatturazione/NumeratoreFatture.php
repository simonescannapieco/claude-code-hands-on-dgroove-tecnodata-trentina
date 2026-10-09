<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

use PDO;

/**
 * Numerazione progressiva per anno di emissione: FT-AAAA-NNNNNN, unica per
 * fatture e note di credito.
 */
final class NumeratoreFatture
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function prossimo(int $anno): string
    {
        $stmt = $this->pdo->prepare('SELECT MAX(id) FROM fatture WHERE id LIKE :prefisso');
        $stmt->execute(['prefisso' => sprintf('FT-%04d-%%', $anno)]);
        $ultimo = $stmt->fetchColumn();
        $numero = is_string($ultimo) ? (int) substr($ultimo, -6) + 1 : 1;

        return sprintf('FT-%04d-%06d', $anno, $numero);
    }
}
