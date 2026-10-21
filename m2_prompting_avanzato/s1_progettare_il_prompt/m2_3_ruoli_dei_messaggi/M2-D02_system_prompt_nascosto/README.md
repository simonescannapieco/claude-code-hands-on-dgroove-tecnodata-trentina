# M2-D02 — Il system prompt che non vedete

Demo del Modulo 2, nella parte «System, user, developer». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova ciò che la documentazione di Claude Code dice del suo
system prompt, che non vedete, e delle due opzioni che lo cambiano: la
stessa domanda di una riga con il system prompt di Claude Code, con una
riga aggiunta in coda (`--append-system-prompt`) e con una riga al suo
posto (`--system-prompt`).

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
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato;
- `controlla_sistema.py`: il controllo che esegue
  `tools/verifica.sh M2-D02`, da leggere se volete sapere come confronta i
  token e le risposte.

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

### Che cosa dice Anthropic

- Il glossario di Claude Code: il system prompt è «Le istruzioni che
  Claude Code invia prima della tua conversazione a ogni richiesta, che
  descrivono come Claude utilizza gli strumenti, si comporta in modo
  sicuro e formatta le sue risposte.»
  https://code.claude.com/docs/it/glossary#system-prompt
- La guida ai system prompt dell'Agent SDK, che lo confronta con la CLI:
  «Questo differisce da `claude -p`, che utilizza il system prompt di
  Claude Code per impostazione predefinita.»
  https://code.claude.com/docs/it/agent-sdk/modifying-system-prompts
- Il riferimento della CLI, «Flag del prompt di sistema»:
  `--system-prompt` «Sostituisce l'intero prompt predefinito»,
  `--append-system-prompt` «Aggiunge al prompt predefinito». Poco sotto:
  «La sostituzione elimina l'intero prompt predefinito, inclusa la guida
  dello strumento e le istruzioni di sicurezza, quindi assumi la
  responsabilità di qualsiasi cosa il tuo compito abbia ancora bisogno.»
  Nelle esercitazioni di questo modulo, dove si misura il solo prompt e
  non servono strumenti, le chiamate usano `--system-prompt`.
  https://code.claude.com/docs/it/cli-reference#system-prompt-flags
- La guida al prompt caching, sul conteggio dei token: «La risposta di
  utilizzo include tre campi separati per i token di input che insieme
  rappresentano il tuo input totale». `leggi_json.py token_entrata` ne fa
  la somma.
  https://platform.claude.com/docs/it/build-with-claude/prompt-caching
- La domanda, «Rispondi solo: ok», è un'istruzione esplicita, e la guida
  «Best practice per il prompting» dice: «Claude risponde bene a
  istruzioni chiare ed esplicite.»
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices

Ciò che la documentazione di Anthropic dice delle opzioni e dei token è
una garanzia del prodotto: vale a ogni esecuzione. La frase della guida al
prompting è una raccomandazione.

### Che cosa misura il controllo

Il controllo legge `sistema.tsv` e stampa, per le tre chiamate, i token in
entrata e la risposta, e come dati le due differenze: quanto pesa il
predefinito più della chiamata con la riga al suo posto, e quanto aggiunge
la riga in coda. Poi:

- due garanzie, che decidono l'uscita e confrontano le tre chiamate fra
  loro: con la riga al posto del system prompt i token in entrata sono
  meno di quelli del predefinito, benché la riga ci sia e nel predefinito
  no; con la riga in coda sono più di quelli del predefinito. Una garanzia
  non confermata fa uscire la verifica con 1. Le tre chiamate
  differiscono soltanto per l'opzione: la domanda, e ciò che non fa parte
  del system prompt, pesano lo stesso in tutte e tre e nel confronto si
  cancellano. Il glossario di Claude Code lo dice dei vostri file: «I tuoi
  file CLAUDE.md e le istruzioni del tuo stile di output non fanno parte
  del prompt di sistema.» Un `CLAUDE.md` personale cambia quindi i numeri,
  non le due garanzie;
- l'istruzione «Rispondi solo: ok», chiamata per chiamata: «rispettata» se
  la risposta, tolti spazi e punti ai bordi e senza badare alle maiuscole,
  è «ok»; altrimenti «non rispettata in questa esecuzione», che si legge e
  non fa fallire la verifica.

Nella registrazione del corso (16 ottobre 2026, Claude Code 2.1.301,
Haiku, una chiamata per variante): 3.669 token in entrata con il system
prompt di Claude Code, 3.689 con la riga in coda, 567 con la riga al suo
posto. Le due garanzie confermate; «ok» in 3 risposte su 3. Fra la prima e
la terza chiamata cambia soltanto l'opzione: i 3.102 token di differenza
sono il system prompt di Claude Code, meno la riga che lo sostituisce. La
riga in coda ne aggiunge 20.

## Verifica (tools/verifica.sh M2-D02)

Dalla cartella `esercitazioni`, `tools/verifica.sh M2-D02` esegue il
controllo descritto qui sopra e ne stampa i numeri e gli esiti. Esce con 0
quando in `sistema.tsv` ci sono le tre righe e le due garanzie sono
confermate; l'ultima riga è allora «Fatto: ogni affermazione è stata messa
alla prova; gli esiti sono qui sopra.» Esce con 1 quando manca una
risposta o un numero di token, o una garanzia non è confermata; con 2
quando non può partire (manca lo spazio di lavoro o python3, `sistema.tsv`
non si legge).

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- I numeri sono diversi da quelli registrati: il system prompt di Claude
  Code non è fisso, cambia nel tempo e con il modello, e le vostre
  impostazioni utente di Claude Code (per esempio un hook o un `CLAUDE.md`
  personale) entrano anche in queste chiamate. Contano le due garanzie,
  non i numeri esatti.
- Una garanzia «non confermata in questa esecuzione»: controllate di non
  avere scambiato le righe di `sistema.tsv` e che le tre chiamate abbiano
  le stesse opzioni, salvo `--append-system-prompt` e `--system-prompt`.
- L'istruzione «Rispondi solo: ok» non rispettata in una chiamata: è
  l'esito di quella risposta; la verifica lo riporta senza fallire.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D02`.

## Impronta d'uso sul piano Pro

Tre chiamate brevissime su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent.

## Per approfondire

- Le opzioni del system prompt nel riferimento della CLI:
  https://code.claude.com/docs/en/cli-reference
- Anche claude.ai ha un system prompt di Anthropic; le note di rilascio
  dei system prompt:
  https://platform.claude.com/docs/en/release-notes/system-prompts/overview
- In claude.ai le vostre regole stabili vanno nelle Instructions for
  Claude o nelle istruzioni di un progetto:
  https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features
