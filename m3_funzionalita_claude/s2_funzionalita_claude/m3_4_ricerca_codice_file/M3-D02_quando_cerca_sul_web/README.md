# M3-D02 — Quando Claude cerca sul web

Demo del Modulo 3, nella parte «Web search, Research, codice e file». In
aula il docente mostra il risultato registrato in Claude Code, poi la
provate voi in claude.ai; la parte in Claude Code potete rifarla da soli
quando volete.

## Obiettivo

Mettere alla prova ciò che Anthropic descrive della ricerca sul web:
Claude cerca quando la domanda chiede informazioni attuali, e risponde
senza cercare quando basta un sapere stabile. Due domande che
differiscono in una cosa, il bisogno di informazioni attuali: l'ultima
versione di Claude Code nel changelog ufficiale, e che cos'è la fibra
FTTH. Stesso modello, stesse opzioni e un solo strumento per il web,
WebSearch: una sua chiamata è una ricerca, e nient'altro lo è.

## Tempo

4 minuti in aula: il risultato del docente, poi la vostra prova in
claude.ai. Circa 6 minuti per rifare da soli la parte in Claude Code.

## Prerequisiti

Un account claude.ai con il piano Pro; per la parte in Claude Code,
Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
verde (`PRIMA_DEL_CORSO.md`); Python 3, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M3-D02)

Lo spazio di lavoro `~/corso-claude-code/M3-D02/` con:

- `attuale.md`: la domanda che chiede un'informazione attuale, il numero
  dell'ultima versione di Claude Code nel changelog ufficiale, «Rispondi
  in due frasi.» come l'altra: le due domande finiscono allo stesso modo;
- `stabile.md`: la domanda su un sapere stabile, «Che cos'è la fibra
  FTTH? Rispondi in due frasi.»;
- `conta_ricerche.py`: legge lo stream di ogni chiamata, conta quante
  volte Claude ha cercato (le chiamate a WebSearch), dice l'esito
  dell'affermazione e scrive `esiti.tsv`.

## Passi in Claude Code (e in claude.ai)

1. **In claude.ai, con il modello predefinito:** aprite una chat nuova,
   incollate il testo di `attuale.md` (nella cartella `demo/` di questo
   elemento, o nello spazio di lavoro del passo 2) e inviate. Poi
   un'altra chat nuova, con `stabile.md`. Per ognuna guardate se la
   risposta mostra le fonti, con le citazioni, e ditelo a voce. Se nella
   casella del messaggio vedete ancora «Chat» e «Cowork», avete
   l'esperienza precedente: lì controllate che «Web search» sia acceso.

2. **In Claude Code:** preparate lo spazio di lavoro ed entrateci, dalla
   cartella `esercitazioni`:

       tools/prepara_esercizio.sh M3-D02
       cd ~/corso-claude-code/M3-D02

3. Le sei chiamate: tre coppie, prima la domanda attuale e poi la
   stabile, con lo stream di ogni chiamata in `risposte/`.
   `--tools WebSearch` lascia a Claude un solo strumento, WebSearch, e
   `--allowedTools WebSearch` lo consente: nella modalità Manual è uno
   strumento che chiede il permesso:

       mkdir -p risposte
       for n in 1 2 3; do
         for q in attuale stabile; do
           claude -p "$(cat "$q.md")" --model sonnet --effort low \
             --tools WebSearch --allowedTools WebSearch \
             --strict-mcp-config --no-session-persistence \
             --output-format stream-json --verbose \
             > "risposte/$q-$n.jsonl"
         done
       done

4. Quando ha cercato Claude, e l'esito dell'affermazione:

       python3 conta_ricerche.py

`_docente/live.sh`, la prova del docente, e la registrazione del corso
mandano gli stessi testi con le stesse opzioni, più
`--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`.

## Che cosa osservare

### Che cosa dice Anthropic

