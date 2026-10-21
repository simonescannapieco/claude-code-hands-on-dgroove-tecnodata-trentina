# M2-D03 — Solo JSON, o uno schema

Demo del Modulo 2, nella parte «Tag e struttura». In aula la esegue il
docente; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova tre affermazioni di Anthropic sull'output in JSON, e
mostrarne una quarta, con la stessa estrazione dal messaggio di un
cliente: chiesta a parole su tre modelli, poi su Haiku con uno schema
(`--json-schema`), poi su Haiku con uno schema non valido. Le tre chiamate
su Haiku differiscono in una cosa sola: lo schema.

## Tempo

3 minuti in aula; circa 7 per rifarla da soli.

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
- `schema-non-valido.json`: lo stesso schema con una parola cambiata,
  `"type": "oggetto"` al posto di `"type": "object"`; «oggetto» non è un
  tipo di JSON Schema;
- `istruzione.txt`: «Rispondi in italiano.»;
- `controlla_json.py`: mette alla prova tre affermazioni, mostra la quarta
  e scrive `esiti.tsv`, una riga per affermazione;
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
           --strict-mcp-config --no-session-persistence \
           --output-format json > "risposte/solo-json-$m.json"
       done

3. La stessa richiesta con lo schema, su Haiku:

       claude -p "$(cat richiesta-json.md)" --model haiku --effort low \
         --tools "" --system-prompt "$(cat istruzione.txt)" \
         --strict-mcp-config --no-session-persistence \
         --output-format json --json-schema "$(cat schema.json)" \
         > risposte/schema-haiku.json
       python3 leggi_json.py structured_output < risposte/schema-haiku.json

4. La stessa chiamata con lo schema non valido. Lo STDOUT va in un file;
   lo STDERR e il codice d'uscita in un altro, perché il controllo li
   legge separati:

       claude -p "$(cat richiesta-json.md)" --model haiku --effort low \
         --tools "" --system-prompt "$(cat istruzione.txt)" \
         --strict-mcp-config --no-session-persistence \
         --output-format json --json-schema "$(cat schema-non-valido.json)" \
         > risposte/schema-non-valido.json 2> risposte/schema-non-valido.txt
       echo "uscita: $?" >> risposte/schema-non-valido.txt
       cat risposte/schema-non-valido.txt

   La riga con `echo` va subito dopo `claude`: `$?` è il codice d'uscita
   del comando appena eseguito.

5. Le affermazioni alla prova:

       python3 controlla_json.py

   Stampa i numeri che legge, l'esito delle prime tre affermazioni e la
   dimostrazione della quarta, e scrive `esiti.tsv`.

`_docente/live.sh`, la prova del docente, e la registrazione del corso
mandano gli stessi testi con le stesse opzioni, più
`--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`.

## Che cosa osservare

### Che cosa dice Anthropic

1. **Il JSON chiesto a parole è da provare.** Nella pagina sugli output
   strutturati: «Senza output strutturati, Claude può generare risposte
   JSON malformate o input di strumenti non validi che compromettono le
   tue applicazioni. Anche con un prompting accurato, potresti
   incontrare:», fra l'altro, «Errori di parsing dovuti a sintassi JSON
   non valida» e «Campi obbligatori mancanti».
   https://platform.claude.com/docs/it/build-with-claude/structured-outputs

   Nella pagina sulla coerenza dell'output: «Se hai bisogno che Claude
   produca sempre JSON valido conforme a uno schema specifico, usa gli
   Structured Outputs (output strutturati) invece delle tecniche di prompt
   engineering riportate di seguito.»
   https://platform.claude.com/docs/it/test-and-evaluate/strengthen-guardrails/increase-consistency

   E nelle best practice per il prompting, al posto delle risposte
   precompilate: «Prova prima a chiedere al modello di conformarsi alla
   tua struttura di output, poiché i modelli più recenti possono
   rispettare in modo affidabile schemi complessi quando viene loro
   richiesto, specialmente se implementato con tentativi ripetuti.»
   https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices

