# M4-D08 — Il log in una pipe

Demo del Modulo 4, nella parte «Oltre il codice». In aula il docente la fa
girare; potete rifarla da soli quando volete: costa una chiamata breve.

## Obiettivo

Usare Claude Code come un comando qualunque in una pipe: si filtrano i log
con `grep` e si passano a `claude -p`, che risponde. E vedere che cosa
succede quando in pipe arriva troppo: lo stesso comando, con la stessa
domanda, riceve una volta le righe di un solo apparato e una volta il
syslog di un'intera settimana ripetuto fino a superare i 12 MiB. I due
bracci differiscono soltanto nell'ingresso.

## Tempo

3 minuti in aula. Circa 5 minuti per rifarla da soli.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- `ANTHROPIC_API_KEY` non impostata nel terminale (`PRIMA_DEL_CORSO.md`,
  «La chiave API non serve»): con `claude -p` la chiave, se c'è, si usa
  sempre al posto dell'abbonamento.
- Python 3, per la verifica; circa 13 MB liberi nello spazio di lavoro,
  per il file grande.

## Punto di partenza (tools/prepara_esercizio.sh M4-D08)

Lo spazio di lavoro `~/corso-claude-code/M4-D08/` con:

- `progetti/rete/`: la rete di CiaspoLink, con i log della settimana da
  lunedì 7 a domenica 13 settembre 2026, fra cui il syslog di tutti gli
  apparati in `progetti/rete/log/syslog/`, un file al giorno;
- `domanda.txt`: la domanda dei due bracci, gli orari del guasto di martedì
  8 settembre su `olt-pergine-01`, con la risposta in una riga.

Apparati, log e guasti sono inventati, come tutti i dati del corso. La
verità, gli orari giusti, non è nello spazio di lavoro: la conosce soltanto
il controllo dell'elemento.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M4-D08
       cd ~/corso-claude-code/M4-D08

2. I due ingressi: le righe di `olt-pergine-01` nel syslog della
   settimana, e il syslog della settimana ripetuto 63 volte, oltre i 12
   MiB:

       grep -h olt-pergine-01 progetti/rete/log/syslog/syslog_*.log > olt-pergine-01.log
       for i in $(seq 63); do cat progetti/rete/log/syslog/syslog_*.log; done > grande.log
       wc -c olt-pergine-01.log grande.log

3. I due bracci: lo stesso comando, `claude -p` con la stessa domanda e
   senza strumenti, e in pipe una volta un file e una volta l'altro. Di
   ogni braccio restano in `pipe/` la risposta (`.out`), i messaggi d'errore
   (`.err`), il codice d'uscita di `claude` (`.uscita`) e i byte passati
   (`.byte`):

       mkdir -p pipe
       p="$(cat domanda.txt)"
       for r in filtrato grande; do
         f=olt-pergine-01.log
         if [ "$r" = grande ]; then f=grande.log; fi
         wc -c < "$f" > "pipe/$r.byte"
         cat "$f" | claude -p --model sonnet --effort low --tools "" \
           --strict-mcp-config --no-session-persistence \
           --output-format json -- "$p" > "pipe/$r.out" 2> "pipe/$r.err"
         echo "${PIPESTATUS[1]}" > "pipe/$r.uscita"
       done
       cat pipe/grande.uscita pipe/grande.err

   `${PIPESTATUS[1]}` è il codice d'uscita del secondo comando della
   pipe, `claude`, non quello di `cat`.

4. Verificate, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D08

   Poi, se volete, cancellate il file grande: `rm
   ~/corso-claude-code/M4-D08/grande.log`.

`_docente/live.sh`, la prova del docente, fa gli stessi passi 2 e 3 con le
stesse opzioni, più `--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`, e poi la verifica.

## Che cosa osservare

### Che cosa dice Anthropic

Nella pagina della documentazione su `claude -p`, la modalità non
interattiva:

- «Non-interactive mode reads stdin, so you can pipe data in and redirect
  the response out like any other command-line tool.» In modalità non
  interattiva Claude Code legge lo STDIN: gli si passano dati in pipe e si
  redirige la risposta, come con qualunque comando. L'esempio della stessa
  pagina è un log di build: «cat build-error.txt | claude -p 'concisely
  explain the root cause of this build error' > output.txt».
- «Piped stdin is capped at 10MB. If you exceed the cap, Claude Code exits
  with a clear error and a non-zero status.» Lo STDIN in pipe ha un tetto
  di 10 MB: oltre, Claude Code esce con un errore chiaro e un codice
  d'uscita diverso da zero.

https://code.claude.com/docs/en/headless

