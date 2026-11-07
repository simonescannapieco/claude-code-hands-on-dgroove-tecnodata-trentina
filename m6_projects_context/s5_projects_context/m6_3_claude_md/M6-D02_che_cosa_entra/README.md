# M6-D02 — Che cosa entra all'avvio, e che cosa quando serve

Demo del Modulo 6, nella parte «CLAUDE.md: istruzioni che si caricano
sempre». Il docente la fa girare in aula; potete rifarla da soli quando volete,
con lo stesso comando.

## Obiettivo

Mettere alla prova ciò che la documentazione di Claude Code dice su quali file
di istruzioni entrano nel contesto all'avvio di una sessione e quali solo
quando servono. Un piccolo progetto ha nove parole in codice, casuali, in nove
posti: il CLAUDE.md della radice, un commento HTML a blocco dentro di esso, un
file che il CLAUDE.md importa con `@`, un percorso citato fra backtick, il
CLAUDE.local.md, una regola senza `paths`, una regola con `paths`, il
CLAUDE.md di una sottocartella e un file di testo che Claude legge. Un hook
`InstructionsLoaded` registra ogni file di istruzioni che si carica, con il
motivo. Si chiede a Claude quali parole vede, una volta senza strumenti e una
volta dopo aver letto due file; un controllo legge il registro e le risposte e
decide. Sono garanzie del prodotto: devono valere a ogni esecuzione. Poi
quattro bracci, con la stessa domanda breve, misurano quanto pesano nel
contesto un commento, lo stesso testo visibile e lo stesso testo importato.

## Tempo

3 minuti in aula, la demo del docente: un'esecuzione, sei chiamate brevi. Per
rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M6-D02)

Lo spazio di lavoro `~/corso-claude-code/M6-D02/` con:

- `progetto/`: il piccolo progetto dei nove posti. Al posto di ogni parola c'è
  un segnaposto, `__RADICE__`, `__COMMENTO__` e così via: le parole non stanno
  nel repository, `in_classe.sh` le genera quando parte, nuove per ogni
  chiamata, e nessuno le conosce prima.

  | posto | dove sta la parola |
  |---|---|
  | radice | `CLAUDE.md`, una riga |
  | commento | `CLAUDE.md`, in un commento `<!-- … -->` su righe sue |
  | importato | `docs/glossario.md`, che `CLAUDE.md` importa con `@docs/glossario.md` |
  | fra backtick | `docs/escluso.md`, che `CLAUDE.md` cita fra backtick, `` `@docs/escluso.md` `` |
  | locale | `CLAUDE.local.md` |
  | regola | `.claude/rules/generale.md`, senza frontmatter |
  | regola PHP | `.claude/rules/php.md`, con `paths: ["**/*.php"]` nel frontmatter |
  | sub/CLAUDE.md | `sub/CLAUDE.md` |
  | file letto | `sub/nota.txt`, un file di testo qualunque |

  Poi `src/a.php`, un file PHP senza parole, e `.claude/`: `settings.json`,
  con l'hook `InstructionsLoaded` e le impostazioni prudenti del corso, e
  `hooks/registra_caricamenti.py`, la copia dello script di `tools/` del
  repository, che scrive una riga per ogni caricamento in
  `.claude/caricamenti.jsonl`: il motivo, il file, il file che l'ha fatto
  caricare;
- `costo/`: i quattro `CLAUDE.md` dei bracci di costo, in `base/`,
  `commento/`, `inline/` e `import/`, e `procedura.md`, il testo: la scheda
  KB-10 della base di conoscenza dell'assistenza di CiaspoLink
  (`progetti/assistenza-clienti/kb/kb-10-trasloco.md`), byte per byte, 2.188
  byte;

  | braccio | `CLAUDE.md` |
  |---|---|
  | `base` | un titolo e una riga di istruzioni |
  | `commento` | gli stessi, poi `procedura.md` fra `<!--` e `-->` |
  | `inline` | gli stessi, poi `procedura.md`, visibile |
  | `import` | gli stessi, poi la riga `@docs/procedura.md` |

  Ogni braccio ha anche `docs/procedura.md`: i quattro differiscono soltanto
  nel `CLAUDE.md`;
- `domanda_avvio.txt`, `domanda_lettura.txt`, `domanda_costo.txt`: le tre
  richieste;
