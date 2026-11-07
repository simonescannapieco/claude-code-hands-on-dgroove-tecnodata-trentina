# M6-E03 — Un CLAUDE.md per la rete

Laboratorio del Modulo 6, traccia della rete, pensata per chi gestisce sistemi e
reti: un CLAUDE.md per il progetto della rete di CiaspoLink, l'operatore
inventato del corso, provato come il codice. Le stesse tre richieste girano
senza CLAUDE.md, con una prima versione e con una seconda, ognuna in una
sessione nuova, e un controllo legge che cosa è cambiato. L'altra traccia, con
lo stesso metodo, è M6-E02, sul gestionale: ognuno ne fa una.

## Obiettivo

Il team di rete sa cose che il repository non dice: le ha scritte negli
appunti, `appunti-del-team.md`. Qui decidete, appunto per appunto, che cosa
serve a Claude a ogni sessione e dove va: nel CLAUDE.md, in una regola per una
parte del progetto, in una regola che lo vieta, da nessuna parte perché Claude
lo trova da solo. Il metodo è quello di Anthropic: si comincia senza CLAUDE.md,
si guarda dove Claude va corretto, si scrive solo ciò che serve, si riprova.

Alla fine avete:

- `CLAUDE.md`, alla radice dello spazio di lavoro, in due versioni diverse;
- una regola in `.claude/rules/`, con `paths:`, per il generatore;
- le regole `deny` in `.claude/settings.json`;
- `prove-contesto/`, le tre richieste in tre versioni, `base`, `v1` e `v2`, con
  ciò che Claude ha fatto in ognuna e una fotografia di ogni versione.

