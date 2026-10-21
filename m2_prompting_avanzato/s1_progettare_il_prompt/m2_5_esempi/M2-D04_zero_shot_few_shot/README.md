# M2-D04 — Zero-shot contro few-shot

Demo del Modulo 2, nella parte «Esempi: quando aiutano, quando
danneggiano». In aula la fate anche voi, in claude.ai; poi il docente
mostra la stessa prova in Claude Code.

## Obiettivo

Mettere alla prova tre affermazioni di Anthropic sugli esempi e sul
formato della risposta. La stessa segnalazione, da classificare nel
formato «categoria | priorità | team», va a quattro prompt, e ognuno
cambia una cosa sola rispetto al precedente: senza esempi; con due
esempi; con l'elenco delle etichette ammesse; lo stesso prompt con uno
schema JSON.

## Tempo

3 minuti in aula; circa 6 per rifarla da soli.

## Prerequisiti

Un account claude.ai con il piano Pro; per la parte in Claude Code, Claude
Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto verde
(`PRIMA_DEL_CORSO.md`); Python 3, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D04)

Lo spazio di lavoro `~/corso-claude-code/M2-D04/` con:

- `zero-shot.md`: l'istruzione e la segnalazione da classificare (i
  backup notturni verso il cloud che non finiscono più in tempo);
- `few-shot.md`: lo stesso prompt con due segnalazioni già classificate,
  fra i tag `<examples>` e `<example>`;
- `con-etichette.md`: il prompt di `few-shot.md` con l'elenco delle
  categorie, delle priorità e dei team, e la regola «Usa solo le
  etichette elencate.»;
- `schema.json`: lo schema JSON della classificazione, con un `enum` per
  campo, uguale agli elenchi di `con-etichette.md`;
- `istruzione.txt`: «Rispondi in italiano.»;
- `controlla_etichette.py`: legge il JSON di ogni chiamata, dice l'esito
  di tre affermazioni e scrive `esiti.tsv`;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

Le segnalazioni sono inventate, come tutti i dati del corso.

## Passi in Claude Code

1. **In claude.ai, con il modello predefinito:** aprite una chat nuova,
   incollate il testo di `zero-shot.md` (nella cartella `demo/` di questo
   elemento, o nello spazio di lavoro del passo 2) e inviate. Poi un'altra
   chat nuova, con `few-shot.md`. Per ognuna delle due risposte
   controllate a occhio una regola, «una riga sola, minuscole e trattino
   basso, tre campi separati da |», e dite a voce se la rispetta.

2. **In Claude Code:** preparate lo spazio di lavoro ed entrateci, dalla
   cartella `esercitazioni`:

       tools/prepara_esercizio.sh M2-D04
       cd ~/corso-claude-code/M2-D04

3. I quattro prompt su Haiku e su Sonnet, una chiamata ciascuno, con il
   JSON della risposta in `risposte/`. La quarta chiamata manda il prompt
   di `con-etichette.md` con `--json-schema`:

       chiedi() {
         local m="$1" p="$2"
         shift 2
         claude -p "$(cat "$p")" --model "$m" --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --output-format json "$@"
       }
       mkdir -p risposte
       for m in haiku sonnet; do
         for v in zero-shot few-shot con-etichette; do
           chiedi "$m" "$v.md" > "risposte/$v-$m.json"
         done
         chiedi "$m" con-etichette.md --json-schema "$(cat schema.json)" \
           > "risposte/schema-$m.json"
       done

4. Che cosa è arrivato, e l'esito delle tre affermazioni:

       python3 controlla_etichette.py

## Che cosa osservare

### Che cosa dice Anthropic

- Sugli esempi, nella guida «Best practice per il prompting», sezione
  «Usa gli esempi in modo efficace»: «Gli esempi sono uno dei modi più
  affidabili per orientare il formato, il tono e la struttura dell'output
  di Claude.» Per la stessa sezione gli esempi vanno strutturati:
  «racchiudi gli esempi in tag `<example>` (più esempi in tag
  `<examples>`) in modo che Claude possa distinguerli dalle istruzioni.»
  E aggiunge: «Includi 3–5 esempi per ottenere i migliori risultati.»
  Qui gli esempi sono due: la prova guarda la forma della risposta, non
  la bontà della classificazione.
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Sul formato chiesto nel prompt, nella stessa guida: «Sii specifico sul
  formato di output desiderato e sui vincoli.» (sezione «Sii chiaro e
  diretto»); e «Prova prima a chiedere al modello di conformarsi alla tua
  struttura di output, poiché i modelli più recenti possono rispettare in
  modo affidabile schemi complessi quando viene loro richiesto,
  specialmente se implementato con tentativi ripetuti.» (sezione «Migrare
  dalle risposte precompilate»).
