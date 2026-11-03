# M5-D03 — Tre garanzie

Demo del Modulo 5, nella parte «Skill e Claude Code». In aula il docente fa
girare una coppia per ogni garanzia; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova tre cose che la documentazione di Claude Code garantisce
intorno a una skill: un `` !`comando` `` porta i dati prima che Claude legga, e
un comando non consentito ferma l'invocazione; `allowed-tools` concede un
permesso per un turno solo; una skill con `context: fork` gira in un subagent
che non vede la conversazione. Per ogni garanzia ci sono esecuzioni che
differiscono in una cosa sola, uno script legge i loro stream e decide. Sono
garanzie del prodotto: devono valere a ogni esecuzione.

## Tempo

4 minuti in aula, la demo del docente. Per rifarla da soli, qualche minuto.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M5-D03)

Lo spazio di lavoro `~/corso-claude-code/M5-D03/` con:

- `coppie/`: otto cartelle, una per braccio, ciascuna con la sua skill in
  `.claude/skills/`. Le due di una coppia differiscono in una cosa sola:
  `diff -r coppie/parola-inline coppie/parola-fork` lo mostra;
- `conta.sh` ed `elenco.txt`: lo script che le skill eseguono e il suo elenco
  di apparati. `conta.sh` stampa una sentinella che nel suo testo non c'è:
  compare soltanto se lo script gira. E non è un comando di sola lettura: `cat`
  e `wc`, che lo sono, passerebbero comunque;
- `in_classe.sh` e `lib_coppie.sh`: la demo;
- `controlla_garanzie.py`: il controllo, che legge gli stream.

Il codice casuale di `codice.txt` e la parola in codice non stanno nel
repository: `in_classe.sh` li genera quando parte, per ogni spazio di lavoro.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M5-D03
       cd ~/corso-claude-code/M5-D03

2. Lanciate la demo. Mostra ogni comando prima di eseguirlo e si ferma prima di
   ogni coppia (`HANDSON_NO_PAUSE=1` per non fermarsi):

       bash in_classe.sh

   Sono undici chiamate a `claude -p`, ognuna con il suo stream, che è ciò che il
   controllo legge. Ogni braccio gira in una copia nuova, in una cartella
   temporanea, con Sonnet ed effort low, in `dontAsk`. Ciò che ogni coppia manda:

   | coppia | braccio | che cosa manda |
   |---|---|---|
   | `codice` | `con`, `senza` | `/prova-codice` |
   | `comando` | `con`, `senza` | `/prova-conta` |
   | `permesso` | `con` | `/prova-esegui`, poi con `--resume` «Esegui di nuovo bash conta.sh con Bash e riporta il risultato, così com'è.» |
   | `permesso` | `senza` | `/prova-esegui` |
   | `parola` | `inline`, `fork` | «Ricorda: la parola in codice è ciaspola-…. Rispondi solo: ok», poi con `--resume` `/prova-parola` |

   Le chiamate di `parola` hanno `--allowedTools Skill,Agent`, in tutti e due i
   bracci: `Skill` senza un nome fra parentesi, quindi ogni skill della copia, che
   qui ne ha una sola. Le altre chiamate non hanno nessuno strumento consentito.

3. Dalla cartella `esercitazioni`, la verifica:

       cd -
       tools/verifica.sh M5-D03

   Oppure, dallo spazio di lavoro (`cd -` vi riporta lì),
   `python3 controlla_garanzie.py`.

`_docente/live.sh` lancia lo stesso `in_classe.sh` con tre esecuzioni per
braccio: `PN_ESECUZIONI` ne sceglie da 1 a 9.

## Che cosa osservare

### Che cosa dice Anthropic

Tutte le frasi vengono da «Extend Claude with skills»,
https://code.claude.com/docs/en/skills.

- **Il `!` porta i dati prima che Claude legga.** «The command output replaces
  the placeholder, so Claude receives actual data, not the command itself.»
- **Un comando non consentito ferma l'invocazione.** «Outside auto mode, when a
  command's permission check returns anything other than allow, Claude Code
  aborts the invocation with the same error.» E il rimedio: «To keep an
  unmatched command from aborting here, pre-approve it with allowed-tools.» Di
  un comando che fallisce la pagina dice: «A failed command aborts the entire
  skill invocation, not just its own placeholder. Claude never sees the skill
  content for that invocation.»