2. **Con `--json-schema`, un oggetto convalidato in `structured_output`.**
   «Per ottenere output conforme a uno schema specifico, utilizza
   `--output-format json` con `--json-schema` e una definizione JSON
   Schema. La risposta include metadati sulla richiesta (ID sessione,
   utilizzo, ecc.) con l'output strutturato nel campo
   `structured_output`.» E: «Se un'esecuzione termina senza un output
   strutturato valido, ad esempio perché Claude ha rifiutato la
   richiesta, la risposta non contiene il campo `structured_output`.
   Prima che il tuo script utilizzi `structured_output`, verifica che il
   campo sia presente.»
   https://code.claude.com/docs/it/headless

   Il riferimento della CLI, per `--json-schema`: «Ottieni output JSON
   convalidato corrispondente a uno JSON Schema dopo che l'agente completa
   il suo flusso di lavoro (solo modalità print).»
   https://code.claude.com/docs/it/cli-reference

   La pagina sugli output strutturati degli agenti, a cui rimanda: «Un
   risultato può anche terminare con subtype `success` ma senza valore
   `structured_output`, ad esempio quando l'esecuzione si completa senza
   che l'agente produca un output strutturato. Trattare anche quel caso
   come un errore.»
   https://code.claude.com/docs/it/agent-sdk/structured-outputs

3. **Uno schema non valido ferma `claude` all'avvio.** «Se il valore non è
   un JSON Schema valido, `claude` esce con `Error: --json-schema is not a
   valid JSON Schema` seguito dalla diagnostica del validatore.»
   https://code.claude.com/docs/it/headless

   «Uno schema che non è un JSON Schema valido non riesce all'avvio con un
   errore che nomina il problema.»
   https://code.claude.com/docs/it/agent-sdk/structured-outputs

4. **Lo schema controlla la forma, non il contenuto.** Fra le conoscenze
   che chiede la guida d'esame «Claude Certified Architect –
   Foundations», al task 4.3: «che gli schemi JSON rigorosi via tool use
   eliminano gli errori di sintassi ma non impediscono gli errori
   semantici» (traduzione nostra).
   https://everpath-course-content.s3-accelerate.amazonaws.com/instructor%2F6nizmqk8tpzpfjvt6qmmav7rh%2Fpublic%2F1783542750%2FClaude+Certified+Architect+%E2%80%93+Foundations+Exam+Guide.pdf

### Che cosa misura il controllo

`python3 controlla_json.py` legge le risposte e scrive `esiti.tsv`: per
ogni affermazione la classe (garantita, da provare, oppure dimostrazione),
l'esito («confermata», «non confermata in questa esecuzione», oppure «non
distinguibile» quando manca la risposta che serve; «nessun verdetto» per
la dimostrazione) e i numeri letti.

1. «Se lo chiedete, il JSON arriva valido e conforme» (da provare). Per
   ogni modello: il testo intero della risposta si legge come JSON, come
   lo leggerebbe un programma? E rispetta `schema.json`: le cinque chiavi,
   nessuna in più, i valori ammessi? Il controllo stampa quante risposte
   lo sono, «n su 3», poi «confermata» se lo sono tutte e tre, altrimenti
   «non confermata in questa esecuzione» («non distinguibile» se una
   risposta manca). È una raccomandazione, non una garanzia: confermata o
   no, non fa fallire la verifica; una risposta che manca, invece, la fa
   fallire, come per ogni affermazione.
2. «Con --json-schema, structured_output è validato» (garantita). La
   chiamata finisce con subtype `success`, e `structured_output` c'è e
   rispetta `schema.json`. Se il campo manca, la chiamata è finita senza
   un output strutturato valido: la documentazione dice di trattarla come
   un errore, e il controllo chiede di rifarla.