Il file si scrive in una sessione interattiva di Claude Code, dove si lavora di
solito e si approva ciò che Claude scrive. Le prove girano in `claude -p`, che
senza `--bare` carica CLAUDE.md e regole come una sessione interattiva:
«claude -p discovers and loads them as an interactive session would»
(https://code.claude.com/docs/en/headless). E ognuna parte da una sessione
nuova, perché il confronto chiede esecuzioni che differiscano soltanto nei file
di istruzioni.

## Tempo

59 minuti: 8 per partire e per la prima prova, 20 per la prima versione, 10 per
le sue prove, 12 per la seconda versione, 7 per le sue prove e la verifica, 2
per il punto della situazione.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3.8 o successivo, il comando `python3`, e git: li usano il progetto,
  le prove e la verifica.
- Il comando `pgrep`, che `tools/prova_contesto.sh` richiede: su Debian e
  Ubuntu sta nel pacchetto `procps`.
- Niente PHP né Docker: il progetto della rete è fatto di file di testo e di un
  generatore in Python.
- Su Windows, WSL 2.

## Punto di partenza (tools/prepara_esercizio.sh M6-E03)

Lo spazio di lavoro `~/corso-claude-code/M6-E03/`, un repository git con un
primo commit, con:

- `progetti/rete/`: configurazioni, log, inventario e allarmi, il generatore e
  la checklist di audit, senza un CLAUDE.md. Nello standard di AUD-02 di
  `checklist-audit.md` c'è un refuso, messo apposta: lo chiede di correggere
  la seconda richiesta;
- `appunti-del-team.md`, gli appunti del team: sintetici, come tutto nel corso;
- `.claude/settings.json`: le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e l'hook `InstructionsLoaded`, con il suo script in `.claude/hooks/`:
  scrive in `.claude/caricamenti.jsonl` una riga per ogni file di istruzioni
  che Claude Code carica, con il motivo;
- `.gitignore`: tiene fuori da git le prove, il registro dell'hook,
  `CLAUDE.local.md` e `.claude/settings.local.json`.

Le tre richieste, scritte come le scriverebbe chiunque, stanno nella cartella
dell'elemento, in `prove/richieste.tsv`, e restano le stesse per le tre
versioni:

| | richiesta | che cosa guarda il controllo |
|---|---|---|
| r1 | «Controlla che i file del progetto rete siano a posto e dimmi l'esito.» | quali controlli del progetto ha lanciato, se la risposta riporta il loro esito, se ha cambiato file |
| r2 | «Nella checklist di audit c'è un refuso nello standard di AUD-02: correggilo e fai il commit.» | il refuso, il commit e il suo messaggio, i file toccati |
| r3 | «Che cosa controlla la categoria AUD-07 della checklist di audit? Rispondi in cinque righe.» | una richiesta che col CLAUDE.md non c'entra: che cosa costa il file |

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro e fate la prima
   prova, senza CLAUDE.md:

       tools/prepara_esercizio.sh M6-E03
       tools/prova_contesto.sh M6-E03 base

   Ogni richiesta gira in una sessione nuova di `claude -p`, in una copia pulita
   dello spazio di lavoro, al massimo tre insieme, con l'auto memory, la
   memoria automatica del Modulo 4, spenta (`CLAUDE_CODE_DISABLE_AUTO_MEMORY`:
   «Set to 1 to disable auto memory.»,
   https://code.claude.com/docs/en/env-vars): così le versioni differiscono
   soltanto nei file di istruzioni. Nelle prove Claude può, senza chiedere:
   leggere e cercare nei file, in tutte e tre le richieste; eseguire comandi
   con Bash nelle prime due, tranne `sudo`, `git push`, `curl` e `wget`;
   modificare file nella seconda. Lavora in una copia temporanea dello spazio
   di lavoro, che alla fine viene cancellata. Mentre girano, leggete
   `~/corso-claude-code/M6-E03/appunti-del-team.md` e chiedetevi, per ogni
   appunto, le due domande di Anthropic (sotto, «Che cosa dice Anthropic»):
   Claude lo troverebbe leggendo il repository? Andrebbe a cercarlo? Quando le
   prove finiscono, lo strumento stampa ciò che il controllo ha letto in ogni
   esecuzione: guardate che cosa Claude ha trovato da solo.

2. La prima versione. In un altro terminale entrate nello spazio di lavoro e
   aprite Claude Code, su Sonnet con effort medium:

       cd ~/corso-claude-code/M6-E03
       claude --model sonnet --effort medium

   Alla prima apertura vi chiede se vi fidate della cartella: «In an interactive
   session, Claude Code shows the workspace trust dialog when you start it in a
   folder you haven’t trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì: in Claude Code 2.1.319 il cursore parte da «No, exit», quindi
   scendete con la freccia su «Yes, I trust this folder» e date Invio. Poi
   `/init`, che scrive la bozza: «Initialize project with a CLAUDE.md guide.»
   (https://code.claude.com/docs/en/commands). Quando ha finito, incollate:

   <!-- prompt 1 -->

       <role>
       Sei un collega del team che cura il progetto in progetti/ e
       scrivi il CLAUDE.md che i colleghi caricano a ogni sessione di
       Claude Code.
       </role>

       <context>
       Il CLAUDE.md alla radice di questa cartella l'ha appena scritto
       /init: è la bozza da asciugare. In appunti-del-team.md ci sono gli
       appunti del team, che il repository non contiene: decisioni prese
       a voce, abitudini, procedure, preferenze. Il CLAUDE.md entra nel
       contesto all'inizio di ogni sessione, e ogni sua riga pesa su ogni
       richiesta: tieni solo ciò che cambia quello che Claude fa.
       </context>

       <instructions>
       1. Leggi il CLAUDE.md, appunti-del-team.md e i documenti che
          nominano.
       2. Per ogni riga del CLAUDE.md fatti le due domande: Claude la
          troverebbe leggendo il repository? Andrebbe davvero a cercarla?
          Togli le righe con due sì.
       3. Aggiungi dagli appunti ciò che il repository non dice e che
          vale per tutto il team, con i comandi esatti e la cartella da
          cui si lanciano.
       4. Per ultimo conta le righe del file e rileggile una per una con
          le due domande: correggi finché il file sta in una pagina,
          sotto le 200 righe, e ogni riga ha almeno un no.
       </instructions>

       <format>
       Il CLAUDE.md con titoli Markdown ed elenchi puntati, righe
       concrete e verificabili: una riga su che cos'è il progetto, poi
       le sezioni Comandi, Convenzioni che il codice non dice e Insidie,
       quelle che servono. Nella risposta, al massimo dieci righe: per
       ogni appunto, dove va (CLAUDE.md, già nel repository, una regola
       per una parte del codice, una skill, CLAUDE.local.md, una regola
       deny) e perché.
       </format>

       <constraints>
       Scrivi soltanto il CLAUDE.md alla radice. Ciò che vale per una
       sola parte del codice, le procedure in più passi, le preferenze
       personali e ciò che deve valere sempre restano fuori dal file:
       elencali nella risposta, per il passo seguente.
       </constraints>

   <!-- /prompt 1 -->

   È lo stesso prompt della traccia del gestionale: il metodo non cambia con il
   progetto. Se Claude Code vi chiede di approvare la scrittura del file,
   leggete la modifica, poi approvate. Lasciate aperta la sessione: serve al
   passo 4.

   Il file si carica nelle sessioni nuove, non in quella dove è nato: «Your
   project-root and user-level CLAUDE.md files are read once at session start
   and held in memory.» (https://code.claude.com/docs/en/prompt-caching). Per
   vederlo caricato, nel primo terminale:

       cd ~/corso-claude-code/M6-E03
       claude -p "/context all"
       cd -

   Il CLAUDE.md è nell'elenco dei file di memoria, con i suoi token: «To
   confirm the file loaded, run /context all in a session and check the list
   under Memory files.» (https://code.claude.com/docs/en/memory).

3. Le prove della prima versione. Dalla cartella `esercitazioni`:

       tools/prova_contesto.sh M6-E03 v1

   Le stesse tre richieste, con la v1. Il confronto dice, per ogni criterio,
   base contro v1: «confermata» se senza il file no e con il file sì, «non
   distinguibile» se è uguale, «non confermata in questa misura» se senza sì e
   con no. Copiate le righe che lo strumento stampa, da «Il confronto delle
   versioni» all'ultima: servono al passo 4.

4. La seconda versione. Nella sessione del passo 2 incollate questo seguito,
   con le righe del passo 3 al posto della riga fra i tag
   `<verification_result>`:

   <!-- prompt 2 -->

       <context>
       La prima versione del CLAUDE.md è stata provata: le stesse tre
       richieste, ciascuna in una sessione nuova, senza CLAUDE.md (base)
       e con questa versione (v1). Che cosa il controllo ha letto nelle
       esecuzioni è fra i tag verification_result, qui sotto: per ogni
       richiesta i criteri in base e in v1, il confronto, turni e token.
       </context>

       <instructions>
       1. Leggi il risultato del controllo, il CLAUDE.md e
          appunti-del-team.md.
       2. Per ogni criterio che con la v1 non passa, aggiungi al
          CLAUDE.md la riga che manca, o rendi più concreta quella che
          c'è.
       3. Togli una riga se in base Claude ha fatto da solo ciò che
          chiede, e con la v1 non ha risparmiato turni.
       4. Ciò che negli appunti vale per una sola parte del codice va in
          una regola nuova in .claude/rules/, con paths: nel frontmatter
          e i percorsi dalla radice.
       5. Ciò che negli appunti deve valere sempre diventa una regola
          deny in .claude/settings.json.
       6. Per ultimo rileggi i tre file: il CLAUDE.md sotto le 200 righe,
          la regola con il suo paths:, settings.json un JSON valido con
          l'hook di prima.
       </instructions>

       <format>
       Al massimo cinque righe: che cosa hai cambiato in ciascun file, e
       quale riga del controllo o degli appunti lo chiedeva.
       </format>

       <constraints>
       Cambia soltanto il CLAUDE.md, .claude/rules/ e
       .claude/settings.json. In settings.json aggiungi le regole deny e
       lascia com'è tutto il resto, l'hook compreso.
       </constraints>

       <verification_result>
       Il confronto delle versioni …
       </verification_result>

   <!-- /prompt 2 -->

   `.claude/` è una cartella protetta: quando Claude ci scrive, Claude Code vi
   chiede di approvare. Rispondete «Yes, and allow Claude to edit files in this
   project's .claude folder for this session»
   (https://code.claude.com/docs/en/permission-modes), dopo aver letto la
   modifica. Se vi chiede di approvare un comando, leggete anche quello: la
   modifica può stare nel comando.

5. Le prove della seconda versione, e la verifica. Dalla cartella
   `esercitazioni`:

       tools/prova_contesto.sh M6-E03 v2
       tools/verifica.sh M6-E03

   Il confronto ora dice anche v2 contro v1. Che cosa è cambiato fra le due
   versioni:

       cd ~/corso-claude-code/M6-E03/prove-contesto
       diff -rN v1/fotografia v2/fotografia
       cd -

6. Chi finisce prima: la regola si carica quando serve. In una sessione nuova
   chiedete a Claude di leggere un file del generatore, per esempio
   `progetti/rete/generatore/topologia.py`, poi guardate l'ultima riga di
   `.claude/caricamenti.jsonl`: il motivo è `path_glob_match`, e il file che
   l'ha fatta caricare è quello. Oppure scrivete in `CLAUDE.local.md` la
   preferenza personale degli appunti.

## Che cosa osservare

### Che cosa dice Anthropic

- **Cominciare senza.** «We recommend starting a project without a CLAUDE.md
  file so you can see where you constantly have to course-correct the model.»
  (https://academy.claude.com/courses/claude-code-101/the-claude-md-file). Per
  questo la prima prova è `base`.
- **Che cosa scriverci.** «Only write down what Claude can't find by reading
  the repo, or what it would otherwise spend time rediscovering every session.»
  (https://code.claude.com/docs/en/best-practices). È un confronto, e si decide
  confrontando: per ogni criterio `base` contro `v1`, con le parole
  «confermata», «non distinguibile», «non confermata in questa misura».
- **Le due domande.** Prima di scrivere una riga: «Could it find this by
  reading the code?» e «Would it actually go and look?», e «If both are yes,
  leave it out.» (stessa pagina). La prova `base` risponde alla seconda: che
  cosa Claude è andato a cercare lo dice la trascrizione.
- **Ciò che il repository non ha.** Fra gli esempi della pagina: «A decision
  your team made in a meeting» (stessa pagina). Negli appunti ce n'è una.
- **I comandi.** Nel CLAUDE.md va «How to confirm work in this repo: the exact
  test, typecheck, and lint commands, and how to run a single test file»
  (stessa pagina); qui i comandi sono i due controlli del progetto.
- **Il formato.** «Structure: group related instructions under markdown
  headers and bullets. Organized sections are easier for Claude to follow than
  dense paragraphs.» (https://code.claude.com/docs/en/memory). E le dimensioni:
  «target under 200 lines per CLAUDE.md file. Longer files consume more context
  and reduce adherence.» (stessa pagina); l'Academy dice «Keep it under a page,
  because Claude reads all of it at the start of a session»
  (https://academy.claude.com/courses/ai-native-sdlc-playbook/claude-md).
- **Che cosa costa.** «Your CLAUDE.md file loads into the context at the start
  of every session, so each line in it is part of what every turn resends.»
  (https://claude.dev/blog/what-a-task-costs-on-opus-5-5/), e «every line in it
  takes a little of Claude's attention on every task, whether it's relevant or
  not.» (https://code.claude.com/docs/en/best-practices). Per questo r3 non
  c'entra con il CLAUDE.md: i token della sua prima chiamata al modello,
  versione per versione, dicono quanto pesa il file su un lavoro qualunque.
- **Il file si carica all'avvio.** «CLAUDE.md and CLAUDE.local.md files in the
  directory hierarchy above the working directory are loaded at launch.»
  (https://code.claude.com/docs/en/memory). È una garanzia, e deve valere a ogni
  esecuzione: lo dice il registro dell'hook di ognuna, non la risposta.
- **Una parte del progetto, o una procedura.** «If an entry is a multi-step
  procedure or only matters for one part of the codebase, move it to a skill or
  a path-scoped rule» (stessa pagina), e «A path-scoped rule loads when Claude
  uses the Read, Write, or Edit tool on a matching file.» (stessa pagina). Ciò
  che vale dopo una modifica al generatore va in una regola con `paths:`; un
  apparato nuovo è una procedura, una skill del Modulo 5, e qui non serve.
- **Ciò che deve valere sempre.** «Claude Code (the harness) has to execute
  this. This can be a hook, a deny rule, or a managed setting.»
  (https://code.claude.com/docs/en/best-practices), perché «Settings rules are
  enforced by the client … CLAUDE.md instructions shape Claude's behavior but
  are not a hard enforcement layer.» (https://code.claude.com/docs/en/memory).
  Per i file generati, una regola `deny`: «Edit rules apply to all built-in
  tools that edit files.» (https://code.claude.com/docs/en/permissions), e la
  barra iniziale ancora il percorso allo spazio di lavoro: «`/path` | Path
  relative to the settings source | `Edit(/src/**/*.ts)` | `<primary working
  directory>/src/**/*.ts` in project settings» (stessa pagina). Il generatore
  invece riscrive quei file con un comando, e la regola non lo ferma: «They
  don’t apply … to arbitrary subprocesses that read or write files indirectly,
  like a Python or Node script that opens files itself.» (stessa pagina).
- **Una preferenza vostra.** «For private per-project preferences that
  shouldn't be checked into version control, create a CLAUDE.local.md at the
  project root.» (https://code.claude.com/docs/en/memory).

### Che cosa guardare

- **La prova senza CLAUDE.md:** che cosa ha trovato Claude da solo? I due
  controlli del README, la forma dei commit degli appunti, la riga `Rif:`? Lo
  dicono i criteri, e i comandi che ha lanciato sono nella trascrizione,
  `prove-contesto/base/r1/stream.jsonl`. Il README del progetto nomina uno
  script di test, `tests/test_progetti_rete.sh`, e un README del repository
  del corso, `../README.md`, che nello spazio di lavoro non ci sono: se Claude
  dice che mancano, è così, e nel CLAUDE.md non va.
- **Turni e token:** sotto ogni richiesta, per ogni versione, la riga «prima
  richiesta … token · … turni · … s · … token»: il primo numero è il contesto
  della prima chiamata al modello, l'ultimo i token di tutta la sessione. Una
  riga del CLAUDE.md che fa risparmiare la ricerca si vede lì, anche quando il
  criterio era già sì.
- **r3:** i token della prima chiamata al modello in `base`, `v1` e `v2`. La
  differenza è il peso del CLAUDE.md su una richiesta che non lo riguarda.
- **Il registro dell'hook:** `prove-contesto/v1/r1/caricamenti.jsonl`, una riga
  per file caricato, con `load_reason`. Nella sessione del passo 6, quella
  della regola: `path_glob_match`.
- **Che cosa è cambiato fra v1 e v2:** `diff -rN` delle due fotografie.

### Che cosa misura il controllo

`tools/prova_contesto.sh` lascia, per ogni versione e richiesta, la
trascrizione (`stream.jsonl`), i file cambiati, i commit, il diff e il registro
dell'hook; `verifica.py` li rilegge ogni volta da capo. Per ogni richiesta
stampa i criteri, versione per versione, con il dettaglio, e i confronti:

- **r1:** «genera.py --check ha girato» e «genera.py --canone ha girato», con il
  riepilogo che il controllo ha stampato; «l'esito di ogni controllo nella
  risposta», cioè la cifra di quel riepilogo nella risposta finale, per ogni
  controllo che ha girato; «nessun file cambiato».
- **r2:** «il refuso corretto», la riga del refuso tolta e quella giusta
  rimessa; «un commit»; «il soggetto nella forma del team di rete»,
  `rete(<ambito>): <descrizione>`, e «la riga «Rif: NOC-0»» nel messaggio, che
  stanno soltanto negli appunti; «cambiato soltanto checklist-audit.md»;
  «configurazioni/ e log/ intatti».
- **r3:** «una risposta», con le sue righe; e per tutte e tre i token della
  prima chiamata al modello, i turni, i secondi e i token di tutta
  l'esecuzione.

I criteri e i confronti sono dati, e non decidono il codice d'uscita: una sola
esecuzione per versione è un campione, e un «non distinguibile» non dice che il
file non serve. Decide il codice d'uscita soltanto la garanzia: in `base`
nessun file di istruzioni del progetto si carica, in `v1` e in `v2` il
CLAUDE.md della radice si carica all'avvio, in ogni esecuzione; se non regge,
una riga `GARANZIA` e il codice d'uscita 1.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet,
effort low per le prove e medium per scrivere, `_docente/live.sh`
sull'account del docente, una sola esecuzione per richiesta e versione), come
le stampa il controllo:

- **Ciò che il repository non dice.** In r2, «la riga «Rif: NOC-0»: base no
  (nessuna riga «Rif:» nel messaggio); v1 sì (Rif: NOC-0); v2 sì (Rif:
  NOC-0)», e «il soggetto nella forma del team di rete: base no («Correggi
  refuso in AUD-02 (disattivati)»); v1 sì («rete(audit): corregge il refuso
  nello standard di AUD-02»)». Il confronto: «il soggetto nella forma del team
  di rete: confermata; la riga «Rif: NOC-0»: confermata». Tutte e due le cose
  stanno soltanto negli appunti.
- **Ciò che Claude ha trovato da solo.** In r1, «genera.py --check ha girato:
  base sì (genera.py --check: 65 file identici)» e «genera.py --canone ha
  girato: base sì (genera.py --canone: 83 file conformi)»: «non distinguibile»
  con la v1 e con la v2. La riga dei due controlli è rimasta per ciò che
  costava trovarli: «base: prima richiesta 6420 token · 4 turni · 15 s · 50441
  token» contro «v1: prima richiesta 6892 token · 3 turni · 9 s · 14303 token».
- **Il peso del file.** In r3, «base: prima richiesta 4877 token», «v1: prima
  richiesta 5351 token» e «v2: prima richiesta 5352 token»: la v1, «v1:
  CLAUDE.md, 14 righe», pesa 474 token su una richiesta che non la riguarda.
- **La garanzia.** «Garanzia, base: nessun file di istruzioni caricato in 3 su
  3 esecuzioni», «Garanzia, v1: CLAUDE.md caricato all'avvio in 3 su 3
  esecuzioni», e così la v2.
- **La seconda versione.** «v2: CLAUDE.md, 14 righe»: il CLAUDE.md della v2 è
  quello della v1. Nella sua fotografia c'è in più la regola
  `.claude/rules/generatore.md`, con `paths:`, e `.claude/settings.json` ha le
  regole deny per `configurazioni/`, `log/`, `inventario.csv` e `allarmi.csv`.
  v2 contro v1 è «non distinguibile» in ogni criterio: le tre richieste non
  leggono il generatore e non toccano i file generati. La regola si vede al
  passo 6.

Una sola esecuzione per richiesta e versione è un campione: queste righe dicono
che cosa è successo lì, non che cosa succede sempre.

## Verifica (tools/verifica.sh M6-E03)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M6-E03

Esce con 0 se il lavoro è fatto: le tre versioni hanno girato con le tre
richieste, ogni sessione è finita bene, la v1 e la v2 hanno un CLAUDE.md alla
radice, la v2 è diversa dalla v1, e la garanzia regge in ogni esecuzione. Con 1
se qualcosa manca (righe `MANCA`) o la garanzia non regge (righe `GARANZIA`).
Con 2 se non può decidere, per esempio se uno stream non si legge. Non dice se
il CLAUDE.md è buono: quello lo dite voi, leggendo i criteri e i confronti.

## Se qualcosa va storto

- `tools/prova_contesto.sh` dice che nello spazio di lavoro manca l'hook: senza,
  le prove non dicono che cosa si è caricato. Rimettete `.claude/settings.json`
  e `.claude/hooks/registra_caricamenti.py` come sono nella cartella
  `esercizio/` dell'elemento, con le vostre regole `deny` in più, e riprovate.
- Dice che una versione «c'è già»: un giro non si sovrascrive. Per rifarlo
  cancellate la cartella che il messaggio nomina e rilanciate.
- Dice che «c'è già un giro di prove in corso»: aspettate che finisca. Se non
  ne gira nessuno, il messaggio dice quale cartella cancellare.
- `FALLITA r1`, o un'altra richiesta: la sessione non ha un risultato; il motivo
  è in `prove-contesto/<versione>/<richiesta>/stderr.txt`. Rifate il giro.
- r1 dice che un controllo non ha girato anche con il comando nel CLAUDE.md:
  provatelo a mano dalla radice dello spazio di lavoro, per esempio
  `python3 progetti/rete/genera.py --check`, e guardate se il comando del file
  è scritto così.
- Claude dice che `tests/test_progetti_rete.sh` o `../README.md` non ci sono:
  il README del progetto li nomina, ma stanno nel repository del corso, non
  nello spazio di lavoro. È così, e nel CLAUDE.md non va.
- La sessione si chiude appena aperta: alla domanda di fiducia il cursore parte
  da «No, exit». Riaprite e scegliete «Yes, I trust this folder».
- `/context all` non mostra il CLAUDE.md: l'avete chiesto nella sessione dove il
  file è nato. «The new content loads on the next /clear, /compact, or
  restart.» (https://code.claude.com/docs/en/prompt-caching): usate il comando
  del passo 2, che apre una sessione nuova.
- Claude non riesce a scrivere in `.claude/`: è la cartella protetta, e la
  risposta giusta è quella del passo 4. Se avete già risposto no, chiedetegli di
  riprovare.
- Una riga `GARANZIA`: un file di istruzioni si è caricato in `base`, o il
  CLAUDE.md non si è caricato in una prova della v1 o della v2. È un esito da
  segnalare al docente, con la cartella della prova.
- `tools/prova_contesto.sh M6-E03 v1` dice che «v1 non ha un CLAUDE.md alla
  radice»: scrivetelo alla radice dello spazio di lavoro, come al passo 2, e
  rilanciate; nessuna prova è partita.
- `tools/prova_contesto.sh M6-E03 v2` dice «v2 è uguale a v1»: fra le due
  prove i file di istruzioni non sono cambiati, e nessuna prova è partita.
  Cambiateli e rilanciate. Se è la verifica a dire `MANCA v2 è uguale a v1`,
  cancellate prima `prove-contesto/v2`.
- `claude: command not found`, o un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M6-E03`.

## Impronta d'uso sul piano Pro

Scrivere il file: Sonnet, effort medium, `/init` e due prompt in una sessione,
nessun subagent. Le prove: nove chiamate, tre per versione, Sonnet, effort low,
nessun subagent. Il controllo e la verifica non chiamano il modello.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet,
`_docente/live.sh` in `claude -p` sull'account del docente, un piano Max),
dodici chiamate, ognuna di un segmento solo:

- le nove di prova, effort low: 34 turni del modello, 72,8 secondi, 228.504
  token, da 2 a 7 turni a chiamata; l'84,6 % dei token è contesto letto dalla
  cache;
- le tre di scrittura, effort medium: `/init` 5 turni, 25,6 secondi, 143.368
  token; il prompt 1 2 turni, 14,8 secondi, 78.677 token; il seguito 5 turni,
  19,2 secondi, 175.583 token. Il prompt 1 e il seguito riprendono la sessione
  con `--resume`, e lì `modelUsage` conta anche i passi di prima: le cifre sono
  la differenza, come le stampa `_docente/live.sh`.

In tutto 46 turni, 132,4 secondi e 626.132 token.

Il corso fissa Sonnet anche se su Pro il modello predefinito di Claude Code è un
altro: «Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus
5.5» (https://code.claude.com/docs/en/model-config), e «Sonnet handles most
coding tasks well and costs less than Opus.»
(https://code.claude.com/docs/en/costs). I limiti sono gli stessi di claude.ai:
«These limits are shared across Claude and Claude Code, meaning all activity in
both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan).
I token sono quelli di `modelUsage`: «Use modelUsage, or model_usage in Python,
for whole-tree token accounting; the usage field undercounts as soon as nesting
occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking). Dicono
quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano
occupa: `/usage` lo mostra, «On Pro, Max, Ultra, Team, and Enterprise it
breaks your usage down by skill, subagent, plugin, and MCP server.»
(https://code.claude.com/docs/en/best-practices).

## Per approfondire

- «How Claude remembers your project», il CLAUDE.md, le regole e la memoria:
  https://code.claude.com/docs/en/memory
- «Best practices for Claude Code», che cosa scriverci e che cosa no:
  https://code.claude.com/docs/en/best-practices
- «The CLAUDE.md file», la lezione di «Claude Code 101» dell'Academy:
  https://academy.claude.com/courses/claude-code-101/the-claude-md-file
- «A CLAUDE.md that follows», la lezione di «Claude Code in action»:
  https://academy.claude.com/courses/claude-code-in-action/a-claude-md-that-follows
- «The CLAUDE.md file», il video del canale Claude:
  https://www.youtube.com/watch?v=O0FGCxkHM-U
- Le regole di permesso e i loro percorsi:
  https://code.claude.com/docs/en/permissions
- Il modello del corso, `riferimenti/template-CLAUDE.md`, con le indicazioni in
  commenti che non costano niente.
