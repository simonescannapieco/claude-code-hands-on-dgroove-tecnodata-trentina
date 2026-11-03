# M5-E02 — Una skill di revisione contro le convenzioni del team

Laboratorio del Modulo 5, traccia (a), sul gestionale in PHP di CiaspoLink,
l'operatore inventato del corso: una skill che rivede un pull request contro le
convenzioni numerate del team, provata come il codice, con tre casi di prova,
una baseline senza la skill e due iterazioni. Le altre due tracce sono M5-E03,
la risposta nel tono di voce dell'assistenza, e M5-E04, l'audit delle
configurazioni.

## Obiettivo

Il team del gestionale ha le sue regole scritte,
`progetti/gestionale-php/docs/convenzioni.md`, e chi rivede un pull request cita
il numero di quella che non è rispettata. Qui portate Claude da una revisione
generica a quella del team, con un metodo: si guarda che cosa fa senza la skill;
si scrive una prima versione, adattando la skill di esempio `revisione-pr` o
riempiendo il modello; si prova su tre pull request più difficili di quello
della demo M5-D04, ognuno in una sessione nuova; si legge, si cambia e si
riprova.

Alla fine avete:

- `.claude/skills/revisione-pr/`, la skill, in due versioni diverse;
- `revisione-pr-workspace/`, le due iterazioni, con le risposte, i voti e i
  conteggi;
- `revisione-pr-workspace/iteration-1/feedback.json`, i vostri commenti.

Mettete alla prova ciò che Anthropic dice di come si prova una skill, e di che
cosa cambia con una skill.

## Tempo

70 minuti: 10 per la baseline, 20 per adattare la skill, 10 per le prove della
prima versione, 20 per l'iterazione, 10 per la seconda versione e la verifica.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3.8 o successivo, il comando `python3`, e git: li usano le prove e la
  verifica.
- Niente PHP né Docker: la revisione legge il codice, non lo esegue.

## Punto di partenza (tools/prepara_esercizio.sh M5-E02)

Lo spazio di lavoro `~/corso-claude-code/M5-E02/`, un repository git con un
primo commit, con:

