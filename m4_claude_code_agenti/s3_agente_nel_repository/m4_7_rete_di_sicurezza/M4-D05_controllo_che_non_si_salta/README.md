# M4-D05 — Il controllo che non si salta

Demo del Modulo 4, nella parte «La rete di sicurezza». In aula la mostra
il docente; potete rifarla da soli quando volete, con i comandi del passo
3 di «Passi in Claude Code».

## Obiettivo

Mettere alla prova ciò che Anthropic afferma di uno Stop hook, un comando
che Claude Code esegue alla fine di ogni turno: se esce con 2, il turno
non si chiude, e ciò che il comando ha scritto su stderr torna a Claude.
Lo stesso prompt, che chiede soltanto una docstring più chiara per
`urgenza.py`, in due bracci che differiscono in una cosa sola: con uno
Stop hook che esegue i test del progetto, e senza. Un'istruzione nel
prompt Claude può anche non seguirla; un hook lo esegue Claude Code.

## Tempo

5 minuti in aula: il docente lancia i due bracci e legge i verdetti.
Circa 6 minuti per rifarla da soli.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, già chiesti dal corso: l'hook e il controllo eseguono
  i test con Python, e ogni copia del progetto è un repository git.

## Punto di partenza (tools/prepara_esercizio.sh M4-D05)

Lo spazio di lavoro `~/corso-claude-code/M4-D05/` con:

- `progetti/urgenze/`: il progetto più piccolo del corso, la funzione
  `urgente(clienti, giorni_aperta)` di CiaspoLink, con la regola nella
  docstring, e i suoi tre test `unittest`;
- `prompt.txt`: il prompt, uguale nei due bracci, che chiede soltanto la
  docstring;
- `impostazioni/senza-hook.json` e `impostazioni/con-hook.json`: le
  impostazioni di Claude Code dei due bracci, con le regole prudenti del
  repository; la seconda ha in più lo Stop hook:

      "hooks": {
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "cd \"$CLAUDE_PROJECT_DIR\" && python3 -m unittest -q 1>&2 || exit 2"
              }
            ]
          }
        ]
      }

  Il comando comincia con `cd "$CLAUDE_PROJECT_DIR"`, poi esegue i test;
  manda la loro uscita su stderr (`1>&2`) e, se falliscono, esce con 2
  (`|| exit 2`);
- `nuova_copia.sh`: prepara la copia del progetto in cui lavora una
  sessione, `esecuzioni/<braccio>-<n>/urgenze/`, con le impostazioni del
  suo braccio in `.claude/settings.json` e un repository git a sé, con un
  commit. Ogni esecuzione parte così dallo stesso punto.

Il controllo, `controlla_stop.py`, sta nella cartella di questo elemento,
non nello spazio di lavoro: lo fa girare `tools/verifica.sh M4-D05`.

## Passi in Claude Code

