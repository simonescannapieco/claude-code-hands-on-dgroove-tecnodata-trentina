# M8-E02 — Metà dei token, a parità di qualità

Laboratorio del Modulo 8: si prende un prompt volutamente troppo lungo dell'assistenza
di CiaspoLink, il fornitore di connettività inventato del corso, si misura che cosa
costa e come risponde, lo si taglia con Claude Code e si misura di nuovo, sugli
stessi tre messaggi di clienti, con gli stessi controlli e lo stesso giudice.

## Obiettivo

Imparare il metodo: si misura un prompt, si toglie ciò che non cambia la risposta,
si rimisura. Alla fine avete nello spazio di lavoro:

- `prompt/v1.md`, la vostra versione, più corta di `prompt/v0.md`;
- le tabelle di `./misura.sh`, una per versione: token in entrata, token in uscita,
  costo, controlli superati, affermazioni rispettate dal giudice;
- il confronto con v0: quanto si è ridotto il peso del prompt e se controlli e
  giudice sono rimasti dove erano.

L'obiettivo del laboratorio, preso dal programma del corso: almeno il 50 % di
token in entrata in meno, a parità di qualità. Il 50 % è una soglia del laboratorio,
non una frase di Anthropic: `./misura.sh --confronta` la stampa accanto alla
riduzione, come dato, e non decide l'esito di niente.

## Tempo

22 minuti in aula: 2 con il docente per partire, 6 sui passi con le slide (la misura
di v0 parte subito), 12 a timer per tagliare, leggere che cosa ha fatto Claude,
rimisurare, confrontare e, se resta tempo o se la verifica non passa, fare una v2, 2 per
la verifica e il punto della situazione.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto verde
  (`PRIMA_DEL_CORSO.md`). I comandi che cominciano con `tools/` si lanciano dalla
  cartella `esercitazioni`, cioè dal repository del corso.
- Python 3 e git, che lo stesso `tools/verifica_ambiente.sh` controlla: li usano
  `misura.sh` e la verifica.
- Consigliato: M2-E01 o M2-E02, dove si usano gli stessi attrezzi di misura. Non è
  necessario averli fatti: questo laboratorio ha i suoi attrezzi, in `strumenti/`.

## Punto di partenza (tools/prepara_esercizio.sh M8-E02)

Lo spazio di lavoro `~/corso-claude-code/M8-E02/`, un repository git con un primo
commit, con:

- `prompt/v0.md`: il prompt di partenza, il testo sotto prova. È volutamente lungo
  e ripetitivo: una presentazione dell'azienda, le istruzioni dette tre volte in
  modi diversi, esempi scritti in prosa, il formato ripetuto, e i segnaposto
  `{{tono}}`, `{{procedure}}`, `{{messaggio}}` e `{{stato}}`;
- `documenti/tono.md` e `documenti/procedure.md`: i due documenti che v0 include al
  posto dei segnaposto `{{tono}}` e `{{procedure}}`, la guida al tono di voce intera
  e le procedure sui guasti collettivi (KB-11) e sui collegamenti radio (KB-04)
  dell'assistenza, copiate da `progetti/assistenza-clienti/`;
- `casi/caso-1/`, `caso-2/` e `caso-3/`: tre messaggi di clienti alle prese con un
  guasto (`messaggio.md`, dai `scenari/` del progetto), lo stato della linea e i
  fatti che la risposta deve portare (`stato.md`), i controlli scritti in codice
  (`controlli.tsv`) e le affermazioni per il giudice (`rubrica.md`);
- `misura.sh`, `strumenti/kit.py`, `schema-giudizio.json`,
  `.claude/agents/giudice.md`: gli attrezzi della misura; `listino.json`, i prezzi,
  in un file solo (quelli che valgono il 10 novembre 2026, con le pagine da cui
  vengono);
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro ed entrate:

       tools/prepara_esercizio.sh M8-E02
       cd ~/corso-claude-code/M8-E02
       claude --model sonnet

   Alla prima apertura Claude Code vi chiede se vi fidate della cartella: «In an
   interactive session, Claude Code shows the workspace trust dialog when you start
   it in a folder you haven’t trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì. Sonnet è il modello della sessione di lavoro: la stessa famiglia
   delle risposte che misurate.

