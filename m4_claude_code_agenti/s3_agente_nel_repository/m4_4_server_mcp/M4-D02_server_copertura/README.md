# M4-D02 — Un server MCP per la copertura

Demo del Modulo 4, nella parte «Un server MCP». In aula il docente mostra
la stessa domanda con e senza il server; poi aggiungete voi il server a
Claude Code e gli fate la domanda.

## Obiettivo

Dare a Claude Code l'accesso ai dati di un sistema che non vede: la
copertura del gestionale di CiaspoLink, attraverso un server MCP scritto
per il corso, `server/server_copertura.py`. Il docente fa la stessa
domanda a Claude Code due volte: con il server dichiarato e senza. Le due
esecuzioni differiscono soltanto nella configurazione MCP. Voi aggiungete
il server con `claude mcp add` e lo interrogate in una sessione.

## Tempo

5 minuti in aula: 3 per la demo del docente, mentre voi preparate lo
spazio di lavoro e lanciate il passo 1, e 2 per la vostra prova. Chi non
finisce in aula continua da solo, con questo README: i passi sono gli
stessi. Circa 3 minuti per rifarla da soli, con l'ambiente del server
pronto.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`): fra l'altro controlla `uv`, che
  serve qui.
- Per il passo 1, una volta sola, la rete: `uv sync` scarica FastMCP e le
  sue dipendenze.
- Python 3, per la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M4-D02)

Lo spazio di lavoro `~/corso-claude-code/M4-D02/` con `domanda.txt`, la
domanda, e nient'altro: nessun dato della copertura. La risposta può
venire soltanto dal server.

Il server sta nella cartella di questo elemento, `server/`, e non viene
copiato nello spazio di lavoro: è un progetto uv con FastMCP 3.4.11, la
versione fissata in `pyproject.toml` e, con tutte le dipendenze, in
`uv.lock`. Espone un solo strumento, `cerca_copertura`, in sola lettura:
per ogni comune e tecnologia (FTTH, la fibra fino a casa; FWA, la radio)
gli indirizzi coperti, cioè con una data di disponibilità, quelli
pianificati, senza data, e la velocità massima. I dati sono quelli
sintetici del gestionale, `progetti/gestionale-php/database/`, che il
server riceve nella variabile d'ambiente `COPERTURA_DATI` e carica
all'avvio in un database SQLite in memoria. Niente rete, niente chiavi.

## Passi in Claude Code

Mentre gira la demo del docente, dalla cartella `esercitazioni`,
preparate lo spazio di lavoro, poi lanciate il passo 1:

    tools/prepara_esercizio.sh M4-D02

1. Una volta sola, ancora dalla cartella `esercitazioni` e mentre la demo
   gira, l'ambiente del server. La prima volta `uv sync` scarica FastMCP e
   le sue dipendenze, e, se il vostro Python è più vecchio della 3.10,
   anche un Python adatto (`--frozen` è spiegato al passo 3):

       uv sync --frozen --directory m4_claude_code_agenti/s3_agente_nel_repository/m4_4_server_mcp/M4-D02_server_copertura/server

2. La vostra prova comincia qui, sempre dalla cartella `esercitazioni`:
   due variabili con i percorsi assoluti del server e dei dati, poi
   entrate nello spazio di lavoro:

       S="$PWD/m4_claude_code_agenti/s3_agente_nel_repository/m4_4_server_mcp/M4-D02_server_copertura/server"
       D="$PWD/progetti/gestionale-php/database"
       cd ~/corso-claude-code/M4-D02

3. Aggiungete il server a Claude Code, nello scope local, quello
   predefinito: vale soltanto in questo spazio di lavoro e soltanto per
   voi. Poi controllate:

       claude mcp add copertura -e COPERTURA_DATI="$D" -- uv run --frozen --directory "$S" server_copertura.py
       claude mcp get copertura

   L'ordine conta: prima il nome, poi `-e` con la variabile, poi `--` e
   il comando che avvia il server. `--frozen`, nella guida di `uv run`:
   «Run without updating the `uv.lock` file». uv usa le versioni di
   `uv.lock` così come sono: un uv diverso da quello del corso non
   riscrive il file, che il repository tiene sotto controllo (lo stesso
   vale per `uv sync --frozen` al passo 1).

4. Aprite Claude Code su Sonnet con effort low, date `/mcp` e guardate il
   server `copertura`; poi incollate la domanda (è anche in
   `domanda.txt`):

       claude --model sonnet --effort low

   <!-- prompt -->

       Quali comuni hanno indirizzi coperti dalla fibra FTTH di CiaspoLink? Rispondi soltanto con l'elenco dei comuni, uno per riga, in ordine alfabetico.

   <!-- /prompt -->

   Se Claude Code vi chiede il permesso di usare lo strumento del
   server, rispondete Yes: è in sola lettura. Poi chiedete di salvare la
   risposta, e approvate la scrittura del file:

       Scrivi quell'elenco, un comune per riga, nel file risposta.txt.

   Uscite con `/exit`.

5. Verificate, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D02

6. Quando avete finito, togliete il server, dallo spazio di lavoro:

       cd ~/corso-claude-code/M4-D02
       claude mcp remove copertura

`_docente/live.sh`, la prova del docente, non usa `claude mcp add`: fa la
domanda di `domanda.txt` sei volte con `claude -p` dallo spazio di
lavoro, tre coppie, con `--strict-mcp-config` e `--mcp-config` su
`con.json` (il server, con `uv run --frozen` e i percorsi assoluti che lo
script scrive al momento) oppure su `senza.json` (nessun server); in tutti
e due i bracci Sonnet, effort low, `--tools Read`,
`--allowedTools mcp__copertura__cerca_copertura`,
`--output-format stream-json --verbose`. Lo spazio di lavoro deve avere
soltanto `domanda.txt` e `.claude/`, e così resta durante le sei
esecuzioni: le due configurazioni e gli stream stanno in una cartella
temporanea sotto `/tmp`, fuori dallo spazio di lavoro, e lo script li
copia in `mcp/` e `risposte/` soltanto dopo l'ultima esecuzione. Il
perché è in «Che cosa osservare».

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina sui server MCP di Claude Code: «MCP servers give Claude
  Code access to your tools, databases, and APIs.» I server MCP danno a
  Claude Code accesso ai vostri strumenti, database e API.
  https://code.claude.com/docs/en/mcp
- Nella stessa pagina, per la prova del docente: «Start the session with
  --strict-mcp-config. Claude Code then uses only the MCP servers you
  pass with --mcp-config.» Con `--strict-mcp-config` Claude Code usa
  soltanto i server passati con `--mcp-config`.
- Nel riferimento degli hook, sul nome degli strumenti: «MCP tools follow
  the naming pattern mcp__<server>__<tool>». Per questo lo strumento del
  server si chiama `mcp__copertura__cerca_copertura`.
  https://code.claude.com/docs/en/hooks
- Come si dichiara un server locale, nella pagina sui server MCP:
  «claude mcp add [options] <name> -- <command> [args...]», dove «the --
  (double dash) separates Claude's own options, such as --transport,
  --env, and --scope, from the command and arguments that run the
  server.» E sull'ordine: «--env accepts multiple KEY=value pairs. If the
  server name comes directly after --env, the CLI reads the name as
  another pair and rejects it». Per questo, nel passo 3, il nome viene
  prima di `-e`, come nell'esempio di `claude mcp add --help`: «claude mcp
  add my-server -e API_KEY=xxx -- npx my-mcp-server».
  https://code.claude.com/docs/en/mcp
- Lo scope del passo 3, nella stessa pagina: «Local scope is the default.
  A local-scoped server loads only in the project where you added it and
  stays private to you.»
- Perché i percorsi assoluti, nella guida al debug della configurazione:
  «Relative file paths in command or args are a frequent cause … they
  resolve against the directory you launched Claude Code from».
  https://code.claude.com/docs/en/debug-your-config
- Di chi fidarsi, ancora nella pagina sui server MCP: «Verify you trust
  each server before connecting it. Servers that fetch external content
  can expose you to prompt injection risk.» E nella pagina sulla
  sicurezza: «We encourage either writing your own MCP servers or using
  MCP servers from providers that you trust.»
  https://code.claude.com/docs/en/security

Perché FastMCP: nella skill di Anthropic per costruire server MCP, fra
gli SDK, «Official TypeScript SDK (@modelcontextprotocol/sdk) | TS/JS |
Default choice. … FastMCP 3.x (fastmcp on PyPI) | Python | User prefers
Python», e uno script locale lanciato sul proprio computer, nell'esempio
con npx o uvx, va bene per gli strumenti personali: «A script launched
via npx / uvx on the user's machine. Fine for personal tools and
prototypes.» Il corso lo lancia con `uv run` dal suo progetto, così la
versione è quella di `uv.lock`.
https://github.com/anthropics/claude-plugins-official/blob/main/plugins/mcp-server-dev/skills/build-mcp-server/SKILL.md

Che cosa legge il controllo nello stream, nella pagina su `claude -p`:
l'evento iniziale `system/init` ha il campo «mcp_servers | array | MCP
servers in the session, each with name and status».
https://code.claude.com/docs/en/headless

### Perché i due bracci hanno soltanto Read, e le risposte entrano alla fine

Le due esecuzioni di una coppia devono differire soltanto nel server. Se
gli stream si salvassero in `risposte/` dentro lo spazio di lavoro mentre
la prova va avanti, la sessione senza il server potrebbe leggere lo stream
che quella con il server ha appena salvato, oppure seguire il percorso dei
dati scritto nella configurazione del server: la sua risposta non
verrebbe più da ciò che sa senza il server, e i due bracci non
differirebbero più soltanto nel server.

Per questo, durante le sei esecuzioni, lo spazio di lavoro ha soltanto
`domanda.txt` e `.claude/`: le configurazioni e gli stream stanno in una
cartella temporanea sotto `/tmp`, e `live.sh` li copia in `mcp/` e
`risposte/` dopo l'ultima esecuzione. E tutti e due i bracci hanno un solo
strumento integrato, `--tools Read`, che basta a guardare nello spazio di
lavoro e non oltre:

- il flag lascia gli strumenti MCP, così il braccio con il server ha
  ancora il suo: «The flag doesn’t affect MCP tools; to deny those too, use
  --disallowedTools "mcp__*".» (https://code.claude.com/docs/en/cli-reference);
- Read legge la cartella da cui si è partiti: «By default, Claude has
  access to files in the directory where you launched it.»
  (https://code.claude.com/docs/en/permissions);
- e il resto, nella modalità della prova, è negato senza chiedere: «If you
  set dontAsk mode, Claude Code auto-denies every tool call that would
  otherwise prompt you»
  (https://code.claude.com/docs/en/permission-modes).

Le chiamate del braccio senza il server, a Read o ad altro, si stampano
come dati: non decidono l'esito.

### Che cosa misura il controllo

`controlla_copertura.py`, nella cartella dell'elemento, calcola la verità
dagli stessi dati del server, fuori dallo spazio di lavoro: i comuni con
almeno un indirizzo coperto dalla fibra FTTH, con una data di
disponibilità. Poi guarda ciò che trova nello spazio di lavoro.

- **La prova del docente**, le sei esecuzioni in `risposte/`: dall'evento
  `system/init` di ciascuna i server MCP della sessione, con il loro
  stato, e l'elenco degli strumenti; dai blocchi `tool_use` gli strumenti
  chiamati. Due garanzie, ciascuna confermata o non confermata in questa
  esecuzione, e una non confermata fa uscire la verifica con 1:
  - «Con --strict-mcp-config, solo i server di --mcp-config»: con il
    server, nella sessione c'è esattamente il server `copertura`; senza,
    nessun server MCP, nessuno strumento `mcp__` nell'elenco e nessuna
    chiamata `mcp__`;
  - «Gli strumenti MCP si chiamano mcp__<server>__<tool>»: con il server,
    `mcp__copertura__cerca_copertura` è nell'elenco degli strumenti, e
    ogni strumento o chiamata che porta il nome `cerca_copertura` si
    chiama proprio così.

  Se con il server lo stato non è `connected`, il server non si è
  collegato: la prova non è andata come quella registrata, e il nome non
  si decide. Sono dati, «n su 3», e non decidono l'esito: se Claude ha
  chiamato lo strumento del server, e se la risposta nomina esattamente i
  comuni giusti, con il server e senza. Dei comuni di ogni risposta il
  controllo stampa quanti sono giusti e quanti mancano, e nomina quelli in
  più.
- **La vostra prova**: `claude mcp get copertura`, una chiamata alla CLI e
  non al modello, deve dire che il server è configurato nello spazio di
  lavoro, e `risposta.txt` deve nominare esattamente i comuni giusti.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low, tre coppie): in
ognuna delle tre esecuzioni con il server, `copertura (connected)`, una
chiamata a `mcp__copertura__cerca_copertura` e «13 comuni nominati, giusti
13 su 13, mancano 0, in più nessuno»; in ognuna delle tre senza, nessun
server, due chiamate a Read e nessun comune. «Con --strict-mcp-config,
solo i server di --mcp-config»: confermata in tutte e sei le esecuzioni;
«Gli strumenti MCP si chiamano mcp__<server>__<tool>»: confermata in
tutte e tre quelle con il server. Come dati: lo strumento del server
chiamato 3 su 3; risposte con esattamente i comuni giusti, con il server
3 su 3, senza 0 su 3. La vostra prova, rifatta dal docente con
`claude -p` invece che in una sessione: `claude mcp get copertura` ha
detto «Status: ✔ Connected», la risposta ha nominato i 13 comuni e la
verifica è passata. Le sei esecuzioni sono nella cartella
`soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M4-D02)

