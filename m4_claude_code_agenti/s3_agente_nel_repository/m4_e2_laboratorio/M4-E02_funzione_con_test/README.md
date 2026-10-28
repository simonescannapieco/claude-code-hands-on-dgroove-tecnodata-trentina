# M4-E02 — Una funzione nuova, con i test

Laboratorio del Modulo 4, traccia (a), sul gestionale di CiaspoLink,
l'operatore inventato del corso, un progetto sintetico: una funzione
nuova, con i suoi test scritti da un subagent a partire dalla specifica
mentre la sessione principale implementa, e un revisore che non ha visto
scrivere il codice. In due parti: la prima finisce con un commit e una
nota, `NOTA.md`; la seconda parte del laboratorio riparte da lì.

## Obiettivo

La pagina Ticket del gestionale di CiaspoLink filtra per stato, priorità,
categoria e cliente; manca il filtro per **apparato** e per **intervallo
di date**, che nella settimana dei disservizi serve. `SPECIFICA.md` dice
che cosa deve fare, con un esempio per requisito e i casi di
accettazione. Le regole del laboratorio:

- prima il piano, in plan mode;
- almeno un subagent: qui due, uno che scrive i test e uno che rivede;
- un controllo che Claude può eseguire: la suite PHPUnit del gestionale;
- piccoli passi, con un commit ciascuno;
- Sonnet con effort medium, i subagent su Haiku dove il lavoro è semplice;
- alla fine della prima parte, un commit e `NOTA.md`: che cosa è fatto,
  che cosa manca, i comandi per riprendere.

Mettete alla prova quello che Anthropic dice dei subagent: quando
ripagano, che cosa non danno, e che un revisore con soli strumenti di
lettura non può modificare niente.

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
- Docker, oppure PHP 8.3 o successivo con Composer: i test del gestionale
  girano con `tools/php.sh` (`PRIMA_DEL_CORSO.md`, «Docker, oppure PHP e
  Composer»).
- Python 3.8 o successivo, il comando `python3`: lo usa la verifica.
- M4-E01, il riscaldamento: lo stesso gestionale e lo stesso comando dei
  test.

## Punto di partenza (tools/prepara_esercizio.sh M4-E02)

Lo spazio di lavoro `~/corso-claude-code/M4-E02/` con:

- `progetti/gestionale-php/`: il gestionale, con i suoi test in `tests/` e
  le regole del team in `docs/convenzioni.md`;
- `SPECIFICA.md`: la funzione da fare, sette requisiti e i casi di
  accettazione, con gli identificativi veri dei dati di esempio;
- `tools/php.sh`: una copia di `tools/php.sh` del repository, per i
  comandi di PHP dello spazio di lavoro;
- `.claude/agents/autore-test.md`, il subagent che scrive i test: `tools:
  Read, Grep, Glob, Write`, `model: sonnet`; scrive dalla specifica e dai
  test che ci sono, senza leggere i due file che intanto la sessione
  principale cambia, e risponde in un formato fisso (FILE, REQUISITI
  COPERTI, DUBBI);
- `.claude/agents/revisore.md`, il revisore: `tools: Read, Grep, Glob`,
  `model: haiku`; confronta il diff con la specifica e con le regole del
  team, e risponde in un formato fisso (ESITO, REQUISITI, PROBLEMI);
