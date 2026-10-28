# M4-D06 — Delegare la lettura

Demo del Modulo 4, nella parte «Subagent: delegare o fare da sé». In aula
il docente fa girare le coppie di esecuzioni con `_docente/live.sh`; una
coppia potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova che cosa cambia quando Claude delega una lettura
pesante a un subagent. La stessa domanda su una settimana di log della
rete di CiaspoLink, una volta chiedendo a Claude di delegare la lettura
dei log al subagent Explore, una volta chiedendogli di leggerli da sé: le
due esecuzioni di una coppia differiscono soltanto nella prima frase del
prompt. La domanda è esatta, con una lettura sola: «Martedì 8 settembre
2026 un guasto su olt-pergine-01 ha messo fuori servizio insieme più
linee di clienti. Quando è cominciato, quando è finito (quando le ONT
sono tornate in linea) e quante linee di clienti (ONT) ha coinvolto?
Rispondi in una riga: 'inizio: HH:MM | fine: HH:MM | ONT: N'.» Dice che
cosa contare, non dove trovarlo. Si guarda che cosa arriva alla
conversazione principale, quanto contesto le resta all'ultima richiesta e
quanti token costa il tutto.

## Tempo

5 minuti in aula, la demo del docente. Per rifare una coppia da soli,
qualche minuto.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M4-D06)

Lo spazio di lavoro `~/corso-claude-code/M4-D06/` con:

- `progetti/rete/`: la rete di CiaspoLink, senza il materiale del docente;
  in `progetti/rete/log/` una settimana di log (syslog, PPPoE, RADIUS,
  DHCP, SIP), da lunedì 7 a domenica 13 settembre 2026;
- `prompt_delega.txt` e `prompt_senza.txt`: i due prompt;
- `controlla_delega.py`: il controllo, che legge gli stream.

Ogni sessione parte da `progetti/rete/log/`, dove ci sono soltanto i log:
lì niente dice la risposta. La risposta giusta sta in `verita.json`, nella
cartella di questo elemento, fuori dallo spazio di lavoro, e la legge la
verifica.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M4-D06
       cd ~/corso-claude-code/M4-D06

