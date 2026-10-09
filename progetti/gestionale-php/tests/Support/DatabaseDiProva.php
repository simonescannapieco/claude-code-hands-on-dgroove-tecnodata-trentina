<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Support;

use CiaspoLink\Gestionale\Database\Connessione;
use PDO;

/**
 * Database SQLite in memoria per i test di integrazione.
 */
final class DatabaseDiProva
{
    private const CARTELLA = __DIR__ . '/../../database';

    /**
     * Schema e dati di esempio di database/dati/.
     */
    public static function conDati(): PDO
    {
        $pdo = Connessione::crea(':memory:');
        Connessione::inizializza($pdo, self::CARTELLA);

        return $pdo;
    }

    /**
     * Solo lo schema: i dati li inserisce il test.
     */
    public static function vuoto(): PDO
    {
        $pdo = Connessione::crea(':memory:');
        Connessione::inizializza($pdo, self::CARTELLA, false);

        return $pdo;
    }
}
