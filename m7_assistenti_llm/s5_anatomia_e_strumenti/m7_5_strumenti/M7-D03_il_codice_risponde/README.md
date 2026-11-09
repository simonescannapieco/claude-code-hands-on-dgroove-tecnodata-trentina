# M7-D03 — Il modello chiede, il codice risponde

Demo del Modulo 7, nella parte «Strumenti: il modello chiede, il codice
esegue». In aula la esegue il docente; potete rifarla da soli quando volete,
con lo stesso comando.

## Obiettivo

Vedere chi fa che cosa quando un assistente usa uno strumento. Un assistente di
CiaspoLink, il fornitore di connettività inventato dei progetti del corso, ha un
solo strumento, «stato_linea», e un server MCP locale al posto del sistema vero.
Riceve due messaggi: uno per una linea che esiste nei dati sintetici di uno scenario
e uno per una linea che non esiste. Il registro del server dice che cosa è stato
chiesto e che cosa è stato eseguito; lo stream della chiamata dice che cosa è
arrivato a Claude, compreso il risultato con l'errore quando la linea non esiste.

## Tempo

3 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`): fra l'altro controlla `uv`, che serve al
  server MCP del banco di prova.
- Per la prima esecuzione, la rete, una volta sola: il banco prepara l'ambiente
  del server con `uv sync`, dalle versioni fissate in `uv.lock`.
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M7-D03)

Lo spazio di lavoro `~/corso-claude-code/M7-D03/` con:

- `assistente/system-prompt.md` e `assistente/strumenti.json`: il system
  prompt, breve, e la definizione dell'unico strumento;
- `casi/`: i due messaggi, sui dati dello scenario
  `sc-01-fibra-assente-guasto-pergine.json`: la linea LN-000201, che esiste,
  e la LN-999999, che non esiste;
- `progetti/assistenza-clienti/banco/`: il banco di prova, con il server MCP;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_mosse.py`: il controllo, che legge gli esiti.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e
   fa partire la demo:

       tools/prepara_esercizio.sh M7-D03
       m7_assistenti_llm/s5_anatomia_e_strumenti/m7_5_strumenti/M7-D03_il_codice_risponde/demo/in_classe.sh ~/corso-claude-code/M7-D03

   Lo script mostra ogni comando prima di eseguirlo. I due casi passano dal
   banco di prova (`prova.py casi`): una chiamata di `claude -p` per caso, con
   `--tools ""` (nessuno strumento integrato), il solo server MCP `assistenza`
   e Sonnet con effort low, una volta sola (la prova del docente tre volte).

2. Il system prompt dell'assistente, `assistente/system-prompt.md`, una richiesta
   breve:

   <!-- prompt sistema -->

       Sei l'assistente clienti di CiaspoLink: per dire come sta una linea leggi sempre lo stato con lo strumento, e rispondi al cliente in due righe.

   <!-- /prompt sistema -->

   I due messaggi sono testi sotto prova e restano così come sono:

   <!-- prompt esistente -->

       Buongiorno, ho la linea LN-000201 e non ho più internet. Mi dite come sta la mia linea?

   <!-- /prompt esistente -->

   <!-- prompt inesistente -->

       Buongiorno, ho la linea LN-999999 e non ho più internet. Mi dite come sta la mia linea?

   <!-- /prompt inesistente -->

   L'unico strumento è definito in `assistente/strumenti.json`: il nome
   `stato_linea`, una descrizione che dice che cosa fa, quando si usa e
   quando no, e che cosa significa il parametro `id_linea`, nel formato
   `LN-000000`. Il campo `capacita` collega lo strumento al motore del banco
   e il modello non lo vede.

3. In sala si guarda ciò che stampa `controlla_mosse.py`, per ogni caso: lo
   strumento che il modello ha chiesto, con gli argomenti; il risultato
   scritto dal server nel suo registro; la risposta; e le due garanzie.

Perché `claude -p` e il banco, e non una sessione aperta a mano: ogni caso
deve partire da zero e lo stream dice ogni mossa; il banco tiene un registro
del server, così uno script legge chi ha chiesto e chi ha risposto.

## Che cosa osservare

### Che cosa dice Anthropic

- «The model never runs anything on its own. It emits a structured request,
  your code (or Anthropic’s servers) runs the operation»: nella pagina su come
  funziona l'uso degli strumenti.
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
- In Claude Code, quando il risultato di uno strumento MCP è un errore: «when a
  tool returns a result marked isError: true, Claude receives the result's text
  as the tool's error message.»
  https://code.claude.com/docs/en/mcp
- Perché un server MCP locale per provare uno strumento: «Wrapping your tools
  in a local MCP server … will allow you to connect and test your tools in
  Claude Code or the Claude Desktop app.»
  https://www.anthropic.com/research/writing-tools-for-agents

