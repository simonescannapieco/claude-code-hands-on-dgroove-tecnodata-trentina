# M6-D04 — Una modifica a sessione avviata, e dopo /compact

Demo del Modulo 6, nella parte «Il budget del contesto». Il docente la fa
girare in aula; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Mettere alla prova che cosa dice la documentazione di Claude Code di un
CLAUDE.md in una sessione che resta aperta: una modifica fatta da fuori a
sessione avviata non vale fino al `/compact` o al `/clear` successivo; dopo
`/compact` il CLAUDE.md della radice si rilegge dal disco; una regola con
`paths` si carica quando Claude legge un file che le corrisponde. Tre
sessioni, ognuna un solo processo di Claude Code che riceve i messaggi uno
alla volta, come una sessione che tenete aperta voi; un hook
`InstructionsLoaded` registra ogni file di istruzioni che si carica, con il
motivo. Un controllo legge le risposte e il registro e decide. Sono garanzie
del prodotto: devono valere a ogni esecuzione. Della regola con `paths` dopo
`/compact` il controllo non decide: riporta, come reperto, che cosa hanno
trovato le esecuzioni.

## Tempo

3 minuti in aula, la demo del docente: un'esecuzione, tre sessioni di cinque
passi. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M6-D04)

Lo spazio di lavoro `~/corso-claude-code/M6-D04/` con:

- `progetto/`: `CLAUDE.md`, con una parola in codice al posto del segnaposto
  `__RADICE__`; `.claude/rules/php.md`, una regola con `paths: ["**/*.php"]` e
  la sua parola, `__REGOLAPHP__`; `src/a.php`, un file PHP di prova; e
  `.claude/`, con `settings.json` (l'hook `InstructionsLoaded` e le
  impostazioni prudenti del corso) e `hooks/registra_caricamenti.py`, la copia
  dello script di `tools/` del repository, che scrive una riga per ogni
  caricamento in `.claude/caricamenti.jsonl`. Le parole non stanno nel
  repository: `sessione.py` le genera quando parte, nuove per ogni sessione;
- `domanda.txt`, `leggi.txt`, `elenca.txt`: i tre testi;
- `in_classe.sh`: la demo; `sessione.py`: una sessione;
  `controlla_sessione.py`: il controllo.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro e lanciate la
   demo:

       tools/prepara_esercizio.sh M6-D04
       m6_projects_context/s5_projects_context/m6_6_budget_del_contesto/M6-D04_modifica_e_compact/demo/in_classe.sh ~/corso-claude-code/M6-D04

   Per ogni sessione `in_classe.sh` mostra il comando di `sessione.py` e, su un
   terminale, si ferma prima di eseguirlo (`HANDSON_NO_PAUSE=1` per non
   fermarsi); `sessione.py` mostra il comando di `claude` e ogni passo, con la
   risposta. Ogni sessione gira in una copia nuova di `progetto/`, in una
   cartella temporanea fuori dallo spazio di lavoro, un repository git con un
   commit; un solo processo, con Sonnet ed effort low, in `dontAsk`, con le
   sole impostazioni di progetto e locali, senza server MCP, senza salvare la
   sessione e con l'auto memory, la memoria automatica del Modulo 4, spenta:

       claude -p --input-format stream-json --output-format stream-json --verbose …

   | sessione | strumenti | i cinque passi |
   |---|---|---|
   | `compact-1` | nessuno, `--tools ""` | 1 la domanda; 2 `CLAUDE.md` riscritto da fuori, con una parola nuova al posto di quella di prima; 3 la domanda; 4 `/compact`; 5 la domanda |
   | `clear-1` | nessuno, `--tools ""` | gli stessi, con `/clear` al passo 4 |
   | `regola-1` | solo `Read` | 1 leggi `src/a.php`; 2 `/compact`; 3 elenca le parole; 4 leggi `src/a.php`; 5 elenca le parole |

   I testi sono sotto prova, e restano così come sono: la domanda,

   <!-- prompt 1 -->

       Senza leggere file, qual è la parola in codice delle tue istruzioni di progetto? Rispondi solo con la parola.

   <!-- /prompt 1 -->

   la lettura,

   <!-- prompt 2 -->

       Leggi src/a.php, senza leggere altri file, e rispondi solo: letto

   <!-- /prompt 2 -->

   e l'elenco.

   <!-- prompt 3 -->

       Senza leggere file, elenca tutte le parole in codice che compaiono nelle tue istruzioni di progetto, una per riga. Se non ne vedi nessuna, rispondi NON LA SO.

   <!-- /prompt 3 -->