- `.claude/settings.json`: le impostazioni di progetto. Tengono le regole
  prudenti del repository (`.env`, `secrets/`, chiavi) e aggiungono:
  - una regola `allow` per il comando dei test,
    `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit`, con i
    suoi argomenti: Claude lo esegue senza chiedervelo;
  - regole `deny` di `Edit` su `tools/php.sh`, su `SPECIFICA.md` e su
    `.claude/agents/`: `Edit(/tools/php.sh)`, `Edit(/SPECIFICA.md)` e
    `Edit(/.claude/agents/**)`. Si scrive il codice, non si cambiano lo
    strumento, la specifica o i subagent. «Edit rules apply to all
    built-in tools that edit files.»
    (https://code.claude.com/docs/en/permissions);
  - `defaultMode` `default`, la modalità Manual: «The mode that reviews
    every action is named Manual in the CLI … Its config value is
    default» (https://code.claude.com/docs/en/permission-modes);
  - `plansDirectory` `./piani`: il piano che Claude scrive in plan mode
    resta nello spazio di lavoro, in `piani/`, e la seconda parte lo
    ritrova: «Choose where Claude Code stores the plan files it writes in
    plan mode.» (https://code.claude.com/docs/en/settings-reference).

Le tre regole `deny` aggiunte cominciano con `/`. Nella pagina sui
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

1. Dalla cartella `esercitazioni`: preparate lo spazio di lavoro, entrateci,
   installate le dipendenze del gestionale e aprite Claude Code in plan
   mode, su Sonnet con effort medium:

       tools/prepara_esercizio.sh M4-E02
       cd ~/corso-claude-code/M4-E02
       tools/php.sh composer install -d progetti/gestionale-php
       claude --permission-mode plan --model sonnet --effort medium

   Intanto leggete voi `SPECIFICA.md`: è il metro con cui giudicherete il
   lavoro.

   Alla prima apertura Claude Code vi chiede se vi fidate della cartella:
   «In an interactive session, Claude Code shows the workspace trust
   dialog when you start it in a folder you haven't trusted.»
   (https://code.claude.com/docs/en/security). Rispondete sì: la regola
   `allow` del comando dei test vale soltanto dopo, «permissions.allow
   rules, permissions.additionalDirectories, extraKnownMarketplaces, and
   most env values apply only after each teammate trusts the folder …
   deny and ask rules apply right away»
   (https://code.claude.com/docs/en/settings), e da lì «Allow rules let
   Claude Code use the specified tool without manual approval.»
   (https://code.claude.com/docs/en/permissions). La prova del corso,
   fatta con `claude -p` e senza quella domanda, a ogni chiamata ha
   scritto «Ignoring 1 permissions.allow entry from .claude/settings.json:
   this workspace has not been trusted».

2. Il piano. Incollate:

   <!-- prompt 1 -->

       Leggi SPECIFICA.md, il codice dei ticket che la riguarda
       (progetti/gestionale-php/src/Ticket/,
       progetti/gestionale-php/src/Web/TicketController.php,
       progetti/gestionale-php/templates/ticket_elenco.php) e i test che ci
       sono in progetti/gestionale-php/tests/. Prepara un piano a piccoli
       passi, uno per requisito, ciascuno con il suo commit. Nel piano: i
       test li scrive dalla specifica il subagent autore-test, in
       background, mentre tu implementi; dopo ogni passo esegui il
       controllo, questo comando, da solo, senza concatenarlo ad altri:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php
       prima del commit che chiude la funzione, il subagent revisore
       confronta le modifiche con SPECIFICA.md.

   <!-- /prompt 1 -->

   Quando Claude presenta il piano, leggetelo: ci sono i passi, il
   subagent, il controllo, i commit? Se no, ditegli che cosa cambiare. Se
   va bene, approvatelo scegliendo di approvare le modifiche una per una:
   finché non lo approvate, niente cambia.

3. Il lavoro. Dopo l'approvazione Claude esegue il piano. Se nel primo
   passo non lancia il subagent `autore-test`, incollate:

   <!-- prompt 2 -->

       Il piano va bene: eseguilo un passo alla volta. Per i test lancia
       @agent-autore-test: scriva in progetti/gestionale-php/tests/ i test
       di SPECIFICA.md, dalla specifica e dai test che ci sono. Mentre
       lavora, implementa i requisiti. Quando il subagent ha finito, esegui
       il controllo con questo comando, da solo, senza concatenarlo ad
       altri:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php
       e correggi il codice finché passa; i test si cambiano solo se
       contraddicono SPECIFICA.md. Dopo ogni passo che passa il controllo
       fai un commit: git add, poi git commit -m con il messaggio fra
       virgolette, un comando per volta, e un messaggio come chiede la
       regola 11.1 di progetti/gestionale-php/docs/convenzioni.md.

   <!-- /prompt 2 -->

   Leggete ogni modifica prima di approvarla. Il comando dei test gira
   senza chiedere niente; i commit li approvate voi, leggendo il messaggio.

4. La revisione, prima del commit che chiude la funzione. Incollate:

   <!-- prompt 3 -->

       Prima del commit che chiude la funzione: esegui git log --oneline,
       poi git diff dal primo commit, il punto di partenza, e passa il diff
       a @agent-revisore perché lo confronti con SPECIFICA.md. Correggi ciò
       che segnala, esegui di nuovo il controllo e fai il commit.

   <!-- /prompt 3 -->

5. La nota, alla fine della prima parte. Incollate:

   <!-- prompt 4 -->

       Siamo alla fine della prima parte del laboratorio. Scrivi NOTA.md,
       nella cartella in cui siamo: che cosa è fatto (i requisiti di
       SPECIFICA.md già soddisfatti, con i loro commit), che cosa manca, e
       i comandi per riprendere (il controllo, il revisore). Poi fai un
       commit di NOTA.md: git add, poi git commit -m, un comando per volta.

   <!-- /prompt 4 -->

   Poi `/exit`.

### Seconda parte

6. Una sessione nuova, che riparte dalla nota. Partite dalla cartella
   `esercitazioni`, come nel passo 1: in un terminale nuovo,
   `cd ~/esercitazioni` se avete clonato il repository nella cartella di
   casa, come chiede `PRIMA_DEL_CORSO.md` in WSL 2, altrimenti il suo
   percorso. Poi entrate nello spazio di lavoro e aprite Claude Code:

       cd ~/corso-claude-code/M4-E02
       claude --model sonnet --effort medium

   e incollate:

   <!-- prompt 5 -->

       Leggi NOTA.md e SPECIFICA.md e riprendi il lavoro da dove si era
       fermato: finisci ciò che manca un passo alla volta, con un commit per
       passo. Dopo ogni passo esegui il controllo, da solo, senza
       concatenarlo ad altri:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php
       Prima dell'ultimo commit esegui git log --oneline e git diff dal
       primo commit, e passa il diff a @agent-revisore perché lo confronti
       con SPECIFICA.md.

   <!-- /prompt 5 -->

   L'alternativa è riprendere la conversazione della prima parte con
   `claude --continue`, che «resumes the most recent session in the
   current directory» (https://code.claude.com/docs/en/common-workflows).
   Ma una sessione nuova «starts with a fresh context window, without the
   conversation history from previous sessions»
   (https://code.claude.com/docs/en/how-claude-code-works): riparte dalla
   nota, piccola, e non da tutta la conversazione. Riprendere una
   conversazione lunga dopo un'interruzione lunga, invece, è più lento:
   «After a long enough gap, the next request recomputes the full input
   and re-establishes the cache, which is why the first turn back after
   stepping away can be noticeably slower.»
   (https://code.claude.com/docs/en/prompt-caching), e sul piano Pro può
   chiedere conferma: «On Pro and Max plans, the dialog can appear when
   you resume a long conversation after a long break or on a different
   model.» (https://code.claude.com/docs/en/sessions).

7. Se il controllo non passa, incollate:

   <!-- prompt 6 -->

       Esegui il controllo, da solo, senza concatenarlo ad altri:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php
       e correggi il codice finché passa. Poi esegui git diff dal primo
       commit, passalo a @agent-revisore perché lo confronti con
       SPECIFICA.md, e fai il commit.

   <!-- /prompt 6 -->

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate. `~/esercitazioni` è la cartella in cui `PRIMA_DEL_CORSO.md`
   fa clonare il repository in WSL 2; se l'avete clonato altrove, usate il
   suo percorso:

       cd ~/esercitazioni
       tools/verifica.sh M4-E02

## Che cosa osservare

### Che cosa dice Anthropic

- **Quando un subagent ripaga.** La pagina delle best practice di Claude
  Code ne dà due casi, fra gli altri: «Running independent pieces of work
  at the same time» e «Getting a reviewer that hasn't seen how the code
  was written» (https://code.claude.com/docs/en/best-practices). Qui sono
  i due subagent: `autore-test` lavora mentre la sessione principale
  implementa, `revisore` guarda il diff senza aver visto scriverlo.
- **Che cosa non danno.** «You get parallelism or a fresh pair of eyes out
  of it, but not a smarter answer.» e «Handing the same task to a subagent
  doesn't make the answer any better. A fresh reviewer does help, because
  it hasn't seen your reasoning»
  (https://code.claude.com/docs/en/best-practices). L'Academy lo dice del
  revisore prima del commit: «A subagent gets a fresh pair of eyes on the
  codebase — it doesn't carry the bias the main agent might have from the
  session.»
  (https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow)
- **Un revisore che non può modificare.** Un subagent in `.claude/agents/`
  con soli `tools: Read, Grep, Glob`: «Now it's a reviewer that can't edit
  anything», e il limite lo impone Claude Code: «enforced by Claude Code»
  (https://code.claude.com/docs/en/best-practices). È una garanzia del
  prodotto: la verifica la controlla nella trascrizione del revisore.
- **Il modello e il formato.** «Set model: haiku in a subagent's
  definition if its work is simple»
  (https://code.claude.com/docs/en/best-practices), ed è il revisore; e
  «The single most important improvement you can make to a subagent is
  defining an output format in its system prompt.»
  (https://academy.claude.com/courses/introduction-to-subagents/designing-effective-subagents),
  ed è il formato fisso dei due.
- **La @-mention.** «Natural language: name the subagent in your prompt;
  Claude decides whether to delegate…@-mention: guarantees the subagent
  runs for one task» (https://code.claude.com/docs/en/sub-agents): per
  questo i prompt 2, 3, 5 e 6 scrivono `@agent-autore-test` e
  `@agent-revisore`. E «With nothing configured, a subagent that Claude
  spawns from your main conversation starts in the background.»
  (https://code.claude.com/docs/en/sub-agents)
- **Prima il piano.** «If you take one thing away from this course, let it
  be this workflow: Explore, Plan, Code, and Commit.»
  (https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow);
  in plan mode «Claude reads files and proposes a plan but makes no edits
  until you approve.» (https://code.claude.com/docs/en/common-workflows).
- **Il giudice va provato.** Per i test che decidono se una modifica è
  giusta, Anthropic consiglia: «Run it against the original code to
  confirm it passes. Then run it against deliberately broken code to
  confirm it fails» (https://claude.com/resources/articles/ai-code-migration).
  Qui il codice di partenza è quello a cui manca la funzione: i test nuovi
  devono passare sul vostro codice e fallire su quello di partenza.

### Che cosa guardare

- **Il piano:** ci sono i passi, il subagent dei test, il controllo, i
  commit? Lo approvate voi.
- **Il subagent dei test:** parte in background mentre la sessione
  principale scrive il codice? La sua risposta ha il formato fisso? Nei
  DUBBI, trova punti poco chiari della specifica?
- **Il controllo:** Claude lo esegue dopo ogni passo, e quando è rosso
  corregge il codice, non i test?
- **Il revisore:** che cosa trova che la sessione principale non aveva
  visto? Claude corregge?
- **I commit e la nota:** piccoli, con i messaggi della regola 11.1?
  `NOTA.md` basta per riprendere?

### Che cosa misura la verifica

- `tools/verifica.sh M4-E02` legge lo spazio di lavoro con git, a partire
  dal suo primo commit: conta il lavoro nei commit e quello ancora fuori.
  Cerca i file di test nuovi o cambiati sotto
  `progetti/gestionale-php/tests/`.
- Esegue con `tools/php.sh` del repository la suite intera e i test nuovi,
  sul vostro codice: devono passare.
- In una copia del gestionale al primo commit, con i vostri test nuovi,
  esegue i test nuovi: devono fallire, perché lì la funzione manca. Se
  passano anche lì, non provano la funzione nuova.
- Nella trascrizione del revisore cerca gli strumenti che modificano
  (Edit, Write, NotebookEdit): se ce n'è uno, è una garanzia di Claude
  Code che non ha tenuto, e la verifica lo segnala. Se avete cambiato la
  definizione del revisore dandogli altri strumenti, la garanzia non si
  applica. Se riconosce meno trascrizioni del revisore che chiamate,
  l'esito è «non distinguibile»: una chiamata senza trascrizione non si
  controlla. Una trascrizione che non si legge ferma la verifica, con
  l'uscita 2.
- Come dati, mai come uscita: `NOTA.md`, i commit dopo il punto di
  partenza, i file cambiati, le sessioni di Claude Code dello spazio di
  lavoro e le chiamate al tool Agent, per tipo di subagent. Le sessioni
  stanno dove Claude Code le salva: «By default, Claude Code stores
  transcripts as JSONL at ~/.claude/projects/<project>/<session-id>.jsonl»
  (https://code.claude.com/docs/en/sessions), e i subagent accanto: «find
  IDs in the transcript files at
  ~/.claude/projects/{project}/{sessionId}/subagents/. Each transcript is
  stored as agent-{agentId}.jsonl.»
  (https://code.claude.com/docs/en/sub-agents). Il tool che lancia i
  subagent si chiama Agent: «In version 2.1.63, the Task tool was renamed
  to Agent.» (https://code.claude.com/docs/en/sub-agents); la verifica
  conta tutti e due i nomi. Senza chiamate stampa «nessun subagent
  trovato»: la regola del laboratorio lo chiede, ma la verifica non vi
  boccia per questo.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `_docente/live.sh` sull'account del docente, con le regole
scritte allora senza la barra iniziale, equivalenti dalla radice dello
spazio di lavoro): due file di test nuovi,
`Integrazione/TicketFiltroApparatoDateTest.php` e
`Unit/Ticket/FiltroTicketTest.php`; la suite intera sul codice di
Claude, «OK (100 tests, 882 assertions)»; i test nuovi, «OK (56 tests,
775 assertions)» sul codice di Claude e, sul codice di partenza,
«Tests: 56, Assertions: 44, Errors: 18, Failures: 6, Warnings: 17.»:
falliscono, come devono, «il giudice è valido». Il revisore (tools:
Glob, Grep, Read): 3 trascrizioni, nessuno strumento che modifica, «la
garanzia vale». Come dati: `NOTA.md` di 27 righe non vuote, 7 commit, 2
sessioni, «chiamate al tool Agent: 4 (autore-test 1, revisore 3)».

## Verifica (tools/verifica.sh M4-E02)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M4-E02

Esce con 0 se la suite intera e i test nuovi passano sul vostro codice e i
test nuovi falliscono su quello di partenza; con 1 se qualcosa manca o non
torna (e dice che cosa), o se il revisore ha modificato file; con 2 se non
può partire, per esempio se mancano le dipendenze del gestionale.

## Se qualcosa va storto

- `tools/php.sh composer install` si ferma con «servono PHP >= 8.3 o
  Docker» o con «il demone Docker non risponde»: rivedete
  `PRIMA_DEL_CORSO.md`, «Docker, oppure PHP e Composer».
- La verifica esce con 2 e dice che mancano le dipendenze: dalla cartella
  dello spazio di lavoro,
  `tools/php.sh composer install -d progetti/gestionale-php`.
- Claude esegue `tools/php.sh phpunit` dalla cartella dello spazio di
  lavoro e riceve «vendor/bin/phpunit non trovato»: ricordategli il
  comando del controllo, che funziona da qui.
- Claude vi chiede di approvare una riga che unisce più comandi: rispondete
  **No** e chiedetegli un comando per volta. «Claude Code is aware of shell
  operators, so a rule like Bash(safe-cmd *) won't give it permission to
  run the command safe-cmd && other-cmd.»
  (https://code.claude.com/docs/en/permissions)
- `git commit` si ferma con «Please tell me who you are»: git non sa chi
  firma i commit. Dallo spazio di lavoro, una volta: `git config
  user.name "Partecipante"` e `git config user.email
  partecipante@example.org`.
- Claude vuole cambiare `SPECIFICA.md` o un file di `.claude/agents/`: la
  regola `deny` lo ferma. Si corregge il codice; se la specifica vi sembra
  sbagliata, ditelo al docente.
- I test del subagent non passano: prima di cambiarli, guardate se
  contraddicono la specifica. Il controllo rosso dice dove guardare; il
  codice si corregge finché i test giusti passano.
- La verifica dice che i test nuovi passano anche sul codice di partenza:
  non provano la funzione. Chiedete a Claude un test per un caso di
  accettazione, con i suoi identificativi.
- `claude --continue` dice «No conversation found to continue»: lo
  lanciate da un'altra cartella; entrate in `~/corso-claude-code/M4-E02`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-E02`.

## Impronta d'uso sul piano Pro

Sessioni interattive su Sonnet, effort medium; nella prova del corso 40
turni del modello in tutto, nelle due parti (sotto); due subagent,
`autore-test` su Sonnet, una chiamata, e `revisore` su Haiku, tre
chiamate. I subagent non sono gratis: «What they
cost you is mostly tokens, since every subagent sends its own requests and
they count against the same usage as your main conversation.» Per
spendere meno, risposte brevi: «Ask for short summaries back, so twenty
results don't fill your context anyway.»
(https://code.claude.com/docs/en/best-practices); i due formati fissi
servono anche a questo. I test e la verifica girano sul vostro computer,
senza chiamate al modello. I limiti sono gli stessi di claude.ai: «These
limits are shared across Claude and Claude Code, meaning all activity in
both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan),
e fra ciò che pesa ci sono il modello e l'effort: «Additional factors that
affect your usage limits include: … Tool usage (e.g., Research, web
search) | Model choice | Effort level»
(https://support.claude.com/en/articles/9797557-usage-limit-best-practices).

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `claude -p` sull'account del docente), dal JSON di ogni
chiamata: cinque chiamate, quattro nella prima parte e una nella
seconda, con 12, 10, 8, 4 e 6 turni del modello (`num_turns`); 49,6,
40,8, 29,2, 20,3 e 24,8 secondi; token in entrata della conversazione
principale, cache compresa, 138.804, 558.130, 434.250, 300.882 e
207.524. I token dei subagent si aggiungono a questi.

## Per approfondire

- La pagina delle best practice di Claude Code, con i subagent:
  https://code.claude.com/docs/en/best-practices
- I subagent: https://code.claude.com/docs/en/sub-agents
- I flussi di lavoro, con plan mode e la ripresa delle sessioni:
  https://code.claude.com/docs/en/common-workflows ·
  https://code.claude.com/docs/en/sessions
- Le modalità di permesso: https://code.claude.com/docs/en/permission-modes
- Il corso «Claude Code 101» dell'Academy, Explore, Plan, Code, Commit:
  https://academy.claude.com/courses/claude-code-101/the-explore-plan-code-commit-workflow
- Il corso dell'Academy sui subagent:
  https://academy.claude.com/courses/introduction-to-subagents/designing-effective-subagents
- Un giudice per il codice, nell'articolo di Anthropic sulle migrazioni:
  https://claude.com/resources/articles/ai-code-migration