1. **Il docente**, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D05
       m4_claude_code_agenti/s3_agente_nel_repository/m4_7_rete_di_sicurezza/M4-D05_controllo_che_non_si_salta/_docente/live.sh ~/corso-claude-code/M4-D05

   Lo script parte soltanto da uno spazio di lavoro al punto di partenza
   (`git status` vuoto) e con le impostazioni dei due bracci uguali, tolto
   l'hook; poi mostra ogni comando prima di eseguirlo: la differenza fra
   le impostazioni dei due bracci (`diff`: soltanto l'hook), poi per ogni
   braccio la copia e `claude -p` dalla copia, poi la verifica. Con
   `--esecuzioni N` fa N esecuzioni per braccio.

2. **In sala** si guarda:
   - nel braccio con l'hook, quante volte lo Stop hook ha bloccato la
     fine del turno, e che cosa è cambiato nella copia;
   - nel braccio senza, dove si ferma Claude;
   - in tutti e due, i test rieseguiti nella copia alla fine, e quali
     file sono cambiati: se cambia `test_urgenza.py`, un test è stato
     toccato, e l'hook passa anche così.

3. **Rifarla da soli**, quando volete. Preparate lo spazio di lavoro ed
   entrateci, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D05
       cd ~/corso-claude-code/M4-D05

   Poi i due bracci: per ognuno una copia del progetto, con le sue
   impostazioni, e una sessione che parte dalla copia:

   <!-- comandi -->
       p="$(cat prompt.txt)"
       for b in con-hook senza-hook; do
         bash nuova_copia.sh "esecuzioni/$b-1" "impostazioni/$b.json"
         (cd "esecuzioni/$b-1/urgenze" && claude -p "$p" --model sonnet \
           --effort low --allowedTools 'Read,Edit,Bash(python3 -m unittest*)' \
           --permission-mode acceptEdits --strict-mcp-config \
           --no-session-persistence --output-format stream-json --verbose) \
           > "esecuzioni/$b-1/stream.jsonl"
       done
   <!-- /comandi -->

   Infine i dati e i verdetti, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D05

   Per altre esecuzioni, di nuovo dallo spazio di lavoro (`cd -` vi
   riporta lì), `-2`, `-3` al posto di `-1` nel blocco.

`_docente/live.sh` manda lo stesso testo con le stesse opzioni, dalle
stesse copie, più `--setting-sources project,local` e
`--permission-prompts none`.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina delle best practice, sullo Stop hook: «Exit code 2 is what
  blocks the stop. Whatever the command prints to stderr goes back to
  Claude as the reason it can't finish yet». È l'uscita con codice 2 a
  bloccare la fine del turno, e ciò che il comando scrive su stderr torna
  a Claude come il motivo per cui non può ancora finire.
  https://code.claude.com/docs/en/best-practices
- Nella stessa pagina, l'esempio con il compilatore di TypeScript (`tsc`):
  «ask Claude for a change that breaks a type: instead of finishing, it
  gets the compiler errors back and keeps going until tsc passes.» Qui il
  controllo è la suite di test, e il prompt non la nomina.
- Il limite, nella stessa pagina: «If the hook blocks eight stops in a
  row with no tool call between them, Claude Code overrides the next
  block and ends the turn.»
- Che cosa succede senza un controllo, ancora lì: «Claude stops when the
  work looks done.» E: «If it has nothing to run that tells it whether
  the work actually is done, "looks done" is all it has to go on.»
- Perché un hook e non una riga nel prompt: «there's no guarantee that
  it'll follow your instructions. It can still decide not to do things,
  or do other things.» Mentre: «Deterministic: you configure the
  instruction, and Claude Code (the harness) has to execute this.»
  (https://code.claude.com/docs/en/best-practices)
- Gli hook in `claude -p`: «a -p session runs the hooks in a project’s
  .claude/settings.json and connects the servers in its .mcp.json, even
  in a folder you’ve never trusted»
  (https://code.claude.com/docs/en/headless).
- Un'avvertenza della Claude Academy: «A test can be quietly loosened so
  it passes no matter what.»
  (https://academy.claude.com/courses/claude-code-in-action/verification-skills)
  Per questo il controllo dice quali file sono cambiati nella copia.

### Che cosa misura il controllo

`controlla_stop.py` legge, per ogni esecuzione dei due bracci, lo stream
e la copia del progetto in cui la sessione ha lavorato. Conta i blocchi
dello Stop hook, cioè i messaggi «Stop hook feedback» della conversazione
principale, e il numero più alto di blocchi di fila senza chiamate a
strumenti in mezzo; conta gli strumenti chiamati e i permessi negati; dice
quali file del progetto la copia ha cambiato rispetto a
`progetti/urgenze/`; riesegue i test nella copia. Il testo dei blocchi, con
l'uscita dei test, non lo stampa.

Poi, su ogni esecuzione con l'hook:

- «L'uscita 2 dello Stop hook blocca la fine del turno», una garanzia del
  prodotto: confermata se l'hook ha bloccato almeno una volta e alla
  fine i test sono verdi; non distinguibile se l'hook non ha mai
  bloccato (i test erano già verdi alla prima fine del turno). Con i test
  rossi e otto blocchi di fila senza strumenti in fondo allo stream, è il
  limite che la documentazione descrive, e si stampa come tale. Con i
  test rossi e senza quel limite in fondo, è una segnalazione: «non
  confermata in questa esecuzione», e la verifica esce 1;
- «Claude continua finché il controllo passa», un comportamento che
  Anthropic descrive: confermata se, dopo almeno un blocco, alla fine i
  test sono verdi; poi «confermata n su N». Non fa fallire la verifica.

Se in nessuna esecuzione con l'hook lo Stop hook ha bloccato, la garanzia
non si è potuta mettere alla prova: la verifica dice «Non ancora» ed esce
1, e chiede un'altra esecuzione per braccio.

Sul braccio senza hook, i test verdi alla fine sono un dato: «n su N».

Prima di decidere, il controllo guarda che la coppia sia una coppia: ci
sono i due bracci, ogni copia ha le impostazioni del suo braccio e, tolto
l'hook, sono uguali in tutte; tutte le esecuzioni hanno lo stesso modello
e la stessa modalità; nessuna esecuzione senza hook mostra blocchi.
Altrimenti la verifica esce 1 e dice che cosa rifare. Il controllo non
scrive niente.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low, in acceptEdits, tre esecuzioni per braccio): con
l'hook, un blocco in ogni esecuzione, `urgenza.py` cambiato e
`test_urgenza.py` no, e i test verdi alla fine (3 test, OK). «L'uscita 2
dello Stop hook blocca la fine del turno»: confermata in tutte e tre;
«Claude continua finché il controllo passa»: confermata 3 su 3. Senza
l'hook, nessun blocco, `urgenza.py` cambiato e `test_urgenza.py` no, ma i
test rossi alla fine in tutte e tre, «FAILED (failures=1)»: «Senza lo
Stop hook, i test verdi alla fine: 0 su 3». Come dato, con l'hook un
permesso negato in ogni esecuzione, senza nessuno. Le sei esecuzioni sono
nella cartella `soluzione/esecuzioni/` di questo elemento.

## Verifica (tools/verifica.sh M4-D05)

La verifica fa girare `controlla_stop.py`, quello della cartella
dell'elemento, sulle esecuzioni dello spazio di lavoro. È fatta quando ci
sono i due bracci, ogni stream è quello riuscito di `claude -p` con
accanto la sua copia, la coppia differisce soltanto nell'hook, almeno
un'esecuzione con l'hook mostra un blocco e la garanzia tiene: l'ultima
riga dice «Fatto: …». Sul punto di partenza, senza `esecuzioni/`, esce 1.

## Se qualcosa va storto

- `live.sh` dice che ci sono già delle esecuzioni: ripartite da capo con
  `tools/reset_esercizio.sh M4-D05` (le esecuzioni si perdono), oppure
  aggiungetene con i comandi del passo 3 e il numero successivo.
- `live.sh` dice che lo spazio di lavoro non è al punto di partenza (un
  file del progetto è cambiato, o ce n'è uno in più, e finirebbe in ogni
  copia), oppure che le impostazioni dei due bracci, tolto l'hook,
  differiscono: `tools/reset_esercizio.sh M4-D05` lo prepara di nuovo.
- La verifica dice «nessun blocco nello stream: l'hook ha girato?»:
  guardate che `esecuzioni/con-hook-<n>/urgenze/.claude/settings.json`
  abbia l'hook e che la sessione sia partita dalla copia (il `cd` del
  blocco), dove stanno le sue impostazioni.
- La verifica dice «Non ancora: in nessuna esecuzione con l'hook lo Stop
  hook ha bloccato»: i test erano già verdi alla prima fine del turno, e
  la garanzia non si è potuta mettere alla prova. Aggiungete
  un'esecuzione per braccio, con il numero successivo.
- La verifica dice che le impostazioni di una copia non sono quelle del
  suo braccio, o che le copie differiscono in altro, oppure che uno
  stream manca, che una riga non è JSON, che lo stream non finisce con il
  risultato o che c'è soltanto il risultato (`--output-format json` al
  posto di `stream-json`): la verifica vuole buone tutte le esecuzioni di
  `esecuzioni/`, quindi togliete prima la cartella di quella che non va,
  dallo spazio di lavoro, con `rm -rf esecuzioni/<braccio>-<n>` (con
  `rm -r` vi chiederebbe conferma per ogni file della copia: i suoi
  oggetti git sono in sola lettura). Poi rifatela, con `nuova_copia.sh`,
  il file di `impostazioni/` del braccio e lo STDERR fuori dal file;
  oppure ripartite da capo con `tools/reset_esercizio.sh M4-D05`.
- Con l'hook, i test rossi e otto blocchi di fila in fondo allo stream:
  è il limite descritto dalla documentazione, non un errore della
  verifica.
- La verifica stampa una segnalazione: in quell'esecuzione la garanzia
  non ha tenuto. Conservate la cartella `esecuzioni/` e mostratela al
  docente.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Due sessioni `claude -p` per esecuzione, una per braccio, su Sonnet con
effort low e acceptEdits, un solo prompt, gli strumenti Read, Edit e i
test, nessun subagent. Nel braccio con l'hook ogni blocco fa continuare
la sessione, e consuma altre richieste. claude.ai e Claude Code
consumano gli stessi limiti: se il limite della sessione è vicino,
guardate il risultato del docente invece di rifare i due bracci.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low), dal JSON di ogni esecuzione: con l'hook 8, 7 e
8 turni (`num_turns`), 18,5, 21,0 e 38,6 secondi, 112.670, 111.465 e
153.979 token in entrata, cache compresa; senza, 5, 4 e 4 turni, 15,8,
17,1 e 12,3 secondi, 72.221, 71.988 e 71.975 token.

## Per approfondire

- «Best practices for Claude Code», con lo Stop hook che esegue un
  controllo: https://code.claude.com/docs/en/best-practices
- «Automate actions with hooks», la guida agli hook:
  https://code.claude.com/docs/en/hooks-guide
- Il riferimento degli hook: eventi, codici d'uscita, configurazione:
  https://code.claude.com/docs/en/hooks
- `claude -p` in modalità non interattiva, e gli hook che carica:
  https://code.claude.com/docs/en/headless
- Il corso «Claude Code in action» della Claude Academy, sulle sessioni
  lunghe e poco sorvegliate e su come verificarle:
  https://academy.claude.com/courses/claude-code-in-action
- Il video «Building verification loops in Claude Code», sul canale
  YouTube di Claude: https://www.youtube.com/watch?v=mQZB0l-rhxE