- Nel centro assistenza, sulla web search di claude.ai: «When you ask
  about topics that benefit from current information, Claude invokes a
  search tool». Quando si chiede di argomenti che beneficiano di
  informazioni aggiornate, Claude ricorre a uno strumento di ricerca. E
  sulle risposte che ne nascono: «Every response includes citations, so
  you can easily verify sources yourself.»
  https://support.claude.com/en/articles/10684626-enable-and-use-web-search
- Nella documentazione dello strumento di web search dell'API: «Claude
  searches when the request depends on information that is current,
  changing, or outside its training data», e «Claude answers directly
  without searching when the request draws on stable knowledge». Cerca
  quando la richiesta dipende da informazioni attuali, che cambiano o
  fuori dai suoi dati di addestramento; risponde senza cercare quando
  basta un sapere stabile.
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- In claude.ai, nella nuova esperienza: «If you have the new Claude
  experience, there's no web search toggle. Claude searches the web when
  it helps.» Come capire quale avete: «If you're on a Pro or Max plan and
  your message box still shows "Chat" and "Cowork" options, you don't
  have it yet.»
  (https://support.claude.com/en/articles/16761823-claude-cowork-and-chat-are-one-claude)
  Nell'esperienza precedente l'interruttore c'è: «Web search: on by
  default for Free, Pro and Max plans.»
  (https://academy.claude.com/tutorials/getting-started-with-claude)

Le frasi del primo e del terzo punto sono del centro assistenza di
claude.ai; quelle del secondo vengono dalla pagina dello strumento di web
search dell'API e parlano di quello strumento: quando Claude, con la web
search, cerca e quando risponde senza cercare. La demo gira in Claude
Code, dove la controparte di quello strumento è WebSearch, nel
riferimento degli strumenti: «WebSearch runs a query against Anthropic's
web search backend and returns result titles and URLs. It doesn't fetch
the result pages.» (https://code.claude.com/docs/en/tools-reference).
Claude Code ha anche WebFetch, che, nello stesso riferimento, «Fetches
content from a specified URL»: apre una pagina di cui ha già l'indirizzo,
e aprire una pagina non è cercare. Per questo la prova offre a Claude
soltanto WebSearch: WebFetch non c'è, e non può prendere il posto di una
ricerca. WebSearch è la controparte, in Claude Code, della ricerca di
claude.ai e dello strumento dell'API, non lo stesso prodotto: la prova
guarda se Claude, in Claude Code e con WebSearch, decide di cercare come
Anthropic descrive.

Perché lo stream: con `--output-format json` arriva un JSON solo, «json:
structured JSON with result, session ID, and metadata». Con lo
stream-json, invece, «Each line is a JSON object representing an event»,
e «The last line of the stream is a result message with the final
response text, cost, and session metadata.»
(https://code.claude.com/docs/en/headless)

### Che cosa misura il controllo

`conta_ricerche.py` legge lo stream di ogni chiamata, riga per riga, e
conta i blocchi `tool_use` dei messaggi dell'assistente con il nome
`WebSearch`, una volta ciascuno: sono le ricerche di Claude. Ogni altra
chiamata a uno strumento (WebFetch, se mai comparisse) si stampa come
dato, con gli indirizzi che ha aperto, e non conta come ricerca. Per ogni
chiamata stampa anche che cosa ha cercato, gli indirizzi citati nella
risposta, i primi 300 caratteri della risposta e, per la domanda attuale,
il numero di versione che la risposta dà. Scrive `esiti.tsv`, una riga
per file.

Poi, coppia per coppia (la chiamata n della domanda attuale con la n
della stabile), «Cerca per l'attuale, non per lo stabile»: confermata se
per la domanda attuale Claude ha chiamato WebSearch almeno una volta e
per la stabile mai; altrimenti non confermata in questa esecuzione, con
il perché. Poi «confermata n su 3». È una descrizione di come Claude
decide, non una garanzia, e il verdetto si stampa senza far fallire la
verifica.

Il numero di versione è un dato, non un verdetto: il controllo non sa
quale sia l'ultima versione del changelog, e non la va a cercare. Nella
registrazione del corso del 21 ottobre 2026, con Sonnet e il solo WebSearch, le
ricerche sulla domanda attuale hanno trovato una pagina di terzi con una
versione più vecchia: per questo contano le fonti citate, che servono a
controllare da dove viene un numero, come dice il centro assistenza
(«Che cosa dice Anthropic», primo punto). In claude.ai la stessa prova la
guardate a occhio, dalle fonti citate.
`tools/verifica.sh M3-D02` fa girare lo stesso controllo, quello della
cartella dell'elemento, sullo stream dello spazio di lavoro: decide dalle
chiamate, non legge `esiti.tsv` e non scrive niente.

Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,
Sonnet con il solo WebSearch, tre coppie, le due domande come sono qui,
con la stessa coda): per la domanda attuale una chiamata a WebSearch in
ognuna delle tre esecuzioni, con la ricerca «Claude Code changelog
latest version»; per la stabile, nessuna. «Cerca per l'attuale, non per
lo stabile»: confermata 3 su 3. Le risposte sull'attuale hanno citato
pagine di terzi e dato 2.1.263, una versione più vecchia di quella
installata per la registrazione, e lo hanno detto loro stesse: il
changelog ufficiale non l'avevano trovato, consultato o verificato. È un
dato, non un esito: il controllo non decide sulla versione. Le sei
esecuzioni sono nella cartella `soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M3-D02)

La verifica fa girare `conta_ricerche.py` dell'elemento sullo stream di
`risposte/`, senza scrivere niente (non legge `esiti.tsv`). È fatta quando
le sei chiamate ci sono e ognuna è lo stream-json riuscito di `claude -p`,
che finisce con il risultato. Il verdetto si stampa e non fa fallire la
verifica. La parte in claude.ai non si verifica: la raccontate a voce.

## Se qualcosa va storto

- In claude.ai la risposta alla domanda attuale non cita fonti:
  nell'esperienza precedente l'interruttore «Web search» può essere
  spento. Il centro assistenza suggerisce anche di chiederlo nel prompt
  («If you want to ensure that Claude uses web search, include "Search
  the web" or "Use web search" in your prompt to Claude.»), ma allora la
  prova non guarda più se Claude decide da sé.
- `conta_ricerche.py` dice che una chiamata manca, che una riga non è
  JSON, che lo stream non finisce con il risultato o che c'è soltanto il
  risultato (`--output-format json` al posto di `stream-json`): rifate
  quella chiamata così com'è nel passo 3 (per
  `risposte/stabile-2.jsonl`: `n=2`, `q=stabile`, poi la riga
  `claude -p`), con lo STDERR fuori dal file, poi di nuovo
  `python3 conta_ricerche.py`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-D02`.

## Impronta d'uso sul piano Pro

In claude.ai, due messaggi brevi; ricerca e lettura delle pagine
consumano i limiti: «Usage of web search and web fetch counts toward your
usage limits.» In Claude Code, sei chiamate su Sonnet con effort low, il
solo WebSearch e nessun subagent. claude.ai e Claude Code consumano gli
stessi limiti: se il limite della sessione è vicino, guardate il
risultato del docente invece di rifare le sei chiamate.

## Per approfondire

- La web search in claude.ai: come si usa, le citazioni, i limiti:
  https://support.claude.com/en/articles/10684626-enable-and-use-web-search
- Lo strumento di web search dell'API, e quando Claude cerca:
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- WebSearch e WebFetch nel riferimento degli strumenti di Claude Code:
  https://code.claude.com/docs/en/tools-reference
- `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- Quando basta la web search e quando serve Research, nel corso Claude 101
  della Claude Academy:
  https://academy.claude.com/courses/claude-101/research-mode-for-deep-dives