2. La prima misura. Nella sessione, con il punto esclamativo davanti (il comando va
   alla shell, senza passare da Claude: «Run shell commands directly without going
   through Claude by prefixing your input with !», scrive
   https://code.claude.com/docs/en/interactive-mode):

       ! ./misura.sh v0

   Per ogni caso `misura.sh` compone il prompt (i dati del caso e i documenti al
   posto dei segnaposto), chiede la risposta a Sonnet con `claude -p`, effort low,
   senza strumenti, poi esegue i controlli e chiede il giudizio al subagent
   `giudice`, su Haiku. Ogni comando viene stampato prima di girare; alla fine la
   tabella: per caso e in totale, i token in entrata, i token in uscita, il costo
   ricalcolato da `listino.json`, i controlli superati, le affermazioni rispettate
   dal giudice. Leggete almeno una risposta (`risposte/v0/caso-1.md`): è quella che
   poi cercate di non peggiorare. Occhio ai token in entrata: il peso del prompt è
   la colonna da abbassare.

3. Il taglio. Claude Code scrive `prompt/v1.md` a partire da v0: togliere ciò che
   non cambia la risposta, riassumere i documenti nelle regole che servono, tenere
   ciò che i controlli e le rubriche chiedono. Incollate nella sessione:

   <!-- prompt taglio -->

       <role>
       Sei un collega esperto di prompt e lavori per il team dell'assistenza di
       CiaspoLink: riduci i token di un prompt senza perdere qualità nelle
       risposte.
       </role>

       <context>
       prompt/v0.md è il prompt con cui l'assistente virtuale risponde ai
       clienti: è lungo e ripetitivo. I segnaposto {{tono}} e {{procedure}}
       includono documenti/tono.md e documenti/procedure.md; {{messaggio}} e
       {{stato}} portano i dati di ciascuno dei tre casi di casi/. Ogni versione
       si misura con misura.sh, con i controlli scritti in codice di
       casi/*/controlli.tsv e un giudice che legge le affermazioni di
       casi/*/rubrica.md. Il risultato lo usa chi lancia misura.sh per
       confrontare i token e la qualità delle risposte.
       </context>

       <instructions>
       1. Leggi prompt/v0.md, documenti/tono.md e documenti/procedure.md, e in
          casi/ i messaggi, gli stati, i controlli e le rubriche.
       2. Scrivi prompt/v1.md partendo da prompt/v0.md: togli ciò che non cambia
          la risposta, cioè le ripetizioni e la presentazione dell'azienda.
       3. Riassumi la guida al tono e le procedure nelle sole regole che la
          risposta richiede: togli i segnaposto {{tono}} e {{procedure}} se i
          documenti non ti servono più; {{messaggio}} e {{stato}} restano.
       4. Tieni ciò che i controlli e le rubriche chiedono e il formato della
          risposta, nel canale che lo stato indica.
       5. Per ultimo rileggi prompt/v1.md e controlla che ogni regola chiesta
          dalle rubriche e dai controlli ci sia ancora e che {{messaggio}} e
          {{stato}} ci siano; correggi ciò che manca.
       </instructions>

       <format>
       Scrivi soltanto prompt/v1.md. Nella risposta, al massimo otto righe: che
       cosa hai tolto, che cosa hai riassunto, che cosa hai tenuto e perché.
       </format>

       <constraints>
       Cambia soltanto prompt/v1.md. Tieni tutti i fatti e le regole che i
       controlli e le rubriche chiedono, in italiano, e scegli le parole che
       servono al risultato.
       </constraints>

   <!-- /prompt taglio -->

   Se Claude Code vi chiede il permesso di scrivere `prompt/v1.md`, approvate quando
   la proposta vi convince; se lo chiede per leggere i file o per un comando, leggete
   che cosa chiede e decidete. Poi leggete che cosa ha tagliato.

4. La seconda misura, e il confronto:

       ! ./misura.sh v1
       ! ./misura.sh --confronta v0 v1

   Il confronto mette v0 e v1 fianco a fianco, per caso e in totale, e stampa la
   riduzione dei token in entrata e la riga «obiettivo del laboratorio: almeno il 50 %
   in meno»: un dato. Se i controlli o il giudice sono scesi, la verifica non passa e
   serve una v2: le righe con ✗ sopra la tabella dicono quali criteri ha perso, e
   `controlli/v1/` e `giudizi/v1/` lo dicono caso per caso. Copiate v1, incollate
   nella sessione la richiesta qui sotto e misurate v2 (rimisurare una copia identica
   non prova niente):

       ! cp prompt/v1.md prompt/v2.md

   <!-- prompt correzione -->

       Correggi prompt/v2.md: rimetti soltanto ciò che serve a superare i controlli e le affermazioni che v1 ha perso, che trovi in controlli/v1/ e giudizi/v1/, e lascia tutto il resto com'è.

   <!-- /prompt correzione -->

       ! ./misura.sh v2
       ! ./misura.sh --confronta v0 v2

5. Se volete, potete anche misurare un'altra versione con un altro modello o un
   altro effort (`--modello`, `--effort`): la verifica, però, confronta a parità di
   modello e di effort.

6. Uscite con `/exit`, tornate nella cartella `esercitazioni` e verificate:

       /exit
       cd -
       tools/verifica.sh M8-E02

Perché una sessione di Claude Code e `claude -p`: il taglio è un lavoro di Claude su
più file, e in una sessione lo vedete e lo correggete; la misura vuole invece due
chiamate che partano ognuna da zero, con il solo prompt diverso e nessuno strumento,
e `claude -p` dà per ogni chiamata i token e il costo, che uno script confronta
versione per versione.

## Che cosa osservare

### Che cosa dice Anthropic

Il laboratorio parte da due frasi della pagina sull'ottimizzazione di costi e
qualità (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence):

- «Most agent requests carry tokens that never influence the answer.»
- «Trimming them rarely costs output quality, although not every lever here saved
  money when measured.»

Le mette in pratica su un prompt costruito per il corso: è una dimostrazione. Una
coppia di misure su un prompt costruito non decide una frase sugli agenti in generale,
né una che dice «rarely».

Anthropic spiega anche quale prompt cercare: «you should be striving for the minimal
set of information that fully outlines your expected behavior.» e «Note that minimal
does not necessarily mean short»
(https://www.anthropic.com/research/effective-context-engineering-for-ai-agents).
Tagliare non è accorciare a caso: resta ciò che la risposta richiede.

Le altre frasi che il laboratorio usa:

- i token in entrata, nella tabella e nel confronto, sono quelli dell'API: «Total
  input tokens in a request is the summation of input_tokens,
  cache_creation_input_tokens, and cache_read_input_tokens.»
  (https://platform.claude.com/docs/en/api/messages/create);
- il costo in `listino.json` è ricalcolato con il metodo della pagina: «Price each of
  the five token counts in a response’s usage at its own rate»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence);
  accanto, come dato, c'è la cifra `total_cost_usd` del JSON, che secondo
  https://code.claude.com/docs/en/headless è una stima: «Both figures are client-side
  estimates and can differ from your actual bill.»;
- il giudice è un subagent su Haiku, con il suo modello e il suo prompt, e arriva con
  uno schema: «Get validated JSON output matching a JSON Schema after the agent
  completes its workflow (print mode only).»
  (https://code.claude.com/docs/en/cli-reference); Anthropic dice del modello che fa
  da giudice: «it should not be the model you are testing»
  (https://claude.dev/blog/automating-eval-design-and-hillclimbing/): le risposte le
  scrive Sonnet, il giudice è Haiku.

### Che cosa misura il controllo

`tools/verifica.sh M8-E02` legge le esecuzioni, i JSON di `risposte/` e di
`giudizi/`, e rifà i controlli sulla risposta di ogni caso con i `controlli.tsv` del
punto di partenza. Per ogni versione stampa, come dati: token in entrata, token in
uscita, costo ricalcolato, controlli superati, affermazioni rispettate. Per ogni
versione dopo v0, a parità di modello e di effort, stampa la riduzione dei token in
entrata rispetto a v0 e la riga dell'obiettivo del laboratorio. Le due frasi di
Anthropic si stampano senza un esito, perché il prompt è costruito per il corso: la
coppia dà i dati (i token in entrata sono scesi, controlli e giudice non sono scesi),
e la verifica si ferma lì.

È una misura piccola, tre casi e un'esecuzione per caso. Da una misura all'altra
cambiano sia le risposte sia i giudizi: «Even with temperature set to 0, the results
will not be fully deterministic, and identical inputs might produce different outputs
across API calls.»
(https://platform.claude.com/docs/en/about-claude/glossary). Il giudice, anche lui,
sbaglia: se un esito vi sembra sbagliato, leggete il suo motivo in `giudizi/`; se un
criterio cambia esito da una misura all'altra, non è una prova.

### Nella prova del corso

Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322,
`_docente/live.sh` sull'account del docente: v0 e la versione di riferimento di
`soluzione/`, una misura ciascuna, Sonnet con effort low per le risposte e Haiku per
il giudice) il confronto stampa queste righe:

    Confronto v0 → v1
    caso                  token in         token out     controlli       giudice
    caso-1            10273 → 2170         339 → 374     7/7 → 7/7     4/5 → 5/5
    caso-2            10301 → 2198         305 → 292     9/9 → 9/9     4/5 → 4/5
    caso-3            10194 → 2091         189 → 208     7/7 → 7/7     5/5 → 5/5
    totale            30768 → 6459         833 → 874 23/23 → 23/23 13/15 → 14/15

      riduzione dei token in entrata, v0 → v1: 79,0 %
      obiettivo del laboratorio: almeno il 50 % in meno

Il costo ricalcolato dalla stessa misura passa da 0,0151 $ a 0,0131 $, e i sei giudizi
strutturati sono conformi allo schema. Nei motivi del giudice si legge che cosa è
costato i punti: in v0, alla cliente del caso 1, che scrive dall'area clienti, la
risposta dà del tu, e nel caso 2 non dice che il problema non dipende dal rifugio; in
v1, al caso 2, non nomina la zona radio. Leggete le risposte, oltre alle tabelle. Una
misura sola può andare diversamente, per quello che dice il glossario qui sopra.

Attenzione al costo, che è un dato: dipende anche da che cosa è già in cache
(`cache_read_input_tokens`: «Number of tokens retrieved from the cache for this
request», https://platform.claude.com/docs/en/build-with-claude/prompt-caching).
In questa registrazione gran parte dei prompt era in cache da una prova precedente
entro l'ora, e per questo i due costi sono così vicini. Se rimisurate una versione a
breve distanza, i token in entrata restano quelli e il costo ricalcolato scende; e
dopo un taglio il costo può perfino salire, se v0 si legge dalla cache e la versione
nuova si scrive per la prima volta. Per questo il confronto che conta è quello dei
token in entrata e della qualità. La versione
di riferimento è in `soluzione/prompt/v1.md` (nel repository del corso; la copia senza
soluzioni non l'ha): la vostra sarà un'altra, e il metodo è quello.

## Verifica (tools/verifica.sh M8-E02)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M8-E02

Esce con 0 quando almeno una versione dopo v0 è misurata sui tre casi, con lo stesso
modello e lo stesso effort di v0, pesa meno token in entrata e non è peggiore di v0 né
nei controlli né nelle affermazioni del giudice, sul totale dei tre casi: le ultime
righe sono «Fatto: almeno una versione dopo v0 è misurata sui tre casi, pesa meno
token in entrata e non è peggiore di v0; gli esiti sono qui sopra.» e «VERIFICA OK
M8-E02: fatto.». Esce con 1 se manca qualcosa, se nessuna versione è più leggera e
non peggiore di v0, se i file di una versione non sono quelli misurati, se un file
del punto di partenza è cambiato (`prompt/v0.md`,
i documenti, i casi, il listino, lo schema, il giudice: si rimettono com'erano con
`git checkout -- <file>`), o se un giudizio strutturato non rispetta lo schema (una
garanzia della documentazione); dice che cosa fare. Esce con 2 quando non può partire.
Il 50 % si stampa come dato e le frasi di Anthropic si stampano senza un esito: non
decidono l'uscita.

## Se qualcosa va storto

- `misura.sh` dice che manca un segnaposto: controllate il nome tra doppie graffe; i
  dati del caso si chiamano `{{messaggio}}` e `{{stato}}` e devono esserci in ogni
  versione, i documenti stanno in `documenti/`, uno per segnaposto.
- `misura.sh` si ferma perché una chiamata è fallita: rilanciate la stessa versione,
  che riparte da capo; una nuova misura cancella prima quella vecchia. Se succede
  per i limiti del piano, aspettate qualche minuto.
- La verifica dice che una versione è incompleta o che manca un JSON: rilanciate
  `./misura.sh` su quella versione, dallo spazio di lavoro.
- La verifica dice che il punto di partenza è cambiato: rimettete il file com'era con
  `git checkout -- <file>` e misurate di nuovo le versioni.
- La verifica dice che v1 è peggiore di v0, oppure che non pesa meno token: leggete
  quali controlli o quali affermazioni ha perso (`controlli/v1/`, `giudizi/v1/`),
  rimettete in v2 le regole che mancano, oppure tagliate ancora, e misuratela. Un
  giudice instabile si riconosce rimisurando la stessa versione: un esito che cambia
  da una misura all'altra non è una prova.
- La verifica dice che i file di una versione non sono quelli misurati: il prompt, i
  documenti o i casi sono cambiati dopo la misura; rimettete a posto, se occorre, e
  misuratela di nuovo. Se è una versione lasciata a metà che non vi serve più, per
  esempio una v3, toglietela dallo spazio di lavoro: `rm -r risposte/v3 controlli/v3
  giudizi/v3`.
- `./misura.sh --confronta` dice che una misura è incompleta: misurate di nuovo la
  versione che nomina.
- Il giudizio arriva senza esito strutturato (manca `structured_output`): rilanciate
  la misura di quella versione.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M8-E02`.

## Impronta d'uso sul piano Pro

Chiamate brevi di `claude -p`, senza strumenti: per ogni versione misurata tre risposte
(Sonnet con effort low, un turno ciascuna) e tre giudizi (Haiku con effort low, due o
tre turni ciascuno nella registrazione): misurare v0 e una versione dopo v0 fa dodici
chiamate, ogni versione in più sei. Più la sessione interattiva su Sonnet, una
sessione di lavoro vera, che legge il prompt, i documenti e i casi, una quindicina di
file, e scrive `prompt/v1.md`, senza subagent. Niente Fable: «Pro plans and standard seats on Team plans: Fable models
aren’t included in your plan's usage limits.»
(https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan).

Misurato nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322,
`_docente/live.sh`, dal campo `usage` e da `duration_ms` di ogni JSON): le dodici
chiamate in 57 secondi dall'inizio alla fine (16,3 secondi di risposte e 27,0 di
giudizi, sommando `duration_ms`), 19 turni. Le risposte di v0 da 10.194 a 10.301 token
in entrata e da 189 a 339 in uscita ciascuna, quelle di v1 da 2.091 a 2.198 in entrata
e da 208 a 374 in uscita; i sei giudizi, insieme, 21.051 token in entrata e 5.651 in
uscita. I token dicono quanto lavoro è stato, non quanta parte del vostro piano
occupa. La sessione interattiva con il prompt del taglio non è stata misurata: quanto
pesa sui vostri limiti lo dice `/usage`, prima e dopo.

## Per approfondire

- La pagina sull'ottimizzazione di costi e qualità:
  https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- L'articolo di Anthropic sul context engineering:
  https://www.anthropic.com/research/effective-context-engineering-for-ai-agents
- I prezzi: https://platform.claude.com/docs/en/about-claude/pricing
- Il prompt in tag: `riferimenti/pattern-di-prompt.md`, e i laboratori M2-E01 e
  M2-E02 del Modulo 2, con gli stessi attrezzi di misura.
- Il progetto da cui vengono i documenti e i casi: `progetti/assistenza-clienti/`.
