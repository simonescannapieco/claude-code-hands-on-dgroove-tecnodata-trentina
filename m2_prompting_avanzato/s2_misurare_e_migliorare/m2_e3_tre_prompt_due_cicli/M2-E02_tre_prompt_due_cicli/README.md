# M2-E02 — Tre prompt, due cicli

Esercitazione del Modulo 2, nella pratica «Tre prompt, due cicli»: il
laboratorio del modulo. Usa gli stessi attrezzi di M2-E01.

## Obiettivo

Migliorare tre prompt di lavoro, uno per famiglia (sviluppo, supporto,
sistemi), con due cicli ciascuno, e a ogni ciclo mettere alla prova una
pratica della guida di Anthropic, una sola: misurare, cambiare il prompt
secondo quella pratica, rimisurare, e leggere se la pratica è confermata,
confrontando le due versioni sui criteri che la riguardano. La misura la
danno i controlli scritti in codice e un giudice, un subagent che
verifica le affermazioni di una rubrica.

## Tempo

80 minuti: cinque per partire, poi circa 25 per prompt.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- `claude --version` 2.1.293 o successiva: il giudice gira su Haiku.
- Python 3, che lo stesso controllo verifica.
- Consigliato: M2-E01, dove gli stessi attrezzi si usano su un prompt solo.

## Punto di partenza (tools/prepara_esercizio.sh M2-E02)

Lo spazio di lavoro `~/corso-claude-code/M2-E02/` con una cartella per
famiglia, ciascuna con `prompt/v0.md` (un prompt di una riga, come se ne
scrivono tanti), `dati/` (i dati del compito), `rubrica.md` (le
affermazioni che il giudice verifica: che cosa fa una buona risposta) e
`controlli.tsv` (i controlli scritti in codice):

- `sviluppo/`: «spiega questa funzione», sul frammento di
  `legacy/listino.inc.php` del gestionale che calcola il canone di una
  linea, con la convenzione del team sul rateo;
- `supporto/`: «rispondi al cliente», sull'e-mail di un cliente privato la
  cui linea cade più volte all'ora, con un estratto della guida al tono di
  voce dell'assistenza;
- `sistemi/`: «cosa è successo?», su un estratto del syslog di una OLT.

Poi gli attrezzi, gli stessi di M2-E01: `misura.sh`, `strumenti/kit.py`,
`schema-giudizio.json`, `.claude/agents/giudice.md`; e `registro.md`, il
registro delle versioni con una riga per famiglia e versione e la colonna
«pratica». I dati vengono dai progetti di esempio di CiaspoLink: sono
tutti inventati.