Il server comunica con Claude Code sullo standard input e output: lo dice la
specifica del Model Context Protocol, «Stdio transport: Uses standard
input/output streams for direct process communication between local processes
on the same machine» (https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture).
Per questo lo STDOUT del server è riservato ai messaggi del protocollo: «The
server MUST NOT write anything to its stdout that is not a valid MCP message.»;
i messaggi di log vanno altrove: «The server MAY write UTF-8 strings to stderr
for any logging purposes»
(https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio).
Claude Code è l'host di questa architettura: «an MCP host — an AI application
like Claude Code or Claude Desktop — establishes connections to one or more MCP
servers.» (la stessa pagina dell'architettura, sotto `learn/architecture`).

### Che cosa misura il controllo

`controlla_mosse.py` legge, per ogni esecuzione e per ogni caso, lo stream della
chiamata, il registro del server (`registro.jsonl`: una riga per chiamata, con
strumento, argomenti, risultato) ed `esito.json`, il riepilogo del banco, e
stampa:

- ciò che il modello ha chiesto (lo strumento, con il prefisso
  `mcp__assistenza__` tolto, e gli argomenti, dallo stream) e ciò che il server
  ha fatto (il risultato, dal registro);
- la risposta, e, come dimostrazione che fa lo script e non dice niente su
  Claude, i dati della risposta che vengono dal risultato e i numeri, i codici
  e gli orari della risposta che nel risultato non ci sono (il codice di una
  linea inesistente viene dal messaggio del cliente);
- turni, secondi e i token della prima richiesta.

Le due garanzie, una riga per caso, «confermata» oppure «non confermata in
questa esecuzione» (e allora l'uscita è 1):

- «The model never runs anything on its own»: ogni chiamata che il modello
  chiede nello stream è nel registro del server, con gli stessi argomenti e lo
  stesso risultato, e la risposta arriva dopo il risultato;
- «Claude receives the result's text as the tool's error message», per la
  linea che non esiste: il registro segna l'errore e, nello stream, il blocco
  `tool_result` del messaggio utente ha `is_error: true` con il testo del
  risultato.

Nella registrazione del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni dei due casi, `_docente/live.sh` sull'account del
docente):

- in tutti e sei i casi il modello ha chiesto `stato_linea` una volta, con il
  codice del messaggio, e il registro del server ha la chiamata con gli stessi
  argomenti, e nello stream il risultato precede la risposta: la prima
  garanzia, confermata 6 su 6;
- nel caso della linea che esiste la risposta riporta i dati del risultato (il
  guasto, l'orario 10:12, «circa 40» linee, i tecnici sul posto), e nelle tre
  esecuzioni il controllo non trova nella risposta numeri, codici o orari
  estranei al risultato;
- nel caso della linea che non esiste, nello stream: `"is_error":true` nel
  blocco `tool_result` del messaggio utente, con il testo del risultato,
  `{"errore": "linea non trovata: serve il codice LN-000000"}`; e la risposta
  chiede di ricontrollare il codice, in tutte e tre le esecuzioni: la seconda
  garanzia, confermata 3 su 3;
- la prima richiesta: da 1.429 a 1.432 token.

Gli stream e i registri sono nella cartella `soluzione/risposte/` di questo
elemento (nel repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M7-D03)

La verifica fa girare `controlla_mosse.py` dell'elemento, non la copia dello
spazio di lavoro, sulle esecuzioni di `risposte/`. È fatta quando ogni caso di
ogni esecuzione c'è, è finito bene e le due garanzie valgono. Quando tutto è in
ordine, le ultime due righe sono «Fatto: ogni esecuzione è stata messa alla
prova; gli esiti sono qui sopra.» e «VERIFICA OK M7-D03: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica dice che manca un caso, o che uno stream non è finito: una
  chiamata si è fermata a metà. Ricominciate da capo:
  `tools/reset_esercizio.sh M7-D03`.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M7-D03`.
- Una garanzia «non confermata in questa esecuzione»: l'uscita è 1, e la riga
  dice dove; per esempio «nel registro del server non c'è nessuna chiamata»,
  se il modello ha risposto senza chiedere lo strumento.
- `prova.py` dice che il server non si prepara: serve `uv` (la rete la prima
  volta); rilanciate `tools/verifica_ambiente.sh`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, il server MCP del banco, nessuno strumento integrato:
due chiamate per esecuzione, due turni ciascuna (la richiesta dello strumento e
la risposta); la prova del docente ne fa sei. Nella registrazione del corso (9
novembre 2026, Claude Code 2.1.319, `_docente/live.sh` sull'account del
docente), dal `result` di ogni stream: da 2,2 a 4,2 secondi e da 3.099 a 3.705
token a chiamata (entrata, cache e uscita); le sei chiamate insieme: 12 turni,
20.275 token, 18 secondi. Sono misure del lavoro, non un prezzo e non quanta
parte del vostro piano occupano.

Ogni chiamata del banco ha `--no-session-persistence`: nessuna sessione resta
salvata. Rifarla da soli costa un'esecuzione, due chiamate.

## Per approfondire

- Come funziona l'uso degli strumenti:
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
- I server MCP in Claude Code: https://code.claude.com/docs/en/mcp
- Scrivere strumenti per gli agenti:
  https://www.anthropic.com/research/writing-tools-for-agents
- Il Model Context Protocol, l'architettura:
  https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture
- Il banco di prova, nel repository delle esercitazioni:
  `progetti/assistenza-clienti/banco/README.md`
