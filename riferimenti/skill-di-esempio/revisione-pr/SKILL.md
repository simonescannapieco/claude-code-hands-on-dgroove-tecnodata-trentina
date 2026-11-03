---
name: revisione-pr
description: Rivede un pull request del gestionale PHP contro le convenzioni numerate del team e cita il numero di ogni regola non rispettata. Da usare quando si chiede di rivedere un pull request, un branch o una differenza del gestionale, o di dire se una modifica è pronta per il merge, anche se le convenzioni non vengono nominate.
compatibility: Requires Claude Code and git
---

# Revisione di un pull request

## Il pull request

I commit rispetto a `main`:

!`git log --format='%h %s' main..HEAD`

I file cambiati:

!`git diff --stat main...HEAD`

La differenza:

!`git diff main...HEAD`

## Procedura

1. Leggi `references/convenzioni.md` per intero: le regole numerate valgono per ogni pull request, e la sezione 1 dice quali valgono dove.
2. Classifica ogni file cambiato secondo quella sezione: codice nuovo, `legacy/`, file generati.
3. Confronta ogni riga aggiunta con le regole che valgono per quel file. Se ti serve il contesto intorno a una riga, leggi il file; ciò che il pull request non tocca non si rivede.
4. Controlla poi il pull request nel suo insieme: i messaggi di commit, la dimensione, i test.
5. Scrivi la revisione con il modello qui sotto: una riga per ogni violazione, anche se la stessa regola torna due volte, perché chi corregge lavora riga per riga.
6. Prima di chiudere, rileggi la tabella: ogni numero di regola esiste nelle convenzioni, e ogni file e ogni riga stanno nella differenza.

## Modello della revisione

```markdown
| regola | file | riga | che cosa non va | come si corregge |
|---|---|---|---|---|
| 7.1 | src/Clienti/ClienteRepository.php | 42 | valore concatenato nell'SQL | query preparata con parametri con nome |

Esito: da modificare
```

L'esito è `approvabile` quando la tabella è vuota, `da modificare` altrimenti. Con nessuna violazione la tabella non serve: scrivi «Nessuna violazione» e l'esito.

## Esempi

Una riga aggiunta in un file nuovo di `src/Report/`:

```php
public function totale($cliente)
```

La sua riga nella revisione:

```markdown
| 4.1 | src/Report/ReportFatturato.php | 12 | parametro e valore di ritorno senza tipo | `int $clienteId`, ritorno `int` |
```

Una riga aggiunta in `src/Clienti/`:

```php
$riga = $db->query("SELECT * FROM clienti WHERE id = " . $id)->fetch();
```

La sua riga nella revisione:

```markdown
| 7.1 | src/Clienti/ClienteRepository.php | 42 | valore concatenato nell'SQL | query preparata con il parametro `:id` |
```

## Casi limite

- Un problema che nessuna regola numerata descrive non va in tabella: scrivilo sotto, in una riga che comincia con «Fuori regola:».
- Il numero che citi è quello delle convenzioni: se due regole descrivono lo stesso problema, cita la più specifica.

## Gotchas

- I percorsi della differenza partono dalla radice dello spazio di lavoro, per esempio `progetti/gestionale-php/src/…`: la sezione 1 delle convenzioni parla delle cartelle sotto `progetti/gestionale-php/`.
- Una violazione può stare in ciò che manca, non solo nelle righe aggiunte.