2. La verifica, dalla cartella `esercitazioni`:

       tools/verifica.sh M6-D04

`_docente/live.sh` lancia lo stesso `in_classe.sh` con tre esecuzioni, nove
sessioni: `PN_ESECUZIONI` ne sceglie da 1 a 9.

Perché un solo processo con `--input-format stream-json`: «Input format (only
works with --print): "text" (default), or "stream-json" (realtime streaming
input)» (`claude --help`, versione 2.1.319). La sessione resta aperta fra un
messaggio e l'altro, come quella che usate voi, mentre il file cambia da
fuori. Con `--resume`, che riprende una conversazione precisa («--resume with a
session ID to continue a specific conversation», da «Run Claude Code
programmatically», https://code.claude.com/docs/en/headless), ogni messaggio
sarebbe un `claude -p` nuovo, un processo nuovo: la sessione non resterebbe
aperta, e la demo non metterebbe più alla prova la frase qui sotto. Se una
conversazione ripresa con `--resume` rilegga il `CLAUDE.md` modificato, le
pagine di Anthropic lette per il corso non lo dicono.

## Che cosa osservare

### Che cosa dice Anthropic

Da «How Claude Code uses prompt caching»,
https://code.claude.com/docs/en/prompt-caching: «Your project-root and
user-level CLAUDE.md files are read once at session start and held in memory.
Editing them mid-session does not invalidate the cache, but the edit also
doesn't apply. Claude keeps working with the version that was loaded at session
start. The new content loads on the next /clear, /compact, or restart.»

Da «How Claude remembers your project», https://code.claude.com/docs/en/memory:
«Project-root CLAUDE.md survives compaction: after /compact, Claude re-reads it
from disk and re-injects it into the session.»

Da «Explore the context window», https://code.claude.com/docs/en/context-window,
la tabella di che cosa resta dopo la compaction: «Project-root CLAUDE.md and
unscoped rules | Re-injected from disk» e «Rules with paths: frontmatter |
Claude Code reloads them on demand». E sotto: «Path-scoped rules and nested
CLAUDE.md files load into message history when Claude reads, writes, or edits
their trigger file, so compaction summarizes them away».

La prova del corso del 7 novembre 2026, con Claude Code 2.1.319, in una
sessione sola, ha trovato questo: dopo `/compact` il registro non ha nessun
caricamento della regola al `Read` di un file che le corrisponde, 3 su 3, e la
parola della regola è nella risposta subito dopo `/compact`, 3 su 3. Un'altra
versione di Claude Code, o una sessione ripresa con `--resume`, dove ogni
messaggio è un processo nuovo, può comportarsi diversamente: il docente rifà la
prova prima di ogni edizione del corso.

Di `/clear`, da «Commands», https://code.claude.com/docs/en/commands: «/clear
[name] | Start a new conversation with empty context.»

Da «Hooks reference», https://code.claude.com/docs/en/hooks: «load_reason | Why
the file was loaded: "session_start", "nested_traversal", "path_glob_match",
"include", or "compact"», e del motivo `compact`: «The "compact" value fires
when instruction files are re-loaded after a compaction event». L'hook «runs
asynchronously for observability purposes»: per questo `sessione.py`, dopo ogni
risultato, aspetta che il registro resti fermo prima di segnare quante righe
ha.

Come si leggono le esecuzioni:

- `--tools ""`: «Specify the list of available tools from the built-in set. Use
  "" to disable all tools» (`claude --help`).
- `--no-session-persistence`: «Disable session persistence - sessions will not
  be saved to disk and cannot be resumed (only works with --print)»
  (`claude --help`).
- L'auto memory spenta, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`: «Set to 1 to
  disable auto memory.» (https://code.claude.com/docs/en/env-vars)

### Che cosa misura il controllo

`controlla_sessione.py` legge, in `risposte/`, lo stream, il registro dell'hook
e i passi di ogni sessione (`<nome>.sessione.json`: le parole, i testi mandati
e quante righe aveva il registro alla fine di ogni passo, così ogni
caricamento appartiene a un passo). Decide, sessione per sessione:

- `compact` e `clear`: dopo la modifica (passo 3) la risposta ha ancora la
  parola caricata all'avvio, non quella nuova;
- `compact` e `regola`: dopo `/compact` il registro ha un caricamento `compact`
  di `CLAUDE.md`;
- `compact`: dopo `/compact` (passo 5) la risposta ha la parola nuova;
- `clear`: dopo `/clear` (passo 5) la risposta ha la parola nuova, e non quella
  di prima;
- `regola`: dopo il `Read` di `src/a.php` (passo 1) un `path_glob_match` di
  `.claude/rules/php.md` con `trigger_file_path` `src/a.php`.

Una garanzia che non regge è «non confermata in questa esecuzione»: un esito
da segnalare, e il controllo esce con 1. Una sessione che non la mette alla
prova è «non distinguibile», con il perché: la prima risposta non ha la
parola, `/compact` non ha compattato, `/clear` non ha aperto una conversazione
nuova, Claude non ha letto il file. Anche lì il controllo esce con 1, e la demo
si rifà.

Dopo le garanzie il controllo stampa un reperto, mai un esito né un'uscita:
la data e la versione delle esecuzioni che legge, in quante sessioni `regola`
il registro non ha nessun caricamento della regola dopo `/compact`, con il
`Read` di `src/a.php` del passo 4 riuscito, e in quante la parola della regola
è nella risposta subito dopo `/compact`.

Come dati, mai come esito né come uscita: per ogni passo la risposta, le
parole che vi compaiono, i `Read`, i caricamenti, i turni e i secondi; i token
prima e dopo la compaction, e quali parole porta il riassunto; per la regola,
se la sua parola c'è nella risposta dopo `/compact`, prima e dopo aver riletto
`src/a.php`, e i suoi caricamenti dopo `/compact`; per ogni sessione turni,
secondi e token, sommati su ogni risultato: i token di
`model_usage_since_last_result`, tutti i modelli, compresa la richiesta della
compaction, e accanto quelli di `usage`.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet
con effort low, tre esecuzioni e nove sessioni, `_docente/live.sh`
sull'account del docente):

- «Una modifica a CLAUDE.md a sessione avviata non si applica: confermata 6 su
  6»;
- «Dopo /compact il CLAUDE.md della radice si rilegge dal disco: confermata 6
  su 6»;
- «Il contenuto nuovo si carica al /compact successivo: confermata 3 su 3»;
- «Il contenuto nuovo si carica al /clear successivo: confermata 3 su 3»;
- «La regola con paths si carica quando Claude legge un file che corrisponde:
  confermata 3 su 3»;

e «Ogni garanzia è confermata in ogni esecuzione.» Dopo le garanzie, il
reperto, così come il controllo lo stampa:

    Reperto: la pagina dice «Rules with paths: frontmatter | Claude Code reloads them on demand» e «Path-scoped rules and nested CLAUDE.md files load into message history when Claude reads, writes, or edits their trigger file, so compaction summarizes them away» (https://code.claude.com/docs/en/context-window); in queste esecuzioni, del 7 novembre 2026, con Claude Code 2.1.319, in una sessione sola: nessun caricamento della regola dopo /compact al Read di un file che corrisponde, 3 su 3, e la parola della regola nella risposta subito dopo /compact, 3 su 3.

Come dati, nelle sessioni della regola: «nel riassunto: radice sì; regola sì»,
3 su 3, «Come dato, la parola della regola nella risposta dopo /compact, prima
di rileggere src/a.php: sì; dopo averlo riletto: sì.», 3 su 3, e «Come dato, i
caricamenti della regola dopo /compact: nessuno.», 3 su 3. Nelle sessioni
`compact` il riassunto porta la parola di prima, «nel riassunto: prima sì;
nuova no», e la risposta dopo `/compact` ha quella nuova, 3 su 3. Gli stream, i
registri e i passi della registrazione stanno nella cartella
`soluzione/risposte/` di questo elemento (nel repository del corso; la copia
senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M6-D04)

La verifica fa girare `controlla_sessione.py` dell'elemento, non la copia
dello spazio di lavoro, sui file di `risposte/` dello spazio di lavoro. È fatta
quando c'è almeno un'esecuzione completa, ogni stream ha un risultato riuscito
per ogni messaggio e ogni garanzia è confermata a ogni esecuzione. Le ultime
due righe sono allora «Fatto: ogni garanzia è stata messa alla prova; gli
esiti sono qui sopra.» e «VERIFICA OK   M6-D04: fatto.» Il reperto sulla regola
dopo `/compact` si stampa e non decide l'uscita.

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo;
  gli stream vanno in `risposte/` soltanto quando l'ultima sessione è finita.
- `in_classe.sh` dice che `risposte/` c'è già, o che lo spazio di lavoro non è
  al punto di partenza: per ricominciare, `tools/reset_esercizio.sh M6-D04`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `sessione.py` dice «nessun risultato in 300 secondi», o che claude si è
  fermato prima del risultato: la sessione si è bloccata; ricominciate da capo,
  come sopra. `PN_SESSIONE_ATTESA` dà a ogni passo più tempo.
- La verifica dice che una sessione manca o non va (un risultato in meno dei
  messaggi, i passi a metà): una sessione si è fermata; ricominciate da capo.
- Una garanzia è «non distinguibile»: leggete il perché nella sua riga, poi
  ricominciate. Se torna, segnalatelo: la demo non sta mettendo alla prova ciò
  che dice.
- Una garanzia è «non confermata»: è un esito da segnalare al docente, con i
  file di `risposte/` che la riga nomina.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent. Un'esecuzione sono tre sessioni, tre
processi di `claude -p`, con quattro o cinque messaggi brevi e una
compaction ciascuna, tranne quella con `/clear`; la prova del docente ne fa
nove. Sul Pro il modello predefinito di Claude Code è un altro, «Pro, Max,
Ultra, Team, Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config): la demo sceglie Sonnet con
`--model sonnet`, come le altre del corso, perché la registrazione e le vostre
prove usino lo stesso modello. Nessuna sessione resta salvata: tutte hanno
`--no-session-persistence`.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet
con effort low, `_docente/live.sh` sull'account del docente, un piano Max):
«Come dato, tutte le 9 sessioni: turni 36; token 168.204 (usage 132.038);
100,5 s.» Una sessione `compact` costa circa 13.600 token, una `clear` 7.500,
una `regola` 35.000. I token sono quelli di ogni richiesta, entrata, cache e
uscita, compreso il contesto letto dalla cache: dicono quanto lavoro è stato,
non un prezzo, e non quanta parte del vostro piano occupa. Contano tutti i
modelli, «Use modelUsage, or model_usage in Python, for whole-tree token
accounting; the usage field undercounts as soon as nesting occurs.»
(https://code.claude.com/docs/en/agent-sdk/cost-tracking), e la compaction è
anch'essa una richiesta al modello: lo stream la conta in
`model_usage_since_last_result`, non in `usage`, che lì è zero. Rifarla da
soli costa un'esecuzione, tre sessioni.

## Per approfondire

- «How Claude Code uses prompt caching», che cosa succede a una modifica a
  sessione avviata: https://code.claude.com/docs/en/prompt-caching
- «Explore the context window», che cosa resta dopo la compaction:
  https://code.claude.com/docs/en/context-window
- «How Claude remembers your project», CLAUDE.md e regole:
  https://code.claude.com/docs/en/memory
- «Hooks reference», l'evento InstructionsLoaded:
  https://code.claude.com/docs/en/hooks
