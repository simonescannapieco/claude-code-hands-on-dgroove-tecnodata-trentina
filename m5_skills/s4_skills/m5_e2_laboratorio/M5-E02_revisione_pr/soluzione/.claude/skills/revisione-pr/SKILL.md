---
name: revisione-pr
description: Rivede un pull request del gestionale PHP contro le convenzioni numerate del team e risponde con una tabella di regola, file e riga per ogni violazione, più l'esito approvabile o da modificare. Controlla anche ciò che manca, come il test o la copia legacy non aggiornata, e le regole del codice legacy. Da usare quando si chiede di rivedere un pull request, un branch o una differenza, di dare un'occhiata prima del merge o di dire se si può unire, anche se le convenzioni non vengono nominate.
compatibility: Requires Claude Code, git and python3
allowed-tools: Bash(python3 *) Bash(git diff *)
---

# Revisione di un pull request

## Il pull request

La differenza rispetto a `main`:

!`git diff main...HEAD`

Il prospetto di `scripts/segnala.py`: le righe aggiunte con il numero di riga del file nuovo, i candidati a violazione, le copie gemelle in `legacy/` o `src/`, i test, i commit. Lo prepara lo script perché la shell può essere negata durante la revisione, e numeri di riga e ricerche non si fanno a occhio.

!`python3 ${CLAUDE_SKILL_DIR}/scripts/segnala.py main`

## Procedura

1. Leggi `references/convenzioni.md` per intero: le regole numerate valgono per ogni pull request, e la sezione 1 dice quali valgono dove.
2. Classifica ogni file cambiato secondo quella sezione: codice nuovo, `legacy/`, file generati.
3. Passa le sezioni delle convenzioni una alla volta, dalla 2 alla 11, e per ciascuna chiediti se una riga aggiunta la viola. Un passaggio solo sulle regole che saltano all'occhio lascia fuori le meno vistose (per esempio il formato delle date, 5.4). Dai ai candidati del prospetto una conferma o uno scarto leggendo il file; ciò che il pull request non tocca non si rivede. In `legacy/` valgono solo le regole della sezione 9.
4. Controlla poi il pull request nel suo insieme, con la lista qui sotto.
5. Scrivi la revisione con il modello qui sotto: una riga per ogni violazione, anche se la stessa regola torna due volte, perché chi corregge lavora riga per riga.
6. Prima di chiudere, rileggi la tabella: ogni numero di regola esiste nelle convenzioni, e ogni file e ogni riga stanno nella differenza.

## Controlli sull'insieme

Per ogni pull request, anche se la differenza sembra a posto:

- **Test**: ogni modifica a `src/` ha un test che fallirebbe senza la modifica (10.2). Una correzione di calcolo ha un test su un caso che prima dava il risultato sbagliato (per gli importi, 5.2). Una modifica di comportamento in `legacy/` ha prima un test di caratterizzazione (9.3). Se nella differenza non c'è nessun test, è una violazione: riga con file `-` e riga `-`.
- **Copia gemella**: se la modifica cambia una regola di calcolo o di dominio, la stessa logica può stare nell'altra metà, `legacy/` o `src/`. Parti dalle gemelle del prospetto; se non ne elenca, leggi i file dell'altra metà sul tema (per esempio i totali o l'IVA). Se la copia non è stata aggiornata, è una violazione di 9.6, e la riga della tabella ha il file e la riga della copia rimasta com'era, non `-`: chi corregge deve sapere dove andare.
- **Legacy**: in `legacy/` una funzionalità nuova viola 9.1 e il titolo mancante del motivo viola 9.2. Righe riformattate (indentazione, virgolette, `isset` in `??`, query spezzate) insieme a un cambio di comportamento violano 9.4: una riga per ogni zona riformattata, con il file e la riga di inizio. Il codice nuovo che chiama il legacy senza classe ponte viola 9.5.
- **Insieme**: formato dei commit (11.1), dimensione e una cosa sola (11.2), descrizione (11.3), file generati toccati a mano (1.3).
- **Errori silenziati**: un `catch` vuoto è 6.3, anche se restituisce un valore di ripiego.

Una regola si cita sempre per numero: non descrivere un problema che una regola copre senza il suo numero.

## Modello della revisione

```markdown
| regola | file | riga | che cosa non va | come si corregge |
|---|---|---|---|---|
| 7.1 | src/Clienti/ClienteRepository.php | 42 | valore concatenato nell'SQL | query preparata con parametri con nome |

Esito: da modificare
```

L'esito è `approvabile` quando la tabella è vuota, `da modificare` altrimenti. Con nessuna violazione la tabella non serve: scrivi «Nessuna violazione» e l'esito.

Rispondi sempre con la tabella e l'esito, anche se la richiesta è informale («mi dai un'occhiata?», «si può unire?»): chi legge corregge riga per riga. Nessun giudizio generico come «è corretta, via libera» prima della tabella. La revisione è di sola lettura: non modificare file e non offrire di applicare le correzioni; il «come si corregge» sta nella tabella.

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

- Un problema che nessuna regola numerata descrive non va in tabella: scrivilo sotto, in una riga che comincia con «Fuori regola:». Prima cerca la regola: molti problemi ne hanno una (SQL concatenato 7.1, query in un ciclo 7.3, valore non protetto nel template 8.1, `float` per il denaro 5.1).
- Se la shell è negata, non riprovarla: usa il prospetto e la lettura dei file. Un controllo davvero impossibile lo dici in una riga, dopo l'esito.
- Il numero che citi è quello delle convenzioni: se due regole descrivono lo stesso problema, cita la più specifica.

## Gotchas

- I percorsi della differenza partono dalla radice dello spazio di lavoro, per esempio `progetti/gestionale-php/src/…`: la sezione 1 delle convenzioni parla delle cartelle sotto `progetti/gestionale-php/`.
- Una violazione può stare in ciò che manca, non solo nelle righe aggiunte.