La verifica fa girare `controlla_copertura.py` dell'elemento sullo spazio
di lavoro e, se c'è `risposta.txt`, prima `claude mcp get copertura` dallo
spazio di lavoro. È fatta quando ciò che c'è va: il server configurato e
`risposta.txt` giusto, e, se ci sono le esecuzioni del docente, le due
garanzie confermate. L'ultima riga è «Fatto: ogni affermazione è stata
messa alla prova; gli esiti sono qui sopra.» Non scrive niente.

## Se qualcosa va storto

- `/mcp` mostra `copertura` non collegato: controllate di aver fatto il
  passo 1, e che i percorsi siano assoluti e giusti (`echo "$S" "$D"`,
  nel terminale del passo 2); poi `claude mcp remove copertura` e di
  nuovo il passo 3.
- `claude mcp add` rifiuta il nome: l'ordine del passo 3, con il nome
  prima di `-e`.
- `uv: command not found`: il paragrafo «Python e uv» di
  `PRIMA_DEL_CORSO.md`.
- La verifica dice che il server non è configurato: `claude mcp add` è
  stato dato da un'altra cartella, e lo scope local vale per la cartella
  in cui lo si dà. Rifate il passo 3 dallo spazio di lavoro.
- La verifica dice che in `risposta.txt` mancano comuni, o ce ne sono in
  più: guardate se nella sessione Claude ha usato lo strumento
  `mcp__copertura__cerca_copertura`; rifate la domanda in una sessione
  nuova e salvate di nuovo la risposta.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- `_docente/live.sh` si ferma e dice che lo spazio di lavoro deve avere
  soltanto `domanda.txt` e `.claude/`: ci sono le risposte o le
  configurazioni di una prova precedente, che una sessione potrebbe
  leggere. `tools/reset_esercizio.sh M4-D02` lo prepara di nuovo.
