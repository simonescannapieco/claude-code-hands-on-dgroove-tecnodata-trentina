# La coppia del docente di M3-E02

La dashboard in claude.ai mette alla prova, fra l'altro, un consiglio
della documentazione di Anthropic sulle tabelle:

> «When the model has to compute over a table … let the model query it
> with code execution instead of pasting it in.»
> (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)

È un confronto fra due strade, e lo decide una coppia di esecuzioni che
differiscono in quella cosa sola: la chat di un partecipante è un braccio
solo (il file caricato, interrogato con il codice), e i suoi KPI giusti
sono un dato. La coppia la registra il docente in Claude Code, con
`claude -p`, attraverso il registratore del modulo. Questa nota ne è il
contratto; i comandi qui sotto non vanno lanciati dai partecipanti.

## Le due braccia

| braccio | la tabella | strumenti | prompt | risposta |
|---|---|---|---|---|
| `incollato` | il testo di `ticket-anonimi.csv` sull'input standard: arriva nel messaggio | nessuno, `--tools ""` | `_docente/prompt-incollato.md` | `gemello/incollato-<n>.json` |
| `file` | `ticket-anonimi.csv` nella cartella di lavoro | `--tools Bash` con `--allowedTools "Bash(python3 *)"`: solo `python3`, niente Read | `_docente/prompt-file.md` | `gemello/file-<n>.json` |

I due prompt sono il prompt dei partecipanti, `esercizio/prompt-numeri.md`,
con un primo paragrafo diverso: dove sta la tabella e, nel braccio `file`,
«calcola con il codice, sul file» e il suo solo comando, «L'unico comando
permesso è python3: eseguilo da solo, senza concatenarlo ad altri
comandi.» Senza quella frase, nella prima registrazione del 21 ottobre
2026 Claude ha messo un `cd` o un `cat` davanti al suo `python3` in due
esecuzioni su tre: con `--permission-mode dontAsk` il comando è stato
rifiutato e l'oggetto è arrivato con tutti i valori a zero, una misura
dei permessi, non della strada. Il secondo paragrafo, le dieci chiavi e
le regole, è uguale byte per byte nei tre file (lo controlla
`m3_funzionalita_claude/_docente/test_m3_e02.sh`).

Tutto il resto è uguale nelle due braccia:

- `--model sonnet --effort low`;
- `--output-format json --json-schema "$(cat _docente/schema_kpi.json)"`:
  lo schema dei dieci KPI, con tutte le chiavi obbligatorie e nessuna in
  più;
- `--permission-mode dontAsk --setting-sources project,local
  --strict-mcp-config --no-session-persistence`;
- tre esecuzioni per braccio, n = 1, 2, 3, ognuna in una cartella di
  lavoro nuova sotto `/tmp`, fuori da ogni repository (niente `CLAUDE.md`
  né `.claude/` che entrino in un braccio e non nell'altro) e mai sotto
  `~/.claude`: vuota nel braccio `incollato`, con soltanto
  `ticket-anonimi.csv`, la copia di `esercizio/`, nel braccio `file`.

Non c'è un `_docente/live.sh`: la parte in claude.ai non si esegue da uno
script. La prova del docente in claude.ai segue i passi del README, e i
suoi file (`kpi.json` e il CSV caricato) passano da `verifica.py`.

## I comandi di un'esecuzione

Con `E` il percorso assoluto dell'elemento, `R` una cartella nuova per le
risposte, `U` una cartella di lavoro nuova e vuota, `T` una cartella di
lavoro nuova con la sola copia del CSV (tutte e tre sotto `/tmp`):

    mkdir -p "$R/gemello"
    (cd "$U" && claude -p --model sonnet --effort low --tools "" \
      --output-format json --json-schema "$(cat "$E/_docente/schema_kpi.json")" \
      --permission-mode dontAsk --setting-sources project,local \
      --strict-mcp-config --no-session-persistence \
      -- "$(cat "$E/_docente/prompt-incollato.md")" \
      < "$E/esercizio/ticket-anonimi.csv") > "$R/gemello/incollato-1.json"
    (cd "$T" && claude -p --model sonnet --effort low --tools Bash \
      --allowedTools "Bash(python3 *)" \
      --output-format json --json-schema "$(cat "$E/_docente/schema_kpi.json")" \
      --permission-mode dontAsk --setting-sources project,local \
      --strict-mcp-config --no-session-persistence \
      -- "$(cat "$E/_docente/prompt-file.md")" < /dev/null) \
      > "$R/gemello/file-1.json"

Poi il controllo, che legge le sei risposte e nient'altro:

    python3 -B -I "$E/_docente/confronta_gemello.py" "$R/gemello"
    python3 -B -I "$E/_docente/confronta_gemello.py" --json "$R/gemello"

## Che cosa misura, e che cosa no

- Per ogni esecuzione, i KPI giusti dell'oggetto `structured_output`,
  confrontati con `kpi_veri.py` sul CSV di riferimento, con la regola di
  `kpi_definizioni.md`; come dato, i token in entrata (input, più la cache
  scritta e letta) e in uscita, il modello e i turni. Un'esecuzione senza
  `structured_output`, o con `is_error`, è fallita e conta 0: «If a run
  ends without valid structured output, for example because Claude
  declined the request, the response has no structured_output field.»
  (https://code.claude.com/docs/en/headless).
- Per ogni coppia n: confermata se con il file e il codice sono giusti più
  KPI, non distinguibile se sono tanti quanti, non confermata in questa
  esecuzione se sono meno; poi «confermata k su 3». Nessun esito dice che
  il consiglio è sbagliato: una coppia non lo smentisce.
- Le condizioni non sono quelle di Anthropic. La sua prova: «An
  Anthropic-constructed set of 25 aggregate questions over a 1,862-row
  slice of a public liquor-sales CSV … with thinking disabled» (la stessa
  pagina). Qui dieci indicatori su 343 righe, con Sonnet; e su Sonnet 5.5
  il thinking non si spegne: «You can't turn thinking off on Opus 5.5,
  Sonnet 5.5, Haiku 5.5, or the Fable models.»
  (https://code.claude.com/docs/en/model-config). Le due braccia girano
  con lo stesso effort, il primo dell'elenco di `claude --help`: «--effort
  <level> Effort level for the current session (low, medium, high, xhigh,
  max)». I numeri della coppia sono del corso, non quelli di Anthropic.
- Nel braccio `file`, `python3` può anche stampare tutta la tabella: i
  token in entrata, stampati come dato, lo mostrano.

## Le opzioni, dalla documentazione

- L'input standard: «Non-interactive mode reads stdin, so you can pipe
  data in and redirect the response out like any other command-line
  tool.» (https://code.claude.com/docs/en/headless)
- Lo schema: «To get output conforming to a specific schema, use
  --output-format json with --json-schema and a JSON Schema definition.»
  e l'oggetto: «The response includes metadata about the request (session
  ID, usage, etc.) with the structured output in the structured_output
  field.» (https://code.claude.com/docs/en/headless)
- Gli strumenti: «--tools <tools...> Specify the list of available tools
  from the built-in set. Use "" to disable all tools» (`claude --help`); e
  «The --allowedTools flag uses permission rule syntax. The trailing *
  enables prefix matching, so Bash(git diff *) allows any command starting
  with git diff.» (https://code.claude.com/docs/en/headless)
