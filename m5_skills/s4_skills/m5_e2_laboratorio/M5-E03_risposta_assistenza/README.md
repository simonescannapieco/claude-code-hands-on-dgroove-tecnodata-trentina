# M5-E03 — Una skill di risposta nel tono di voce dell'assistenza

Laboratorio del Modulo 5, traccia (b), sull'assistenza clienti di CiaspoLink,
l'operatore inventato del corso: una skill che scrive la risposta a un cliente
nel tono di voce e nella forma del canale, provata come il codice, con tre casi
di prova, una baseline senza la skill e due iterazioni. Le altre due tracce sono
M5-E02, la revisione di un pull request, e M5-E04, l'audit delle configurazioni.

## Obiettivo

L'assistenza ha le sue regole scritte, il tono di voce in
`progetti/assistenza-clienti/tono-di-voce.md` e le procedure in
`progetti/assistenza-clienti/kb/`, e chi risponde a un cliente le segue. Qui
portate Claude da una risposta generica a quella dell'assistenza, con un metodo:
si guarda che cosa fa senza la skill; si scrive una prima versione, adattando la
skill di esempio `risposta-assistenza` o riempiendo il modello; si prova su tre
messaggi diversi da quello della demo M5-D04, ognuno in una sessione nuova; si
legge, si cambia e si riprova.

Alla fine avete:

- `.claude/skills/risposta-assistenza/`, la skill, in due versioni diverse;
- `risposta-assistenza-workspace/`, le due iterazioni, con le risposte, i voti e
  i conteggi;
- `risposta-assistenza-workspace/iteration-1/feedback.json`, i vostri commenti:
  il tono sta qui, perché lo legge una persona.

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
- Niente PHP né Docker: la skill scrive un messaggio.

## Punto di partenza (tools/prepara_esercizio.sh M5-E03)

Lo spazio di lavoro `~/corso-claude-code/M5-E03/`, un repository git con un
primo commit, con:

- `progetti/assistenza-clienti/`: l'assistenza, con `tono-di-voce.md` e le
  procedure in `kb/`;
- `.claude/skills/risposta-assistenza/evals/`, senza ancora uno `SKILL.md`:
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
- `.gitignore`: tiene fuori da git `risposta-assistenza-workspace/`, dove restano
  le prove;
