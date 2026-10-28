# M4-E05 — Il rapporto quotidiano dei log

Laboratorio del Modulo 4, traccia (c), la variante dei sistemi, sulla rete
di CiaspoLink, l'operatore inventato del corso, un progetto sintetico: lo
script che ogni mattina scrive il rapporto dei disservizi del giorno prima
dai log della rete, in Python o in Bash, scritto in Claude Code a partire
da una specifica, con un controllo che Claude esegue da sé e un revisore
che non può modificare niente. In due parti: la prima finisce con un
commit e una nota, `NOTA.md`; la seconda parte del laboratorio riparte da
lì. L'altra variante della traccia (c) è M4-E04, il controllo notturno del
gestionale.

## Obiettivo

Ogni mattina il NOC di CiaspoLink manda all'assistenza clienti il
rapporto dei disservizi del giorno prima: che cosa si è rotto, dove, da
quando a quando, quante linee ne hanno risentito. Finora lo scrive una persona
leggendo i log. `SPECIFICA.md` dice che cosa deve fare
`rapporto_giornaliero.py` (o `rapporto_giornaliero.sh`): le opzioni, i
tre file di log che legge, i cinque tipi di disservizio, una riga per
disservizio, le uscite. Le regole del laboratorio:

- prima il piano, in plan mode;
- almeno un subagent: qui il revisore, che controlla il contratto dello
  script prima del commit che lo chiude;
- un controllo che Claude può eseguire: `controlla_rapporto.py`;
- piccoli passi, con un commit ciascuno;
- Sonnet con effort medium, il revisore su Haiku;
- alla fine della prima parte, un commit e `NOTA.md`: che cosa è fatto,
  che cosa manca, i comandi per riprendere.

Mettete alla prova quello che Anthropic dice di un lavoro che Claude porta
avanti da solo: che cosa gli serve prima di lasciarlo andare, a che cosa
serve un controllo che risponde «passa» o «non passa», e che un revisore
con soli strumenti di lettura non può modificare niente.

## Tempo

87 minuti, in due parti. Prima parte, 52 minuti: 6 per la presentazione
delle tre tracce; 44 di lavoro, 4 per preparare lo spazio di lavoro e
leggere la specifica, 10 per il piano, 23 per il lavoro, 7 per la
revisione e la nota; 2 per chiudere la parte, con il commit della nota.
Seconda parte, 35 minuti: 2 per ciò che resta, traccia per traccia; 33
di lavoro, circa 13 per riprendere dalla nota, 15 per finire, 5 per la
verifica.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3.8 o successivo, il comando `python3`: lo usano il controllo, la
  verifica e lo script, se lo scrivete in Python.
- Per lo script in Bash, il `bash` del terminale di Linux o della
  distribuzione WSL 2.
- Niente PHP né Docker: la rete è fatta di file di testo.

## Punto di partenza (tools/prepara_esercizio.sh M4-E05)

Lo spazio di lavoro `~/corso-claude-code/M4-E05/` con:

- `progetti/rete/`: la rete dell'operatore immaginario, con una settimana
  di log in `log/` (syslog degli apparati, sessioni PPPoE, RADIUS, DHCP,
  SBC SIP), l'inventario e gli allarmi; i formati delle righe di ogni
  sorgente sono in `progetti/rete/README.md`, «I log della settimana»;
- `SPECIFICA.md`: lo script da fare;
- `controlla_rapporto.py`: il controllo che Claude esegue (sotto, «Che cosa
  misura il controllo»);
- `.claude/agents/revisore.md`, il revisore: `tools: Read, Grep, Glob`,
  `model: haiku`; confronta lo script con la specifica (le uscite, stdout e
  stderr, le opzioni, i cinque tipi) e risponde in un formato fisso (ESITO,
  CONTRATTO, PROBLEMI);
