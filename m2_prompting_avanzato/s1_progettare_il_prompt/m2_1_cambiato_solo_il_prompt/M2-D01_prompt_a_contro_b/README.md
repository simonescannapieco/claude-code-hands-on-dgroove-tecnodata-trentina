# M2-D01 — Prompt A contro prompt B

Demo del Modulo 2, nella parte «È cambiato solo il prompt». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Vedere che, a parità di modello, il prompt decide la risposta: lo stesso
messaggio di un cliente, una volta con «Riassumi.», una volta con un prompt
di cinque righe.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D01)

Lo spazio di lavoro `~/corso-claude-code/M2-D01/` con:

- `messaggio.md`: il messaggio di un cliente business, la Falegnameria
  Fittizia di Rovereto: il centralino fermo venerdì, ordini persi, il numero
  della segnalazione perso, una domanda sull'indennizzo, una sulla linea di
  riserva, un telefono per richiamare;
- `prompt-a.md`: «Riassumi.» e il messaggio;
- `prompt-b.md`: cinque righe (ruolo, contesto, istruzione, formato,
  vincoli) e il messaggio tra i tag `<messaggio>`;
- `istruzione.txt`: il system prompt delle due chiamate, «Rispondi in
  italiano.»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

Il messaggio è inventato, come tutti i dati del corso.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D01
       cd ~/corso-claude-code/M2-D01

2. Le due chiamate, su Sonnet, con le stesse opzioni:

       chiedi() {
         claude -p "$(cat "$1")" --model sonnet --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --output-format json
       }
       a="$(chiedi prompt-a.md)"
       b="$(chiedi prompt-b.md)"

3. Raccogliete token e risposte in `confronto.tsv`:

       riga() {
         printf '%s\t%s\t%s\t%s\n' "$1" \
           "$(python3 leggi_json.py token_entrata <<< "$2")" \
           "$(python3 leggi_json.py token_uscita <<< "$2")" \
           "$(python3 leggi_json.py result <<< "$2")" | tee -a confronto.tsv
       }
       printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\n' > confronto.tsv
       riga A "$a"; riga B "$b"

## Che cosa osservare

- Con «Riassumi.» il modello ha deciso da solo la forma, la lunghezza e che
  cosa fare del nome e del telefono del cliente: nella registrazione del
  corso il riassunto li riporta entrambi.
- Con il prompt di cinque righe: una tabella, una riga per problema, il
  telefono omesso, «non indicato» dove il dato manca.
- I token: B ne manda di più, perché il prompt è più lungo (nella
  registrazione 937 per A, 1.211 per B, circa 1,3 volte); le risposte
  hanno una lunghezza simile (475 e 452 token in uscita).
- Ogni ingrediente che manca è una decisione che lasciate al modello.

## Verifica (tools/verifica.sh M2-D01)

In `confronto.tsv`: la risposta a B è una tabella e non ripete il telefono
del cliente, e B manda al modello più token di A.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Un JSON vuoto: rilanciate la chiamata di quel prompt
  (`a="$(chiedi prompt-a.md)"` o `b="$(chiedi prompt-b.md)"`), poi
  `riga A "$a"; riga B "$b"` su un `confronto.tsv` ricreato con la sua
  intestazione.
- Token molto diversi da quelli registrati: le vostre impostazioni utente
  di Claude Code (per esempio un hook o un `CLAUDE.md` personale) entrano
  anche in queste chiamate. Con `--setting-sources project,local` nel
  comando restano fuori.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D01`.

## Impronta d'uso sul piano Pro

Due chiamate brevi su Sonnet, con effort low, nessuno strumento e nessun
subagent.

## Per approfondire

- La guida «Prompting best practices» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La lezione «Effective prompting techniques» del corso AI Fluency della
  Claude Academy:
  https://academy.claude.com/courses/ai-fluency-framework-foundations/effective-prompting-techniques