- Per ricominciare da capo: `claude mcp remove copertura` dallo spazio di
  lavoro, poi `tools/reset_esercizio.sh M4-D02`.

## Impronta d'uso sul piano Pro

La vostra prova: una sessione su Sonnet con effort low, due messaggi (la
domanda e la richiesta di salvare la risposta), qualche chiamata allo
strumento del server, nessun subagent. Il server gira sul vostro computer
e non chiama il modello. La prova del docente: sei chiamate brevi
`claude -p`, Sonnet con effort low. claude.ai e Claude Code consumano gli
stessi limiti: «These limits are shared across Claude and Claude Code,
meaning all activity in both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low), dal JSON di ogni esecuzione: le tre con il server,
2 turni ciascuna (`num_turns`), in 7,5, 4,7 e 14,6 secondi, 10.075 token
in entrata ciascuna, cache compresa; le tre senza, 3 turni ciascuna, in
19,9, 9,5 e 15,7 secondi, con 12.614, 12.621 e 12.639 token in entrata.
La vostra prova, rifatta dal docente con `claude -p`: la domanda 3 turni,
5,7 secondi e 81.080 token in entrata; il salvataggio di `risposta.txt`
2 turni, 7,1 secondi e 56.315 token.

## Per approfondire

- «Connect Claude Code to tools via MCP», la pagina sui server MCP: come
  si aggiungono, gli scope, l'approvazione, i nomi degli strumenti:
  https://code.claude.com/docs/en/mcp
- Il debug della configurazione, con i server MCP che non partono:
  https://code.claude.com/docs/en/debug-your-config
- La sicurezza in Claude Code, server MCP compresi:
  https://code.claude.com/docs/en/security
- `claude -p` e l'evento `system/init` dello stream-json:
  https://code.claude.com/docs/en/headless
- La skill di Anthropic per costruire server MCP:
  https://github.com/anthropics/claude-plugins-official/blob/main/plugins/mcp-server-dev/skills/build-mcp-server/SKILL.md