- `.claude/settings.json`: le impostazioni di progetto. Tengono le regole
  prudenti del repository (`.env`, `secrets/`, chiavi) e aggiungono:
  - tre regole `allow`: il controllo, `python3 controlla_rapporto.py`, e
    lo script, `python3 rapporto_giornaliero.py` o
    `bash rapporto_giornaliero.sh` con i loro argomenti; Claude li esegue
    senza chiedervelo;
  - regole `deny` di `Edit` sul controllo, su `SPECIFICA.md`, su
    `.claude/agents/` e su tutto `progetti/rete/`:
    `Edit(/controlla_rapporto.py)`, `Edit(/SPECIFICA.md)`,
    `Edit(/.claude/agents/**)` e `Edit(/progetti/rete/**)`. I log sono i
    dati, non si toccano. «Edit rules apply to all built-in tools that
    edit files.» (https://code.claude.com/docs/en/permissions);
  - `defaultMode` `default`, la modalità Manual: «The mode that reviews
    every action is named Manual in the CLI … Its config value is default»
    (https://code.claude.com/docs/en/permission-modes);
  - `plansDirectory` `./piani`: il piano che Claude scrive in plan mode
    resta nello spazio di lavoro, in `piani/`, e la seconda parte lo
    ritrova: «Choose where Claude Code stores the plan files it writes in
    plan mode.» (https://code.claude.com/docs/en/settings-reference).

Le quattro regole `deny` aggiunte cominciano con `/`. Nella pagina sui
permessi: «`path` or `./path` | Path relative to current directory |
`Read(*.env)` | `<cwd>/*.env`» e «`/path` | Path relative to the settings
source | `Edit(/src/**/*.ts)` | `<primary working directory>/src/**/*.ts`
in project settings» (https://code.claude.com/docs/en/permissions):
senza la barra il percorso vale rispetto alla cartella corrente, con la
barra rispetto allo spazio di lavoro. Nelle prove del corso di M4-D04,
dopo un `cd` una regola senza la barra non ha più coperto il suo file,
quella con la barra sì.

## Passi in Claude Code

### Prima parte

1. Dalla cartella `esercitazioni`: preparate lo spazio di lavoro, entrateci
   e aprite Claude Code in plan mode, su Sonnet con effort medium:

       tools/prepara_esercizio.sh M4-E05
       cd ~/corso-claude-code/M4-E05
       claude --permission-mode plan --model sonnet --effort medium

   Intanto leggete voi `SPECIFICA.md`: è il metro con cui giudicherete il
   lavoro. Scegliete il linguaggio: i prompt qui sotto sono per Python; per
   Bash, nei prompt 1 e 2 scrivete `rapporto_giornaliero.sh, in Bash, con
   #!/bin/bash e set -euo pipefail` al posto di `rapporto_giornaliero.py,
   in Python 3.8 o successivo, solo libreria standard`, e
   `bash rapporto_giornaliero.sh` al posto di
   `python3 rapporto_giornaliero.py`.

   Alla prima apertura Claude Code vi chiede se vi fidate della cartella:
   «In an interactive session, Claude Code shows the workspace trust
   dialog when you start it in a folder you haven't trusted.»
   (https://code.claude.com/docs/en/security). Rispondete sì: le tre
   regole `allow` valgono soltanto dopo, «permissions.allow rules,
   permissions.additionalDirectories, extraKnownMarketplaces, and most
   env values apply only after each teammate trusts the folder … deny and
   ask rules apply right away» (https://code.claude.com/docs/en/settings),
   e da lì «Allow rules let Claude Code use the specified tool without
   manual approval.» (https://code.claude.com/docs/en/permissions). La
   prova del corso, fatta con `claude -p` e senza quella domanda, a ogni
   chiamata ha scritto «Ignoring 3 permissions.allow entries from
   .claude/settings.json: this workspace has not been trusted».

2. Il piano. Incollate:

   <!-- prompt 1 -->

       Leggi SPECIFICA.md e la descrizione dei log in progetti/rete/README.md
       («I log della settimana»); dei log di progetti/rete/log/ guarda
       poche righe per sorgente, senza leggerli interi. Prepara un piano a
       piccoli passi per scrivere rapporto_giornaliero.py, in Python 3.8 o
       successivo, solo libreria standard, ciascuno con il suo commit. Nel
       piano: dopo ogni passo esegui il controllo, questo comando, da solo,
       senza concatenarlo ad altri:
       python3 controlla_rapporto.py
       e leggi l'esito nella sua ultima riga; prima del commit che chiude lo
       script, il subagent revisore ne controlla il contratto d'uscita e i
       messaggi con SPECIFICA.md.

   <!-- /prompt 1 -->

   Quando Claude presenta il piano, leggetelo: ci sono i passi, i cinque
   tipi di disservizio, il controllo dopo ogni passo, il revisore, i
   commit? Se no, ditegli che cosa cambiare. Se va bene, approvatelo
   scegliendo di approvare le modifiche una per una: finché non lo
   approvate, niente cambia.

3. Il lavoro. Dopo l'approvazione Claude esegue il piano. Se si ferma
   prima di finire, incollate:

   <!-- prompt 2 -->

       Il piano va bene: eseguilo un passo alla volta. Dopo ogni passo
       esegui il controllo, da solo, senza concatenarlo ad altri:
       python3 controlla_rapporto.py
       e correggi lo script finché l'ultima riga dice uscita: 0; il
       controllo non si cambia. Prova anche lo script su un giorno della
       settimana dei log, da solo:
       python3 rapporto_giornaliero.py --giorno 2026-09-08
       Dopo ogni passo che passa il controllo fai un commit: git add, poi
       git commit -m con il messaggio fra virgolette, un comando per volta,
       e un messaggio breve nella forma tipo(ambito): descrizione, per
       esempio feat(rapporto): legge il syslog.

   <!-- /prompt 2 -->

   Leggete ogni modifica prima di approvarla. Il controllo e lo script
   girano senza chiedere niente; i commit li approvate voi, leggendo il
   messaggio. In un altro terminale, nella cartella dello spazio di lavoro,
   provate anche voi lo script su altri giorni della settimana, da lunedì
   7 a domenica 13 settembre 2026, e guardatene l'uscita:

       python3 rapporto_giornaliero.py --giorno 2026-09-10
       echo "uscita: $?"

4. La revisione, prima del commit che chiude lo script. Incollate:

   <!-- prompt 3 -->

       Prima del commit che chiude lo script: esegui git log --oneline, poi
       git diff dal primo commit, il punto di partenza, e passa il diff a
       @agent-revisore perché controlli il contratto d'uscita e i messaggi
       dello script con SPECIFICA.md. Correggi ciò che segnala, esegui di
       nuovo il controllo e fai il commit.

   <!-- /prompt 3 -->

5. La nota, alla fine della prima parte. Incollate:

   <!-- prompt 4 -->

       Siamo alla fine della prima parte del laboratorio. Scrivi NOTA.md,
       nella cartella in cui siamo: che cosa è fatto (i punti di
       SPECIFICA.md già soddisfatti, con i loro commit), che cosa manca, e i
       comandi per riprendere (il controllo, lo script su un giorno della
       settimana, il revisore). Poi fai un commit di NOTA.md: git add, poi
       git commit -m, un comando per volta.

   <!-- /prompt 4 -->

   Poi `/exit`.

### Seconda parte

6. Una sessione nuova, che riparte dalla nota. Partite dalla cartella
   `esercitazioni`, come nel passo 1: in un terminale nuovo,
   `cd ~/esercitazioni` se avete clonato il repository nella cartella di
   casa, come chiede `PRIMA_DEL_CORSO.md` in WSL 2, altrimenti il suo
   percorso. Poi entrate nello spazio di lavoro e aprite Claude Code:

       cd ~/corso-claude-code/M4-E05
       claude --model sonnet --effort medium

   e incollate:

   <!-- prompt 5 -->

       Leggi NOTA.md e SPECIFICA.md e riprendi il lavoro da dove si era
       fermato: finisci ciò che manca un passo alla volta, con un commit per
       passo. Dopo ogni passo esegui il controllo, da solo, senza
       concatenarlo ad altri:
       python3 controlla_rapporto.py
       Prima dell'ultimo commit esegui git log --oneline e git diff dal
       primo commit, e passa il diff a @agent-revisore perché controlli il
       contratto d'uscita e i messaggi dello script con SPECIFICA.md.

   <!-- /prompt 5 -->

   L'alternativa è riprendere la conversazione della prima parte con
   `claude --continue`, che «resumes the most recent session in the
   current directory» (https://code.claude.com/docs/en/common-workflows).
   Ma una sessione nuova parte senza la conversazione di prima: «Each new
   session starts with a fresh context window, without the conversation
   history from previous sessions»
   (https://code.claude.com/docs/en/how-claude-code-works); riparte dalla
   nota, piccola. Riprendere una conversazione lunga dopo un'interruzione
   lunga, invece, è più lento: «After a long enough gap, the next request
   recomputes the full input and re-establishes the cache, which is why
   the first turn back after stepping away can be noticeably slower.»
   (https://code.claude.com/docs/en/prompt-caching), e sul piano Pro può
   chiedere conferma: «On Pro and Max plans, the dialog can appear when
   you resume a long conversation after a long break or on a different
   model.» (https://code.claude.com/docs/en/sessions).

7. Se il controllo non passa, incollate:

   <!-- prompt 6 -->

       Esegui il controllo, da solo, senza concatenarlo ad altri:
       python3 controlla_rapporto.py
       e correggi lo script finché l'ultima riga dice uscita: 0. Poi esegui
       git diff dal primo commit, passalo a @agent-revisore perché controlli
       il contratto d'uscita e i messaggi dello script con SPECIFICA.md, e
       fai il commit.

   <!-- /prompt 6 -->

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate. `~/esercitazioni` è la cartella in cui `PRIMA_DEL_CORSO.md`
   fa clonare il repository in WSL 2; se l'avete clonato altrove, usate il
   suo percorso:

       cd ~/esercitazioni
       tools/verifica.sh M4-E05

## Che cosa osservare

### Che cosa dice Anthropic

- **Prima di lasciarlo lavorare da solo.** La pagina delle best practice
  di Claude Code propone cinque domande prima di un lavoro senza
  sorveglianza: «it's worth going through these five questions with that
  specific task in mind: 1. Does it know what done looks like? … 2. Can
  it check its own work? … 3. What's it allowed to touch? … 4. What stops
  it? --max-turns, --max-budget-usd, a spend limit. 5. Where does the
  result go, and who signs off?»
  (https://code.claude.com/docs/en/best-practices). Qui le risposte sono
  nello spazio di lavoro: il «finito» è `SPECIFICA.md`; il lavoro si
  controlla con `controlla_rapporto.py`; che cosa può toccare lo dicono le
  regole `deny` di `.claude/settings.json`; a fermarlo, in questa sessione
  interattiva, siete voi: «Esc stops Claude mid-action and keeps
  everything up to that point, so you can redirect without losing work.»
  (stessa pagina), mentre un lavoro senza nessuno davanti lo fermano i
  limiti della quarta domanda. Alla quinta, «Dove va il risultato, e chi
  lo approva?», il laboratorio risponde con un commit per passo e con
  `NOTA.md`: li approvate voi. Le stesse domande valgono per lo script che
  scrivete, che girerà ogni mattina senza nessuno davanti: la risposta è
  il suo contratto, che cosa legge, che cosa stampa, con quale uscita.
- **Un controllo che risponde «passa» o «non passa».** «Give Claude
  something it can run that comes back pass or fail. Once it has that, it
  can keep going on its own»
  (https://code.claude.com/docs/en/best-practices). Senza: «Claude stops
  when the work looks done.» Con il controllo, il ciclo: «It makes the
  change, runs the check, and if something broke it reads the output and
  fixes it before running the check again.» E il controllo «can be almost
  anything, as long as Claude can read the result» (stessa pagina): qui è
  uno script che esegue il vostro su log di prova e ne confronta uscita,
  stdout e stderr con la specifica. È una raccomandazione: dice che cosa
  Claude può fare, non che lo farà a ogni sessione.
- **Un revisore che non può modificare.** Fra i casi in cui un subagent
  ripaga: «Giving a task fewer tools than the main session has, like a
  reviewer that can read but not edit»; e un subagent in `.claude/agents/`
  con soli `tools: Read, Grep, Glob`: «Now it's a reviewer that can't edit
  anything», un limite «enforced by Claude Code»
  (https://code.claude.com/docs/en/best-practices). È una garanzia del
  prodotto: la verifica la controlla nella trascrizione del revisore. Il
  revisore parte dal diff, come consiglia l'Academy per un lavoro che non
  si è seguito passo passo: «Don't start with Claude's summary of what it
  did. Start with the diff itself.»
  (https://academy.claude.com/courses/claude-code-in-action/trust-it-verifying-unsupervised-runs)
- **I log e la conversazione.** Una settimana di log è lunga, e la pagina
  dei subagent consiglia di usarne uno «when a side task would flood your
  main conversation with search results, logs, or file contents you won't
  reference again» (https://code.claude.com/docs/en/sub-agents): per
  questo il prompt 1 chiede poche righe per sorgente. Se vi serve un
  secondo subagent, è questo il caso.
- **Il modello e il formato.** «Set model: haiku in a subagent's definition
  if its work is simple» (https://code.claude.com/docs/en/best-practices),
  ed è il revisore; e «The single most important improvement you can make
  to a subagent is defining an output format in its system prompt.»
  (https://academy.claude.com/courses/introduction-to-subagents/designing-effective-subagents),
  ed è il formato fisso di `revisore.md`.
- **La @-mention.** «Natural language: name the subagent in your prompt;
  Claude decides whether to delegate…@-mention: guarantees the subagent
  runs for one task» (https://code.claude.com/docs/en/sub-agents): per
  questo i prompt 3, 5 e 6 scrivono `@agent-revisore`. E «With nothing
  configured, a subagent that Claude spawns from your main conversation
  starts in the background.» (stessa pagina)
- **Prima il piano.** «If you take one thing away from this course, let it
  be this workflow: Explore, Plan, Code, and Commit.»
  (https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow);
  in plan mode «Claude reads files and proposes a plan but makes no edits
  until you approve.» (https://code.claude.com/docs/en/common-workflows).

### Che cosa guardare

- **Il piano:** ci sono i passi, i cinque tipi di disservizio, il
  controllo dopo ogni passo, il revisore, i commit? Lo approvate voi.
- **I log:** come li legge Claude, a pezzi con `grep` e `head`, o interi?
  Quante righe di log finiscono nella conversazione?
- **Il controllo:** Claude lo esegue dopo ogni passo? Quando un caso dice
  NO, corregge lo script o prova a cambiare il controllo, che la regola
  `deny` protegge?
- **Il rapporto sui giorni della settimana:** che cosa trova, giorno per
  giorno? È ciò che vi aspettereste leggendo i log a mano, e in quanto
  tempo lo avreste scritto?
- **Il revisore:** che cosa trova, nel contratto d'uscita, nei messaggi e
  nei cinque tipi, che la sessione principale non aveva visto? Claude
  corregge?
- **I commit e la nota:** piccoli, con messaggi chiari? `NOTA.md` basta per
  riprendere?

### Che cosa misura il controllo

`python3 controlla_rapporto.py` crea in una cartella temporanea piccole
cartelle di log di prova, nei formati dei log della rete e con apparati
inventati: un giorno con un disservizio per tipo, e uno che a fine giornata
non si è chiuso, accanto al rumore di fondo di una settimana qualunque (un
ONT che va offline per `dying-gasp`, una stazione radio che si disconnette,
una sessione BGP che cade e torna, gli accessi del NOC); un giorno
tranquillo, con il rumore soltanto; un giorno senza file; un giorno a cui
manca il file dell'SBC. Esegue lo script, in Python o in Bash, in otto
casi: `--help`; il giorno con i disservizi, dove le righe devono essere
proprio quelle attese, in ordine di inizio; il giorno tranquillo; la
cartella dei log che manca; il giorno senza file; il file che manca; un
giorno non valido; un'opzione sconosciuta. Per ogni caso confronta
l'uscita, stdout e stderr con la specifica e controlla che lo script non
scriva nella cartella dei log; stampa `ok` o `NO` con il motivo e,
nell'ultima riga, `uscita: 0`, `1` o `2`. Non sa quali disservizi ci sono
nella settimana dei log di esempio: quelli li trova lo script.

### Che cosa misura la verifica

- `tools/verifica.sh M4-E05` non si fida di ciò che lo script dice, né
  degli script dello spazio di lavoro: lo esegue sui log originali del
  repository, copiati in una cartella temporanea, e lo spazio di lavoro
  non cambia. È la distinzione che Anthropic fa per gli agenti: «A
  flight-booking agent might say “Your flight has been booked” … but the
  outcome is whether a reservation exists in the environment’s SQL
  database.»
  (https://www.anthropic.com/research/demystifying-evals-for-ai-agents)
- Esegue il controllo dell'esercizio nella sua copia originale, quella del
  repository: un controllo dello spazio di lavoro cambiato non basta.
- Esegue lo script su martedì 8 settembre, il giorno di un disservizio che
  la verifica conosce: deve uscire con 1 e, fra le sue righe, avere quel
  disservizio con l'apparato, la porta, l'inizio, la fine e le linee
  giusti. Li confronta per impronta, con `verita.json`: stampa per ogni
  campo «sì» o «no», mai il valore atteso.
- Lo esegue su un giorno tranquillo della settimana: deve uscire con 0,
  senza nessuna riga.
- Nella trascrizione del revisore cerca gli strumenti che modificano (Edit,
  Write, NotebookEdit): se ce n'è uno, è una garanzia di Claude Code che
  non ha tenuto, e la verifica lo segnala. Se avete cambiato la definizione
  del revisore dandogli altri strumenti, la garanzia non si applica. Se
  riconosce meno trascrizioni del revisore che chiamate, l'esito è «non
  distinguibile»: una chiamata senza trascrizione non si controlla. Una
  trascrizione che non si legge ferma la verifica, con l'uscita 2.
- Come dati, mai come uscita: gli altri giorni della settimana (l'uscita,
  quante righe, se il disservizio che la verifica conosce in quel giorno
  c'è), `NOTA.md`, i commit dopo il punto di partenza, i file cambiati, le
  sessioni di Claude Code dello spazio di lavoro, le chiamate al tool Agent
  per tipo di subagent, e quante volte Claude ha eseguito il controllo, con
  l'uscita dell'ultima: quante volte il ciclo del controllo è girato lo
  dicono le chiamate della sessione, non il controllo, che non tiene un
  registro. Le sessioni stanno dove Claude Code le salva: «By default,
  Claude Code stores transcripts as JSONL at
  ~/.claude/projects/<project>/<session-id>.jsonl»
  (https://code.claude.com/docs/en/sessions), e i subagent accanto: «find
  IDs in the transcript files at
  ~/.claude/projects/{project}/{sessionId}/subagents/. Each transcript is
  stored as agent-{agentId}.jsonl.»
  (https://code.claude.com/docs/en/sub-agents). Il tool che lancia i
  subagent si chiama Agent: «In version 2.1.63, the Task tool was renamed
  to Agent.» (stessa pagina); la verifica conta tutti e due i nomi. Senza
  chiamate stampa «nessun subagent trovato»: la regola del laboratorio lo
  chiede, ma la verifica non vi boccia per questo.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, la variante in Python, `_docente/live.sh` sull'account del
docente, con le regole scritte allora senza la barra iniziale,
equivalenti dalla radice dello spazio di lavoro): il controllo
dell'esercizio, «8 casi su 8 come la specifica»; martedì 8 settembre,
uscita 1 e una riga, con il disservizio che la verifica conosce,
«apparato sì · porta sì · inizio sì · fine sì · linee sì»; lunedì 7,
uscita 0 e nessuna riga. Il revisore (tools: Glob, Grep, Read): 3
trascrizioni, nessuno strumento che modifica, «la garanzia vale». Come
dati: gli altri giorni, uscita 1, con 18 righe mercoledì 9 e una sola
negli altri, e il disservizio conosciuto trovato in ognuno; `NOTA.md`
c'è, 4 commit, 3 file cambiati, 2 sessioni, «chiamate al tool Agent: 3
(revisore 3)», e «il controllo eseguito da Claude: 11 volte, l'ultima con
uscita 0».

## Verifica (tools/verifica.sh M4-E05)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M4-E05

Esce con 0 se il controllo dell'esercizio passa, se lo script trova il
disservizio che la verifica conosce, campo per campo, e se in un giorno
tranquillo tace; con 1 se qualcosa manca o non torna (e dice che cosa), o
se il revisore ha modificato file; con 2 se non può partire, per esempio
se mancano i log della rete nel repository.

## Se qualcosa va storto

- Il controllo dice `uscita: 2` perché lo script non c'è: Claude non l'ha
  ancora scritto, o l'ha chiamato in un altro modo; i due nomi ammessi sono
  in `SPECIFICA.md`. Dice `uscita: 2` anche se ci sono tutti e due:
  tenetene uno.
- Il caso del giorno con i disservizi dice «righe che non sono nel
  formato»: fra un campo e l'altro ci vuole un TAB, non degli spazi.
- Claude legge i log interi e la sessione si appesantisce: chiedetegli di
  guardarne poche righe, con `grep` o `head`. Per un file troppo grande la
  pagina di aiuto suggerisce: «Ask Claude to read the oversized file in
  smaller chunks, such as a specific line range or function»
  (https://code.claude.com/docs/en/troubleshooting).
- Claude vi chiede di approvare una riga che unisce più comandi: rispondete
  **No** e chiedetegli un comando per volta. «Claude Code is aware of shell
  operators, so a rule like Bash(safe-cmd *) won't give it permission to
  run the command safe-cmd && other-cmd.»
  (https://code.claude.com/docs/en/permissions)
- `git commit` si ferma con «Please tell me who you are»: git non sa chi
  firma i commit. Dallo spazio di lavoro, una volta: `git config
  user.name "Partecipante"` e `git config user.email
  partecipante@example.org`.
- Claude vuole cambiare il controllo, `SPECIFICA.md`, un file di
  `.claude/agents/` o i log: la regola `deny` lo ferma. Si corregge lo
  script; se la specifica vi sembra sbagliata, ditelo al docente.
- Il controllo passa e la verifica no: rileggete la tabella dei tipi di
  `SPECIFICA.md` (che cosa apre e che cosa chiude un disservizio, quali
  linee si contano, l'ora come è scritta nella riga) e chiedete a Claude di
  provare lo script sui giorni della settimana, non solo sul controllo.
- Un giorno tranquillo, per la verifica, non lo è: lo script segnala
  qualcosa che non è uno dei cinque tipi; l'elenco di ciò che non entra
  nel rapporto è in `SPECIFICA.md`.
- `claude --continue` dice «No conversation found to continue»: lo lanciate
  da un'altra cartella; entrate in `~/corso-claude-code/M4-E05`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-E05`.

## Impronta d'uso sul piano Pro

Sessioni interattive su Sonnet, effort medium; nella prova del corso 28
turni del modello in tutto, nelle due parti (sotto); un subagent, il
revisore, su Haiku, chiamato tre volte. «Sonnet handles most coding tasks
well and costs less than Opus.»
(https://code.claude.com/docs/en/costs). Leggere i log a pezzi tiene
piccola la conversazione; i subagent non sono gratis: «What they cost you
is mostly tokens, since every subagent sends its own requests and they
count against the same usage as your main conversation.» Per spendere
meno, risposte brevi: «Ask for short summaries back, so twenty results
don't fill your context anyway.»
(https://code.claude.com/docs/en/best-practices); il formato fisso del
revisore serve anche a questo. Il controllo, lo script e la verifica
girano sul vostro computer, senza chiamate al modello. I limiti sono gli
stessi di claude.ai: «These limits are shared across Claude and Claude
Code, meaning all activity in both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan);
`/usage` mostra quanto pesa ciascuno: «On Pro, Max, Team, and Enterprise
it breaks your usage down by skill, subagent, plugin, and MCP server.»
(https://code.claude.com/docs/en/best-practices).

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `claude -p` sull'account del docente), dal JSON di ogni
chiamata: cinque chiamate, quattro nella prima parte e una nella
seconda, con 11, 6, 3, 4 e 4 turni del modello (`num_turns`); 74,0, 16,7,
7,4, 18,6 e 14,0 secondi; token in entrata della conversazione
principale, cache compresa, 194.792, 306.986, 177.656, 244.259 e
171.550. I token del revisore si aggiungono a questi.

## Per approfondire

- «Best practices for Claude Code»:
  https://code.claude.com/docs/en/best-practices
- «Create custom subagents»: https://code.claude.com/docs/en/sub-agents
- «Common workflows», con plan mode e la ripresa delle sessioni:
  https://code.claude.com/docs/en/common-workflows
- «Choose a permission mode»:
  https://code.claude.com/docs/en/permission-modes
- Il corso «Claude Code 101» dell'Academy, la lezione Explore, Plan, Code,
  Commit:
  https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow
- Il corso «Claude Code in action» dell'Academy, la lezione «Trust it:
  verifying unsupervised runs»:
  https://academy.claude.com/courses/claude-code-in-action/trust-it-verifying-unsupervised-runs
- Il corso «Introduction to subagents» dell'Academy:
  https://academy.claude.com/courses/introduction-to-subagents
- Il video «Building verification loops in Claude Code»:
  https://www.youtube.com/watch?v=mQZB0l-rhxE