- Sulla classificazione, subito dopo: «Per le attività di
  classificazione, usa strumenti con un campo enum contenente le
  etichette valide oppure gli structured outputs.» Con `claude -p` lo
  schema si passa con `--json-schema`: «Ottieni output JSON convalidato
  corrispondente a uno JSON Schema dopo che l'agente completa il suo
  flusso di lavoro (solo modalità print).»
  (https://code.claude.com/docs/it/cli-reference). La pagina a cui
  rimanda spiega che l'SDK «convalida l'output rispetto ad esso,
  ripetendo la richiesta in caso di mancata corrispondenza. Se la
  convalida non ha successo entro il limite di tentativi, il risultato è
  un errore anziché dati strutturati»
  (https://code.claude.com/docs/it/agent-sdk/structured-outputs). E per
  `claude -p`: «Se un'esecuzione termina senza un output strutturato
  valido, ad esempio perché Claude ha rifiutato la richiesta, la risposta
  non contiene il campo `structured_output`.»
  (https://code.claude.com/docs/it/headless)
- Sulle maiuscole, nella pagina «Output strutturati»: «Gli output
  strutturati non garantiscono l'uso delle maiuscole nei valori `enum` e
  `const` di tipo stringa»; e: «Confronta i valori enum senza distinzione
  tra maiuscole e minuscole».
  https://platform.claude.com/docs/it/build-with-claude/structured-outputs

### Che cosa misura il controllo

`controlla_etichette.py` legge il JSON di ogni chiamata e scrive
`esiti.tsv`, una riga per file:

- `forma_esempi`: «sì» se la risposta è una riga sola nella forma degli
  esempi, tre campi di lettere minuscole e trattini bassi separati da
  « | »; un «Classificazione:» davanti è ammesso, perché c'è negli
  esempi. Il grassetto, una seconda riga o una maiuscola danno «no»;
- `etichette_ammesse`, solo per `con-etichette`: «sì» se ogni campo è fra
  le etichette elencate nel prompt («—» se la risposta non ha la forma);
- `oggetto_schema`, solo per `schema`: «sì» se `structured_output`
  rispetta `schema.json` (le tre chiavi, nessuna in più, ogni valore fra
  quelli dell'`enum`, senza badare alle maiuscole), «no» se non lo
  rispetta, «assente» se la risposta non ce l'ha;
- `scelta`: la categoria, la priorità e il team come li ha scritti il
  modello; senza la forma, la risposta intera.

Prima di leggere le risposte controlla che gli `enum` di `schema.json`
siano uguali agli elenchi di `con-etichette.md`: se non lo sono si
ferma. In claude.ai la regola del passo 1 la controllate voi, a occhio:
è quella della colonna `forma_esempi`.

Poi, per Haiku e per Sonnet, dice l'esito di ogni affermazione di cui ci
sono le risposte:

- «Gli esempi orientano il formato»: confermata se la forma degli esempi
  manca senza esempi e c'è con gli esempi; non distinguibile se c'è già
  senza esempi; non confermata in questa esecuzione se manca con gli
  esempi.
- «Con l'elenco nel prompt, forma ed etichette rispettate»: confermata se
  la risposta di `con-etichette` ha la forma e solo etichette elencate;
  altrimenti non confermata in questa esecuzione.
- «Con --json-schema, l'oggetto rispetta lo schema»: confermata se
  `oggetto_schema` vale «sì». È una garanzia: un «no» fa fallire la
  verifica, e un oggetto assente è una chiamata fallita, da rifare.

Le prime due sono raccomandazioni: il loro esito si stampa e non fa
fallire la verifica. Quale categoria, quale priorità e quale team sceglie
il modello è un giudizio sul caso, non un fatto che Anthropic dichiara: il
controllo li stampa e non li giudica. `tools/verifica.sh M2-D04` fa girare
lo stesso controllo, quello della cartella dell'elemento, sulle risposte
dello spazio di lavoro: decide dalle risposte, non legge `esiti.tsv` e non
scrive niente.

Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.305,
Haiku e Sonnet, tre chiamate per variante e modello): la forma degli
esempi 0 su 6 senza esempi e 6 su 6 con gli esempi; forma ed etichette
elencate 6 su 6 con l'elenco; l'oggetto conforme allo schema 6 su 6 con
lo schema.

## Verifica (tools/verifica.sh M2-D04)

La verifica fa girare `controlla_etichette.py` dell'elemento sulle
risposte di `risposte/`, senza scrivere niente (non legge `esiti.tsv`). È
fatta quando le otto risposte (quattro varianti per due modelli) ci sono
e, con `--json-schema`, l'oggetto rispetta lo schema su tutti e due i
modelli. Gli esiti delle altre due affermazioni si stampano e non fanno
fallire la verifica. La parte in claude.ai non si verifica: la raccontate
a voce.

## Se qualcosa va storto

- In claude.ai la risposta spiega a lungo invece di stare in una riga:
  anche questo è un esito, e la regola dice no.
- `controlla_etichette.py` dice che una risposta manca, o che non è il
  JSON di `claude -p`: rifate la chiamata di quella variante e di quel
  modello, poi di nuovo `python3 controlla_etichette.py`.
- `controlla_etichette.py` dice che un `enum` di `schema.json` è diverso
  da un elenco di `con-etichette.md`: uno dei due file è cambiato, e
  anche la verifica si ferma; `tools/reset_esercizio.sh M2-D04` riporta
  lo spazio di lavoro all'inizio (le risposte si perdono).
- Con lo schema la verifica dice «chiamata fallita»: la risposta non ha
  `structured_output`; rifate quella chiamata.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D04`.

## Impronta d'uso sul piano Pro

In claude.ai, due messaggi brevi. In Claude Code, otto chiamate brevi su
Haiku e Sonnet, quattro per modello, con effort low, nessuno strumento e
nessun subagent. Con lo schema, un oggetto che non lo rispetta fa
ripetere la richiesta (vedete «Che cosa dice Anthropic»): quelle due
chiamate possono costare un po' di più.

## Per approfondire

- Gli esempi, il formato e la classificazione nella guida «Best practice
  per il prompting»:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Gli output strutturati, e le maiuscole nei valori enum:
  https://platform.claude.com/docs/it/build-with-claude/structured-outputs
- `--json-schema` nel riferimento della CLI, e l'output strutturato di
  `claude -p`: https://code.claude.com/docs/it/cli-reference e
  https://code.claude.com/docs/it/headless
- La lezione «Effective prompting techniques» del corso AI Fluency della
  Claude Academy:
  https://academy.claude.com/courses/ai-fluency-framework-foundations/effective-prompting-techniques
