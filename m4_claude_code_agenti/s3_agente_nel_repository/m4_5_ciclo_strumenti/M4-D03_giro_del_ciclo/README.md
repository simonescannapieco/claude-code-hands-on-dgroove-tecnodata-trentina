# M4-D03 — Un giro del ciclo, registrato

Demo del Modulo 4, nella parte «Il ciclo degli strumenti». In aula la
mostra il docente; potete rifarla da soli quando volete, con i comandi
del passo 3 di «Passi in Claude Code».

## Obiettivo

Guardare un giro del ciclo degli strumenti di Claude Code una richiesta
alla volta, e mettere alla prova ciò che Anthropic afferma: a ogni
richiesta Claude Code rimanda tutta la conversazione, e ogni volta che
Claude usa degli strumenti parte un'altra richiesta con i loro risultati.
Il compito è piccolo e ha un controllo che Claude può eseguire da sé:
correggere il confine dei 7 giorni nel progetto delle urgenze ed eseguire
i test finché passano.

## Tempo

4 minuti in aula: il docente lancia la sessione e legge la tabella delle
richieste. Circa 5 minuti per rifarla da soli.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, già chiesti dal corso: la copia del progetto è un
  repository git, e il controllo riesegue i test con Python.

## Punto di partenza (tools/prepara_esercizio.sh M4-D03)

Lo spazio di lavoro `~/corso-claude-code/M4-D03/` con:

- `progetti/urgenze/`: il progetto più piccolo del corso, la funzione
  `urgente(clienti, giorni_aperta)` di CiaspoLink, con la regola nella
  docstring, e i suoi tre test `unittest`;
- `prompt.txt`: il compito, la stessa frase per ogni esecuzione;
- `nuova_copia.sh`: prepara la copia del progetto in cui lavora una
  sessione, `esecuzioni/giro-<n>/urgenze/`, con le impostazioni di Claude
  Code dello spazio di lavoro e un repository git a sé, con un commit.
  Ogni esecuzione parte così dallo stesso punto, e `progetti/urgenze/`
  resta com'era.

Il controllo, `controlla_giro.py`, sta nella cartella di questo elemento,
non nello spazio di lavoro: lo fa girare `tools/verifica.sh M4-D03`.

## Passi in Claude Code

1. **Il docente**, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D03
       m4_claude_code_agenti/s3_agente_nel_repository/m4_5_ciclo_strumenti/M4-D03_giro_del_ciclo/_docente/live.sh ~/corso-claude-code/M4-D03

   Lo script mostra ogni comando prima di eseguirlo: la copia, poi
   `claude -p` dalla copia, poi la verifica. Per la registrazione del
   corso lo stesso script gira con `--esecuzioni 3`.

2. **In sala** si guarda la tabella che stampa la verifica, una riga per
   ogni richiesta al modello:
   - accanto a ogni richiesta, gli strumenti che Claude chiama: la
     sequenza si confronta con l'esempio di ciclo della documentazione,
     in «Che cosa osservare»;
   - i token in entrata, e quanto crescono da una richiesta alla
     successiva: ogni richiesta porta con sé tutto ciò che c'era prima,
     più i risultati degli strumenti;
   - in fondo, i test rieseguiti nella copia: dove è arrivata la sessione.

3. **Rifarla da soli**, quando volete. Preparate lo spazio di lavoro ed
   entrateci, dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M4-D03
       cd ~/corso-claude-code/M4-D03

   Poi una copia del progetto e una sessione che parte dalla copia, con
   lo stream in `esecuzioni/giro-1/stream.jsonl`:

   <!-- comandi -->
       p="$(cat prompt.txt)"
       bash nuova_copia.sh esecuzioni/giro-1
       (cd esecuzioni/giro-1/urgenze && claude -p "$p" --model sonnet \
         --effort low --allowedTools 'Read,Edit,Bash(python3 -m unittest*)' \
         --strict-mcp-config --no-session-persistence \
         --output-format stream-json --verbose) > esecuzioni/giro-1/stream.jsonl
   <!-- /comandi -->

   Infine la tabella e il verdetto, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D03

   Per un'altra esecuzione, di nuovo dallo spazio di lavoro (`cd -` vi
   riporta lì), `giro-2` al posto di ogni `giro-1` del blocco.