- `progetti/gestionale-php/`: il gestionale, con `docs/convenzioni.md`;
- `.claude/skills/revisione-pr/evals/`, senza ancora uno `SKILL.md`:
  `evals.json`, i tre casi di prova con le loro asserzioni, e
  `eval_queries.json`, una richiesta che non deve attivare la skill. Prima le
  prove, come chiede Anthropic: «Create evaluations BEFORE writing extensive
  documentation.»
  (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices),
  e nel posto che dice la guida dello standard Agent Skills: «Store test cases
  in evals/evals.json inside your skill directory»
  (https://agentskills.io/skill-creation/evaluating-skills);
- `controlla_skill.py` e `lib_leggi_frontmatter.py`: il controllo del file, lo
  stesso di `tools/controlla_skill.py`. Dice se il file segue le regole che si
  leggono dai file, non se la skill funziona;
- `.gitignore`: tiene fuori da git `revisione-pr-workspace/`, dove restano le
  prove;
- `.claude/settings.json`: le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e tre regole `deny`, `Edit(/controlla_skill.py)`,
  `Edit(/lib_leggi_frontmatter.py)` e
  `Edit(/.claude/skills/revisione-pr/evals/**)`: Claude cambia la skill, non il
  controllo né i casi di prova. Le regole valgono per i suoi strumenti di file,
  «Edit rules apply to all built-in tools that edit files.»
  (https://code.claude.com/docs/en/permissions), non per uno script: vedi «Se
  qualcosa va storto». La barra iniziale ancora il percorso allo spazio di lavoro:
  «`/path` | Path relative to the settings source | `Edit(/src/**/*.ts)` |
  `<primary working directory>/src/**/*.ts` in project settings» (stessa pagina).

I tre pull request non stanno nello spazio di lavoro. `tools/prove_skill.sh` crea
in ogni copia il ramo del suo caso e vi applica una patch: nella sessione si
vedono soltanto come differenza fra il ramo e `main`.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro:

       tools/prepara_esercizio.sh M5-E02

2. La baseline: che cosa fa Claude senza la skill. Sempre dalla cartella
   `esercitazioni`:

       tools/prove_skill.sh M5-E02 1 without

   Tre esecuzioni, una per caso, al massimo tre insieme. È il primo passo del
   metodo di Anthropic: «Run Claude on representative tasks without a Skill. …
   Build three scenarios that test these gaps. … Measure Claude's performance
   without the Skill.»
   (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
   La guida dello standard dice come: «Start with 2-3 test cases.», «Include at
   least one prompt that tests a boundary condition», qui il secondo, dove ciò
   che non va sta in ciò che manca; e «run each test case twice: once with the
   skill and once without it (or with a previous version)»; «Each pass through
   the full eval loop gets its own iteration-N/ directory.»; «Each eval run
   should start with a clean context — no leftover state from previous runs or
   from the skill development process.»
   (https://agentskills.io/skill-creation/evaluating-skills). Per questo ogni
   esecuzione è una sessione nuova di `claude -p`, in una copia pulita dello
   spazio di lavoro, senza `evals/` e senza la skill.

   Aprite le tre risposte, in
   `~/corso-claude-code/M5-E02/revisione-pr-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md`,
   e così `eval-2` e `eval-3`. Che cosa dà una revisione generica? Cita i numeri
   delle regole? Dice il file e la riga? Chiude con un esito?

   Le asserzioni stanno già in `evals.json`, perché uno script le possa
   decidere. La guida dice un'altra cosa: «Add them after you see your first
   round of outputs». Aggiungete le vostre adesso, a mano, nell'elenco
   `assertions` di un caso: restano «da valutare a mano», fuori dai conteggi. La
   guida spiega perché certe cose è meglio così: «Reserve assertions for things
   that can be checked objectively.», e lo stile o l'impressione «are hard to
   decompose into pass/fail checks. These are better caught during human
   review.»

3. La skill. Dalla cartella `esercitazioni` copiate l'esempio, o il modello con
   `copia modello`; poi, in un altro terminale, entrate nello spazio di lavoro e
   aprite Claude Code, su Sonnet con effort medium:

       tools/prove_skill.sh M5-E02 copia esempio

       cd ~/corso-claude-code/M5-E02
       claude --model sonnet --effort medium

   Alla prima apertura vi chiede se vi fidate della cartella: «In an interactive
   session, Claude Code shows the workspace trust dialog when you start it in a
   folder you haven't trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì, poi incollate:

   <!-- prompt 1 -->

       <role>
       Sei uno sviluppatore del gestionale di CiaspoLink e adatti una skill di
       Claude Code per i colleghi che chiedono una revisione.
       </role>

       <context>
       La skill in .claude/skills/revisione-pr/ viene da un esempio del corso,
       o dal suo modello, e deve far valere le convenzioni del team, in
       progetti/gestionale-php/docs/convenzioni.md: chi la usa legge la
       revisione e corregge il codice riga per riga. Come ha risposto Claude
       senza la skill è in
       revisione-pr-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md,
       e così in eval-2 e in eval-3; ciò che ci si aspetta è nei campi
       expected_output di .claude/skills/revisione-pr/evals/evals.json.
       </context>

       <instructions>
       1. Leggi il SKILL.md della skill e, se ci sono, i file della sua
          cartella references/.
       2. Leggi le tre risposte senza la skill e i campi expected_output, e
          annota che cosa manca alle risposte.
       3. Cambia la description e il corpo della skill per ciò che manca.
       4. Esegui da solo questo comando, e correggi finché dice 0 errori:
          python3 -B -I controlla_skill.py .claude/skills/revisione-pr
       </instructions>

       <format>
       Al massimo cinque righe: che cosa hai cambiato e perché.
       </format>

       <constraints>
       Cambia soltanto i file sotto .claude/skills/revisione-pr/, evals/
       escluso. Tieni il SKILL.md nella forma dello standard Agent Skills,
       frontmatter e Markdown semplice, con titoli, elenchi, tabelle e blocchi
       di codice, sotto le 500 righe. Scrivi ciò che vale per qualunque pull
       request del gestionale.
       </constraints>

   <!-- /prompt 1 -->

   `.claude/` è una cartella protetta: quando Claude ci scrive con i suoi strumenti
   di file, Claude Code vi chiede di approvare la scrittura. Rispondete «Yes, and
   allow Claude to edit files in this project's .claude folder for this session»
   (https://code.claude.com/docs/en/permission-modes), dopo aver letto la modifica.
   Claude può anche cambiare la skill con un comando, invece che con Edit: in una
   sessione del corso su questo prompt (Claude Code 2.1.317) l'ha fatto con uno
   script Python dentro un comando Bash, e Claude Code ha chiesto di approvare ogni
   comando: «This command requires approval». Allora la modifica sta nel comando:
   leggete ogni comando prima di approvarlo, anche quello del controllo. Questo
   prompt fa ciò che dice la guida: «Effective skills are grounded in real
   expertise. The key is feeding domain-specific context into the creation
   process.», e fra i materiali da cui
   partire «Internal documentation, runbooks, and style guides», per poi «Then
   extract the reusable pattern into a skill.»
   (https://agentskills.io/skill-creation/best-practices). E fa ciò che dice
   Anthropic: «Write minimal instructions: Create just enough content to address
   the gaps and pass evaluations.»
   (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
   Lasciate aperta la sessione: serve al passo 5.

4. Le prove della prima versione. Dalla cartella `esercitazioni`:

       tools/prove_skill.sh M5-E02 1 with

   Quattro esecuzioni: i tre casi e la richiesta che non deve attivare la skill.
   Leggete la tabella (sotto, «Che cosa misura il controllo»), le risposte in
   `iteration-1/eval-*/with_skill/outputs/risposta.md` e i voti in
   `grading.json`. Poi scrivete i vostri commenti: «Record specific feedback for
   each test case and save it in the workspace»
   (https://agentskills.io/skill-creation/evaluating-skills), una riga per ogni
   `eval-<id>`, in
   `~/corso-claude-code/M5-E02/revisione-pr-workspace/iteration-1/feedback.json`:

       {
         "eval-1": "Elenca le regole, ma due righe non dicono in quale file.",
         "eval-2": "",
         "eval-3": "Dice di non unire il ramo, non che cosa spostare in src/."
       }

   La forma è quella della guida: «"The chart is missing axis labels" is
   actionable; "looks bad" is not.», e «Empty feedback means the output looked
   fine»: la stringa vuota dice che avete letto, e andava bene.

5. L'iterazione. Nella stessa sessione del passo 3 incollate:

   <!-- prompt 2 -->

       <context>
       La prima versione della skill è stata provata, e i risultati sono in
       revisione-pr-workspace/iteration-1/. I segnali sono tre: le asserzioni
       non passate, in eval-1/with_skill/grading.json e così per eval-2 e
       eval-3; i commenti di chi ha letto le risposte, in feedback.json; le
       trascrizioni, in eval-1/with_skill/outputs/stream.jsonl e così per gli
       altri due.
       </context>

       <instructions>
       1. Leggi i tre grading.json, feedback.json e il SKILL.md di
          .claude/skills/revisione-pr/.
       2. Per ogni asserzione non passata e per ogni commento, cerca nella
          trascrizione di quel caso, a pezzi con grep, che cosa Claude ha
          letto e che cosa ha saltato.
       3. Cambia la skill per le cause che hai trovato.
       4. Esegui da solo questo comando, e correggi finché dice 0 errori:
          python3 -B -I controlla_skill.py .claude/skills/revisione-pr
       </instructions>

       <format>
       Al massimo cinque righe: che cosa hai cambiato, e quale segnale lo
       chiedeva.
       </format>

       <constraints>
       Generalizza dai commenti: la skill serve per ogni pull request, non per
       questi tre. Tieni la skill snella: togli le istruzioni che le
       trascrizioni mostrano inutili. Spiega il perché di ogni istruzione.
       Raccogli in scripts/ il lavoro che ogni esecuzione rifà da capo. Cambia
       soltanto i file sotto .claude/skills/revisione-pr/, evals/ escluso.
       </constraints>

   <!-- /prompt 2 -->

   I tre segnali e le quattro linee guida sono quelli della guida: «give all
   three — along with the current SKILL.md — to an LLM and ask it to propose
   changes», «Generalize from feedback. … Keep the skill lean. … Explain the
   why. … Bundle repeated work.»
   (https://agentskills.io/skill-creation/evaluating-skills). E le buone pratiche
   dello standard: «Read agent execution traces, not just final outputs.», e
   «When an agent makes a mistake you have to correct, add the correction to the
   gotchas section.» (https://agentskills.io/skill-creation/best-practices).
   Leggete la modifica, o il comando che la fa, prima di approvarla: un'istruzione
   che nomina una riga di questi tre pull request non serve al prossimo.

6. La seconda versione. Dalla cartella `esercitazioni`:

       tools/prove_skill.sh M5-E02 2 with
       tools/verifica.sh M5-E02

   «Rerun all test cases in a new iteration-<N+1>/ directory.», e «When improving
   an existing skill, use the previous version as your baseline. Snapshot it
   before editing» (https://agentskills.io/skill-creation/evaluating-skills). Due
   differenze dalla guida, e sono scelte del corso. `old_skill`, la baseline della
   seconda iterazione, riusa le esecuzioni dell'iterazione 1, dove la guida le
   rifà: si risparmia la quota del piano. E `iteration-N/skill-snapshot/` è una
   per iterazione, dove la guida ne ha una sola nella cartella delle prove: così
   ogni coppia di versioni si confronta. Che cosa è cambiato:

       cd ~/corso-claude-code/M5-E02/revisione-pr-workspace
       diff -r iteration-1/skill-snapshot iteration-2/skill-snapshot
       cd -

7. Chi finisce prima: una terza iterazione, cambiando ancora la skill e dando
   `tools/prove_skill.sh M5-E02 3 with`, oppure il caricamento su claude.ai di
   M5-D05.

## Che cosa osservare

### Che cosa dice Anthropic

- **Due misure separate.** «measure separately whether Claude invokes it on the
  prompts it should, and whether the output matches what you expect when it
  does.» (https://code.claude.com/docs/en/skills). La tabella le tiene separate:
  «Skill chiamata» e le asserzioni.
- **Con la skill e senza, in una sessione nuova.** «Collect a few realistic
  prompts, run each one in a fresh session with the skill available and again
  with it turned off», e «A fresh session matters because leftover context from
  authoring the skill will mask gaps in the written instructions.» (stessa
  pagina). Per questo le prove non girano nella sessione del passo 3, dove la
  skill è stata scritta.
- **Che cosa cambia con una skill.** Le skill sono risorse che «turn a
  general-purpose agent into a specialist»
  (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
  È un confronto, e si decide confrontando: per ogni caso le regole citate con la
  skill e senza, con le parole «confermata», «non distinguibile», «non confermata
  in questa misura». Una sola esecuzione per caso è un campione: la tabella lo
  scrive accanto a ogni confronto.
- **Iterare.** «Iterate: Run evaluations, compare against baseline, and refine.»
  (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
- **La richiesta che non deve attivarla.** «The most valuable negative test
  cases are near-misses — queries that share keywords or concepts with your skill
  but actually need something different.» E una sola esecuzione non basta a dirlo:
  «Model behavior is nondeterministic — the same query might trigger the skill on
  one run but not the next.»
  (https://agentskills.io/skill-creation/optimizing-descriptions).
- **Ciò che c'è già senza la skill.** Senza `revisione-pr`, Claude può scegliere
  da sé `/code-review`, come è successo nel primo caso della registrazione del
  corso, qui sotto: «/code-review is a bundled skill: its instructions are built into
  Claude Code, so there is no SKILL.md file on disk to open or edit.»;
  «The command works on any plan. The review runs in your own session, so it
  counts toward your plan's usage or API billing»
  (https://code.claude.com/docs/en/code-review-local). È ciò che avete senza una
  skill vostra, e la tabella lo stampa come dato: `Skill chiamata: no (altre:
  code-review)`. Le regole del progetto gli arrivano da un'altra parte: «To give
  every review project rules to follow, add them to your CLAUDE.md.», e «the
  review follows your CLAUDE.md, including in a non-interactive -p run. It
  doesn't read REVIEW.md.» (stessa pagina); qui non c'è un `CLAUDE.md`. Dal
  changelog: «Changed /code-review at medium effort to also report cleanup and
  CLAUDE.md conventions findings on models without tuned review settings,
  including Opus 5.5 and Sonnet 5.5»
  (https://code.claude.com/docs/en/changelog). La skill di questa traccia non si
  chiama `code-review`: «a project or personal skill named code-review runs in
  place of the bundled one, and the /review alias keeps running the bundled
  review.» (https://code.claude.com/docs/en/code-review-local). Scriverne una è
  una strada che la pagina indica: «Build your own reviewer: write a reviewer
  subagent or a review skill» (stessa pagina). Delle skill per la qualità del codice
  e la revisione, un articolo di Anthropic dice: «These can include deterministic
  scripts or tools for maximum robustness. … code-style — enforces code style,
  especially styles that Claude does not do well by default.»
  (https://claude.dev/blog/lessons-from-building-claude-code-how-we-use-skills/).

### Che cosa guardare

- **La baseline:** quante regole cita da sola? Legge `docs/convenzioni.md`, o
  rivede secondo il suo giudizio? Lo dice la trascrizione, `outputs/stream.jsonl`.
- **La skill:** scatta sulle tre richieste, anche su quella che non nomina il pull
  request? E sulla near-miss?
- **Le asserzioni che passano con la skill e non senza:** «Study assertions that
  pass with the skill but fail without. This is where the skill is clearly adding
  value.» (https://agentskills.io/skill-creation/evaluating-skills).
- **Ciò che costa:** «The delta tells you what the skill costs (more time, more
  tokens) and what it buys (higher pass rate).», e all'inizio basta poco: «In
  early iterations with just 2-3 test cases and single runs, focus on the raw pass
  counts and the delta» (stessa pagina).
- **Il modello della tabella**, nello `SKILL.md` dell'esempio: «This is more reliable
  than describing the format in prose, because agents pattern-match well against
  concrete structures.» (https://agentskills.io/skill-creation/best-practices). Se
  lo togliete, che cosa succede al file e alla riga?

### Che cosa misura il controllo

`grading.json`, `timing.json` e `benchmark.json` hanno la forma della guida: «The
other JSON files (grading.json, timing.json, benchmark.json) are produced during
the eval process — by the agent, by scripts, or by you.»; qui da uno script, che li
ricalcola dagli stream ogni volta e non li rilegge: «use a verification script —
scripts are more reliable than LLM judgment for mechanical checks», e valutare
vuol dire «recording PASS or FAIL with specific evidence»: «Require concrete
evidence for a PASS. Don't give the benefit of the doubt.»
(https://agentskills.io/skill-creation/evaluating-skills).

Le quattro asserzioni di ogni caso:

- **«Cita con il numero tutte le regole violate inserite apposta nel pull
  request».** I numeri nel testo finale, interi: `7.1` non vale per `17.1` né per
  `7.10`. Il controllo li confronta per impronta con `verita.json`, che non li
  contiene in chiaro; dopo la prova dice quanti e quali mancano, perché i numeri
  delle regole sono pubblici. Le altre regole citate sono un dato: una revisione
  può trovare anche ciò che non è stato inserito apposta.
- **«Indica il file e la riga di ogni rilievo».** Per ogni regola inserita apposta
  che la risposta cita, una riga con quel numero, un percorso (del pull request o
  del progetto, anche senza `progetti/gestionale-php/`) e un numero di riga:
  `| 7.1 | src/x.php | 42 |`, `src/x.php:42`, `riga 42`. Tutto sulla stessa riga,
  come nel modello della skill di esempio. Non lo chiede alle regole che non hanno
  un posto in un file: la sezione 1, 3.6 (il nome di uno script), 9.2, 9.3, 10.2,
  10.5 e 11.1–11.4 (il pull request nel suo insieme, o ciò che manca). Una regola
  nominata soltanto nel discorso, come «la 5.2 è rispettata», non è un rilievo: il
  controllo la stampa come dato.
- **«Chiude con un esito: approvabile o da modificare».** Una delle due parole
  nelle ultime cinque righe.
- **«Non modifica alcun file».** `outputs/file-cambiati.txt` vuoto. Nella
  registrazione del corso, in `dontAsk`, con Read e Skill consentiti, senza Edit né
  Write, è passata in tutte le esecuzioni delle due configurazioni, e la tabella lo
  dice: «Passano sempre in entrambe le configurazioni». Sta qui proprio per questo.
  La guida dice che farne: «Remove or replace assertions that always pass in both
  configurations.»: quando le prove saranno vostre, è la prima da togliere o da
  sostituire. È ciò che si è visto lì, non una garanzia: Claude ha anche lanciato
  comandi Bash, e una skill può concedersene altri con `allowed-tools`.

La tabella stampa, per ogni caso e configurazione, se la skill è stata chiamata, le
asserzioni passate, turni, token e secondi; poi la near-miss, i conteggi e il
delta. Dopo la tabella, come dati, mai come uscita: la skill chiamata n su 3, le
altre skill che Claude ha scelto da sé, le regole inserite citate per ogni pull
request e il confronto. Una garanzia invece deve reggere a ogni esecuzione, e
se non regge è un reperto, con l'uscita 1: senza la skill, nessuna chiamata riuscita
a `revisione-pr` e `revisione-pr` non fra le skill disponibili; con la skill, la
skill nell'elenco e la sua chiamata né negata dal permesso né respinta dallo
strumento.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet, effort
low per le prove e medium per scrivere, `_docente/live.sh` sull'account del docente,
una sola esecuzione per caso, partendo dalla skill di esempio), come le stampa il
controllo:

- **La prima versione contro la baseline.** «with_skill 3, without_skill 2 asserzioni
  passate: confermata (una sola esecuzione per caso)» nei primi due casi, «with_skill
  4, without_skill 1 asserzione passata: confermata (una sola esecuzione per caso)»
  nel terzo. «Conteggi: without_skill 5 su 12; with_skill 10 su 12». «Delta, with_skill
  meno without_skill: pass rate +0,417; tempo +5,9 s; token +23957».
- **La seconda versione contro la prima.** «with_skill 4, old_skill 3 asserzioni
  passate: confermata (una sola esecuzione per caso)» nei primi due casi, «with_skill
  4, old_skill 4 asserzioni passate: non distinguibile (una sola esecuzione per caso)»
  nel terzo. «Conteggi: old_skill 10 su 12; with_skill 12 su 12». «Delta, with_skill
  meno old_skill: pass rate +0,167; tempo -0,5 s; token +35096».
- **Le regole inserite citate.** «pr-1, regole inserite citate: without_skill 0 su 10;
  with_skill 9 su 10», «pr-2, regole inserite citate: without_skill 0 su 3; with_skill
  3 su 3», «pr-3, regole inserite citate: without_skill 0 su 4; with_skill 4 su 4».
  Nella seconda versione, «pr-1, regole inserite citate: old_skill 9 su 10; with_skill
  10 su 10», e gli altri due come nella prima.
- **L'invocazione, a parte.** «iterazione 1: revisione-pr chiamata 3 su 3 in
  with_skill», «iterazione 2: revisione-pr chiamata 3 su 3 in with_skill». La
  near-miss, tutte e due le volte: «Skill chiamata: no; dovrebbe attivarla: no». Senza
  la skill, nel primo caso, «Claude ha scelto da sé code-review».
- **Ciò che non distingue.** Passano sempre in entrambe le configurazioni, nella prima
  iterazione, «Non modifica alcun file»; nella seconda anche «Chiude con un esito:
  approvabile o da modificare».

Alla fine, «Fatto: la skill passa il controllo del file, le due iterazioni ci sono, i
commenti anche, e le due versioni sono diverse.» Una sola esecuzione per caso è un
campione: queste righe dicono che cosa è successo lì.

È una prova in `claude -p`, senza nessuno davanti, con due differenze dalla vostra
sessione. La skill Claude l'ha adattata in `bozza/revisione-pr/`, con il percorso dei
prompt cambiato, e `_docente/live.sh` l'ha riportata in `.claude/skills/revisione-pr/`:
nelle prove del corso, in `claude -p`, le scritture sotto `.claude/skills/` sono
negate anche con le regole, «permissions.allow rules in settings files do not
pre-approve protected-path writes»
(https://code.claude.com/docs/en/permission-modes). A voi, nel passo 3, Claude Code lo
chiede. E `feedback.json` non l'ha scritto una persona: l'ha scritto uno script, dalle
asserzioni non passate, e il file lo dice.

La skill di quella prova, in `soluzione/.claude/skills/revisione-pr/`, è il lavoro di
Claude, mostrato come l'ha lasciato: non è un modello, e non è stata riscritta. La
seconda versione si concede `allowed-tools: Bash(python3 *) Bash(git diff *)`, più
largo di ciò che le serve. «The trailing * enables prefix matching, so Bash(git diff
*) allows any command starting with git diff.»
(https://code.claude.com/docs/en/headless): `Bash(python3 *)` copre ogni comando che
comincia con `python3`, dove alla skill basta lanciare `scripts/segnala.py`. La forma
stretta è quella della skill di esempio `audit-configurazione`:
`Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py *)`. E la pagina delle
skill avverte: «A skill can grant itself broad tool access, so review the
allowed-tools of skills checked into a repository before you run Claude Code there.»
(https://code.claude.com/docs/en/skills). Anche `scripts/segnala.py` è di quella
prova: se `git` fallisce stampa «Nessuna riga aggiunta rispetto a main», come se il
pull request fosse vuoto.

## Verifica (tools/verifica.sh M5-E02)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M5-E02

Esce con 0 se il lavoro è fatto: la skill passa il controllo del file; i tre casi
hanno le loro esecuzioni, senza la skill e con le due versioni, e la near-miss le
sue due; `iteration-1/feedback.json` ha una voce per ogni caso; le due versioni
sono diverse. Con 1 se qualcosa manca (righe `MANCA`) o una garanzia non regge
(righe `REPERTO`). Con 2 se non può decidere, per esempio se uno stream non si
legge. Non dice se la skill è buona: quello lo dite voi, leggendo la tabella e le
risposte.

## Se qualcosa va storto

- `tools/prove_skill.sh` dice che manca `SKILL.md`: copiate prima l'esempio o il
  modello, passo 3.
- Dice che un'esecuzione «c'è già»: non si sovrascrive. Usate l'iterazione seguente,
  o cancellate ciò che dice il messaggio e rilanciate.
- Dice che «c'è già un giro di prove in corso»: aspettate che finisca. Se non ne
  gira nessuno, il messaggio dice quale cartella cancellare.
- Un `REPERTO` dice che la chiamata a `revisione-pr` è «negata dal permesso».
  Nelle prove del corso (Claude Code 2.1.317), in `claude -p` con `dontAsk`, una
  skill con `allowed-tools` o `disallowed-tools` nel frontmatter, che Claude invoca
  da sé, è negata finché le regole non ammettono `Skill(nome)`. Per questo
  `prove/config`, che sta nella cartella dell'elemento e non nello spazio di lavoro,
  elenca `Skill(revisione-pr)`, in tutti e due i bracci: se aggiungete `allowed-tools`
  alla skill, la chiamata passa lo stesso. Se quella riga manca, lo strumento si ferma
  prima, con l'uscita 2. Un reperto con la riga al suo posto è un esito da segnalare
  al docente, con lo stream.
- Un `REPERTO` dice che la chiamata è «respinta dallo strumento»: il corpo della skill
  non è arrivato, e il motivo è nel `tool_result`, in `outputs/stream.jsonl`.
- La risposta dice che un comando `!` non è ammesso: «Shell command permission check
  failed for pattern "..."» (https://code.claude.com/docs/en/skills). Le righe
  `` !`git diff …` `` e `` !`git log …` `` dell'esempio, nelle prove del corso,
  passano senza `allowed-tools`, perché sono comandi di sola lettura; un altro
  comando può chiedere `allowed-tools` e la sua regola.
- `Skill chiamata: no` su una richiesta: guardate la `description`. Può capitare a
  una sola esecuzione, e può non capitare alla prossima; una richiesta semplice può
  non attivarla: «A simple, one-step request like "read this PDF" may not trigger a
  PDF skill even if the description matches perfectly»
  (https://agentskills.io/skill-creation/optimizing-descriptions). Non aggiungete le
  parole esatte della richiesta: «Avoid adding specific keywords from failed queries
  — that's overfitting.» (stessa pagina).
- Claude non riesce a scrivere nella skill: `.claude/` è protetta, e la risposta
  giusta è quella del passo 3. Se avete già risposto no, chiedetegli di riprovare.
- Claude vuole cambiare `evals/` o il controllo. La regola `deny` ferma i suoi
  strumenti di file e i comandi di file che Claude Code riconosce in Bash, non uno
  script: «They don't apply to … arbitrary subprocesses that read or write files
  indirectly, like a Python or Node script that opens files itself.»
  (https://code.claude.com/docs/en/permissions). Se a farlo è un comando, rispondete
  no quando chiede l'approvazione: si cambia la skill.
- `MANCA … le due versioni della skill sono uguali`: non è cambiato niente fra le
  due iterazioni. Cambiate la skill, cancellate
  `revisione-pr-workspace/iteration-2/` e rilanciate
  `tools/prove_skill.sh M5-E02 2 with`.
- `MANCA iteration-1/feedback.json: non è JSON`: rileggetelo; le virgolette dentro un
  commento vanno scritte `\"`.
- `claude: command not found`, o un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M5-E02`.

## Impronta d'uso sul piano Pro

Scrivere la skill: Sonnet, effort medium, due prompt, nessun subagent. Le prove:
undici chiamate, tre senza la skill e quattro per ogni versione, Sonnet, effort low,
nessun subagent chiesto. `old_skill` non consuma: riusa le esecuzioni che ci sono. Il
controllo, la verifica e i pull request non chiamano il modello. Se finite prima, una
terza iterazione sono altre quattro chiamate.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet,
`_docente/live.sh` in `claude -p` sull'account del docente, un piano Max), tredici
chiamate:

- le undici di prova, effort low: «Consumo, senza le esecuzioni riusate: 7 chiamate,
  33 turni, 618208 token, 164,6 s» fino alla prima versione, baseline compresa, e
  «Consumo, senza le esecuzioni riusate: 4 chiamate, 22 turni, 470106 token, 91,2 s»
  per la seconda: 55 turni del modello, 1.088.314 token e 255,8 secondi, da 2 a 9
  turni a chiamata;
- le due di scrittura, effort medium: 16 e 15 turni del modello, 48,5 e 80,9 secondi,
  196.122 e 537.292 token. La riga che `_docente/live.sh` stampa per la seconda dice
  733.414: è una sessione ripresa con `--resume`, e lì `modelUsage` conta anche la
  sessione di prima; 537.292 è la differenza.

`total_tokens`, in `timing.json`, è quel conto: «Use modelUsage, or model_usage in
Python, for whole-tree token accounting; the usage field undercounts as soon as
nesting occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking). Conta
tutti i modelli e tutti i subagent, e di ogni richiesta l'entrata, la cache e
l'uscita: nelle undici prove l'80 % dei token è contesto letto dalla cache. Dice
quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano occupa.
Lì Claude ha fatto lavorare due subagent che nessuno aveva chiesto: quello dopo la
chiamata a `code-review`, nel primo caso senza la skill, «63896 token (usage: 35217)»,
ed Explore, nel secondo caso della seconda versione, «9 turni in 2 segmenti, 169250
token (usage: 143238)».

«Sonnet handles most coding tasks well and costs less than Opus.»
(https://code.claude.com/docs/en/costs). I limiti sono gli stessi di claude.ai:
«These limits are shared across Claude and Claude Code, meaning all activity in both
tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan).
`/usage` mostra quanto pesa ciascuna cosa: «On Pro, Max, Ultra, Team, and Enterprise
it breaks your usage down by skill, subagent, plugin, and MCP server.»
(https://code.claude.com/docs/en/best-practices).

## Per approfondire

- «Evaluating skill output quality», il metodo di questo laboratorio:
  https://agentskills.io/skill-creation/evaluating-skills
- «Best practices for skill creators»:
  https://agentskills.io/skill-creation/best-practices
- «Optimizing skill descriptions»:
  https://agentskills.io/skill-creation/optimizing-descriptions
- «Extend Claude with skills», le skill in Claude Code e come si provano:
  https://code.claude.com/docs/en/skills
- «Skill authoring best practices», con la checklist:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- «Agent Skills», nella documentazione della piattaforma:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- «Review locally with /code-review»:
  https://code.claude.com/docs/en/code-review-local
- «Choose a permission mode», con i percorsi protetti:
  https://code.claude.com/docs/en/permission-modes
- «Lessons from building Claude Code: How we use skills»:
  https://claude.dev/blog/lessons-from-building-claude-code-how-we-use-skills/