3. «Uno schema non valido fa uscire claude con un errore, all'avvio»
   (garantita). Il codice d'uscita non è 0, c'è la riga «is not a valid
   JSON Schema», e sullo STDOUT non c'è una risposta (né `result` né
   `usage`). Se c'è la riga d'errore ma la riga «uscita» dice 0 e sullo
   STDOUT non c'è niente, la prova non decide («non distinguibile»): la
   riga con `echo` non è venuta subito dopo `claude`, e il passo 4 va
   rifatto.
4. «Lo schema controlla la forma, non il contenuto»: una dimostrazione,
   non un verdetto. Il controllo copia l'oggetto della 2, cambia
   `tipo_cliente` in un altro valore ammesso («privato» al posto di
   «azienda», per esempio) e lo valida di nuovo: lo schema accetta l'uno e
   l'altro, e quale dei due sia giusto per questo cliente non lo sa. È un
   oggetto modificato dal controllo, non una risposta del modello: lo
   costruisce e lo valida il controllo stesso, quindi nessuna esecuzione
   può dire se l'affermazione vale. Si stampa con le sue righe, senza
   esito, e non si conta fra le garanzie, che sono la 2 e la 3. Accanto,
   un dato e non un verdetto: in quante risposte c'è il telefono del
   cliente, un dato personale di cui la richiesta non dice che cosa fare.

Nella registrazione del corso (20 ottobre 2026, Claude Code 2.1.305):
l'affermazione 1, 3 su 3 validi e conformi; la 2, confermata; la 3,
confermata, con uscita 1 e la riga «Error: --json-schema is not a valid
JSON Schema: data/type must be equal to one of the allowed values,
data/type must be array, data/type must match a schema in anyOf»; nella
dimostrazione della 4, la copia dell'oggetto della 2 con «privato» al
posto di «azienda» è conforme allo schema; il telefono del cliente in 4
risposte su 4.

## Verifica (tools/verifica.sh M2-D03)

La verifica fa girare `controlla_json.py` dell'elemento sulle risposte
dello spazio di lavoro, senza scrivere niente: decide dalle risposte, e
non legge `esiti.tsv`. Ne stampa i numeri e gli esiti. È fatta quando ogni
risposta c'è e le due garanzie, la 2 e la 3, sono confermate; la 1 è da
provare: si conta, e non fa fallire la verifica; la 4 è una
dimostrazione, senza esito. Una garanzia non confermata la dice così: «La
documentazione garantisce che …: in questa esecuzione no.»

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- `controlla_json.py` dice «non distinguibile» e nomina un file: rifate il
  passo indicato fra parentesi, poi rilanciate `python3 controlla_json.py`.
- Al passo 4 `claude` risponde invece di fermarsi: il controllo segna la 3
  come «non confermata in questa esecuzione». È una differenza dalla
  documentazione: segnalatela al docente. Se invece esce con un altro
  errore, la 3 è «non distinguibile»: leggete
  `risposte/schema-non-valido.txt`.
- La 3 è «non distinguibile» con «uscita: 0» accanto alla riga d'errore:
  la riga con `echo` non è venuta subito dopo `claude`, e `$?` è il codice
  di un altro comando. Rifate il passo 4 così com'è.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D03`.

## Impronta d'uso sul piano Pro

Quattro chiamate brevi al modello, senza strumenti e con effort low: una
per modello a parole e una con lo schema su Haiku. La quinta, con lo
schema non valido, secondo la documentazione si ferma all'avvio, e il
controllo verifica che sullo STDOUT non ci sia `usage`. Opus pesa sul
limite d'uso più degli altri: qui è una chiamata sola. Nessun subagent.

## Per approfondire

- L'output strutturato di `claude -p` (`--json-schema`):
  https://code.claude.com/docs/it/headless
- L'output strutturato degli agenti, e quando non arriva:
  https://code.claude.com/docs/it/agent-sdk/structured-outputs
- L'output strutturato nella documentazione della piattaforma:
  https://platform.claude.com/docs/it/build-with-claude/structured-outputs