`_docente/live.sh` manda lo stesso testo con le stesse opzioni, dalla
stessa copia, più `--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina sui costi di Claude Code: «Claude Code sends your full
  conversation with every request, and each time Claude uses tools it
  sends another request carrying that batch of tool results.» Claude
  Code manda tutta la conversazione a ogni richiesta, e ogni volta che
  Claude usa degli strumenti manda un'altra richiesta con quei risultati.
  https://code.claude.com/docs/en/costs
- La conseguenza, nella pagina delle best practice: «Every request sends
  the whole conversation, so a session that's collected three unrelated
  tasks re-reads all three on every turn of the fourth.»
  https://code.claude.com/docs/en/best-practices
- Il ciclo, con un esempio, nella pagina su come funziona Claude Code:
  «Run the test suite to see what's failing … Edit the files to fix the
  issue … Run the tests again to verify»
  https://code.claude.com/docs/en/how-claude-code-works
- Come si contano le richieste, nella pagina dell'Agent SDK sul consumo
  di token: «When Claude uses tools in parallel, multiple messages share
  the same id with identical usage data. Track which IDs you've already
  counted and skip duplicates». E: «The deduplicated per-step values are
  accurate for input and cache tokens. Per-step output_tokens is a
  placeholder»: per questo il controllo guarda i token in entrata, non
  quelli in uscita.
  https://code.claude.com/docs/en/agent-sdk/cost-tracking
- La compattazione: «As you work, context fills up. Claude compacts
  automatically, but instructions from early in the conversation can get
  lost.» (https://code.claude.com/docs/en/how-claude-code-works). Nello
  stream si vede: «The SDK emits a message with type: "system" and
  subtype: "compact_boundary" in the stream when this happens»
  (https://code.claude.com/docs/en/agent-sdk/agent-loop). Che cosa fa:
  «Compaction is the practice of taking a conversation nearing the
  context window limit, summarizing its contents, and reinitiating a new
  context window with the summary.»
  (https://www.anthropic.com/research/effective-context-engineering-for-ai-agents)
  Dopo una compattazione, quindi, la conversazione che si rimanda è il
  riassunto.
- Perché un comando alla volta: «Claude Code is aware of shell operators,
  so a rule like Bash(safe-cmd *) won't give it permission to run the
  command safe-cmd && other-cmd.»
  (https://code.claude.com/docs/en/permissions); e l'asterisco in fondo
  alla regola: «The trailing * enables prefix matching, so Bash(git diff
  *) allows any command starting with git diff.»
  (https://code.claude.com/docs/en/headless). Con la modalità della prova
  del docente, «If you set dontAsk mode, Claude Code auto-denies every
  tool call that would otherwise prompt you»
  (https://code.claude.com/docs/en/permission-modes): un comando composto
  non passa.

### Che cosa misura il controllo

`controlla_giro.py` legge lo stream di ogni esecuzione di `esecuzioni/`,
riga per riga. Le richieste al modello sono i messaggi dell'assistente
della conversazione principale, uno per id: più eventi con lo stesso id
sono una richiesta sola, con lo stesso usage. Per ognuna stampa i token
in entrata, cioè `input_tokens` + `cache_read_input_tokens` +
`cache_creation_input_tokens` del suo usage, la differenza dalla
precedente, e gli strumenti che quella richiesta chiama: il file,
relativo alla copia, o il comando di Bash, con «errore» se il risultato
dello strumento è segnato come errore e «negato» se il permesso è stato
negato. Stampa poi i conteggi (richieste, chiamate a strumenti, permessi
negati, durata) e i test, rieseguiti ora nella copia: un dato, che dice
dove è arrivata la sessione.

Poi l'affermazione, su ogni esecuzione: «Ogni richiesta rimanda tutta la
conversazione», confermata se i token in entrata non scendono mai da una
richiesta alla successiva. È una garanzia del prodotto, che deve valere a
ogni esecuzione: una discesa è una segnalazione, «non confermata in
questa esecuzione», e la verifica esce 1. Una discesa subito dopo una
compattazione si stampa come tale e non è una segnalazione. Con una sola
richiesta non c'è niente da confrontare: «non distinguibile». Quante
richieste servono e quali strumenti Claude sceglie non sono verdetti: sono
dati. Il controllo non scrive niente: decide dagli stream e dalle copie.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low, tre esecuzioni): ognuna ha fatto 4 richieste al
modello e 3 chiamate a strumenti, senza permessi negati, e i token in
entrata sono saliti a ogni richiesta, da 17.330 a 17.809, da 17.331 a
17.791 e da 17.332 a 17.922. «Ogni richiesta rimanda tutta la
conversazione»: confermata in ognuna delle tre. Come dato, i test
rieseguiti nella copia: verdi in tutte e tre (3 test, OK). Le tre
esecuzioni sono nella cartella `soluzione/esecuzioni/` di questo
elemento.

## Verifica (tools/verifica.sh M4-D03)

La verifica fa girare `controlla_giro.py`, quello della cartella
dell'elemento, sulle esecuzioni dello spazio di lavoro. È fatta quando
c'è almeno un'esecuzione, ogni stream è quello riuscito di `claude -p`
con accanto la sua copia, e la garanzia tiene in tutte: l'ultima riga
dice «Fatto: …». Sul punto di partenza, senza `esecuzioni/`, esce 1. I
test rossi nella copia non la fanno fallire: sono un dato.

## Se qualcosa va storto

- `live.sh` dice che ci sono già delle esecuzioni: ripartite da capo con
  `tools/reset_esercizio.sh M4-D03` (le esecuzioni si perdono), oppure
  aggiungetene una con i comandi del passo 3 e il numero successivo.
- `live.sh` dice che lo spazio di lavoro non è al punto di partenza: un
  file del progetto è cambiato, o ce n'è uno in più, e finirebbe in ogni
  copia. `tools/reset_esercizio.sh M4-D03` lo prepara di nuovo.
- La verifica dice che uno stream manca, che una riga non è JSON, che lo
  stream non finisce con il risultato o che c'è soltanto il risultato
  (`--output-format json` al posto di `stream-json`): la verifica vuole
  buone tutte le esecuzioni di `esecuzioni/`, quindi togliete prima la
  cartella di quella che non va, dallo spazio di lavoro, con
  `rm -rf esecuzioni/giro-<n>` (con `rm -r` vi chiederebbe conferma per
  ogni file della copia: i suoi oggetti git sono in sola lettura). Poi
  rifatela, con lo stesso numero o un altro, con lo STDERR fuori dal
  file; oppure ripartite da capo con `tools/reset_esercizio.sh M4-D03`.
- `nuova_copia.sh` dice che la copia c'è già: scegliete un altro numero.
- I test della copia restano rossi: è un dato, non un errore della
  verifica; la tabella mostra fin dove è arrivata la sessione, e se un
  comando è stato negato.
- La verifica stampa una segnalazione: in quell'esecuzione la garanzia
  non ha tenuto. Conservate la cartella `esecuzioni/` e mostratela al
  docente.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Una sessione `claude -p` per esecuzione, su Sonnet con effort low, un solo
prompt, gli strumenti Read, Edit e i test, nessun subagent; il docente ne
fa una in aula, la registrazione del corso tre. Ogni richiesta rimanda
tutta la conversazione, quindi ogni richiesta pesa più della precedente:
la tabella lo mostra. Opus «uses meaningfully more of your
quota, so consider switching to Sonnet for routine work»
(https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code).
claude.ai e Claude Code consumano gli stessi limiti: se il limite della
sessione è vicino, guardate il risultato del docente invece di rifare
l'esecuzione. Nella registrazione del corso (28 ottobre 2026, Claude Code
2.1.312, Sonnet con effort low), dal JSON di ogni esecuzione: 4 turni
ciascuna (`num_turns`), in 6,5, 16,5 e 6,6 secondi, con 70.314, 70.288 e
70.638 token in entrata, cache compresa: la somma delle quattro
richieste, ciascuna di poco più di 17.000.

## Per approfondire

- I costi di Claude Code, e il peso di ogni richiesta:
  https://code.claude.com/docs/en/costs
- «Best practices for Claude Code», nella documentazione:
  https://code.claude.com/docs/en/best-practices
- Come funziona Claude Code: il ciclo, gli strumenti, il contesto:
  https://code.claude.com/docs/en/how-claude-code-works
- Il ciclo dell'agente nell'Agent SDK, i turni e la compattazione:
  https://code.claude.com/docs/en/agent-sdk/agent-loop
- `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- Il corso «Claude Code 101» della Claude Academy, sul ciclo agentico, la
  finestra di contesto, gli strumenti e i permessi:
  https://academy.claude.com/courses/claude-code-101
