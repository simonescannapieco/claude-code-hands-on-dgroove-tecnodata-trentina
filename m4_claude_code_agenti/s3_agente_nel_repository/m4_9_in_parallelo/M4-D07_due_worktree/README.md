# M4-D07 — Due filoni, due worktree

Demo del Modulo 4, nella parte «In parallelo». In aula la mostra il
docente; potete rifarla da soli quando volete, con i comandi del passo 3
di «Passi in Claude Code».

## Obiettivo

Mettere alla prova ciò che Anthropic afferma di `claude --worktree` (o
`-w`): crea un worktree isolato su un ramo nuovo e vi avvia Claude, e da
lì Claude Code blocca un Edit, un Write o un NotebookEdit diretto a un
percorso del checkout principale. Due
modifiche allo stesso file, chieste da due sessioni partite insieme: un
esempio d'uso nella docstring di `urgenza.py`, e il parametro
`giorni_aperta` che diventa `giorni_di_apertura`. Due bracci che
differiscono in una cosa sola: le due sessioni nel checkout principale,
oppure ognuna nel suo worktree.

## Tempo

3 minuti in aula: il docente lancia i due bracci e legge i verdetti.
Circa 6 minuti per rifarla da soli, pulizia compresa.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- git, già chiesto dal corso: lo spazio di lavoro è un repository git con
  un commit, e un worktree ne ha bisogno: «Each git worktree is a separate
  checkout on its own branch, created from an existing commit, so the
  repository needs at least one commit first.»
  (https://code.claude.com/docs/en/common-workflows)
- Python 3, che il controllo usa.

## Punto di partenza (tools/prepara_esercizio.sh M4-D07)

Lo spazio di lavoro `~/corso-claude-code/M4-D07/`, un repository git con
un commit e nessuna modifica, con:

- `progetti/urgenze/`: il progetto più piccolo del corso, la funzione
  `urgente(clienti, giorni_aperta)` di CiaspoLink e i suoi tre test;
- `prompt-esempio.txt` e `prompt-rinomina.txt`: le due richieste, che
  nominano il file con il suo percorso e chiedono di non cambiare altro;
- `fotografa.sh`: la fotografia di git dopo un braccio, da prendere
  subito: lo stato del checkout principale (`git status --porcelain`) e,
  secondo il braccio, una copia del suo `urgenza.py` oppure, per ogni
  worktree, il suo stato con il ramo (`git status --porcelain --branch`) e
  una copia del suo `urgenza.py`. Il controllo decide dagli stream e dalle
  fotografie, così si può rifare anche dopo aver tolto i worktree.

Il controllo, `controlla_worktree.py`, sta nella cartella di questo
elemento, non nello spazio di lavoro: lo fa girare `tools/verifica.sh
M4-D07`.

## Passi in Claude Code

1. **Il docente**, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D07
       m4_claude_code_agenti/s3_agente_nel_repository/m4_9_in_parallelo/M4-D07_due_worktree/_docente/live.sh ~/corso-claude-code/M4-D07

   Lo script mostra ogni comando prima di eseguirlo: il braccio senza
   worktree, con le due sessioni che partono insieme, la sua fotografia e
   il checkout di nuovo com'era (`git checkout`); poi il braccio con i
   worktree, la sua fotografia, la verifica e la pulizia. Prima il
   braccio senza: così le sue sessioni non trovano nella cartella le
   copie dei worktree.

2. **In sala** si guarda:
   - senza worktree, `git diff --stat`: le due modifiche nello stesso
     file, nello stesso checkout;
   - con i worktree, `git branch --list 'worktree-*'`: un ramo per
     sessione; poi, nella verifica, che cosa c'è in ogni worktree e nel
     checkout principale;
   - la pulizia, alla fine: `claude -p` lascia i suoi worktree.

3. **Rifarla da soli**, quando volete. Preparate lo spazio di lavoro ed
   entrateci, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D07
       cd ~/corso-claude-code/M4-D07

   Poi i due bracci, ognuno con le sue due sessioni partite insieme (`&`)
   e aspettate (`wait`), e la fotografia subito dopo:

   <!-- comandi -->
       mkdir -p esecuzioni/senza-worktree esecuzioni/con-worktree
       e="$(cat prompt-esempio.txt)"
       r="$(cat prompt-rinomina.txt)"
       o=(--model sonnet --effort low --allowedTools Read,Edit
          --strict-mcp-config --no-session-persistence
          --output-format stream-json --verbose)
       claude -p "$e" "${o[@]}" > esecuzioni/senza-worktree/esempio.jsonl &
       claude -p "$r" "${o[@]}" > esecuzioni/senza-worktree/rinomina.jsonl &
       wait
       bash fotografa.sh senza-worktree
       git checkout -- progetti/urgenze
       claude -p "$e" -w esempio "${o[@]}" > esecuzioni/con-worktree/esempio.jsonl &
       claude -p "$r" -w rinomina "${o[@]}" > esecuzioni/con-worktree/rinomina.jsonl &
       wait
       bash fotografa.sh con-worktree
   <!-- /comandi -->

   Poi i dati e i verdetti, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D07

   E infine la pulizia, dallo spazio di lavoro:

       cd ~/corso-claude-code/M4-D07
       git worktree remove --force --force .claude/worktrees/esempio
       git worktree remove --force --force .claude/worktrees/rinomina
       git branch -D worktree-esempio worktree-rinomina

`_docente/live.sh` manda gli stessi testi con le stesse opzioni, dallo
stesso checkout, più `--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina sui worktree: «Pass --worktree or -w with a name to create
  an isolated worktree and start Claude in it.…on a new branch named
  worktree-<name>». Con `--worktree` (o `-w`) e un nome, Claude Code crea
  un worktree isolato, su un ramo nuovo `worktree-<nome>`, e vi avvia
  Claude.
  https://code.claude.com/docs/en/worktrees
- Nella stessa pagina: «File edits: Claude Code blocks an Edit, Write, or
  NotebookEdit that targets a path in the main checkout.»
- E il suo limite: «None of them tracks which files a shell command
  writes…such as cp or a shell redirect, isn't refused by them». Per
  questo le sessioni della demo hanno il permesso soltanto per Read ed
  Edit: in `claude -p` «Calls needing approval are denied unless you
  approve them with an allow rule, hook, canUseTool callback, or
  --permission-prompt-tool.»
  (https://code.claude.com/docs/en/permission-modes)
- Da dove parte un worktree: «If no remote is configured, or origin/HEAD
  isn't cached locally and can't be fetched, the worktree falls back to
  your current local HEAD.» Lo spazio di lavoro non ha un remote: i
  worktree partono dal suo commit.
- Che cosa resta dopo `-p`: «Non-interactive runs with -p have no exit
  prompt, so Claude doesn't clean up their worktrees». Da qui la pulizia.
- A che cosa servono, nel titolo della pagina: «Isolate parallel Claude
  Code sessions in separate git worktrees so changes don't collide.» E
  nella pagina sul lavoro in parallelo: «Do the tasks touch the same
  files? Isolate the work with worktrees.»
  (https://code.claude.com/docs/en/agents)
- Due lezioni della Claude Academy, le due facce: «Two Claude sessions
  fighting over the same files leads to conflicts. … each one gets its
  own independent file tree.»
  (https://academy.claude.com/courses/claude-code-in-action/steering-long-sessions)
  E: «Tasks that share files run in a single session, one after another.»
  (https://academy.claude.com/courses/ai-native-sdlc-playbook/parallel-sessions-and-subagents)
  I worktree tengono separate le due modifiche; rimetterle insieme su un
  ramo resta un lavoro vostro.

### Che cosa misura il controllo

`controlla_worktree.py` legge gli stream delle quattro sessioni e le
fotografie dei due bracci. Di ogni sessione stampa da dove è partita (la
cartella dell'evento di avvio), gli strumenti chiamati, quanti con errore
e, per il braccio con i worktree, il ramo e le modifiche del suo worktree
e che cosa c'è nel suo `urgenza.py`: l'esempio (una riga che comincia con
`>>>`) e la rinomina (`giorni_di_apertura` al posto di `giorni_aperta`;
«a metà» se ci sono tutti e due).

Sul braccio con i worktree, tre garanzie del prodotto: una che non tiene
è una segnalazione, «non confermata in questa esecuzione», e la verifica
esce 1.

- «Con -w, un worktree isolato su un ramo nuovo, e Claude parte lì», per
  ogni sessione: il worktree c'era, sul ramo `worktree-<nome>`, e la
  sessione è partita lì. Dove sta il worktree la frase non lo dice: il
  controllo lo cerca dove l'ha trovato la registrazione del corso,
  `.claude/worktrees/<nome>` del checkout principale.
- «Le modifiche al checkout principale sono bloccate», nell'ambito della
  frase della pagina sui worktree: un Edit, un Write o un NotebookEdit
  diretto a un percorso del checkout principale. Una segnalazione se dopo
  il braccio il checkout principale ha modifiche ai file tracciati, o se
  una modifica di file riuscita è uscita dal worktree della sua sessione.
  Altrimenti è confermata se almeno una sessione ha provato a modificare
  il checkout principale e lo stream mostra il blocco: la chiamata è
  nell'elenco `permission_denials` del risultato. Un tentativo fallito che
  l'elenco non nomina non si distingue da un altro errore (un file non
  ancora letto, per esempio), e il verdetto è non distinguibile, come
  quando nessuna sessione ci ha provato: le sessioni hanno lavorato nel
  loro worktree, e il blocco non è stato messo alla prova.
- «Ogni worktree tiene soltanto la modifica della sua sessione», per
  ogni sessione: i file tracciati cambiati nel worktree sono fra quelli
  che la sua sessione ha modificato, e il suo `urgenza.py` non ha l'altra
  modifica, salvo che l'abbia scritta la sessione stessa. Non
  distinguibile se l'altra sessione non ha modificato niente: non c'era
  niente da tenere fuori.

Il braccio senza worktree è un dato: che cosa c'è in `urgenza.py` del
checkout (tutte e due le modifiche, una, nessuna, una rinomina a metà, un
file che non è più Python valido) e quanti Edit hanno avuto un errore.
Prima di decidere il controllo guarda che i bracci siano una coppia: le
due sessioni senza worktree partite dallo stesso checkout, i due bracci
dallo stesso checkout, le quattro sessioni con lo stesso modello e la
stessa modalità. Non scrive niente.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low): senza worktree, le due sessioni sono partite nel
checkout principale, e alla fine `urgenza.py` del checkout aveva
l'esempio e la rinomina, «le due modifiche nello stesso file, nello
stesso checkout». Con `-w`, come lo stampa il controllo, l'esempio è
partito in `.claude/worktrees/esempio`, sul ramo `worktree-esempio`, e la
rinomina in `.claude/worktrees/rinomina`, sul ramo `worktree-rinomina`, e
ogni worktree aveva soltanto la sua modifica: «Con -w, un worktree isolato su
un ramo nuovo, e Claude parte lì» e «Ogni worktree tiene soltanto la
modifica della sua sessione», confermata ciascuna per tutte e due le
sessioni; il checkout principale, nessuna modifica ai file tracciati.
«Le modifiche al checkout principale sono bloccate»: non distinguibile,
perché nessuna sessione ha provato a modificarlo. Come dato, dopo
`claude -p` i due worktree c'erano ancora, e la pulizia li ha tolti con i
loro rami. Le esecuzioni sono nella cartella `soluzione/esecuzioni/` di
questo elemento.

## Verifica (tools/verifica.sh M4-D07)

La verifica fa girare `controlla_worktree.py`, quello della cartella
dell'elemento, sullo spazio di lavoro. È fatta quando ci sono i due
bracci con i loro stream e le loro fotografie, sono una coppia e le
garanzie tengono: l'ultima riga dice «Fatto: …». Decide dalle fotografie,
quindi va bene anche dopo la pulizia. Sul punto di partenza, senza
`esecuzioni/`, esce 1.

## Se qualcosa va storto

- `live.sh` dice che ci sono già delle esecuzioni, oppure che il
  checkout ha modifiche: ripartite da capo con
  `tools/reset_esercizio.sh M4-D07`, che toglie lo spazio di lavoro con i
  suoi worktree; la pulizia qui sotto non tocca `esecuzioni/` né le
  modifiche del checkout. Se dice che c'è già un worktree o un ramo
  `worktree-*`: la pulizia qui sotto, oppure lo stesso reset.
- La pulizia, dallo spazio di lavoro:

      cd ~/corso-claude-code/M4-D07
      git worktree remove --force --force .claude/worktrees/esempio
      git worktree remove --force --force .claude/worktrees/rinomina
      git branch -D worktree-esempio worktree-rinomina

  Se un worktree è bloccato («locked»), `git worktree remove` lo toglie
  soltanto con `--force` ripetuto: per questo due volte, così la pulizia
  va in ogni caso. Un worktree che non c'è, o un ramo già cancellato,
  danno un errore che si può ignorare.
- La verifica dice che manca una fotografia: lanciate `bash fotografa.sh
  <braccio>` subito dopo le due sessioni del braccio, prima della
  pulizia; se i worktree non ci sono più, rifate il braccio.
- La verifica dice che il checkout principale è cambiato dopo il braccio
  con i worktree: se prima non lo avevate riportato com'era (`git
  checkout -- progetti/urgenze`), ripartite da capo; se sì, è una
  segnalazione.
- La verifica stampa una segnalazione: in quell'esecuzione una garanzia
  non ha tenuto. Conservate la cartella `esecuzioni/` e mostratela al
  docente.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Quattro sessioni `claude -p`, due alla volta, su Sonnet con effort low,
un solo prompt ciascuna, gli strumenti Read ed Edit, nessun subagent.
«Running several sessions or subagents at once multiplies token usage.»
(https://code.claude.com/docs/en/agents) E per il lavoro di ogni giorno:
«Two or three sessions is a sensible starting point. The practical
ceiling is how many streams one person can review properly»
(https://academy.claude.com/courses/ai-native-sdlc-playbook/parallel-sessions-and-subagents).
claude.ai e Claude Code consumano gli stessi limiti: se il limite della
sessione è vicino, guardate il risultato del docente invece di rifare i
due bracci.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low), dal JSON di ogni sessione: senza worktree,
l'esempio 3 turni (`num_turns`), 7,7 secondi e 52.738 token in entrata,
cache compresa, la rinomina 6 turni, 23,8 secondi e 90.275 token; con i
worktree, l'esempio 3 turni, 21,5 secondi e 53.569 token, la rinomina 5
turni, 9,1 secondi e 91.352 token.

## Per approfondire

- «Run parallel sessions with worktrees», nella documentazione:
  https://code.claude.com/docs/en/worktrees
- «Common workflows», con i worktree fra i flussi di ogni giorno:
  https://code.claude.com/docs/en/common-workflows
- I modi di Claude Code per lavorare su più compiti insieme:
  https://code.claude.com/docs/en/agents
- «The AI-native SDLC playbook» della Claude Academy, con le sessioni in
  parallelo: https://academy.claude.com/courses/ai-native-sdlc-playbook
- Il corso «Claude Code in action» della Claude Academy, con le sessioni
  lunghe e i worktree:
  https://academy.claude.com/courses/claude-code-in-action
