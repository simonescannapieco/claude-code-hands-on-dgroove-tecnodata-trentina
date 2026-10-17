# M2-D03 — Solo JSON, o uno schema

Demo del Modulo 2, nella parte «Tag e struttura». In aula la esegue il
docente; potete rifarla da soli quando volete.

## Obiettivo

Vedere la differenza fra chiedere «solo JSON» e dare uno schema: la stessa
estrazione dal messaggio di un cliente, prima con la richiesta a parole su
tre modelli, poi con `--json-schema`.

## Tempo

3 minuti in aula; circa 6 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D03)

Lo spazio di lavoro `~/corso-claude-code/M2-D03/` con:

- `messaggio.md`: il messaggio della Falegnameria Fittizia;
- `richiesta-json.md`: «rispondi SOLO con un JSON valido» con cinque chiavi
  (tipo di cliente, servizio, problema, urgenza, azione richiesta) e il
  messaggio tra tag;
- `schema.json`: lo schema delle cinque chiavi, con i valori ammessi;
- `istruzione.txt`: «Rispondi in italiano.»;
- `controlla_json.py`: scrive `esiti.tsv` (JSON valido, blocco di codice
  Markdown fra tre apici inversi, telefono del cliente, schema rispettato);
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D03
       cd ~/corso-claude-code/M2-D03

2. La richiesta a parole, sui tre modelli:

       mkdir -p risposte
       for m in haiku sonnet opus; do
         claude -p "$(cat richiesta-json.md)" --model "$m" --effort low \
           --tools "" --system-prompt "$(cat istruzione.txt)" \
           --strict-mcp-config --output-format json \
           > "risposte/solo-json-$m.json"
       done

3. La stessa richiesta con lo schema, su Haiku:

       claude -p "$(cat richiesta-json.md)" --model haiku --effort low \
         --tools "" --system-prompt "$(cat istruzione.txt)" \
         --strict-mcp-config --output-format json \
         --json-schema "$(cat schema.json)" > risposte/schema-haiku.json
       python3 leggi_json.py structured_output < risposte/schema-haiku.json

4. Che cosa è arrivato:

       python3 controlla_json.py

## Che cosa osservare

- Nella registrazione del corso, la richiesta a parole dà un JSON valido su
  tutti e tre i modelli, senza blocco di codice: sui modelli di oggi
  «solo JSON» di solito regge.
- Ma nessuno ha detto che cosa fare dei dati personali: in tutte e quattro
  le risposte il telefono del cliente finisce nell'azione richiesta.
- Con `--json-schema` l'oggetto arriva, validato, nel campo
  `structured_output` del JSON: la forma è garantita. Il contenuto no: il
  telefono c'è ancora. Lo schema toglie gli errori di forma, non quelli di
  contenuto.

## Verifica (tools/verifica.sh M2-D03)

In `esiti.tsv`: le tre risposte alla richiesta a parole ci sono, e con lo
schema l'oggetto rispetta `schema.json`.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- `controlla_json.py` dice che manca un file: rilanciate la chiamata di
  quel modello.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D03`.

## Impronta d'uso sul piano Pro

Quattro chiamate brevi senza strumenti, con effort low: una per modello e
una con lo schema su Haiku. Opus pesa sul limite d'uso più degli altri:
qui è una chiamata sola. Nessun subagent.

## Per approfondire

- L'output strutturato di `claude -p` (`--json-schema`):
  https://code.claude.com/docs/en/headless
- L'output strutturato nella documentazione della piattaforma:
  https://platform.claude.com/docs/en/build-with-claude/structured-outputs
