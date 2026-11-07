# M6-E01 — Che cosa vede Claude

Esercitazione del Modulo 6, dopo la parte su CLAUDE.md: prima di fidarvi di un
CLAUDE.md, guardate se Claude Code lo carica. Nello spazio di lavoro del
gestionale, che non ha un CLAUDE.md, salvate che cosa dice `/context all`;
scrivete dalla shell un CLAUDE.md di due righe; salvate di nuovo `/context all`;
poi, in una sessione, fate a Claude la domanda a cui le due righe rispondono.

## Obiettivo

Vedere la riga che compare sotto «Memory files» quando c'è un CLAUDE.md, con i
suoi token, e la riga che l'hook `InstructionsLoaded` scrive nel registro quando
il file entra nel contesto. È il controllo che Anthropic indica: «To confirm the
file loaded, run /context all in a session and check the list under Memory
files.» (https://code.claude.com/docs/en/memory).

Si lavora in Claude Code, perché CLAUDE.md è un file di Claude Code. I due
`/context all` del confronto si lanciano con `claude -p`, che scrive l'uscita in
un file, `prima.md` e `dopo.md`: così la verifica la legge. La domanda si fa
nella sessione interattiva, dove si lavora di solito, e lì si ripete anche
`/context all`.

## Tempo

8 minuti in aula: 5 per i passi, il resto per la presentazione e per guardare
insieme che cosa è comparso.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3, il comando `python3`: lo usano l'hook e la verifica.
- Docker e PHP non servono: i test del gestionale non si eseguono.

## Punto di partenza (tools/prepara_esercizio.sh M6-E01)

Lo spazio di lavoro `~/corso-claude-code/M6-E01/`, un repository git con un primo
commit, con:

- `progetti/gestionale-php/`: il gestionale di CiaspoLink, l'operatore inventato
  del corso, senza nessun CLAUDE.md;
- `tools/php.sh`: una copia di `tools/php.sh` del repository, il comando con cui
  il gestionale esegue PHP, Composer e PHPUnit; lo nominano le due righe del
  CLAUDE.md;
- `.claude/settings.json`: le impostazioni prudenti del repository e l'hook
  `InstructionsLoaded`, che per ogni CLAUDE.md caricato scrive una riga in
  `.claude/caricamenti.jsonl`: il motivo, il file e il suo tipo;
- `.claude/hooks/registra_caricamenti.py`: lo script dell'hook, una copia di
  `tools/registra_caricamenti.py`. Nel registro i percorsi sono relativi allo
  spazio di lavoro, e «~/…» sotto la vostra cartella di casa;
- `.gitignore`: tiene il registro fuori da git.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro ed entrateci:

       tools/prepara_esercizio.sh M6-E01
       cd ~/corso-claude-code/M6-E01

2. **Prima.** Che cosa vede Claude senza CLAUDE.md: `/context all` in `claude
   -p`, con l'uscita in `prima.md`.

       claude -p "/context all" --model sonnet --setting-sources project,local \
         --strict-mcp-config > prima.md
       cat prima.md

   `--setting-sources project,local` carica solo le impostazioni dello spazio di
   lavoro, non le vostre personali: «Comma-separated list of setting sources to
   load (user, project, local).»; `--strict-mcp-config` lascia fuori i server MCP
   e i connettori: «Only use MCP servers from --mcp-config, ignoring all other MCP
   configurations» (`claude --help`). Così in `prima.md` e `dopo.md` conta
   soltanto ciò che sta nello spazio di lavoro. Nella tabella «Estimated usage by
   category» guardate se c'è «Memory files».

3. **Il CLAUDE.md**, di due righe, scritto dalla shell:

       printf '%s\n' '# Gestionale di CiaspoLink' \
         '- Test, da progetti/gestionale-php: `../../tools/php.sh composer install`, poi `../../tools/php.sh phpunit`' \
         > CLAUDE.md
       cat CLAUDE.md

4. **Dopo.** Lo stesso comando, con l'uscita in `dopo.md`, e il registro
   dell'hook:

       claude -p "/context all" --model sonnet --setting-sources project,local \
         --strict-mcp-config > dopo.md
       cat dopo.md
       cat .claude/caricamenti.jsonl

   In `dopo.md` guardate la tabella «Memory Files»: il tipo, il percorso e i
   token del file. Il percorso è completo, con il nome della vostra cartella di
   casa: `prima.md` e `dopo.md` restano nel vostro spazio di lavoro, e la verifica
   non lo stampa.

5. **La domanda**, in una sessione interattiva su Sonnet con effort low:

       claude --model sonnet --effort low

   Alla prima apertura vi chiede se vi fidate della cartella: «In an interactive
   session, Claude Code shows the workspace trust dialog when you start it in a
   folder you haven't trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì: in Claude Code 2.1.319 il cursore parte da «No, exit», quindi
   scendete con la freccia su «Yes, I trust this folder» e date Invio.

   Nella sessione, prima il controllo:

       /context all

   Poi incollate la domanda:

   <!-- prompt 1 -->

       Con quale comando si eseguono i test di questo progetto?

   <!-- /prompt 1 -->

   Se Claude chiede il permesso di eseguire un comando, potete rispondere di no:
   la domanda chiede quale comando, non di eseguirlo. Quando ha risposto, salvate
   la conversazione in un file di testo e uscite, un comando alla volta:

       /export risposta.txt
       /exit

6. Dalla cartella `esercitazioni`, la verifica:

       cd -
       tools/verifica.sh M6-E01

## Che cosa osservare

### Che cosa dice Anthropic

- **Il controllo.** «To confirm the file loaded, run /context all in a session
  and check the list under Memory files.» E, fra i rimedi quando Claude non segue
  il CLAUDE.md: «Run /context all and check the list under Memory files to verify
  the CLAUDE.md and CLAUDE.local.md files that should load at launch. If one is
  missing there, Claude can't see it.» (https://code.claude.com/docs/en/memory)
- **All'avvio, e su richiesta.** «CLAUDE.md and CLAUDE.local.md files in the
  directory hierarchy above the working directory are loaded at launch. Files in
  subdirectories load on demand.» Per questo un CLAUDE.md in una sottocartella non
  è nella lista: «A CLAUDE.md in a subdirectory of your working directory doesn't
  appear under Memory files, because it loads on demand rather than at launch.»
  (stessa pagina) Il vostro sta nella cartella in cui lanciate Claude Code.
- **Dalla shell.** Per un CLAUDE.md in una sottocartella la pagina consiglia:
  «To test a new one, create it from your shell rather than asking Claude to
  write it, then ask Claude to read a file in that subdirectory.» (stessa pagina)
  Qui il file sta nella cartella di lavoro, e lo scrivete dalla shell allo stesso
  modo, prima di aprire la sessione: in `/context all` c'è il file che avete
  scritto voi.
- **`/context`.** «/context [all] | Visualize current context usage as a colored
  grid. … Pass all to expand it» (https://code.claude.com/docs/en/commands).
  Nelle prove del corso, in `claude -p` la griglia diventa un testo in Markdown,
  con le tabelle.
- **Che cosa ci va.** Fra ciò che va in un CLAUDE.md: «How to confirm work in this
  repo: the exact test, typecheck, and lint commands, and how to run a single
  test file» (https://code.claude.com/docs/en/best-practices). Per questo le due
  righe sono il comando dei test.
- **L'hook.** «Use the InstructionsLoaded hook to log which CLAUDE.md and rules
  files are loaded, when they load, and why.»
  (https://code.claude.com/docs/en/memory) L'evento: «InstructionsLoaded | When a
  CLAUDE.md or .claude/rules/*.md file is loaded into context. Fires at session
  start and when files are lazily loaded during a session»; il motivo, nel campo
  `load_reason`: «Why the file was loaded: "session_start", "nested_traversal",
  "path_glob_match", "include", or "compact"»; e «The hook doesn't support
  blocking or decision control. It runs asynchronously for observability
  purposes.» (https://code.claude.com/docs/en/hooks)
- **Anche in `claude -p`.** «a -p session runs the hooks in a project’s
  .claude/settings.json and connects the servers in its .mcp.json, even in a
  folder you’ve never trusted» (https://code.claude.com/docs/en/headless). Per
  questo il registro ha già la riga del passo 4, prima che al passo 5 diciate di
  fidarvi della cartella.
- **`/export`.** «Export the current conversation as plain text. With a filename,
  writes directly to that file.» (https://code.claude.com/docs/en/commands)

### Che cosa misura la verifica

`tools/verifica.sh M6-E01` legge `prima.md`, `CLAUDE.md`, `dopo.md` e il
registro dell'hook, e decide due cose, che sono garanzie del prodotto e devono
valere a ogni esecuzione:

- «/context all elenca sotto «Memory files» il CLAUDE.md caricato all'avvio»:
  confermata se `prima.md` e `dopo.md` sono l'uscita di `/context all`, il
  CLAUDE.md dello spazio di lavoro manca in `prima.md` e c'è in `dopo.md`, con i
  suoi token. Nella tabella il percorso è completo: la verifica riconosce il
  vostro dal nome della cartella, `M6-E01/CLAUDE.md`, e un CLAUDE.md di una
  cartella più in alto non conta;
- «l'hook InstructionsLoaded scatta all'avvio (load_reason session_start)»:
  confermata se il registro ha almeno una riga `session_start` per `CLAUDE.md`.

Una garanzia che non tiene è «non confermata in questa esecuzione», e la verifica
esce con 1: è un esito da far vedere al docente.

Tutto il resto lo stampa come dati, nelle righe `(dato)`, che non decidono il
codice d'uscita: le altre righe sotto «Memory files», le righe del registro, e la
risposta alla domanda, letta da `risposta.txt`: il suo inizio, quali comandi fra
apici inversi di CLAUDE.md vi compaiono e se nomina CLAUDE.md. Che cosa risponde
Claude dipende da ciò che sceglie di fare; la verifica non lo giudica. Al posto
della vostra cartella stampa «<spazio di lavoro>», e «~» al posto della cartella
di casa.

### Nella prova del corso

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, sull'account del docente, che non è un Pro) sono stati eseguiti i
passi del README, con due opzioni in più al passo 5: la sessione, su un
terminale, aveva anche `--setting-sources project,local` e
`--strict-mcp-config`, come su un computer senza impostazioni personali. Le sue
schermate mostrano comunque «auto mode on», gli strumenti del browser del
docente e il salvataggio della
trascrizione spento da un contrassegno ereditato dalla sessione di Claude Code
che aveva lanciato la prova. Gli esiti della verifica vengono dai due
`claude -p "/context all"` e dal registro dell'hook. `prima.md` non aveva la
riga «Memory files»; `dopo.md` aveva la tabella «Memory Files» con CLAUDE.md,
71 token; nella sessione `/context all` ha mostrato la stessa riga, «Memory
files · /memory» e sotto «CLAUDE.md: 71 tokens». Le righe della verifica:

    dopo.md: l'uscita di /context all; sotto «Memory files» c'è CLAUDE.md, 71 token (Project).
    /context all elenca sotto «Memory files» il CLAUDE.md caricato all'avvio: confermata (prima.md senza, dopo.md con)
    (dato) il registro dell'hook, .claude/caricamenti.jsonl: 2 righe: session_start CLAUDE.md ×2
    l'hook InstructionsLoaded scatta all'avvio (load_reason session_start): confermata
    (dato) i comandi di CLAUDE.md nella risposta: `../../tools/php.sh composer install`: sì; `../../tools/php.sh phpunit`: sì
    (dato) la risposta nomina CLAUDE.md: sì

Le due righe del registro sono del passo 4 e della sessione del passo 5: al passo
2 CLAUDE.md non c'era, e l'hook non ha scritto niente. La risposta salvata con
`/export` cominciava «Dal file CLAUDE.md del progetto, i test si eseguono così,
partendo dalla cartella progetti/gestionale-php», con i due comandi; Claude non ha
chiamato strumenti. Sono le righe di questa esecuzione: dicono che cosa è
successo lì, non che cosa succederà nella vostra.

Lo stesso giorno `_docente/live.sh` ha rifatto i passi in `claude -p`, con la
domanda al posto della sessione: le stesse righe per `prima.md`, `dopo.md` e il
registro, e la risposta con i due comandi, senza nominare CLAUDE.md. In `claude
-p` `/export` non c'è: in una prova del corso ha risposto «/export isn't
available in this environment.».

## Verifica (tools/verifica.sh M6-E01)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M6-E01

Esce con 0 quando `prima.md` e `dopo.md` sono l'uscita di `/context all`,
`CLAUDE.md` c'è, sta sotto «Memory files» in `dopo.md` e non in `prima.md`, e il
registro dell'hook ha il suo caricamento all'avvio; con 1 quando manca un file o
un passo è stato fatto fuori ordine, e dice quale, o quando una garanzia non
tiene; con 2 quando non può partire o non sa leggere un file, per esempio se lo
spazio di lavoro non c'è. Quando tutto è in ordine, le ultime due righe sono
«Fatto: …» e «VERIFICA OK   M6-E01: fatto.»

## Se qualcosa va storto

- `prima.md` è vuoto o dice un errore invece di «Context Usage»: Claude Code non
  è collegato. Rifate i passi di `PRIMA_DEL_CORSO.md`, poi il passo 2.
- La verifica dice che `prima.md` ha già CLAUDE.md: l'avete fatto dopo il passo
  3. Ricominciate con `tools/reset_esercizio.sh M6-E01`: cancella anche
  CLAUDE.md e i file salvati.
- In `dopo.md` CLAUDE.md non c'è: guardate che stia nello spazio di lavoro e non
  in `progetti/gestionale-php/` (`ls CLAUDE.md`), che `dopo.md` l'abbiate fatto
  dopo il passo 3, e rifate il passo 4. Se c'era e non compare, è un esito da far
  vedere al docente.
- Il registro `.claude/caricamenti.jsonl` non c'è: l'hook lo chiama `python3`,
  che dev'esserci nel terminale in cui lanciate Claude Code; e `.claude/` va
  lasciata com'è. Se la verifica dice che l'hook non è configurato, ricominciate
  con `tools/reset_esercizio.sh M6-E01`.
- La sessione si chiude appena aperta: alla domanda di fiducia il cursore parte
  da «No, exit». Riaprite e scegliete «Yes, I trust this folder».
- Claude Code sembra fermo: sta aspettando una risposta, forse il permesso per un
  comando. Potete rispondere di no.
- La verifica dice che `risposta.txt` non c'è: è un dato, e non fa fallire la
  verifica. Per averlo, riaprite la sessione con `claude --model sonnet --effort
  low`, rifate la domanda e `/export risposta.txt`, dallo spazio di lavoro.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M6-E01`.

## Impronta d'uso sul piano Pro

Sonnet, effort low, nessun subagent: i due `/context all` in `claude -p`, e
quello nella sessione, una domanda di pochi turni, `/export`. Sul Pro il modello
predefinito di Claude Code è un altro: «Pro, Max, Ultra, Team, Enterprise, and
Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). Il corso fissa Sonnet perché le
vostre prove e la registrazione del corso girino sullo stesso modello.

In una prova del corso (7 novembre 2026, Claude Code 2.1.319, l'account del
docente) `/context all` in `claude -p` non ha chiamato il modello: lo stesso
comando con `--output-format json` ha dato «num_turns» 0 e nessun token. Nella
registrazione del corso, la domanda, in `claude -p` con `_docente/live.sh`:
«turni 1; token 19762; 2,2 s», senza strumenti. I token sono quelli di
`modelUsage`, entrata, cache e uscita, compreso il contesto letto dalla cache:
dicono quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano
occupa. La sessione interattiva non è stata misurata.

## Per approfondire

- «How Claude remembers your project», la pagina di Claude Code su CLAUDE.md e
  sulla memoria: https://code.claude.com/docs/en/memory
- «Hooks reference», l'evento `InstructionsLoaded` e i suoi campi:
  https://code.claude.com/docs/en/hooks
- «Commands», `/context`, `/export` e gli altri comandi:
  https://code.claude.com/docs/en/commands
- La lezione «The CLAUDE.md file» del corso Claude Code 101 dell'Academy:
  https://academy.claude.com/courses/claude-code-101/the-claude-md-file