Le opzioni della prova, in `claude --help`: `--tools` «Specify the list of
available tools from the built-in set. Use "" to disable all tools»,
quindi Claude non ha strumenti e legge soltanto ciò che arriva in pipe;
`--strict-mcp-config` «Only use MCP servers from --mcp-config, ignoring
all other MCP configurations», e senza `--mcp-config` nessun server MCP
entra nella prova. `--output-format`, nel riferimento della CLI:
«Specify output format for print mode (options: text, json, stream-json)»
(https://code.claude.com/docs/en/cli-reference): con `json` la risposta
arriva in un JSON, che il controllo legge.

Il filtro è il punto: `olt-pergine-01.log` ha poco più di un centinaio di
righe, il syslog della settimana ne ha 1.605 di tutti gli apparati, e
`grande.log`, 63 settimane di syslog, supera il tetto. Si filtra prima,
con gli strumenti di sempre, e a Claude arriva solo ciò che serve.

### Che cosa misura il controllo

`controlla_pipe.py`, nella cartella dell'elemento, legge i file di `pipe/`.

- **Il tetto**, la garanzia: confermata se il braccio grande esce con un
  codice diverso da zero, con un messaggio d'errore (su STDERR, oppure un
  JSON d'errore su STDOUT) e senza una risposta riuscita; altrimenti non
  confermata in questa esecuzione, e la verifica esce con 1. Il testo del
  messaggio, qualunque sia, si stampa come dato. La frase dice «10MB»: il
  controllo pretende che il braccio filtrato stia sotto i 10.000.000 di
  byte e che il grande superi i 10.485.760 (10 MiB), così la prova vale in
  entrambe le letture; un braccio grande più piccolo non mette alla prova
  il tetto, e il controllo chiede di rifarlo. Il tetto si decide soltanto
  se il braccio filtrato è riuscito: se no (un accesso che manca, il
  limite d'uso, la rete), anche il grande può fallire per quello, i due
  bracci non differiscono più soltanto nell'ingresso, e il verdetto è non
  distinguibile.
- **La lettura dello STDIN**: il braccio filtrato deve riuscire, con il JSON
  della risposta. Gli orari della risposta si stampano accanto a quelli
  veri, inizio 10:12 e fine 11:40, che stanno soltanto nelle righe passate
  in pipe: sono dati, giusti o sbagliati, e non decidono l'esito. Si
  stampano anche i byte e i token in entrata di ciascun braccio.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
Sonnet con effort low): il braccio filtrato, 13.564 byte in pipe, è uscito
con 0 e ha risposto «inizio 10:12 | fine 11:40», orari giusti tutti e
due, con 12.308 token in entrata; il braccio grande, 12.664.323 byte, è
uscito con 1, senza niente su STDOUT e con su STDERR «Error: piped stdin
input exceeds 10MB. Pass large content as a file path in your prompt
instead.». «Lo stdin in pipe ha un tetto di 10 MB: oltre, Claude Code
esce con un errore chiaro e un'uscita diversa da zero»: confermata. I
file dei due bracci sono nella cartella `soluzione/pipe/` di questo
elemento.

## Verifica (tools/verifica.sh M4-D08)

La verifica fa girare `controlla_pipe.py` dell'elemento sui file di
`pipe/` dello spazio di lavoro, senza chiamare `claude` e senza scrivere
niente. È fatta quando i due bracci ci sono, il braccio filtrato è riuscito e
la garanzia del tetto è confermata; l'ultima riga è «Fatto: ogni
affermazione è stata messa alla prova; gli esiti sono qui sopra.»

## Se qualcosa va storto

- Il braccio filtrato non è riuscito: guardate `pipe/filtrato.err`. Un
  errore di accesso si sistema con i passi di `PRIMA_DEL_CORSO.md`; poi
  rifate il passo 3.
- Il controllo dice che il braccio grande non supera i 10 MB: `grande.log` è
  stato costruito con meno ripetizioni. Rifate i passi 2 e 3.
- `grep` non trova righe di `olt-pergine-01`: lo spazio di lavoro è
  incompleto; `tools/reset_esercizio.sh M4-D08` lo prepara di nuovo.
- `pipe/*.uscita` è vuoto: il passo 3 va eseguito in bash, il terminale
  di Linux e di WSL 2, dove c'è `PIPESTATUS`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-D08`.

## Impronta d'uso sul piano Pro

Una chiamata breve a Sonnet con effort low, senza strumenti né subagent,
con le righe di un solo apparato in ingresso (circa 13 KB). Il secondo
braccio manda lo stesso comando con il file grande: secondo la documentazione
Claude Code esce con un errore, e il controllo dice se quel braccio ha
prodotto una risposta. Nella registrazione del corso (28 ottobre 2026,
Claude Code 2.1.312, Sonnet con effort low), dal JSON del braccio filtrato:
1 turno (`num_turns`), 3,1 secondi, 12.308 token in entrata, cache
compresa, e 17 in uscita. Per il braccio grande nessun JSON, quindi nessun
dato d'uso: Claude Code è uscito con l'errore.

## Per approfondire

- `claude -p`, lo STDIN in pipe e il suo tetto, il formato JSON:
  https://code.claude.com/docs/en/headless
- Il riferimento della CLI, con `--output-format` e le altre opzioni:
  https://code.claude.com/docs/en/cli-reference
