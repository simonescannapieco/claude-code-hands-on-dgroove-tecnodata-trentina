# M2-D02 — Il system prompt che non vedete

Demo del Modulo 2, nella parte «System, user, developer». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Misurare il system prompt di Claude Code, che non vedete: la stessa domanda
di una riga con il suo system prompt, con una riga aggiunta in coda, e con
una riga al suo posto.

## Tempo

2 minuti in aula; circa 4 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D02)

Lo spazio di lavoro `~/corso-claude-code/M2-D02/` con:

- `domanda.txt`: «Rispondi solo: ok»;
- `istruzione.txt`: la riga che si aggiunge o si sostituisce, «Rispondi in
  italiano.»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D02
       cd ~/corso-claude-code/M2-D02

2. Le tre chiamate, su Haiku, senza strumenti:

       chiedi() {
         claude -p "$(cat domanda.txt)" --model haiku --effort low \
           --tools "" --strict-mcp-config --output-format json "$@"
       }
       p="$(chiedi)"
       a="$(chiedi --append-system-prompt "$(cat istruzione.txt)")"
       s="$(chiedi --system-prompt "$(cat istruzione.txt)")"

   `--append-system-prompt` aggiunge la riga in coda al system prompt di
   Claude Code; `--system-prompt` lo sostituisce con la riga.

3. Raccogliete i token in entrata in `sistema.tsv`:

       riga() {
         printf '%s\t%s\t%s\n' "$1" \
           "$(python3 leggi_json.py token_entrata <<< "$2")" \
           "$(python3 leggi_json.py result <<< "$2")" | tee -a sistema.tsv
       }
       printf 'variante\ttoken_entrata\trisposta\n' > sistema.tsv
       riga predefinito "$p"; riga aggiunto "$a"; riga sostituito "$s"

## Che cosa osservare

- Tre volte «ok»: la risposta è la stessa. Cambia quello che il modello
  riceve prima della vostra domanda.
- Nella registrazione del corso, su Haiku: 3.669 token in entrata con il
  system prompt di Claude Code, 3.689 con la riga in coda, 567 con la riga
  al suo posto. Quasi tutto il resto è il system prompt di Claude Code.
- Sostituirlo toglie anche le istruzioni sugli strumenti e quelle di
  sicurezza: si fa quando Claude non deve comportarsi da Claude Code, come
  nelle esercitazioni di questo modulo, dove misuriamo il solo prompt.
- In claude.ai c'è un system prompt di Anthropic, e le vostre regole stabili
  vanno nelle Instructions for Claude o nelle istruzioni di un progetto.

## Verifica (tools/verifica.sh M2-D02)

In `sistema.tsv`: con la riga al posto del system prompt i token in entrata
sono meno della metà di quelli del predefinito; con la riga in coda sono
almeno quelli del predefinito.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- I numeri sono diversi da quelli registrati: il system prompt di Claude
  Code non è fisso, cambia nel tempo e con il modello. Conta il rapporto
  fra le tre righe.
- Il predefinito pesa molto più del previsto: le vostre impostazioni utente
  di Claude Code (per esempio un hook o un `CLAUDE.md` personale) entrano
  anche in queste chiamate. Con `--setting-sources project,local` nel
  comando restano fuori.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D02`.

## Impronta d'uso sul piano Pro

Tre chiamate brevissime su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent.

## Per approfondire

- Le opzioni del system prompt nel riferimento della CLI:
  https://code.claude.com/docs/en/cli-reference
- Le Instructions for Claude e le istruzioni dei progetti in claude.ai:
  https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features
