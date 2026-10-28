<?php

declare(strict_types=1);

/*
 * Il controllo notturno: legge il database del gestionale e stampa una riga per
 * ogni incoerenza che trova, poi i due conteggi che la chiusura di fine mese
 * gestisce da sé (SPECIFICA.md). Legge soltanto: non scrive niente, nel database
 * né altrove.
 *
 * Uso: php bin/controllo-notturno.php [--db=percorso] [--giorno=AAAA-MM-GG] [--help]
 * Uscita: 0 nessuna segnalazione; 1 almeno una segnalazione; 2 errore (database
 * che manca, giorno non valido, opzione sconosciuta, query che non riesce).
 */

use CiaspoLink\Gestionale\Applicazione;

require __DIR__ . '/../vendor/autoload.php';

$uso = "Uso: php bin/controllo-notturno.php [--db=percorso] [--giorno=AAAA-MM-GG] [--help]\n"
    . "  --db=percorso         il database (di norma quello di config/config.php)\n"
    . "  --giorno=AAAA-MM-GG   il giorno del controllo (di norma la data di quando gira)\n"
    . "  --help                questo aiuto\n"
    . "Uscita: 0 nessuna segnalazione; 1 almeno una segnalazione; 2 errore.\n";

foreach (array_slice($argv, 1) as $argomento) {
    if (preg_match('/^--(db|giorno)=.+$|^--help$/', $argomento) !== 1) {
        fwrite(STDERR, "Opzione sconosciuta: {$argomento}\n{$uso}");
        exit(2);
    }
}
$opzioni = getopt('', ['db:', 'giorno:', 'help']);
if (isset($opzioni['help'])) {
    fwrite(STDOUT, $uso);
    exit(0);
}

$applicazione = Applicazione::avvia(isset($opzioni['db']) ? ['db_path' => (string) $opzioni['db']] : []);
$giorno = (string) ($opzioni['giorno'] ?? date('Y-m-d'));
if (
    preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $giorno, $parti) !== 1
    || !checkdate((int) $parti[2], (int) $parti[3], (int) $parti[1])
) {
    fwrite(STDERR, "Giorno non valido: {$giorno} (atteso AAAA-MM-GG)\n");
    exit(2);
}
$limite = static fn (int $giorni): string => (new DateTimeImmutable($giorno))
    ->modify("-{$giorni} days")
    ->format('Y-m-d');

// I quattro controlli in una query sola, nell'ordine di SPECIFICA.md; il giorno
// di una colonna con l'offset sono i suoi primi dieci caratteri (regola 5.5).
$sqlSegnalazioni = <<<'SQL'
    SELECT 1 AS ordine, 'linea-cliente-cessato' AS controllo, l.id AS id,
           'cliente ' || l.cliente_id || ' cessato, linea ' || l.stato AS dettaglio
      FROM linee l JOIN clienti c ON c.id = l.cliente_id
     WHERE c.stato = 'cessato' AND l.stato <> 'cessata'
    UNION ALL
    SELECT 2, 'linea-senza-apparato', id, 'cliente ' || cliente_id || ', attiva senza apparato o porta'
      FROM linee
     WHERE stato = 'attiva' AND (apparato_id IS NULL OR porta IS NULL OR porta = '')
    UNION ALL
    SELECT 3, 'attivazione-ferma', id, 'in verifica tecnica dal ' || substr(aggiornata_il, 1, 10)
      FROM attivazioni
     WHERE stato = 'verifica_tecnica' AND substr(aggiornata_il, 1, 10) < :limiteAttivazioni
    UNION ALL
    SELECT 4, 'ticket-in-attesa', id, 'in attesa del cliente dal ' || substr(aggiornato_il, 1, 10)
      FROM ticket
     WHERE stato = 'in_attesa_cliente' AND substr(aggiornato_il, 1, 10) < :limiteTicket
     ORDER BY ordine, id
    SQL;
$sqlConteggi = <<<'SQL'
    SELECT (SELECT COUNT(*) FROM fatture WHERE tipo = 'fattura' AND stato = 'scaduta') AS scadute,
           (SELECT COUNT(*) FROM clienti WHERE stato = 'sospeso') AS sospesi
    SQL;

try {
    $pdo = $applicazione->pdo();
    $query = $pdo->prepare($sqlSegnalazioni);
    $query->execute(['limiteAttivazioni' => $limite(30), 'limiteTicket' => $limite(21)]);
    $segnalazioni = $query->fetchAll();
    $conteggi = $pdo->query($sqlConteggi)->fetch();
} catch (RuntimeException | PDOException $errore) {
    fwrite(STDERR, 'Controllo non eseguito: ' . $errore->getMessage() . "\n");
    exit(2);
}

$righe = array_map(
    static fn (array $riga): string => "{$riga['controllo']} {$riga['id']} {$riga['dettaglio']}\n",
    $segnalazioni,
);
fwrite(STDOUT, implode('', $righe)
    . "fatture-scadute {$conteggi['scadute']}\nclienti-sospesi {$conteggi['sospesi']}\n");
exit($segnalazioni === [] ? 0 : 1);