- `in_classe.sh` e `lib_caricamento.sh`: la demo; `controlla_caricamento.py`:
  il controllo.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro e lanciate la
   demo:

       tools/prepara_esercizio.sh M6-D02
       m6_projects_context/s5_projects_context/m6_3_claude_md/M6-D02_che_cosa_entra/demo/in_classe.sh ~/corso-claude-code/M6-D02

   Lo script mostra ogni comando prima di eseguirlo e, su un terminale, si
   ferma prima di ogni gruppo di chiamate (`HANDSON_NO_PAUSE=1` per non
   fermarsi). Ogni chiamata gira in una copia nuova, in una cartella
   temporanea fuori dallo spazio di lavoro: un repository git con un commit,
   le sue parole al posto dei segnaposto, il registro dell'hook vuoto. È una
   sessione nuova di `claude -p`, con Sonnet ed effort low, in `dontAsk`, con
   le sole impostazioni di progetto e locali, senza server MCP, senza salvare
   la sessione e con l'auto memory, la memoria automatica del Modulo 4, spenta:

   | chiamata | strumenti | richiesta |
   |---|---|---|
   | `avvio-1` | nessuno, `--tools ""` | `domanda_avvio.txt` |
   | `lettura-1` | solo `Read` | `domanda_lettura.txt` |
   | `costo-base`, `costo-commento`, `costo-inline`, `costo-import` | nessuno | `domanda_costo.txt` |

   I quattro bracci di costo girano uno dopo l'altro nella stessa cartella,
   con lo stesso messaggio di commit: le quattro copie hanno lo stesso
   percorso e differiscono soltanto nel `CLAUDE.md`. Le richieste sono testi
   sotto prova, e restano così come sono:

   <!-- prompt 1 -->

       Elenca tutte le parole in codice che compaiono nelle tue istruzioni di progetto (non nei file che leggi), una per riga, senza commenti. Se non ne vedi nessuna, rispondi NON LA SO.

   <!-- /prompt 1 -->

   <!-- prompt 2 -->

       Leggi il file src/a.php e il file sub/nota.txt, senza leggere altri file. Poi elenca tutte le parole in codice che compaiono nelle tue istruzioni di progetto (non nei file che hai letto), una per riga, senza commenti. Se non ne vedi nessuna, rispondi NON LA SO.

   <!-- /prompt 2 -->

   <!-- prompt 3 -->

       Rispondi solo: ok

   <!-- /prompt 3 -->

2. La verifica, dalla cartella `esercitazioni`:

       tools/verifica.sh M6-D02

`_docente/live.sh` lancia lo stesso `in_classe.sh` con tre esecuzioni di
`avvio` e di `lettura`: `PN_ESECUZIONI` ne sceglie da 1 a 9. I bracci di costo
girano una volta.

