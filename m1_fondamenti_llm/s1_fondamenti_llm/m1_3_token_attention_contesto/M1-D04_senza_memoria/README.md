# M1-D04 — Ogni chiamata riparte da zero

Demo del Modulo 1, nella parte «Token, attention e contesto». In aula la
esegue il docente; dopo la sessione potete rifarla da soli.

## Obiettivo

Vedere che il modello non si ricorda di voi: ricorda solo ciò che gli
viene rimandato. Una sessione nuova non sa niente di quella precedente;
una sessione ripresa sì, perché Claude Code rimanda al modello tutta la
conversazione, e i token in entrata crescono.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D04)

Lo spazio di lavoro `~/corso-claude-code/M1-D04/` con quattro file:

- `primo.txt`: «Seguo il guasto della linea LN-000204: la fibra cade ogni
  sera verso le nove. Rispondi solo: ricevuto.»;
- `domanda.txt`: «Quale linea seguo, e che guasto ha?»;
- `istruzione.txt`: l'istruzione di sistema, «Rispondi in italiano, in una
  riga.»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

La linea e il guasto sono inventati, come tutti i dati del corso.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M1-D04
       cd ~/corso-claude-code/M1-D04

2. Le tre chiamate, su Haiku: A in una sessione nuova, B in un'altra
   sessione nuova, C nella sessione di A ripresa con `--resume`:

       chiedi() {
         claude -p "$(cat "$1")" --model haiku --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --output-format json "${@:2}"
       }
       a="$(chiedi primo.txt)"
       b="$(chiedi domanda.txt --no-session-persistence)"
       c="$(chiedi domanda.txt --resume "$(python3 leggi_json.py session_id <<< "$a")")"

3. Raccogliete token e risposte in `catena.tsv`:

       riga() {
         printf '%s\t%s\t%s\n' "$1" \
           "$(python3 leggi_json.py token_entrata <<< "$2")" \
           "$(python3 leggi_json.py result <<< "$2")" | tee -a catena.tsv
       }
       printf 'chiamata\ttoken_entrata\trisposta\n' > catena.tsv
       riga A "$a"; riga B "$b"; riga C "$c"

## Che cosa osservare

- B, una sessione nuova, non sa quale linea seguite: le manca il contesto.
- C, la sessione di A ripresa, risponde con la linea e il guasto.
- I token in entrata di C sono più di quelli di A: nella sessione ripresa
  il modello riceve di nuovo anche la conversazione precedente. Nelle
  registrazioni del corso: A 608, B 577, C 660. Sulla vostra macchina i
  numeri possono cambiare di qualche token; conta che C ne riceva più di A.
- Lo stesso vale per una chat: è il programma che rimanda la cronologia a
  ogni turno, non il modello che si ricorda.

## Verifica (tools/verifica.sh M1-D04)

In `catena.tsv`: la risposta di B non nomina LN-000204, quella di C sì, e
C manda al modello più token di A.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- `--resume` non trova la sessione: rilanciate A e poi C nella stessa
  cartella `~/corso-claude-code/M1-D04`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D04`.

## Impronta d'uso sul piano Pro

Tre chiamate brevi su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent.

## Per approfondire

- Il tutorial dell'Academy «How context affects Claude's performance and
  cost»: https://academy.claude.com/tutorials/parametric-memory-and-context
- La pagina «Context windows» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/context-windows
