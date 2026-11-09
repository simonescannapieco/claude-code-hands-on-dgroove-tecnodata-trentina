# Il banco di prova dell'assistente

Serve agli elementi del Modulo 7 per mettere alla prova l'assistente di CiaspoLink senza API: un assistente è una cartella con `system-prompt.md` e `strumenti.json` (e, se c'è, `regole-escalation.md`, che finisce in coda al system prompt); Claude Code lo fa girare con `--system-prompt-file`, `--tools ""` e un server MCP locale al posto dei sistemi veri. Si esegue con `tools/prova_assistente.sh <spazio di lavoro> <comando>` oppure, dallo spazio di lavoro, con `python3 progetti/assistenza-clienti/banco/prova.py <comando>`.

| file | che cosa fa |
|---|---|
| `motore.py` | le capacità sui dati di uno scenario (solo libreria standard) |
| `server/` | il server MCP: `server_banco.py`, un progetto uv con FastMCP fissato in `uv.lock` |
| `prova.py` | i comandi `casi`, `conversazione`, `giudica` |
| `confronta.py` | due versioni a confronto, caso per caso |
| `lib_banco.py` | casi, stream, registro, asserzioni, verdetto della rubrica |
| `casi/` | i cinque casi forniti (uno snapshot ciascuno, con le asserzioni) |
| `.claude/agents/` | il cliente simulato, l'agente `cliente` (su Haiku), e il `giudice` (su Sonnet) |

Serve uv, come per M4-D02: alla prima esecuzione `prova.py` prepara l'ambiente del server dalle versioni fissate in `uv.lock`, una volta sola, fuori dal repository (`~/.cache/corso-claude-code/banco-server`).

## I comandi

```bash
# Ogni caso è una sola chiamata: i casi di casi/, tre alla volta
python3 prova.py casi --versione ../v0 --uscita risultati/v0

# Una conversazione con un cliente simulato, fino a quattro giri
python3 prova.py conversazione --versione ../v0 --scenario ../scenari/sc-04-….json --uscita risultati/conv

# Il giudice su una conversazione nel formato di golden/
python3 prova.py giudica --conversazione ../golden/gc-01-….json --uscita risultati/giudice

# Due versioni a confronto
python3 confronta.py risultati/v0 risultati/v1
```

Altre opzioni di `casi`: `--casi DIR` (i vostri casi), `--kb DIR` (un'altra base di conoscenza), `--paralleli 1|2|3`, `--schema FILE` (uno schema JSON per l'uscita strutturata: finisce nel campo `strutturato` di `esito.json`). Una cartella di uscita già usata non si sovrascrive: si cancella e si rilancia con lo stesso nome, perché le verifiche leggono i nomi fissi (un'altra uscita solo per una prova in più).

In `casi` e in `conversazione` esce 0 quando ogni chiamata è finita bene. Le asserzioni e i verdetti sono dati: li stampa, ma non decidono l'uscita. Esce 1 se una chiamata non è finita, 2 se manca qualcosa per partire. In ogni cartella d'esito ci sono `esito.json`, `trascrizione.md` (o `conversazione.json`), `registro.jsonl` (tutte le chiamate agli strumenti) e `stream.jsonl`.

## Gli strumenti di una versione

`strumenti.json` è una lista: `name`, `description`, `input_schema` e, per collegare uno strumento a ciò che risponde, il campo `capacita`. Il modello non vede `capacita`. Si possono cambiare nomi, descrizioni e parametri senza toccare il codice: il motore cerca i valori per forma (un codice `CL-000000`, una linea `LN-000000`, un'e-mail, un numero di fattura) dentro tutti gli argomenti. Le capacità sono:

`verifica_identita`, `stato_linea`, `guasti_in_corso`, `cerca_kb`, `cerca_cliente`, `leggi_ticket`, `apri_ticket`, `aggiorna_ticket`, `chiudi_ticket`, `gestisci_ticket`, `slot_disponibili`, `prenota_intervento`, `verifica_copertura`, `leggi_fattura`, `registra_accredito`, `passa_a_operatore`, `invia_sms`.

Gli strumenti del v0 hanno i loro nomi e il campo non serve: `gestisci_ticket` è il loro strumento unico `ticket`, e il registro segna la capacità che ha usato davvero (`apri_ticket`, `aggiorna_ticket`…). Uno strumento che non dice la sua capacità ferma `prova.py` prima di ogni chiamata, con un messaggio (`strumento non collegato`) che le elenca.

## I casi

Un caso è un file JSON: `id`, `titolo`, `scenario` (un file di `../scenari/`, i cui dati riempiono il server), `messaggio` (il messaggio del cliente, una sola chiamata: dentro ci stanno già i dati per riconoscerlo, se servono) e `asserzioni`:

| asserzione | vero quando |
|---|---|
| `deve_chiamare`, `non_deve_chiamare` | capacità chiamate o no: nomi di capacità, così una definizione riscritta resta confrontabile |
| `prima_di` | coppie `[a, b]`: `a` compare prima di `b`; se `b` non è stata chiamata, l'asserzione vale |
| `risposta_contiene`, `risposta_non_contiene` | espressioni regolari sulla risposta, senza distinguere maiuscole e minuscole |
| `escalation` | `true`: `passa_a_operatore` chiamata; `false`: mai chiamata |

Una stringa cercata nella risposta dice solo se è scritta: non capisce un «non è vero che» e non capisce un avvertimento. Le asserzioni più solide stanno sulle chiamate agli strumenti.

## Il cliente simulato e il giudice

Il cliente simulato (l'agente `cliente`) legge la scheda dello scenario e la conversazione e scrive il prossimo messaggio del cliente, o `FINE`; non vede la verità nascosta, solo i dati della sua scheda. Il giudice `giudice` applica `../valutazione/rubrica.md`: dà i voti per criterio in `--json-schema`, e il totale e il verdetto li calcola il codice (`lib_banco.verdetto`). Un voto che il giudice non sa dare resta `null`, e il verdetto è «non so».

Il giudice non ha una riga `tools` nel frontmatter: gli strumenti li toglie `--tools ""` sulla riga di comando.

## Impronta d'uso

Un caso, su Sonnet con effort low, è una chiamata di 2–7 turni con pochi strumenti. Una conversazione di quattro giri è circa un minuto, e circa 120.000 token in gran parte dalla cache. Il giudice è una chiamata di 1–2 turni. Le misure di ogni elemento sono nel suo README.