Perché `claude -p` e non una sessione aperta a mano: ciò che si carica è lo
stesso, «Without it, claude -p discovers and loads them as an interactive
session would» («it» è `--bare`, https://code.claude.com/docs/en/headless), e
qui ogni chiamata è una sessione nuova, il suo stream dice che cosa ha fatto
Claude e il registro dell'hook che cosa si è caricato.

## Che cosa osservare

### Che cosa dice Anthropic

Da «How Claude remembers your project», https://code.claude.com/docs/en/memory:

- **All'avvio, e quando serve.** «CLAUDE.md and CLAUDE.local.md files in the
  directory hierarchy above the working directory are loaded at launch. Files
  in subdirectories load on demand.» E delle sottocartelle: «Instead of loading
  them at launch, Claude Code loads each one once Claude reads, writes, or
  edits another file in that subdirectory.» Del file locale: «Within each
  directory, CLAUDE.local.md is appended after CLAUDE.md, so your personal
  notes are the last thing Claude reads at that level.»
- **Gli import.** «CLAUDE.md files can import additional files using
  @path/to/import syntax.» E: «Import parsing skips Markdown code spans and
  fenced code blocks. To mention a path in your CLAUDE.md without importing it,
  wrap it in backticks». Sul loro costo: «Imports help you organize a long file
  but don't reduce its context cost, because imported files load together with
  the CLAUDE.md that imports them.»
- **I commenti.** «Block-level HTML comments (`<!-- maintainer notes -->`) in
  CLAUDE.md files are stripped before the content is injected into Claude's
  context.» Però: «When you open a CLAUDE.md file directly with the Read tool,
  comments remain visible.» Per questo la garanzia del commento si decide
  nella chiamata che non può leggere file.
- **Le regole.** «Rules without paths frontmatter are loaded at launch with the
  same priority as .claude/CLAUDE.md.» Quelle con `paths`: «Rules can also be
  scoped to specific file paths, so they only load into context when Claude
  works with matching files», e «A path-scoped rule loads when Claude uses the
  Read, Write, or Edit tool on a matching file.»
- **L'hook.** «Use the InstructionsLoaded hook to log which CLAUDE.md and rules
  files are loaded, when they load, and why.»

Da «Hooks reference», https://code.claude.com/docs/en/hooks:

- «InstructionsLoaded | When a CLAUDE.md or .claude/rules/*.md file is loaded
  into context. Fires at session start and when files are lazily loaded during
  a session»;
- «load_reason | Why the file was loaded: "session_start", "nested_traversal",
  "path_glob_match", "include", or "compact"»;
- «trigger_file_path | Path to the file whose access triggered this load, for
  lazy loads», «parent_file_path | Path to the parent instruction file that
  included this one, for include loads» e «globs | Path glob patterns from the
  file's paths: frontmatter, if any. Present only for path_glob_match loads»;
- «The hook doesn't support blocking or decision control. It runs
  asynchronously for observability purposes.»

Come si leggono le esecuzioni:

- `--tools ""`: «Specify the list of available tools from the built-in set. Use
  "" to disable all tools» (`claude --help`, versione 2.1.319).
- `--setting-sources project,local`: «Comma-separated list of setting sources
  to load (user, project, local).» (`claude --help`). `local` c'è per il
  CLAUDE.local.md della cartella di lavoro: «Local | `<cwd>/CLAUDE.local.md`
  and `CLAUDE.local.md` in every parent directory | `settingSources` includes
  `"local"`» (https://code.claude.com/docs/en/agent-sdk/claude-code-features)
- `--no-session-persistence`: «Disable session persistence - sessions will not
  be saved to disk and cannot be resumed (only works with --print)»
  (`claude --help`).
- L'auto memory spenta, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`: «Set to 1 to
  disable auto memory.» (https://code.claude.com/docs/en/env-vars)
- La prima richiesta: «total_input_tokens = cache_read_input_tokens +
  cache_creation_input_tokens + input_tokens»
  (https://platform.claude.com/docs/en/build-with-claude/prompt-caching), dal
  primo messaggio dell'assistente della conversazione principale.

### Che cosa misura il controllo

`controlla_caricamento.py` legge, in `risposte/`, lo stream, il registro
dell'hook e le parole di ogni chiamata, e per le chiamate `avvio` e `lettura`
decide, esecuzione per esecuzione:

- all'avvio, `session_start` per `CLAUDE.md`, `CLAUDE.local.md` e
  `.claude/rules/generale.md` (avvio e lettura);
- `include` di `docs/glossario.md`, con `parent_file_path` `CLAUDE.md` (avvio e
  lettura);
- `docs/escluso.md` mai nel registro (avvio e lettura) e, in avvio, la sua
  parola non nella risposta;
- in avvio, che non può leggere file, la parola del commento non nella
  risposta;
- in avvio né `.claude/rules/php.md` né `sub/CLAUDE.md` nel registro, né le
  loro parole nella risposta;
- in lettura, dopo il `Read` di `src/a.php`, `path_glob_match` di
  `.claude/rules/php.md` con `trigger_file_path` `src/a.php`;
- in lettura, dopo il `Read` di `sub/nota.txt`, `nested_traversal` di
  `sub/CLAUDE.md` con `trigger_file_path` `sub/nota.txt`.

Una garanzia che non regge è «non confermata in questa esecuzione»: un esito
da segnalare, e il controllo esce con 1. Un'esecuzione che non la mette alla
prova è «non distinguibile», con il perché: la risposta non ha la parola della
radice (Claude non ha detto che cosa vede, e allora l'assenza della parola del
commento non direbbe niente), oppure Claude non ha letto il file. Anche lì il
controllo esce con 1, e la demo si rifà.

Come dati, mai come esito né come uscita: le parole che ogni risposta riporta,
posto per posto; gli strumenti; i caricamenti, nell'ordine in cui l'hook li ha
scritti; la prima richiesta; turni, token e secondi. La parola di
`sub/nota.txt` arriva a Claude con il `Read`, ma non è un file di istruzioni e
il registro non lo nomina: se Claude la elenca è un dato. Dei quattro bracci
di costo, la prima richiesta di ognuno, il commento sul braccio base, lo
stesso testo visibile e l'import contro il testo incollato, con «import ≥
inline: sì» o «no»: nessuna delle frasi dà una soglia in token.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet
con effort low, tre esecuzioni e dieci chiamate, `_docente/live.sh`
sull'account del docente), ogni garanzia a ogni esecuzione:

- «All'avvio si caricano CLAUDE.md, CLAUDE.local.md e la regola senza paths:
  confermata 6 su 6»;
- «Il file importato con @ si carica con CLAUDE.md: confermata 6 su 6»;
- «Un percorso fra backtick non si importa: confermata 6 su 6»;
- «Il commento HTML a blocco non entra nel contesto: confermata 3 su 3»;
- «La regola con paths e il CLAUDE.md di sub/ non si caricano all'avvio:
  confermata 3 su 3»;
- «La regola con paths si carica quando Claude legge un file che corrisponde:
  confermata 3 su 3»;
- «Il CLAUDE.md di sub/ si carica quando Claude legge un file di sub/:
  confermata 3 su 3»;

e «Ogni garanzia è confermata in ogni esecuzione.» Come dati: senza strumenti
le risposte hanno le parole della radice, dell'import, del file locale e della
regola senza paths, 3 su 3; dopo i due `Read` anche quelle della regola PHP e
di `sub/CLAUDE.md`, 3 su 3; la parola di `sub/nota.txt` in nessuna, 0 su 3. I
costi: «Come dato, la prima richiesta dei bracci di costo, «Rispondi solo:
ok»: base 2.365 token; commento 2.365 token; inline 3.316 token; import 3.389
token.», «Come dato, il commento a blocco sul braccio base: +0 token; lo
stesso testo visibile (inline): +951.» e «Come dato, l'import contro lo stesso
testo incollato: +73 token (import ≥ inline: sì).» Gli stream, i registri e le
parole della registrazione stanno nella cartella `soluzione/risposte/` di
questo elemento (nel repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M6-D02)

La verifica fa girare `controlla_caricamento.py` dell'elemento, non la copia
dello spazio di lavoro, sui file di `risposte/` dello spazio di lavoro. È fatta
quando ci sono almeno un'esecuzione completa e i quattro bracci di costo, ogni
stream è lo stream-json riuscito di `claude -p` e ogni garanzia è confermata a
ogni esecuzione. Le ultime due righe sono allora «Fatto: ogni garanzia è stata
messa alla prova; gli esiti sono qui sopra.» e «VERIFICA OK   M6-D02: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo;
  gli stream vanno in `risposte/` soltanto quando l'ultima chiamata è finita.
- `in_classe.sh` dice che `risposte/` c'è già, o che lo spazio di lavoro non è
  al punto di partenza: per ricominciare, `tools/reset_esercizio.sh M6-D02`.
- La verifica dice che uno stream, un registro o le parole mancano o non vanno:
  una chiamata si è fermata a metà; ricominciate da capo, come sopra.
- Una garanzia è «non distinguibile»: leggete il perché nella sua riga, poi
  ricominciate. Se torna, segnalatelo: la demo non sta mettendo alla prova ciò
  che dice.
- Una garanzia è «non confermata»: è un esito da segnalare al docente, con lo
  stream e il registro di `risposte/` che la riga nomina.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent. Un'esecuzione sono sei chiamate di
`claude -p`: una senza strumenti, di un turno; una con due `Read`, di tre
turni; quattro brevi, di un turno; la prova del docente ne fa dieci. Sul Pro
il modello predefinito di Claude Code è un altro, «Pro, Max, Ultra, Team,
Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config): la demo sceglie Sonnet con
`--model sonnet`, come le altre del corso, perché la registrazione e le vostre
prove usino lo stesso modello. Nessuna sessione resta salvata: tutte hanno
`--no-session-persistence`.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet
con effort low, `_docente/live.sh` sull'account del docente, un piano Max), dal
`result` di ogni stream: «Come dato, tutte le 10 chiamate: turni 16; token
46.625; 23,2 s.» La prima richiesta va da 2.825 a 2.833 token senza strumenti,
da 3.947 a 3.959 con `Read`, da 2.365 a 3.389 nei bracci di costo. Sono i
token di ogni chiamata, entrata, cache e uscita, compreso il contesto letto
dalla cache: dicono quanto lavoro è stato, non un prezzo, e non quanta parte
del vostro piano occupa. Contano tutti i modelli: «Use modelUsage, or
model_usage in Python, for whole-tree token accounting; the usage field
undercounts as soon as nesting occurs.»
(https://code.claude.com/docs/en/agent-sdk/cost-tracking). Rifarla da soli
costa un'esecuzione, sei chiamate.

## Per approfondire

- «How Claude remembers your project», CLAUDE.md, import, regole e commenti:
  https://code.claude.com/docs/en/memory
- «Hooks reference», l'evento InstructionsLoaded:
  https://code.claude.com/docs/en/hooks
- «Run Claude Code programmatically», `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- «Explore the context window», che cosa c'è nel contesto e quando:
  https://code.claude.com/docs/en/context-window