- **`allowed-tools` vale per un turno.** «Tools Claude can use without asking
  permission during the turn that invokes this skill. The grant clears when you
  send your next message.» E ancora: «The grant clears when you send your next
  message, even though the skill content stays in context». Non è un limite:
  «It does not restrict which tools are available: every tool remains callable,
  and your permission settings still govern tools that are not listed.» Questa
  frase la demo non la prova: la cita perché il campo non si legga al contrario.
- **`context: fork` non vede la conversazione.** «The subagent doesn't see your
  conversation history, so the skill's instructions have to stand on their
  own.» Il nome inganna: «Despite the name, a skill with context: fork doesn't
  run in a fork of the current conversation». Di solito il subagent gira in
  background, ma non in `-p`: «Claude Code also waits for the result … In
  non-interactive mode, with the -p flag or the Agent SDK».

Come si leggono le esecuzioni:

- `/nome` nel prompt: «User-invoked skills and custom commands work. Include
  /skill-name in the prompt string and Claude Code expands it before running.»
  (https://code.claude.com/docs/en/headless)
- Il messaggio dopo, nella stessa sessione: «Use --continue to continue the most
  recent conversation, or --resume with a session ID to continue a specific
  conversation.» (stessa pagina)
- I dinieghi, in `dontAsk`: «Claude Code denies every call that would otherwise
  prompt … though a mod you installed can still approve some of those calls.» e
  «With --output-format stream-json, denials appear as permission_denied system
  messages, and the final result message lists them in permission_denials.»
  (stessa pagina)
- Perché `cat` passa comunque, e `bash conta.sh` no: «Claude Code recognizes a
  built-in set of Bash commands as read-only and runs them without a permission
  prompt in every mode, except as
  permissions.blockReadsOutsideWorkingDirectories changes for paths outside your
  working directories. The set includes ls, cat, echo, pwd, head, tail, grep,
  find, wc, which, diff, stat, du, cd, and read-only forms of git.»
  (https://code.claude.com/docs/en/permissions)

### Che cosa misura il controllo

`controlla_garanzie.py` legge gli stream di `risposte/`, un'esecuzione per numero,
e stampa per ogni braccio: la risposta, gli strumenti chiamati, ciò che la sua
coppia guarda, i turni, i token e i secondi, sommati su ogni risultato. Poi i
verdetti, coppia per coppia ed esecuzione per esecuzione:

- **`codice`.** Una riga del corpo, `` !`cat codice.txt` `` contro
  `` `cat codice.txt` ``: un carattere. Confermata se con il `!` il codice
  casuale è nella risposta e non c'è nessuna chiamata a uno strumento, e senza
  c'è una chiamata, oppure il dato non c'è. Il codice non è nel corpo della
  skill: Claude può averlo solo dall'output.
- **`comando`.** `` !`bash conta.sh` ``, con `allowed-tools: Bash(bash conta.sh)`
  e senza. Confermata se con il campo la sentinella è nella risposta, senza
  nessuna chiamata, e senza il campo l'invocazione si ferma: nello stream il
  messaggio «Shell command permission check failed for pattern …», zero turni
  del modello.
- **`permesso`.** Un corpo che chiede di eseguire `bash conta.sh`, con il campo e
  senza. Confermata se con il campo il comando gira, la sentinella è nel suo
  risultato; il messaggio dopo, che lo chiede di nuovo nella stessa sessione, è
  negato, la chiamata è in `permission_denials`; e senza il campo è negato.
- **`parola`.** Un primo turno dice la parola in codice; poi, nella stessa
  sessione, `/prova-parola`, senza `context: fork` e con. Confermata se senza
  il campo la parola torna nella risposta, e con il campo non torna e lo stream
  mostra il subagent.

Una garanzia che non regge è «non confermata in questa esecuzione»: un esito da
segnalare, e il controllo esce con 1. Una coppia che non mostra la differenza
è «non distinguibile», con il perché: Claude non ha riprovato, ha chiamato uno
strumento dove il dato doveva arrivare senza, o il secondo turno non ha ripreso
la stessa sessione. Non dice niente sulla garanzia, ma non l'ha messa alla
prova: anche lì esce con 1, e la coppia si rifà.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, tre esecuzioni per braccio e trentatré chiamate, `_docente/live.sh`
sull'account del docente), le stesse righe a ogni esecuzione:

- `codice`: «con ! il codice nella risposta, nessuno strumento; senza !: Bash (cat
  codice.txt), il codice c'è»;
- `comando`: «con allowed-tools la sentinella nella risposta, nessuno strumento;
  senza, fermata con zero turni»;
- `permesso`: «con il campo eseguito; al messaggio dopo negato; senza il campo
  negato»;
- `parola`: «senza context: fork la parola torna; con context: fork no, e lo stream
  mostra il subagent»; con il campo, la risposta è «NON LA VEDO».

Poi: «! porta il dato prima che Claude legga: confermata 3 su 3», «Un comando non
consentito ferma l'invocazione: confermata 3 su 3», «allowed-tools vale per un
turno: confermata 3 su 3», «Con context: fork il subagent non vede la conversazione:
confermata 3 su 3», e «Ogni garanzia è confermata in ogni esecuzione.» Gli stream
sono nella cartella `soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M5-D03)

La verifica fa girare `controlla_garanzie.py` dell'elemento, non la copia dello
spazio di lavoro, sulle risposte dello spazio di lavoro. È fatta quando c'è
almeno un'esecuzione completa, ogni stream è lo stream-json riuscito di `claude -p`
e ogni garanzia è confermata a ogni esecuzione. Le ultime due righe sono allora
«Fatto: ogni garanzia è stata messa alla prova; gli esiti sono qui sopra.» e
«VERIFICA OK   M5-D03: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: lanciate `bash in_classe.sh`; gli
  stream vanno in `risposte/` soltanto quando l'ultima chiamata è finita.
- `in_classe.sh` dice che `risposte/` c'è già, o la verifica dice che uno stream
  manca o non finisce con il risultato: ricominciate da capo con
  `tools/reset_esercizio.sh M5-D03`.
- Una coppia è «non distinguibile»: leggete il perché nella riga del verdetto,
  poi ricominciate da capo. Se torna, segnalatelo: la demo non sta mettendo alla
  prova ciò che dice.
- Una garanzia è «non confermata»: è un esito da segnalare al docente, con lo
  stream di `risposte/` che la riga nomina.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet, effort low. Undici chiamate per esecuzione, di uno o due turni del modello;
due sono un primo turno che risponde «ok», e una si ferma prima del modello, zero
turni. Il docente fa tre esecuzioni per la registrazione, trentatré chiamate; in
aula e da soli ne basta una. Non lanciate voi nessun subagent: ne apre uno soltanto
il braccio con `context: fork`. Il controllo gira sul vostro computer, senza chiamate
al modello. Le coppie riprese con `--resume` hanno bisogno di una sessione
salvata, e la trascrizione resta dove Claude Code la tiene: «By default, Claude
Code stores transcripts as JSONL at
~/.claude/projects/<project>/<session-id>.jsonl»
(https://code.claude.com/docs/en/sessions).

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, tre esecuzioni per braccio, `_docente/live.sh` sull'account del docente,
un piano Max), la riga del consumo, dal controllo: «Come dato, tutte le 33 chiamate:
turni 39; token 685.117; 134,7 s.» Un'esecuzione è circa un terzo. Quei token sono
la somma di `usage`, entrata, cache e uscita di ogni chiamata, compreso il contesto letto dalla cache:
dicono quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano
occupa. La riga di ogni chiamata ha accanto «tutti i modelli», da `modelUsage`: «Use
modelUsage, or model_usage in Python, for whole-tree token accounting; the usage
field undercounts as soon as nesting occurs.»
(https://code.claude.com/docs/en/agent-sdk/cost-tracking). Nel braccio `fork`
`usage` dice 0, e `modelUsage` 28.835, 28.840 e 28.828, compresi il primo turno
della sessione e il subagent; in una sessione ripresa con `--resume`, `modelUsage`
conta anche il turno di prima: nel messaggio dopo di `permesso`, nella prima
esecuzione, «token 35.661 (tutti i modelli 70.696)».

## Per approfondire

- «Extend Claude with skills», `!`, `allowed-tools` e `context: fork`:
  https://code.claude.com/docs/en/skills
- La pagina dei permessi di Claude Code, con i comandi di sola lettura:
  https://code.claude.com/docs/en/permissions
- `claude -p` e lo stream-json: https://code.claude.com/docs/en/headless
- Il corso dell'Academy «Introduction to agent skills»:
  https://academy.claude.com/courses/introduction-to-agent-skills