2. Una coppia: la stessa domanda con la delega e senza, ognuna in una
   sessione nuova di `claude -p` che parte da `progetti/rete/log/`. Gli
   stream vanno in una cartella temporanea e arrivano in `risposte/` solo
   alla fine, così nessuna sessione trova la risposta di quella prima.
   `--tools Agent,Read,Grep,Glob` lascia alla sessione, fra gli strumenti
   integrati, soltanto Agent, che lancia il subagent, e quelli per leggere
   e cercare: Bash non c'è (il perché è più sotto, in «Perché le sessioni
   non hanno Bash»). `--allowedTools Read,Grep,Glob` consente la lettura
   e le ricerche. Per tre coppie, come il docente, scrivete
   `for n in 1 2 3`:

       r="$(mktemp -d)"
       for n in 1; do
         for b in delega senza; do
           p="$(cat "prompt_$b.txt")"
           (cd progetti/rete/log && claude -p --model sonnet --effort low \
             --tools Agent,Read,Grep,Glob --allowedTools Read,Grep,Glob \
             --permission-mode dontAsk --permission-prompts none \
             --setting-sources project,local \
             --strict-mcp-config --no-session-persistence \
             --output-format stream-json --verbose -- "$p") \
             > "$r/$b-$n.jsonl"
         done
       done
       mkdir -p risposte && mv "$r"/*.jsonl risposte/ && rmdir "$r"

3. Dalla cartella `esercitazioni`, la verifica, con la verità:

       cd -
       tools/verifica.sh M4-D06

   Oppure, dallo spazio di lavoro (`cd -` vi riporta lì),
   `python3 controlla_delega.py`: stampa tutto, tranne il confronto delle
   risposte con la verità, che lì non c'è.

`_docente/live.sh` manda gli stessi prompt con le stesse opzioni, per tre
coppie (la variabile `PN_COPPIE` ne sceglie da 1 a 9).

## Che cosa osservare

### Che cosa dice Anthropic

- Nel riferimento degli strumenti di Claude Code, sul subagent: «The
  parent doesn't see the subagent's intermediate tool calls or outputs,
  only that final result.» La conversazione principale non vede le
  chiamate e i risultati intermedi del subagent: soltanto il suo
  risultato finale. https://code.claude.com/docs/en/tools-reference
- Nella pagina «Create custom subagents», quando usarne uno: «Use one when
  a side task would flood your main conversation with search results,
  logs, or file contents you won't reference again».
  https://code.claude.com/docs/en/sub-agents
- Nella pagina «Best practices for Claude Code», fra i casi in cui un
  subagent ripaga: «Keeping long output, like a full test run or a wide
  search, out of your main conversation». Il costo: «What they cost you is
  mostly tokens, since every subagent sends its own requests and they
  count against the same usage as your main conversation.» Che cosa se ne
  ottiene: «You get parallelism or a fresh pair of eyes out of it, but not
  a smarter answer.» E per spendere meno: «Ask for short summaries back,
  so twenty results don't fill your context anyway.»
  https://code.claude.com/docs/en/best-practices
- Il subagent si chiede per nome, e decide Claude: «Natural language: name
  the subagent in your prompt; Claude decides whether to delegate»
  (https://code.claude.com/docs/en/sub-agents). Explore è uno dei
  subagent già pronti, con i soli strumenti di lettura: «Tools: read-only
  tools; Write and Edit are denied» (stessa pagina). Senza configurazione
  parte in background: «With nothing configured, a subagent that Claude
  spawns from your main conversation starts in the background.» (stessa
  pagina).
- Lo strumento che lancia un subagent: «In version 2.1.63, the Task tool
  was renamed to Agent.» (https://code.claude.com/docs/en/sub-agents); e,
  nello stream, «The tool appears as "Agent" in tool_use blocks but as
  "Task" in the system:init tools list.»
  (https://code.claude.com/docs/en/agent-sdk/subagents).
- Come si leggono gli stream: «Their parent_tool_use_id field says which
  run each one belongs to. Messages from the main conversation carry null
  in that field.» (https://code.claude.com/docs/en/headless). E i token di
  tutto l'albero: «Use modelUsage, or model_usage in Python, for
  whole-tree token accounting; the usage field undercounts as soon as
  nesting occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking)

### Perché le sessioni non hanno Bash

In una registrazione del docente (28 ottobre 2026, Claude Code 2.1.312)
le sessioni avevano tutti gli strumenti integrati. In cinque stream su
sei Claude ha lanciato di sua iniziativa un `ls -la`: nel subagent, nelle
tre esecuzioni con la delega; nella conversazione principale, in due di
quelle senza. In dontAsk, la modalità della prova, è passato senza
chiedere: è un comando di Bash in sola lettura, e quei comandi di regola
non chiedono il permesso. Nella pagina dei permessi: «Claude Code
recognizes a built-in set of Bash commands as read-only and runs them
without a permission prompt in every mode, except as
permissions.blockReadsOutsideWorkingDirectories changes for paths outside
your working directories. The set includes ls, cat, echo, pwd, head,
tail, grep, find, wc, which, diff, stat, du, cd, and read-only forms of
git.» (https://code.claude.com/docs/en/permissions). La colonna del
proprietario di `ls -la` ha scritto negli stream il nome dell'utente
della macchina, che uno stream registrato non deve portare: quella
registrazione non vale più.

Per questo le due sessioni di ogni coppia partono con
`--tools Agent,Read,Grep,Glob`. In `claude --help`: `--tools` «Specify
the list of available tools from the built-in set.»: fra gli strumenti
integrati la sessione ha soltanto quelli che si nominano, e Bash non è
fra questi. Agent resta, perché è lo strumento che lancia il subagent
(sopra: «In version 2.1.63, the Task tool was renamed to Agent.»). Read,
Grep e Glob bastano per leggere i log e cercarci dentro. Glob e Grep, su
macOS, Linux e WSL, Claude Code li lascia fuori dagli strumenti
predefiniti: «On macOS, Linux, and WSL, Claude Code leaves Glob and Grep
out of the default tool set»; qui tornano perché si nominano: «You name
Glob or Grep in --tools or --allowedTools when you start the session»
(https://code.claude.com/docs/en/tools-reference). Le due sessioni
differiscono ancora soltanto nella prima frase del prompt; gli strumenti
che il subagent usa davvero, il controllo li stampa come dati.

### Che cosa misura il controllo

`controlla_delega.py` legge gli stream di `risposte/`, una coppia per
numero: `delega-<n>.jsonl` e `senza-<n>.jsonl`. Per ogni esecuzione
stampa, come dati: gli strumenti della conversazione principale, con le
chiamate Agent e il tipo di subagent, e quelli del subagent; i caratteri
dei risultati degli strumenti dalle due parti; il contesto principale
all'ultima richiesta, cioè l'input e la cache dell'ultimo messaggio
dell'assistente con `parent_tool_use_id` null; i token di tutti i modelli,
dal `modelUsage` del risultato finale; la durata; la risposta, che è il
testo del risultato finale (uno stream con la delega può averne più di
uno), e se è giusta.

Poi i verdetti:

- la garanzia, «La conversazione principale vede solo il risultato del
  subagent»: in ogni esecuzione con la delega in cui il subagent ha
  lavorato (lo stream mostra i risultati dei suoi strumenti), nessun
  messaggio della conversazione principale porta un risultato che non sia
  di una sua chiamata: né di una chiamata del subagent, né di una che lo
  stream non mostra. È una garanzia del prodotto: se non tiene, la
  verifica esce con 1. Un'esecuzione senza subagent, o senza il suo
  lavoro nello stream, non la mette alla prova: non distinguibile; e se
  nessuna esecuzione la mette alla prova, la verifica dice «non ancora»;
- il confronto, «Un subagent tiene i log fuori dalla conversazione
  principale», coppia per coppia: confermata se il contesto principale
  all'ultima richiesta è più piccolo con la delega; non distinguibile se è
  uguale, o se la coppia non differisce nella delega (Claude decide se
  delegare: nessun subagent con la delega, oppure uno anche senza); non
  confermata in questa esecuzione se è più grande. Poi «confermata n su
  N». È un confronto: il verdetto si stampa e non fa fallire la verifica.

Come dati, mai come verdetto: i token di tutti i modelli con la delega e
senza, perché il costo è soprattutto in token, e le risposte giuste da una
parte e dall'altra, perché la risposta non è più intelligente. La verità,
inizio, fine e numero di ONT coinvolti, sta in `verita.json` di questo
elemento; il controllo legge dalla risposta i tre campi della riga
'inizio: HH:MM | fine: HH:MM | ONT: N'.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low, tre coppie, `--tools Agent,Read,Grep,Glob`): in
ogni esecuzione con la delega Claude ha lanciato un subagent Explore, che
ha usato Glob e Grep, e in due su tre anche Read; i risultati dei suoi
strumenti, 38.964, 38.995 e 12.091 caratteri, sono rimasti nel subagent,
e alla conversazione principale ne sono arrivati 976. Senza la delega la
conversazione principale ha usato Glob e Grep, con 11.809, 11.735 e
11.809 caratteri di risultati. «La conversazione principale vede solo il
risultato del subagent»: confermata 3 su 3. «Un subagent tiene i log
fuori dalla conversazione principale»: confermata 3 su 3, con un contesto
principale all'ultima richiesta di 9.948 token contro 16.318, 10.014
contro 16.150 e 9.781 contro 16.318. Come dati: tutti i modelli, 188.296
token in entrata con la delega e 117.147 senza; le risposte giuste, 3 su
3 da tutte e due le parti. Le sei esecuzioni sono nella cartella
`soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M4-D06)

La verifica fa girare `controlla_delega.py` dell'elemento, con
`verita.json` dell'elemento, sulle risposte dello spazio di lavoro. È
fatta quando c'è almeno una coppia completa, ogni stream è lo stream-json
riuscito di `claude -p`, almeno un'esecuzione con la delega mette alla
prova la garanzia e la garanzia tiene. Il confronto, i token e le
risposte si stampano e non la fanno fallire. Quando tutto è in ordine,
l'ultima riga è «Fatto: ogni affermazione è stata messa alla prova; gli
esiti sono qui sopra.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/` o che non c'è nessuna coppia:
  eseguite il passo 2 fino all'ultima riga, che sposta gli stream in
  `risposte/`.
- Dice che manca uno stream, per esempio `risposte/senza-1.jsonl`, o che
  uno stream non finisce con il risultato: rifate la coppia, con
  `rm -r risposte` e di nuovo il passo 2.
- Claude non ha delegato, oppure ha delegato anche quando gli si chiedeva
  di no: Claude decide se delegare, e il controllo stampa quella coppia
  come «non distinguibile». Se in nessuna coppia il subagent ha lavorato,
  la verifica dice «non ancora»: la garanzia non si è potuta mettere alla
  prova; rifate la coppia, con `rm -r risposte` e di nuovo il passo 2.
- Nello stream c'è un messaggio `permission_denied`: in dontAsk Claude
  Code nega ogni chiamata che chiederebbe un permesso.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-D06`.

## Impronta d'uso sul piano Pro

Ogni esecuzione è una sessione di `claude -p` su Sonnet con effort low;
in quella con la delega, se Claude delega, lavora anche un subagent
Explore, che usa il modello della conversazione principale: «Model: the
main conversation's model» (https://code.claude.com/docs/en/sub-agents). La lettura è
pesante: nella registrazione del corso le tre coppie hanno usato in tutto
188.296 token in entrata con la delega e 117.147 senza, contando tutti i
modelli, cioè circa 100.000 per coppia. Per rifarla da soli basta una
coppia; il docente ne fa tre.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low, senza Bash), come le stampa il controllo: con la
delega 16, 13 e 10 secondi dal primo all'ultimo orario dello stream e
66.282, 66.543 e 55.471 token in entrata contando tutti i modelli; senza,
9 secondi ciascuna e 42.108, 32.931 e 42.108 token. Dal JSON: con la
delega ogni stream ha due risultati, 2 turni del modello (`num_turns`)
mentre il subagent lavora in background e 1 per la risposta; senza, 4, 3
e 4 turni.

## Per approfondire

- «Create custom subagents», i subagent e quelli già pronti:
  https://code.claude.com/docs/en/sub-agents
- «Best practices for Claude Code», quando i subagent ripagano e quanto
  costano: https://code.claude.com/docs/en/best-practices
- Il riferimento degli strumenti, con il tool Agent:
  https://code.claude.com/docs/en/tools-reference
- Claude Code senza terminale, `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- Contare i token di tutto l'albero, nell'Agent SDK:
  https://code.claude.com/docs/en/agent-sdk/cost-tracking
- Anthropic Academy, «Introduction to subagents»:
  https://academy.claude.com/courses/introduction-to-subagents
