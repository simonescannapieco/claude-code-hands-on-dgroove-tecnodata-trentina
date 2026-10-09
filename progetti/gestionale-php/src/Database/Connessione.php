<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Database;

use PDO;
use RuntimeException;
use Throwable;

/**
 * Apertura e inizializzazione del database SQLite del gestionale.
 */
final class Connessione
{
    /**
     * Apre un database esistente.
     *
     * @throws RuntimeException se il file non esiste
     */
    public static function apri(string $percorso): PDO
    {
        if (!is_file($percorso)) {
            throw new RuntimeException(sprintf(
                'Database non trovato: %s (crealo con «php bin/inizializza-db.php»)',
                $percorso,
            ));
        }

        return self::configura(new PDO('sqlite:' . $percorso));
    }

    /**
     * Crea (o apre) un database; ':memory:' per un database in memoria.
     */
    public static function crea(string $percorso): PDO
    {
        return self::configura(new PDO('sqlite:' . $percorso));
    }

    /**
     * Crea le tabelle di database/schema.sql e carica i dati di database/dati/.
     *
     * @throws RuntimeException se un file manca o i dati violano i vincoli
     */
    public static function inizializza(PDO $pdo, string $cartellaDatabase, bool $conDati = true): void
    {
        $pdo->exec(self::leggi($cartellaDatabase . '/schema.sql'));
        if (!$conDati) {
            return;
        }

        $pdo->exec('PRAGMA foreign_keys = OFF');
        $pdo->beginTransaction();
        try {
            foreach (self::fileDati($cartellaDatabase . '/dati') as $file) {
                $pdo->exec(self::leggi($file));
            }
            $pdo->commit();
        } catch (Throwable $errore) {
            $pdo->rollBack();
            throw $errore;
        }

        $violazioni = $pdo->query('PRAGMA foreign_key_check')->fetchAll();
        $pdo->exec('PRAGMA foreign_keys = ON');
        if ($violazioni !== []) {
            throw new RuntimeException(sprintf('%d riferimenti non validi nei dati', count($violazioni)));
        }
    }

    private static function configura(PDO $pdo): PDO
    {
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec('PRAGMA foreign_keys = ON');

        return $pdo;
    }

    private static function leggi(string $file): string
    {
        $sql = is_file($file) ? file_get_contents($file) : false;
        if ($sql === false) {
            throw new RuntimeException('File non leggibile: ' . $file);
        }

        return $sql;
    }

    /**
     * @return list<string>
     */
    private static function fileDati(string $cartella): array
    {
        $file = glob($cartella . '/*.sql');
        if ($file === false || $file === []) {
            throw new RuntimeException('Nessun file di dati in ' . $cartella);
        }
        sort($file);

        return $file;
    }
}
