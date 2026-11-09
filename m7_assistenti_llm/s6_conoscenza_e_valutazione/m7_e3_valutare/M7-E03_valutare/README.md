# M7-E03 — Valutare e non regredire

Esercitazione del Modulo 7: misurare un assistente con metodo. Prima tarate il
giudice su conversazioni di cui conoscete il verdetto; poi scrivete un caso
nuovo e il suo opposto; infine fate girare la suite sulle due versioni
dell'assistente e leggete la tabella di regressione.

## Obiettivo

Fidarsi di una valutazione solo dopo averla provata. Il giudice è un modello che
applica una rubrica: lo mettete a confronto con quattro conversazioni di cui
sapete già come dovrebbe andare (tre conversazioni di riferimento del progetto e
una conversazione vera dell'assistente v0, andata male). Poi, con Claude Code,
scrivete un caso nuovo del banco e il suo opposto: lo stesso scenario, un
comportamento che deve accadere e uno che non deve. Infine fate girare i casi
sulle due versioni dell'assistente, v0 e v1, e confrontate: la tabella dice
dove la versione nuova tiene e dove regredisce.

## Tempo

30 minuti in aula: 10 con le slide, 19 di lavoro con il timer, 1 per chiudere. I
19 minuti: circa 4 per la taratura del giudice, 8 per il caso nuovo e il suo opposto,
4 per la suite e la tabella, il resto per leggere i risultati.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`): fra l'altro controlla `uv`, che serve al server
  del banco.
- Python 3 e git.
- Non serve aver fatto M7-E02: lo spazio di lavoro ha già una v1 di riferimento,
  in `v1-riferimento/`. Se avete la vostra v1 di M7-E02, copiatela sopra quella
  (`system-prompt.md`, `strumenti.json`, `regole-escalation.md` se c'è).

## Punto di partenza (tools/prepara_esercizio.sh M7-E03)

Lo spazio di lavoro `~/corso-claude-code/M7-E03/`, un repository git con un primo
commit, con:

- `progetti/assistenza-clienti/`: il progetto di assistenza con il banco di
  prova (`banco/`), i cinque casi forniti (`banco/casi/`), gli scenari, le
  conversazioni di riferimento (`golden/`), la rubrica, l'assistente v0 (`v0/`);
- `taratura/etichette.json`: per le quattro conversazioni della taratura il
  verdetto atteso e da dove viene; `taratura/conversazione-v0-sc-20.json`: la
  conversazione vera del v0 (lo dice il suo campo `fonte`);
- `v1-riferimento/`: la versione di riferimento dell'assistente.

Il primo commit vi serve per vedere che cosa cambia (`git status`).

## Passi in Claude Code

Tenete aperti due terminali: nel primo lavorate nello spazio di lavoro, nel
secondo, dalla cartella `esercitazioni`, lanciate la verifica quando serve.

1. Dalla cartella `esercitazioni`, nel primo terminale:

       tools/prepara_esercizio.sh M7-E03
       cd ~/corso-claude-code/M7-E03

2. **Tarate il giudice.** Il giudice è l'agente del banco, `progetti/assistenza-clienti/banco/.claude/agents/giudice.md`,
   che applica la rubrica e restituisce un voto per criterio, nello schema che
   `--json-schema` impone: «prova.py giudica» lo lancia su ogni conversazione e
   calcola il totale e il verdetto con il codice della rubrica. Dallo spazio di
   lavoro:

       python3 progetti/assistenza-clienti/banco/prova.py giudica \
         --conversazione progetti/assistenza-clienti/golden/gc-01-guasto-collettivo-pergine.json \
         --conversazione progetti/assistenza-clienti/golden/gc-06-marito-chiede-dati.json \
         --conversazione progetti/assistenza-clienti/golden/gc-10-copertura-fibra-in-arrivo.json \
         --conversazione taratura/conversazione-v0-sc-20.json \
         --uscita giudizi

   Per ogni conversazione stampa il totale e il verdetto; in
   `giudizi/<id>/verdetto.json` ci sono i voti per criterio. Se il giudice non
   sa decidere un criterio, lascia il voto a `null` e il verdetto è «non so»: è
   la via d'uscita che la rubrica gli dà.

   Poi, nel secondo terminale (`esercitazioni`), leggete il confronto con le
   etichette: `tools/verifica.sh M7-E03` stampa etichetta, verdetto e accordo
   per ogni conversazione. Esce con 1 («non ancora») finché non avete fatto i
   passi seguenti: per ora guardate soltanto la sezione 1.

       tools/verifica.sh M7-E03

3. **Il caso nuovo e il suo opposto.** Nel primo terminale aprite una sessione:

       claude --model sonnet --effort low

   Alla domanda di fiducia sulla cartella rispondete sì (il cursore parte da
   «No, exit»: scendete con la freccia su «Yes, I trust this
   folder» e date Invio). Poi incollate il prompt:

   <!-- prompt 1 -->

       <role>
       Sei un valutatore di assistenti virtuali e scrivi casi di prova per chi mantiene il banco di prova dell'assistente di CiaspoLink.
       </role>

       <context>
       Il banco di prova è in progetti/assistenza-clienti/banco/: il suo README.md spiega il formato di un caso e le asserzioni, e i cinque casi forniti sono in banco/casi/. Gli scenari sono in progetti/assistenza-clienti/scenari/: per ognuno, verita_nascosta dice che cosa rispondono i dati, esito_atteso e da_evitare che cosa deve fare un buon assistente. Un caso nuovo e il suo opposto misurano un comportamento nei due versi: quando deve accadere e quando non deve.
       </context>

       <instructions>
       1. Scegli uno scenario di scenari/ diverso da quelli dei cinque casi forniti (SC-01, SC-10, SC-14, SC-15, SC-17) e una situazione, tratta dal suo esito_atteso, in cui l'assistente deve fare una cosa precisa.
       2. Scrivi casi-nuovi/caso-06-<nome>.json: il messaggio del cliente in una sola chiamata, con dentro i dati per riconoscerlo se servono, e le asserzioni che dicono che il comportamento c'è stato.
       3. Scrivi casi-nuovi/caso-07-<nome>.json, il suo opposto: lo stesso scenario, una situazione in cui un buon assistente deve fare il contrario, con le asserzioni che dicono che il comportamento non deve accadere.
       4. Controlla che i due file siano JSON validi, con i campi id (CASO-06 e CASO-07), titolo, scenario, messaggio e asserzioni, e che il file dello scenario esista.
       </instructions>

       <format>
       I due file JSON nel formato dei casi del banco, con i nomi dei passi 2 e 3. Nella risposta, due righe: che cosa mette alla prova ciascun caso.
       </format>

       <constraints>
       Nelle asserzioni usa i nomi delle capacità del banco (deve_chiamare, non_deve_chiamare, con nomi come verifica_identita o leggi_fattura), non i nomi degli strumenti di una versione. Nei messaggi del cliente usa soltanto dati dello scenario. Scrivi in italiano.
       </constraints>

   <!-- /prompt 1 -->

   Quando Claude ha scritto i due file, leggeteli e chiedetevi se le asserzioni
   decidono davvero il comportamento. Chiudete la sessione con `/exit`.

4. **La suite e la tabella di regressione.** Dallo spazio di lavoro: i cinque casi
   forniti sulle due versioni, poi i due casi nuovi sulla v1 (dodici chiamate in
   tutto, ogni comando le lancia a gruppi di tre). Qui `v1-riferimento/` è la
   vostra v1; se avete copiato sopra la vostra, la vostra v1 è quella.

       python3 progetti/assistenza-clienti/banco/prova.py casi --versione progetti/assistenza-clienti/v0 --uscita risultati/v0
       python3 progetti/assistenza-clienti/banco/prova.py casi --versione v1-riferimento --uscita risultati/v1
       python3 progetti/assistenza-clienti/banco/prova.py casi --versione v1-riferimento --casi casi-nuovi --uscita risultati/v1-nuovi
       python3 progetti/assistenza-clienti/banco/confronta.py risultati/v0 risultati/v1 | tee regressione.txt

   Il confronto stampa, caso per caso, quante asserzioni soddisfa ogni versione,
   le chiamate e i token, e in fondo la conclusione su tutta la suite. Una
   versione che fa peggio su un caso è una regressione: guardatela in
   `risultati/<versione>/<caso>/trascrizione.md`. I due casi nuovi sono in
   `risultati/v1-nuovi/`.

5. Nel secondo terminale, dalla cartella `esercitazioni`, la verifica:

       tools/verifica.sh M7-E03

Perché così: i giudizi e i casi sono chiamate secche (`claude -p`), perché ognuna
deve partire da zero, sugli stessi dati, e uno script deve poterle confrontare;
il caso nuovo e il suo opposto li scrivete in una sessione interattiva, perché
qui il punto è decidere che cosa mettere alla prova e leggere che cosa Claude ha
scritto.

## Che cosa osservare

### Che cosa dice Anthropic

- Prima di fidarsi di un giudice, si prova su casi di cui si sa già l'esito:
  «Test the judge once, on cases code can also grade, to see whether the two
  graders agree.» (https://academy.claude.com/courses/introduction-to-evals/build-a-minimum-viable-eval);
  «LLM-based grading: Fast and flexible, scalable and suitable for complex
  judgment. Test to ensure reliability first, then scale.»
  (https://platform.claude.com/docs/en/test-and-evaluate/develop-tests).
- La taratura. «LLM-as-judge graders should be closely calibrated with human
  experts to gain confidence that there is little divergence between the human
  grading and model grading.» E la via d'uscita, che nel banco è il voto `null`:
  «To avoid hallucinations, give the LLM a way out, like providing an
  instruction to return “Unknown” when it doesn’t have enough information.»
  (https://www.anthropic.com/research/demystifying-evals-for-ai-agents)
- Il caso e il suo opposto. «Test both the cases where a behavior should occur
  and where it shouldn't. One-sided evals create one-sided optimization.»
  (stessa pagina); «For every positive case, write its negative counterpart: a
  "should serve" for every "should refuse," a "should just do it" for every
  "should ask."» (https://claude.com/resources/articles/the-anatomy-of-effective-commerce-agents)
- La regressione. «Regression evals ask, “Does the agent still handle all the
  tasks it used to?” and should have a nearly 100% pass rate.»
  (https://www.anthropic.com/research/demystifying-evals-for-ai-agents)

### Che cosa misura la verifica

`tools/verifica.sh M7-E03` legge i file che avete prodotto:

- dai verdetti in `giudizi/`, l'etichetta, il verdetto del giudice e l'accordo per
  ognuna delle quattro conversazioni, e i voti lasciati a `null`: l'accordo è un
  dato, non decide l'uscita. Le quattro conversazioni sono etichettate
  «superato» (le tre di riferimento, che la rubrica dice pensate per prendere 2
  su ogni criterio) o «non superato» (quella del v0, che elenca gli strumenti e
  riassume le regole, errori che lo scenario mette fra quelli da evitare: C6,
  privacy e sicurezza, che è bloccante);
- i casi nuovi in `casi-nuovi/`: almeno due file di caso nella forma del banco,
  sullo stesso scenario, con le loro asserzioni, eseguiti in
  `risultati/v1-nuovi/`; stampa come dati le asserzioni e il loro esito;
- la regressione: per i cinque casi forniti l'esito su v0 e su v1 da
  `risultati/`, la tabella ricostruita dagli esiti e non dal file, e il totale;
  `regressione.txt` deve esserci, con la riga «totale:» di `confronta.py`.

Esce con 0 quando questi tre passi sono fatti, gli esiti non decidono. Una
versione che regredisce o un giudice che non è d'accordo sono dati per la
discussione, non un errore del lavoro.

### Nella prova del corso

Nella prova del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con effort
low, `_docente/live.sh` sull'account del docente, che esegue i passi qui sopra
con `claude -p` al posto della sessione interattiva per il caso nuovo), la
verifica ha stampato per la taratura:

    GC-01: etichetta «superato», giudice «superato», totale 18 su 18: d'accordo
    GC-06: etichetta «superato», giudice «superato», totale 17 su 18: d'accordo
    GC-10: etichetta «superato», giudice «superato», totale 16 su 18: d'accordo
    prova-SC-20: etichetta «non superato», giudice «non superato», totale 8 su 18: d'accordo
    (dato) accordo con le etichette: 4 su 4; voti lasciati a null dal giudice: 0

Il prompt del passo 3 ha portato Claude a scrivere la coppia sullo scenario SC-08,
la fibra in arrivo: nel primo caso il cliente lascia nome e numero e chiede di
essere richiamato, nel suo opposto vuole soltanto sapere. Sulla versione di
riferimento: «CASO-06 su v1: asserzioni 7 su 9 (dato)», «CASO-07 su v1:
asserzioni 8 su 9 (dato)». In tutti e due è caduta l'asserzione
`risposta_non_contiene radio`: la risposta nomina la radio per dire che a
quell'indirizzo non c'è, e l'asserzione cerca soltanto la parola. Nel CASO-06
l'assistente non ha chiamato `apri_ticket`: senza un cliente riconosciuto ha detto
di non poter aprire la richiesta. Sono dati da discutere: che cosa ha fatto la
v1 e quanto è facile scrivere un'asserzione che misura qualcosa d'altro.

La tabella di `confronta.py`:

    caso       risultati/v0  ->  risultati/v1
    CASO-01    8/10 · 4 chiamate · 7701 token  ->  10/10 · 4 chiamate · 9689 token
    CASO-02    4/6 · 1 chiamate · 7697 token  ->  6/6 · 2 chiamate · 9686 token
    CASO-03    3/5 · 2 chiamate · 7831 token  ->  5/5 · 4 chiamate · 9822 token
    CASO-04    5/5 · 0 chiamate · 7692 token  ->  5/5 · 0 chiamate · 9681 token
    CASO-05    3/4 · 2 chiamate · 7736 token  ->  4/4 · 2 chiamate · 9726 token
    totale: 23/30  ->  30/30
    la seconda versione rispetto alla prima: confermata in questa misura

Sono i dati di quella prova, una sola esecuzione per caso: nessun caso è
peggiorato con la v1 («casi peggiorati con la v1: nessuno»), ma una misura così
piccola dice che cosa è successo lì, non che cosa succederà con le vostre versioni.

## Verifica (tools/verifica.sh M7-E03)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M7-E03

Stampa la taratura, i casi nuovi con le loro asserzioni, e la tabella di
regressione. Esce con 0 quando il lavoro c'è; con 1 quando manca qualcosa, e
dice che cosa («Non ancora: …»), per esempio se non avete ancora fatto il passo
4; con 2 quando non può partire, per esempio se un file non si legge. Quando
tutto è in ordine, le ultime due righe sono «Fatto: il giudice, i casi nuovi e la
tabella di regressione ci sono; gli esiti sono qui sopra.» e «VERIFICA OK   M7-E03:
fatto.»

## Se qualcosa va storto

- `prova.py giudica` dice che manca qualcosa: guardate `risposta.json` nella
  cartella del giudizio; poi cancellate la cartella della prova non riuscita (per
  esempio `rm -r giudizi/<id>`) e rilanciate con lo stesso nome: la verifica legge i
  nomi fissi, e una cartella già usata non si sovrascrive.
- Il giudice non è d'accordo con un'etichetta: è un dato da discutere. Leggete
  `giudizi/<id>/verdetto.json`, le motivazioni per criterio, e chiedetevi se ha
  ragione il giudice o l'etichetta.
- Un caso nuovo non parte, con «manca il campo»: il file non ha uno dei campi
  richiesti; aprite il file, correggetelo (o rifate il passo 3) e rilanciate il
  comando; se una prova non è riuscita, cancellate prima la sua cartella (per
  esempio `rm -r risultati/v1-nuovi`) e rilanciate con lo stesso nome: la verifica
  legge i nomi fissi.
- La tabella di `confronta.py` si ferma con «manca alla … versione»: i due casi
  nuovi non vanno in `risultati/v1` ma in `risultati/v1-nuovi/`; confrontate solo
  le due cartelle dei casi forniti.
- `claude: command not found`, oppure un errore di accesso, o `uv` che manca:
  rifate i passi di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M7-E03`.

## Impronta d'uso sul piano Pro

Il giudice gira su Sonnet in `claude -p` (una chiamata di 1 o 2 turni per
conversazione, quattro conversazioni); il caso nuovo e il suo opposto li scrive
la sessione interattiva, Sonnet con effort low; la suite sono dodici chiamate
dell'assistente su Sonnet con effort low. Sul Pro il modello predefinito di
Claude Code è un altro: «Pro, Max, Ultra, Team, Enterprise, and Anthropic API:
defaults to Opus 5.5» (https://code.claude.com/docs/en/model-config). Il corso
fissa Sonnet perché le vostre prove e la registrazione del corso girino sullo
stesso modello.

Nella prova del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con effort
low, `_docente/live.sh` sull'account del docente, un piano Max), sommando il
`result` di ogni chiamata: il giudice, quattro chiamate, 8 turni, 21,7 secondi,
46.009 token; la scrittura dei due casi, una chiamata di 8 turni in `claude -p`,
17,9 secondi, 45.400 token; i cinque casi forniti su v0, 14 turni, 35,5 secondi,
110.328 token, e su v1, 17 turni, 34,2 secondi, 168.852 token; i due casi nuovi,
5 turni, 11,3 secondi, 52.061 token. Il totale, 17 chiamate: 52 turni, 120,6
secondi, 422.650 token (tempi di modello, non il tempo d'orologio). I token
sono quelli di `modelUsage`: «Use modelUsage, or model_usage in Python, for
whole-tree token accounting; the usage field undercounts as soon as nesting
occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking). Sono entrata,
cache e uscita, compreso il contesto letto dalla cache: dicono quanto lavoro è
stato, non un prezzo, e non quanta parte del vostro piano occupa. La sessione
interattiva del passo 3, in aula, costa di più della chiamata singola che l'ha
sostituita nella prova: non è stata misurata.

## Per approfondire

- «Demystifying evals for AI agents» (giudici, casi negativi, regressione):
  https://www.anthropic.com/research/demystifying-evals-for-ai-agents
- «Build a minimum viable eval», nel corso «Introduction to evals» dell'Academy:
  https://academy.claude.com/courses/introduction-to-evals/build-a-minimum-viable-eval
- «Develop tests» (come si scelgono i tipi di valutazione):
  https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- Il README del banco di prova, con il formato dei casi e delle asserzioni:
  `progetti/assistenza-clienti/banco/README.md`
- La rubrica: `progetti/assistenza-clienti/valutazione/rubrica.md`
