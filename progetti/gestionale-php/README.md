# Gestionale CiaspoLink

Il gestionale di **CiaspoLink S.r.l.**, l'operatore di connettività immaginario dei progetti di esempio (vedi `../README.md`). Contiene clienti privati, aziende e associazioni; le offerte «Casa» e «Business» in fibra (FTTH) e via radio (FWA), con i servizi aggiuntivi; la copertura per indirizzo; linee e attivazioni; rivenditori e provvigioni; ticket di assistenza; fatture mensili e note di credito.

Il gestionale è cresciuto negli anni. Accanto a una parte scritta di recente, ordinata e con qualche test (`src/`), lavora ancora il vecchio gestionale procedurale (`legacy/`), che la parte nuova in alcuni punti richiama. Tutti i dati sono sintetici. L'interfaccia web non ha autenticazione: è fatta per girare solo in locale.

## Che cosa serve

- **Docker**, oppure PHP 8.3 (o successivo) con Composer. Tutti i comandi passano da `tools/php.sh`, nella radice del repository del corso: usa PHP se è installato, altrimenti le immagini Docker ufficiali di PHP e Composer.
- **Python 3.8** (o successivo), solo per rigenerare i dati di esempio.

## Primo avvio

Dalla cartella `progetti/gestionale-php` (se lavori in una copia del progetto, adatta il percorso di `tools/php.sh`):

```bash
../../tools/php.sh composer install             # dipendenze: PHPUnit e PHP_CodeSniffer
../../tools/php.sh php bin/inizializza-db.php   # crea var/gestionale.sqlite da schema e dati
../../tools/php.sh phpunit                      # test
../../tools/php.sh php vendor/bin/phpcs         # stile PSR-12 sulle parti nuove
../../tools/php.sh serve public 8080            # interfaccia web: http://localhost:8080/
```

Per ripartire dai dati iniziali: `../../tools/php.sh php bin/inizializza-db.php --forza`.

## Le cartelle

| cartella | contenuto |
|---|---|
| `src/` | la parte nuova: namespace `CiaspoLink\Gestionale`, autoload PSR-4, stile PSR-12 |
| `legacy/` | il vecchio gestionale: pagine web (clienti, scheda cliente, stampa fattura, nuovo ticket) e moduli di fine mese |
| `templates/` | i template HTML delle pagine nuove |
| `public/` | l'ingresso web (`index.php?pagina=…`) e il foglio di stile |
| `bin/` | gli script delle operazioni ricorrenti |
| `config/` | la configurazione (percorso del database, fuso orario, dati dell'azienda) |
| `database/` | `schema.sql` e i dati di esempio in `dati/` (generati) |
| `tests/` | test PHPUnit: `Unit/` senza database, `Integrazione/` con SQLite in memoria |
| `docs/` | `convenzioni.md`, le regole del team per scrivere e rivedere il codice |
| `genera.py` | il generatore dei dati di esempio |

## Le operazioni ricorrenti

| quando | comando | che cosa fa |
|---|---|---|
| ogni notte alle 02:30 | `php bin/esporta-attivazioni.php` | CSV delle attivazioni completate il giorno prima, per magazzino e rivenditori (`var/esportazioni/`) |
| il giorno 1, alle 06:00 | `php bin/fatturazione-mensile.php` | fatture del mese precedente; `--simula` calcola senza scrivere |
| il giorno 2, alle 06:15 | `php bin/chiusura-mese.php` | fatture scadute, sospensioni e riattivazioni, indennizzi, provvigioni, report in `var/report/` |
| a richiesta | `php bin/provvigioni-rivenditori.php --periodo=AAAA-MM` | ricalcolo delle provvigioni di un mese non ancora liquidato |
| a richiesta | `php bin/inizializza-db.php --forza` | ricrea il database da capo |

Ogni comando si lancia con `../../tools/php.sh php bin/…`; `--help` non c'è, le opzioni sono scritte in testa a ogni script.

## I dati di esempio

I dati descrivono il gestionale alla fine di domenica 13 settembre 2026, con circa un anno di storia: ticket, fatture e provvigioni partono da settembre 2025. Li produce `genera.py` con un seme fisso. `python3 genera.py --check` verifica che i file di `database/dati/` siano esattamente quelli del generatore (uscita 0 se identici, 1 se diversi, 2 in caso di errore).