- `.claude/settings.json`: le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e tre regole `deny`, `Edit(/controlla_skill.py)`,
  `Edit(/lib_leggi_frontmatter.py)` e
  `Edit(/.claude/skills/risposta-assistenza/evals/**)`: Claude cambia la skill,
  non il controllo né i casi di prova. Le regole valgono per i suoi strumenti di
  file, «Edit rules apply to all built-in tools that edit files.»
  (https://code.claude.com/docs/en/permissions), non per uno script: vedi «Se
  qualcosa va storto». La barra iniziale ancora il percorso allo spazio di lavoro:
  «`/path` | Path relative to the settings source | `Edit(/src/**/*.ts)` |
  `<primary working directory>/src/**/*.ts` in project settings» (stessa pagina).

I tre messaggi dei clienti stanno in `evals.json`. `tools/prove_skill.sh` li dà a
Claude così come sono, ognuno in una copia dello spazio di lavoro senza `evals/`:
nella sessione arriva la richiesta, non ciò che ci si aspetta dalla risposta.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro:

       tools/prepara_esercizio.sh M5-E03

2. La baseline: che cosa fa Claude senza la skill. Sempre dalla cartella
   `esercitazioni`:

       tools/prove_skill.sh M5-E03 1 without

   Tre esecuzioni, una per caso, al massimo tre insieme. È il primo passo del
   metodo di Anthropic: «Run Claude on representative tasks without a Skill. …
   Build three scenarios that test these gaps. … Measure Claude's performance
   without the Skill.»
   (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
   La guida dello standard dice come: «Start with 2-3 test cases.», «Include at
   least one prompt that tests a boundary condition», qui il terzo, dove il
   cliente chiede proprio ciò che non si può dare; e «run each test case twice:
   once with the skill and once without it (or with a previous version)»; «Each
   pass through the full eval loop gets its own iteration-N/ directory.»; «Each
   eval run should start with a clean context — no leftover state from previous
   runs or from the skill development process.»
   (https://agentskills.io/skill-creation/evaluating-skills). Per questo ogni
   esecuzione è una sessione nuova di `claude -p`, in una copia pulita dello
   spazio di lavoro, senza `evals/` e senza la skill.

   Aprite le tre risposte, in
   `~/corso-claude-code/M5-E03/risposta-assistenza-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md`,
   e così `eval-2` e `eval-3`. Che cosa dà una risposta generica? Comincia con
   una premessa? Ha la forma del canale? Rispetta il tono di voce dell'assistenza?

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

       tools/prove_skill.sh M5-E03 copia esempio

       cd ~/corso-claude-code/M5-E03
       claude --model sonnet --effort medium

   Alla prima apertura vi chiede se vi fidate della cartella: «In an interactive
   session, Claude Code shows the workspace trust dialog when you start it in a
   folder you haven't trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì, poi incollate:

   <!-- prompt 1 -->

       <role>
       Sei un operatore dell'assistenza di CiaspoLink e adatti una skill di
       Claude Code per i colleghi che rispondono ai clienti.
       </role>

       <context>
       La skill in .claude/skills/risposta-assistenza/ viene da un esempio del
       corso, o dal suo modello, e deve far valere il tono di voce e le
       procedure dell'assistenza, in
       progetti/assistenza-clienti/tono-di-voce.md e in
       progetti/assistenza-clienti/kb/: chi la usa copia il messaggio e lo
       manda al cliente. Come ha risposto Claude senza la skill è in
       risposta-assistenza-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md,
       e così in eval-2 e in eval-3; ciò che ci si aspetta è nei campi
       expected_output di .claude/skills/risposta-assistenza/evals/evals.json.
       </context>

       <instructions>
       1. Leggi il SKILL.md della skill e, se ci sono, il file del tono di voce
          e le procedure della sua cartella references/ che riguardano i tre
          casi.
       2. Leggi le tre risposte senza la skill e i campi expected_output, e
          annota che cosa manca alle risposte.
       3. Cambia la description e il corpo della skill per ciò che manca.
       4. Esegui da solo questo comando, e correggi finché dice 0 errori:
          python3 -B -I controlla_skill.py .claude/skills/risposta-assistenza
       </instructions>

       <format>
       Al massimo cinque righe: che cosa hai cambiato e perché.
       </format>

       <constraints>
       Cambia soltanto i file sotto .claude/skills/risposta-assistenza/, evals/
       escluso. Tieni il SKILL.md nella forma dello standard Agent Skills,
       frontmatter e Markdown semplice, con titoli, elenchi, tabelle e blocchi
       di codice, sotto le 500 righe. Scrivi ciò che vale per
       qualunque messaggio di un cliente.
       </constraints>

   <!-- /prompt 1 -->

   `.claude/` è una cartella protetta: quando Claude ci scrive con i suoi strumenti
   di file, Claude Code vi chiede di approvare la scrittura. Rispondete «Yes, and
   allow Claude to edit files in this project's .claude folder for this session»
   (https://code.claude.com/docs/en/permission-modes), dopo aver letto la modifica.
   Claude può anche cambiare la skill con un comando, invece che con Edit: in una
   sessione del corso sulla traccia (a), M5-E02 (Claude Code 2.1.317), l'ha fatto con
   uno script Python dentro un comando Bash, e Claude Code ha chiesto di approvare
   ogni comando: «This command requires approval». Allora la modifica sta nel
   comando: leggete ogni comando prima di approvarlo, anche quello del controllo.
   Questo prompt fa ciò che dice la guida: «Effective skills are grounded in real
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

       tools/prove_skill.sh M5-E03 1 with

   Quattro esecuzioni: i tre casi e la richiesta che non deve attivare la skill.
   Leggete la tabella (sotto, «Che cosa misura il controllo»), le risposte, che si
   ristampano per intero dopo la tabella e che stanno anche in
   `iteration-1/eval-*/with_skill/outputs/risposta.md`, e i voti in
   `grading.json`. Il tono non ha un voto: lo leggete voi, e lo dite qui. Scrivete
   i vostri commenti: «Record specific feedback for each test case and save it in
   the workspace» (https://agentskills.io/skill-creation/evaluating-skills), una
   riga per ogni `eval-<id>`, in
   `~/corso-claude-code/M5-E03/risposta-assistenza-workspace/iteration-1/feedback.json`:

       {
         "eval-1": "Chiede una prova sola, bene, ma dà del lei a chi scrive in chat.",
         "eval-2": "",
         "eval-3": "Il no è giusto e suona freddo: non dice che cosa può fare invece."
       }

   La forma è quella della guida: «"The chart is missing axis labels" is
   actionable; "looks bad" is not.», e «Empty feedback means the output looked
   fine»: la stringa vuota dice che avete letto, e andava bene.

5. L'iterazione. Nella stessa sessione del passo 3 incollate:

   <!-- prompt 2 -->

       <context>
       La prima versione della skill è stata provata, e i risultati sono in
       risposta-assistenza-workspace/iteration-1/. I segnali sono tre: le
       asserzioni non passate, in eval-1/with_skill/grading.json e così per
       eval-2 e eval-3; i commenti di chi ha letto le risposte, in
       feedback.json; le trascrizioni, in
       eval-1/with_skill/outputs/stream.jsonl e così per gli altri due.
       </context>

       <instructions>
       1. Leggi i tre grading.json, feedback.json e il SKILL.md di
          .claude/skills/risposta-assistenza/.
       2. Per ogni asserzione non passata e per ogni commento, cerca nella
          trascrizione di quel caso, a pezzi con grep, che cosa Claude ha
          letto e che cosa ha saltato.
       3. Cambia la skill per le cause che hai trovato.
       4. Esegui da solo questo comando, e correggi finché dice 0 errori:
          python3 -B -I controlla_skill.py .claude/skills/risposta-assistenza
       </instructions>

       <format>
       Al massimo cinque righe: che cosa hai cambiato, e quale segnale lo
       chiedeva.
       </format>

       <constraints>
       Generalizza dai commenti: la skill serve per ogni messaggio di un
       cliente, non per questi tre. Tieni la skill snella: togli le istruzioni
       che le trascrizioni mostrano inutili. Spiega il perché di ogni
       istruzione. Raccogli in scripts/ il lavoro che ogni esecuzione rifà da
       capo. Cambia soltanto i file sotto .claude/skills/risposta-assistenza/,
       evals/ escluso.
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
   che nomina Marta o questo firewall non serve al prossimo.

6. La seconda versione. Dalla cartella `esercitazioni`:

       tools/prove_skill.sh M5-E03 2 with
       tools/verifica.sh M5-E03

   «Rerun all test cases in a new iteration-<N+1>/ directory.», e «When improving
   an existing skill, use the previous version as your baseline. Snapshot it
   before editing» (https://agentskills.io/skill-creation/evaluating-skills). Due
   differenze dalla guida, e sono scelte del corso. `old_skill`, la baseline della
   seconda iterazione, riusa le esecuzioni dell'iterazione 1, dove la guida le
   rifà: si risparmia la quota del piano. E `iteration-N/skill-snapshot/` è una
   per iterazione, dove la guida ne ha una sola nella cartella delle prove: così
   ogni coppia di versioni si confronta. Che cosa è cambiato:

       cd ~/corso-claude-code/M5-E03/risposta-assistenza-workspace
       diff -r iteration-1/skill-snapshot iteration-2/skill-snapshot
       cd -

7. Chi finisce prima: una terza iterazione, cambiando ancora la skill e dando
   `tools/prove_skill.sh M5-E03 3 with`, oppure il caricamento su claude.ai di
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
  È un confronto, e si decide confrontando: per ogni caso le asserzioni passate
  con la skill e senza, con le parole «confermata», «non distinguibile», «non
  confermata in questa misura». Una sola esecuzione per caso è un campione: la
  tabella lo scrive accanto a ogni confronto.
- **Iterare.** «Iterate: Run evaluations, compare against baseline, and refine.»
  (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
- **La richiesta che non deve attivarla.** «The most valuable negative test
  cases are near-misses — queries that share keywords or concepts with your skill
  but actually need something different.» E una sola esecuzione non basta a dirlo:
  «Model behavior is nondeterministic — the same query might trigger the skill on
  one run but not the next.»
  (https://agentskills.io/skill-creation/optimizing-descriptions).
- **Il tono lo legge una persona.** «Subjective skills (writing style, design
  quality) are better evaluated qualitatively — don't force assertions onto
  things that need human judgment.»
  (https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md).
  La guida dello standard dice lo stesso, passo 2 qui sopra. Per questo il
  controllo conta ciò che si conta, e stampa ogni risposta per intero; se la
  risposta suona fredda, o dà del tu a chi dà del lei, lo dite voi, in
  `feedback.json`, e il seguito del passo 5 lo legge.
- **Una voce in una skill, o in un output style.** La pagina degli output style
  mette a confronto i due posti: per «Every response in a certain voice, length,
  or format, or Claude in a different role | An output style», mentre una skill
  «Claude loads it only when you invoke it or the task matches, so it doesn't
  shape unrelated responses» (https://code.claude.com/docs/en/output-styles). Qui
  la voce serve per un compito, rispondere a un cliente. Anche Anthropic ne fa
  una skill: un caso d'uso dell'Academy, «Write in my voice … A profile of how you
  write, saved as a skill. … Your real writing is the corpus.»
  (https://academy.claude.com/use-cases/my-voice), e la skill `internal-comms` del
  repository `anthropics/skills`, «A set of resources to help me write all kinds of
  internal communications, using the formats that my company likes to use.»
  (https://github.com/anthropics/skills/blob/main/skills/internal-comms/SKILL.md).

### Che cosa guardare

- **La baseline:** legge `tono-di-voce.md` e la procedura, o risponde di suo? Lo
  dice la trascrizione, `outputs/stream.jsonl`.
- **La skill:** scatta sulle tre richieste, anche sulla terza, dove nessuno dice
  «rispondi al cliente»? E sulla near-miss, che parla di una procedura ma non
  chiede un messaggio?
- **Le asserzioni che passano con la skill e non senza:** «Study assertions that
  pass with the skill but fail without. This is where the skill is clearly adding
  value.» (https://agentskills.io/skill-creation/evaluating-skills).
- **Ciò che costa:** «The delta tells you what the skill costs (more time, more
  tokens) and what it buys (higher pass rate).», e all'inizio basta poco: «In
  early iterations with just 2-3 test cases and single runs, focus on the raw pass
  counts and the delta» (stessa pagina).
- **Il modello del canale**, nello `SKILL.md` dell'esempio: «This is more reliable
  than describing the format in prose, because agents pattern-match well against
  concrete structures.» (https://agentskills.io/skill-creation/best-practices). Se
  lo togliete, che cosa succede alla chat?

### Che cosa misura il controllo

`grading.json`, `timing.json` e `benchmark.json` hanno la forma della guida: «The
other JSON files (grading.json, timing.json, benchmark.json) are produced during
the eval process — by the agent, by scripts, or by you.»; qui da uno script, che li
ricalcola dagli stream ogni volta e non li rilegge: «use a verification script —
scripts are more reliable than LLM judgment for mechanical checks», e valutare
vuol dire «recording PASS or FAIL with specific evidence»: «Require concrete
evidence for a PASS. Don't give the benefit of the doubt.»
(https://agentskills.io/skill-creation/evaluating-skills).

Le asserzioni, sul testo finale di ogni esecuzione; una risposta vuota non ne
passa nessuna:

- **«Contiene il solo testo del messaggio, senza premesse».** La prima riga non è
  una premessa («Ecco», «Risposta:», «Puoi rispondere», «Ti propongo») né un
  titolo; dopo il messaggio non c'è altro: niente dopo la firma, dopo una riga
  `---` o dopo un blocco di codice, e l'ultimo paragrafo non parla del messaggio
  («Nota:», «Ho usato il tu», «Se vuoi lo adatto»). Un commento che non usa queste
  parole non lo vede: lo leggete voi. L'evidenza cita la prima riga.
- **«Non usa le parole da evitare della guida».** Le parole delle tabelle di
  `tono-di-voce.md` e dello `SKILL.md` di esempio, con le forme della stessa parola
  («disservizi» vale come «disservizio», «ti faremo sapere» come «le faremo
  sapere»), maiuscole o minuscole, a parola intera; le sigle di quelle tabelle e i
  nomi degli apparati. L'evidenza nomina le parole trovate.
- **«Non contiene emoji né punti esclamativi in serie».** I blocchi Unicode delle
  emoji e dei simboli (U+2600–U+27BF, U+2B50, U+2B55, U+1F000–U+1FAFF) e due punti
  esclamativi di fila. Un punto esclamativo solo va bene, e una freccia non è
  un'emoji.
- **«Rispetta la forma del canale».** Il canale di ogni caso sta in `verifica.py`:
  la chat nei casi 1 e 3, l'e-mail nel 2. In chat, come dice la guida: al massimo
  tre frasi e un passo numerato; una riga a capo chiude una frase, e la frase del
  passo non si conta. Nell'e-mail: una riga `Oggetto:`, un saluto con un nome, da
  due a quattro paragrafi e la firma «Il team di assistenza CiaspoLink»; saluto,
  saluti finali e firma non sono paragrafi, e un elenco sta con il paragrafo che lo
  introduce. L'evidenza dice i conteggi.
- **«Riporta il numero della segnalazione».** Nel caso 2: il numero del prompt nel
  testo.
- **«Non scrive una password e indica l'area clienti».** Nel caso 3: dopo la parola
  «password» e un segno o «è» nessun valore che sembri una password (con una cifra
  o un simbolo, con maiuscole dentro la parola, fra virgolette, o una parola sola
  dopo i due punti), e «area clienti» nel testo. L'evidenza non ripete il valore.

Se un'asserzione passa in tutte e due le configurazioni, la tabella lo dice:
«Passano sempre in entrambe le configurazioni». La guida dice che farne: «Remove
or replace assertions that always pass in both configurations.»: quando le prove
saranno vostre, è la prima da togliere o da sostituire.

La tabella stampa, per ogni caso e configurazione, se la skill è stata chiamata, le
asserzioni passate, turni, token e secondi; poi la near-miss, i conteggi e il
delta. Dopo la tabella, come dati, mai come uscita: la skill chiamata n su 3, le
altre skill che Claude ha scelto da sé e, per una persona, ogni risposta per intero
con la sua lunghezza in parole. Una garanzia invece deve reggere a ogni esecuzione,
e se non regge è un reperto, con l'uscita 1: senza la skill, nessuna chiamata riuscita
a `risposta-assistenza` e `risposta-assistenza` non fra le skill disponibili; con la
skill, la skill nell'elenco e la sua chiamata né negata dal permesso né respinta dallo
strumento.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet, effort
low per le prove e medium per scrivere, `_docente/live.sh` sull'account del docente,
una sola esecuzione per caso, partendo dalla skill di esempio), come le stampa il
controllo:

- **La prima versione contro la baseline.** «with_skill 3, without_skill 2 asserzioni
  passate: confermata (una sola esecuzione per caso)» nel primo caso, «with_skill 5,
  without_skill 2 asserzioni passate: confermata (una sola esecuzione per caso)» nel
  secondo, «with_skill 5, without_skill 4 asserzioni passate: confermata (una sola
  esecuzione per caso)» nel terzo. «Conteggi: without_skill 8 su 14; with_skill 13 su
  14». «Delta, with_skill meno without_skill: pass rate +0,350; tempo -3,1 s; token
  -24284».
- **La seconda versione contro la prima.** «with_skill 4, old_skill 3 asserzioni
  passate: confermata (una sola esecuzione per caso)» nel primo caso, «with_skill 5,
  old_skill 5 asserzioni passate: non distinguibile (una sola esecuzione per caso)»
  negli altri due. «Conteggi: old_skill 13 su 14; with_skill 14 su 14». «Delta,
  with_skill meno old_skill: pass rate +0,083; tempo -2,7 s; token +24592».
- **L'invocazione, a parte.** «iterazione 1: risposta-assistenza chiamata 3 su 3 in
  with_skill», «iterazione 2: risposta-assistenza chiamata 3 su 3 in with_skill». La
  near-miss, tutte e due le volte: «Skill chiamata: no; dovrebbe attivarla: no».
- **Ciò che non distingue.** Passano sempre in entrambe le configurazioni, nella prima
  iterazione, «Non contiene emoji né punti esclamativi in serie», «Riporta il numero
  della segnalazione» e «Non scrive una password e indica l'area clienti».
- **Le lunghezze, come dati.** 217, 417 e 253 parole senza la skill; 56, 215 e 64 con
  la prima versione; 59, 172 e 49 con la seconda.
- **Lo script della seconda versione, che non ha girato.** Lo `SKILL.md` di quella
  versione chiede di controllare il messaggio con `scripts/controlla_messaggio.py`.
  Nei tre casi il comando composto che lo lancia è negato: «(dato) with_skill: 1 passo
  negato dal permesso: Bash
  «cd /tmp/handson.TYFTas/esecuzione-0/.claude/skills/risposta-assistenza && cat > …»»,
  e così negli altri due. Il 14 su 14 di quella versione non poggia sullo script.

«Da leggere, per una persona: il tono non lo decide il controllo.» Alla fine, «Fatto:
la skill passa il controllo del file, le due iterazioni ci sono, i commenti anche, e
le due versioni sono diverse.» Una sola esecuzione per caso è un campione: queste
righe dicono che cosa è successo lì.

È una prova in `claude -p`, senza nessuno davanti, con due differenze dalla vostra
sessione. La skill Claude l'ha adattata in `bozza/risposta-assistenza/`, con il
percorso dei prompt cambiato, e `_docente/live.sh` l'ha riportata in
`.claude/skills/risposta-assistenza/`: nelle prove del corso, in `claude -p`, le
scritture sotto `.claude/skills/` sono negate anche con le regole, «permissions.allow
rules in settings files do not pre-approve protected-path writes»
(https://code.claude.com/docs/en/permission-modes). A voi, nel passo 3, Claude Code lo
chiede. E `feedback.json` non l'ha scritto una persona: l'ha scritto uno script, dalle
asserzioni non passate, e il file lo dice. Il tono, in quella prova, non l'ha giudicato
nessuno: quello è il vostro passo 4.

## Verifica (tools/verifica.sh M5-E03)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M5-E03

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
- Un `REPERTO` dice che la chiamata a `risposta-assistenza` è «negata dal permesso».
  Nelle prove del corso (Claude Code 2.1.317), in `claude -p` con `dontAsk`, una
  skill con `allowed-tools` o `disallowed-tools` nel frontmatter, che Claude invoca
  da sé, è negata finché le regole non ammettono `Skill(nome)`. Per questo
  `prove/config`, che sta nella cartella dell'elemento e non nello spazio di lavoro,
  elenca `Skill(risposta-assistenza)`, in tutti e due i bracci: se aggiungete
  `allowed-tools` alla skill, la chiamata passa lo stesso. Se quella riga manca, lo
  strumento si ferma prima, con l'uscita 2. Un reperto con la riga al suo posto è un
  esito da segnalare al docente, con lo stream.
- Un `REPERTO` dice che la chiamata è «respinta dallo strumento»: il corpo della skill
  non è arrivato, e il motivo è nel `tool_result`, in `outputs/stream.jsonl`.
- Un `REPERTO` dice, senza la skill, che `risposta-assistenza` è «fra le skill
  disponibili». Non dovrebbe essere quella caricata su claude.ai: queste prove hanno
  `--setting-sources project,local`, con cui, per la pagina di Anthropic, le skill
  dell'account non arrivano, e nella prova del corso di M5-D05 una sessione così non le
  elencava. È un esito da segnalare al docente, con lo stream.
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
  `risposta-assistenza-workspace/iteration-2/` e rilanciate
  `tools/prove_skill.sh M5-E03 2 with`.
- `MANCA iteration-1/feedback.json: non è JSON`: rileggetelo; le virgolette dentro un
  commento vanno scritte `\"`.
- `claude: command not found`, o un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M5-E03`.

## Impronta d'uso sul piano Pro

Scrivere la skill: Sonnet, effort medium, due prompt, nessun subagent. Le prove:
undici chiamate, tre senza la skill e quattro per ogni versione, Sonnet, effort low,
nessun subagent. `old_skill` non consuma: riusa le esecuzioni che ci sono. Il
controllo e la verifica non chiamano il modello. Se finite prima, una terza
iterazione sono altre quattro chiamate.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet,
`_docente/live.sh` in `claude -p` sull'account del docente, un piano Max), tredici
chiamate:

- le undici di prova, effort low: «Consumo, senza le esecuzioni riusate: 7 chiamate,
  33 turni, 503910 token, 107,1 s» fino alla prima versione, baseline compresa, e
  «Consumo, senza le esecuzioni riusate: 4 chiamate, 20 turni, 320137 token, 49,5 s»
  per la seconda: 53 turni del modello, 824.047 token e 156,6 secondi, da 1 a 15
  turni a chiamata;
- le due di scrittura, effort medium: 18 e 18 turni del modello, 49,2 e 60,5 secondi,
  262.792 e 438.371 token. La riga che `_docente/live.sh` stampa per la seconda dice
  701.163: è una sessione ripresa con `--resume`, e lì `modelUsage` conta anche la
  sessione di prima; 438.371 è la differenza.

`total_tokens`, in `timing.json`, è quel conto: «Use modelUsage, or model_usage in
Python, for whole-tree token accounting; the usage field undercounts as soon as
nesting occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking). Conta
tutti i modelli e tutti i subagent, e di ogni richiesta l'entrata, la cache e
l'uscita: nelle undici prove l'82 % dei token è contesto letto dalla cache. Dice
quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano occupa.

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
- «Output styles», dove sta una voce che vale per ogni risposta:
  https://code.claude.com/docs/en/output-styles
- «Write in my voice», un caso d'uso dell'Academy:
  https://academy.claude.com/use-cases/my-voice
- «Choose a permission mode», con i percorsi protetti:
  https://code.claude.com/docs/en/permission-modes