Ogni criterio porta la pratica che lo legge, tra parentesi quadre in
`rubrica.md` e nell'ultima colonna di `controlli.tsv`. I controlli di
formato e di lunghezza portano `chiarezza` (in supporto c'è anche la
firma, «L'assistenza clienti di CiaspoLink»); le affermazioni che
dipendono dal contesto del compito portano `contesto` (`mese_fisso`,
`stesso_mese` e `correzione` in sviluppo; `orari` e `tono` in supporto;
`un_guasto` e `primo_controllo` in sistemi). Gli altri criteri non portano
una pratica: contano nei totali, ma nell'esito di nessuna. I criteri sono
fissati prima di ogni prompt e restano gli stessi per tutte le versioni.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`, poi aprite Claude Code su Sonnet:

       tools/prepara_esercizio.sh M2-E02
       cd ~/corso-claude-code/M2-E02
       claude --model sonnet

2. Scegliete il percorso:
   - **Percorso A, i vostri prompt:** in una o più famiglie mettete un
     prompt che usate davvero, con i dati sostituiti da valori inventati
     (niente nomi di clienti, password, indirizzi o configurazioni reali):
     il prompt in `prompt/v0.md`, i dati in `dati/`, in `rubrica.md`
     quattro o cinque affermazioni che una buona risposta rispetta, e in
     `controlli.tsv` i controlli scritti in codice adatti al vostro
     compito (almeno uno, per esempio `parole_max`: il kit rifiuta un file
     senza controlli, e quelli della famiglia cercano dati che il vostro
     prompt non ha). Segnate su ogni criterio la pratica che lo legge,
     prima di misurare v0;
   - **Percorso B, i prompt di CiaspoLink:** le tre famiglie così come
     sono. La prova del docente è su queste.

3. Il primo ciclo, sulla famiglia più vicina al vostro lavoro (qui
   `sistemi`; al suo posto la vostra):

       ! ./misura.sh sistemi v0

   Su v0 il giudice giudica due volte la stessa risposta: leggete la
   risposta, i due elenchi di ✓ e ✗ con le loro pratiche e la riga
   «Giudice su v0». Poi l'elenco delle pratiche, ognuna con la frase di
   Anthropic che mette alla prova:

       ! ./misura.sh --pratiche

   Scegliete la pratica del ciclo e scrivetela nel registro, alla riga di
   sistemi e v1, colonna «pratica», prima di riscrivere. Sul percorso B la
   prova del docente usa `chiarezza`: aggiunge alla riga di v0 l'istruzione
   e il formato. Copiate il prompt
   (`! cp sistemi/prompt/v0.md sistemi/prompt/v1.md`) e cambiate **una
   pratica sola**. Poi:

       ! ./misura.sh sistemi v1
       ! ./misura.sh --confronta sistemi v0 v1
       ! git diff --no-index sistemi/prompt/v0.md sistemi/prompt/v1.md

   e completate la riga in `registro.md`. Potete chiedere a Claude di
   leggere il confronto, o di farvi domande sul compito prima di
   riscrivere.

4. Il secondo ciclo, dalla versione migliore: copiatela in
   `sistemi/prompt/v2.md` (`! cp sistemi/prompt/v1.md sistemi/prompt/v2.md`,
   se la migliore è v1), scrivete nel registro la pratica di v2 e
   cambiate una pratica sola. Sul percorso B la prova del docente usa
   `contesto`: che cosa sono i dati e a che cosa serve la risposta, con i
   dati nuovi tra tag. Poi misurate v2 e confrontatela con la versione da
   cui l'avete copiata:

       ! ./misura.sh sistemi v2
       ! ./misura.sh --confronta sistemi v1 v2

   Qui la pratica può essere anche l'effort, a testo invariato: copiate la
   versione senza toccarla e misuratela con
   `! ./misura.sh sistemi v2 --effort medium` (pratica `effort`). Il
   modello si cambia allo stesso modo, con `--modello opus` (pratica
   `modello`): il confronto stampa la misura, e l'esito resta non decisa.
   Checkpoint: dopo circa 25 minuti, la prima famiglia misurata fino a v2
   e registrata.

5. Le altre due famiglie, allo stesso modo. Se il tempo stringe, sulla
   terza basta un ciclo.

6. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M2-E02

## Che cosa osservare

### Che cosa dice Anthropic

- Ogni ciclo mette alla prova una frase della guida «Best practice per il
  prompting», sui criteri che la frase nomina:
  - `chiarezza`, sezione «Sii chiaro e diretto»: «Sii specifico sul
    formato di output desiderato e sui vincoli.» e «Più precisamente
    spieghi cosa vuoi, migliore sarà il risultato.»;
  - `contesto`, sezione «Aggiungi contesto per migliorare le prestazioni»:
    «Fornire il contesto o la motivazione alla base delle tue istruzioni,
    ad esempio spiegando a Claude perché un determinato comportamento è
    importante, può aiutare Claude a comprendere meglio i tuoi obiettivi
    e a fornire risposte più mirate.»;
  - `tag`, sezione «Struttura i prompt con tag XML»: «Racchiudere ogni
    tipo di contenuto nel proprio tag (ad esempio, `<instructions>`,
    `<context>`, `<input>`) riduce le interpretazioni errate.» Nelle
    rubriche di partenza nessun criterio la legge;
  - `ruolo`, sezione «Assegna un ruolo a Claude»: «Impostare un ruolo nel
    "system prompt" (prompt di sistema) focalizza il comportamento e il
    tono di Claude per il tuo caso d'uso.» Qui non si mette alla prova:
    `misura.sh` manda il vostro prompt come messaggio, con il system
    prompt fisso «Rispondi in italiano.».

  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- `effort` e `modello`, a testo invariato, mettono alla prova l'articolo
  di Anthropic sulle valutazioni: «Modelli più capaci e livelli di effort
  più alti di solito dovrebbero andare meglio in una valutazione. Se non
  succede, spesso a frenarli sono compiti ambigui o un valutatore mal
  calibrato.» (traduzione nostra). Lo stesso articolo descrive, fra i
  controlli delle prime esecuzioni, la prova che `misura.sh` fa su v0:
  «Claude esegue il valutatore due volte sullo stesso output e riferisce
  se il verdetto è cambiato» (traduzione nostra); e del modello giudice
  dice: «non dovrebbe essere il modello che state valutando» (traduzione
  nostra).
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- La pagina sui criteri di successo e sulle valutazioni, della valutazione
  con un modello: «Testa prima per garantire l'affidabilità, poi scala.»
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- Il giudizio arriva con `--json-schema`. Il riferimento della CLI:
  «Ottieni output JSON convalidato corrispondente a uno JSON Schema dopo
  che l'agente completa il suo flusso di lavoro (solo modalità print).» La
  pagina sull'esecuzione programmatica: «Se un'esecuzione termina senza un
  output strutturato valido, ad esempio perché Claude ha rifiutato la
  richiesta, la risposta non contiene il campo `structured_output`.»
  https://code.claude.com/docs/it/cli-reference ·
  https://code.claude.com/docs/it/headless

### Che cosa misura il controllo

- I criteri vengono prima del prompt, come nella pagina sulle valutazioni:
  un'applicazione «inizia con la definizione chiara dei tuoi criteri di
  successo e poi con la progettazione di valutazioni per misurare le
  prestazioni rispetto a essi». I controlli di `controlli.tsv` li decide
  il codice, e sulla stessa risposta danno sempre lo stesso esito; le
  affermazioni di `rubrica.md` le decide il giudice, un modello. Se ne
  trovate una ambigua, riscrivetela e misurate di nuovo le versioni di
  quella famiglia.
- La prova del giudice: su v0 lo stesso giudice giudica due volte la
  stessa risposta. Un'affermazione su cui i due giudizi non concordano è
  «instabile»: in v0 conta come non rispettata, e negli esiti delle
  pratiche non conta, perché il suo cambiamento non è una prova.
- `./misura.sh --confronta <famiglia> vA vB` legge nel registro la
  pratica di vB e ne dice l'esito, in questa misura, confrontando le due
  versioni. Con `chiarezza`, `contesto` o `tag` conta i criteri segnati
  con quella pratica che hanno un esito in vA e in vB, senza le
  affermazioni instabili, e quanti ne rispetta ciascuna: confermata se vB
  ne rispetta più di vA; non decisa se lo stesso numero, perché questa
  coppia non lo dice; non confermata in questa misura se meno; non decisa
  anche se nessun criterio la legge o la leggono solo affermazioni
  instabili. Il confronto stampa i due conteggi, poi i criteri che vB non
  rispetta. Con `effort`: confermata se la misura (controlli superati più
  affermazioni rispettate, senza le instabili) è più alta con l'effort più
  alto; non decisa se è la stessa, o se con l'effort più basso è già al
  massimo; non confermata in questa misura se è più bassa, e allora il
  confronto ricorda i due sospetti dell'articolo, il compito o il giudice.
  Con `modello` stampa la misura e resta non decisa: il kit non sa quale
  modello sia più capace. Con `ruolo` resta non decisa.
- Una cosa per volta: `misura.sh` registra il modello, l'effort e
  l'impronta del prompt e dei dati in `risposte/<versione>.opzioni`. Se
  da vA a vB è cambiato anche altro, oltre alla pratica, l'esito è non
  decisa, con il motivo. Una pratica non confermata è un risultato, come
  una confermata.
- Il confronto avvisa quando la risposta e il giudizio vengono dallo
  stesso modello (il campo `modelUsage` dei due JSON): per esempio se
  misurate le risposte di Haiku, `--modello haiku`, con il giudice su
  Haiku.
- La verifica stampa le misure e l'esito di ogni pratica, e mette alla
  prova la garanzia di `--json-schema`: ogni giudizio che porta
  `structured_output` lo porta conforme a `schema-giudizio.json`; se uno
  no, scrive «la documentazione garantisce …: in questa esecuzione no» ed
  esce con 1.
- Nella prova del docente del 20 ottobre 2026, con Claude Code 2.1.305,
  una esecuzione per versione, per famiglia (controlli superati, poi
  affermazioni rispettate):
  - sviluppo: v0 1 su 2 e 3 su 5, v1 1 su 2 e 2 su 5, v2 1 su 2 e 4 su 5;
  - supporto: v0 2 su 4 e 4 su 5, v1 4 su 4 e 4 su 5, v2 4 su 4 e 5 su 5;
  - sistemi: v0 2 su 3 e 3 su 4, v1 3 su 3 e 3 su 4, v2 3 su 3 e 4 su 4.

  I due giudizi di v0 d'accordo su 5 affermazioni su 5 in sviluppo e in
  supporto, su 3 su 4 in sistemi (instabile: `primo_controllo`). Gli
  esiti, con i criteri segnati rispettati nelle due versioni:
  - `chiarezza`, da v0 a v1: confermata in supporto (1 su 3, poi 3 su 3)
    e in sistemi (0 su 1, poi 1 su 1); non decisa in sviluppo (1 su 2 e 1
    su 2: in v1 resta non rispettato «al massimo 300 parole»);
  - `contesto`, da v1 a v2: confermata in sviluppo (1 su 3, poi 3 su 3) e
    in supporto (1 su 2, poi 2 su 2); non decisa in sistemi (1 su 1 e 1
    su 1, senza l'affermazione instabile).

  Giudizi conformi allo schema 12 su 12.

## Verifica (tools/verifica.sh M2-E02)

Per ogni famiglia controlla il lavoro, non l'esito: v0 misurata e
giudicata due volte (`giudizi/v0.json` e `giudizi/v0-bis.json`), v1
misurata e diversa da v0, ogni versione misurata completa (risposta,
controlli e giudizio con un esito per ogni affermazione), e in
`registro.md` la riga di ogni versione misurata, compilata e con la sua
pratica (`partenza` per v0, una dell'elenco di `./misura.sh --pratiche`
per le altre); poi che almeno due famiglie abbiano due cicli (v2). Stampa
le misure e l'esito di ogni pratica, ogni versione confrontata con la
precedente (a testo invariato, con la più recente che ha lo stesso
prompt): se avete copiato v2 da v0, l'esito di quel ciclo ve lo dà
`./misura.sh --confronta <famiglia> v0 v2`. Una pratica non confermata non
vi ferma, è un risultato. Esce con 1 se manca qualcosa, o se un giudizio
strutturato non rispetta lo schema.

## Se qualcosa va storto

- `misura.sh` dice che il prompt usa un segnaposto che in `dati/` non c'è:
  controllate il nome tra le doppie graffe, per esempio `{{log}}`.
- `misura.sh` si ferma perché il prompt composto è troppo lungo: i file di
  `dati/` sono troppo lunghi per una chiamata (oltre 100 000 byte, e il
  messaggio dice quanti ne ha ciascuno); accorciateli.
- `misura.sh` si ferma perché la consegna al giudice è troppo lunga: la
  rubrica, i file di `dati/` e la risposta insieme superano lo stesso
  limite; accorciate i file di `dati/` o la rubrica, o chiedete nel prompt
  una risposta più breve.
- `misura.sh` si ferma perché i controlli non sono riusciti, o rifiuta
  una pratica: una riga di `controlli.tsv` o di `rubrica.md` non si legge,
  e il messaggio dice quale. Tra parentesi quadre si scrive `chiarezza`,
  `contesto`, `ruolo` o `tag`; correggete e rilanciate la misura.
- `--confronta` dice «non decisa» perché la pratica è da scrivere:
  scrivetela nella colonna «pratica» di `registro.md` e rilanciate il
  confronto, senza misurare di nuovo. Se dice che è cambiato anche
  altro, rifate il ciclo cambiando una cosa sola.
- La verifica chiede di misurare di nuovo una versione: un file della sua
  misura è incompleto, per v0 anche `giudizi/v0-bis.json`; lanciate il
  comando che la verifica stampa. Una nuova misura cancella prima quella
  vecchia della stessa versione: se si ferma, la versione resta da
  misurare.
- Il giudizio arriva senza esito strutturato: rilanciate la misura della
  stessa versione.
- La verifica scrive «la documentazione garantisce …: in questa esecuzione
  no»: un giudizio strutturato non rispetta lo schema. Misurate di nuovo
  quella versione e avvisate il docente.
- Una famiglia peggiora: guardate il confronto e tornate alla versione
  migliore per il ciclo successivo.
- Una risposta riporta il vostro nome, che nessun prompt né dato
  contiene: prima di mostrarla in aula, toglietelo. Nei file di
  `soluzione/` un nome così è sostituito da «(identità dell'account,
  omessa)».
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E02`.

## Impronta d'uso sul piano Pro

Chiamate brevi `claude -p`, senza strumenti: sette per famiglia, tre su v0
(la risposta e due giudizi) e due su v1 e su v2, ventuno in tutto. La
risposta gira su Sonnet con effort low
(nella prova del docente da 627 a 1571 token in entrata e da 263 a 2155
in uscita per risposta),
i giudizi su Haiku con effort low
(da 2478 a 3617 token in entrata e da 408 a 1831 in uscita per
giudizio). Più la sessione
interattiva su Sonnet, di dieci o quindici turni. Il giudice gira in una
sua chiamata `claude -p`, non come subagent dentro la sessione. Se
cambiate il modello, Opus pesa sul limite d'uso più degli altri: usatelo
per una misura sola. Niente Fable. Alla fine, `/exit`.

## Per approfondire

- La pagina sui criteri di successo e sulle valutazioni:
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- L'articolo «Automating eval design and hillclimbing with Claude», sul
  blog degli sviluppatori di Anthropic:
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- La guida «Best practice per il prompting» della documentazione:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Il talk «Prompting 101 | Code w/ Claude», sul canale YouTube di
  Anthropic: https://www.youtube.com/watch?v=ysPbXH0LpIE
