# M7-D04 — La descrizione è il contratto

Demo del Modulo 7, nella parte «Strumenti: il modello chiede, il codice
esegue». In aula la esegue il docente; potete rifarla da soli quando volete,
con lo stesso comando.

## Obiettivo

Vedere che cosa cambia nelle chiamate di un assistente quando cambiano
soltanto le definizioni degli strumenti: nome, descrizione, parametri. Lo stesso
assistente di CiaspoLink riceve lo stesso messaggio di una cliente, che dà il
codice cliente e l'e-mail, sugli stessi dati sintetici. In una versione gli
strumenti sono vaghi, nello stile della versione 0 dell'assistente; nell'altra
hanno nomi chiari e descrizioni molto dettagliate. Le capacità sono le stesse.
Uno script confronta che cosa ha fatto l'assistente nelle due versioni.

## Tempo

3 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`): fra l'altro controlla `uv`, che serve al
  server MCP del banco di prova.
- Per la prima esecuzione, la rete, una volta sola: il banco prepara l'ambiente
  del server con `uv sync`, dalle versioni fissate in `uv.lock`.
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M7-D04)

Lo spazio di lavoro `~/corso-claude-code/M7-D04/` con:

- `vaga/` e `chiara/`: le due versioni, ciascuna con `system-prompt.md` (lo
  stesso, byte per byte) e `strumenti.json` (le definizioni: uguali le tre
  capacità, verifica d'identità, scheda del cliente, stato della linea;
  diversi i nomi, le descrizioni e i parametri);
- `casi/linea-guasta.json`: il messaggio della cliente, sui dati dello scenario
  `sc-01-fibra-assente-guasto-pergine.json`;
- `progetti/assistenza-clienti/banco/`: il banco di prova, con il server MCP;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_descrizioni.py`: il controllo, che confronta le due versioni.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e
   fa partire la demo:

       tools/prepara_esercizio.sh M7-D04
       m7_assistenti_llm/s5_anatomia_e_strumenti/m7_5_strumenti/M7-D04_la_descrizione/demo/in_classe.sh ~/corso-claude-code/M7-D04

   Lo script mostra ogni comando prima di eseguirlo. La stessa chiamata di
   `claude -p`, attraverso il banco di prova (`prova.py casi`), una volta per
   versione, una sola esecuzione (la prova del docente tre): Sonnet con effort
   low, nessuno strumento integrato (`--tools ""`), il solo server MCP del
   banco, sempre lo stesso messaggio.

2. Il system prompt, breve, uguale nelle due versioni:

   <!-- prompt sistema -->

       Sei l'assistente clienti di CiaspoLink: rispondi al cliente in tre righe al massimo, usando gli strumenti a tua disposizione.

   <!-- /prompt sistema -->

   Il messaggio della cliente, un testo sotto prova, resta così com'è:

   <!-- prompt messaggio -->

       Buongiorno, sono Laura Prova, codice cliente CL-000101, e-mail laura.prova@example.org. Non ho più internet da poco dopo le dieci: mi dite qual è la situazione della mia linea?

   <!-- /prompt messaggio -->

   Le definizioni sono nei due `strumenti.json`. In `vaga/` per esempio lo
   strumento dell'identità si chiama `check_cliente` e la sua descrizione è
   «Controlla il cliente.»; in `chiara/` si chiama `verifica_identita`, dice
   che va chiamato per primo, prima di qualsiasi strumento che legga dati del
   cliente, e che cosa significa ogni parametro.

3. In sala si guarda ciò che stampa `controlla_descrizioni.py`: il primo
   strumento chiamato, le chiamate con i loro argomenti, e la coppia,
   esecuzione per esecuzione.

Perché `claude -p` e il banco, e non una sessione aperta a mano: le due
versioni devono partire da zero e differire soltanto nelle definizioni, e il
registro del server dice quale capacità ha usato ogni chiamata, comunque si
chiami lo strumento.

## Che cosa osservare

### Che cosa dice Anthropic

- La raccomandazione, nella guida alla definizione degli strumenti: «Provide
  extremely detailed descriptions. This is by far the most important factor in
  tool performance.»
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
- Che cosa ci va, sempre lì: «What the tool does | When it should be used (and
  when it shouldn’t) | What each parameter means and how it affects the tool’s
  behavior» e «Aim for at least 3–4 sentences for each tool description, more
  if the tool is complex.»
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools

La frase è una raccomandazione: per questo la demo confronta le due versioni e
dice «n su 3», senza decidere un'uscita.

### Che cosa misura il controllo

Il controllo legge, per ogni esecuzione, il registro del server (la capacità di
ogni chiamata, i suoi argomenti), lo stream ed `esito.json`, e stampa:

- le chiamate, con strumento, capacità e argomenti; il primo strumento
  chiamato;
- il numero di chiamate, i token della prima richiesta (le definizioni degli
  strumenti fanno parte della richiesta: «Everything in the request counts
  toward the context window: the system prompt, every message in messages …
  and your tool definitions.»,
  https://platform.claude.com/docs/en/build-with-claude/context-windows),
  turni e secondi.

Poi le tre proprietà, per esecuzione: il primo strumento è la verifica
d'identità; la verifica d'identità c'è e viene prima delle letture dei dati
del cliente (la scheda, la linea); gli argomenti hanno il formato che la
capacità si aspetta (il codice `CL-000000`, il recapito e il codice
`LN-000000` ciascuno intero, nel suo valore). Infine la coppia, esecuzione per
esecuzione, sul numero di proprietà che ogni versione rispetta: «confermata» se
la versione chiara fa meglio della vaga, «non distinguibile» se pari, «non
confermata in questa esecuzione» se fa peggio, poi «confermata n su N». Questi
esiti si stampano e non decidono l'uscita: una raccomandazione si misura, non si
impone.

Nella registrazione del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni per versione, `_docente/live.sh` sull'account del
docente):

- con le definizioni vaghe il primo strumento è sempre `cercaCliente`, con
  `{"q": "CL-000101"}`, e nelle tre esecuzioni la scheda completa si legge
  senza nessuna verifica d'identità; poi `check_linea` in due casi su tre, una
  volta la risposta viene dalla sola scheda;
- con le definizioni chiare il primo strumento è sempre `verifica_identita`,
  con codice cliente e recapito ciascuno nel suo parametro, poi `stato_linea`
  con `LN-000201`;
- la coppia, sulle tre proprietà: «vaga 1 su 3, chiara 3 su 3» in ogni
  esecuzione, «confermata 3 su 3»;
- la prima richiesta: 1.481 o 1.482 token con le definizioni vaghe, 2.287 o 2.288
  con quelle chiare, circa 800 in più: le due versioni differiscono soltanto
  nelle definizioni.

Gli stream e i registri sono nella cartella `soluzione/risposte/` di questo
elemento (nel repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M7-D04)

La verifica fa girare `controlla_descrizioni.py` dell'elemento, non la copia
dello spazio di lavoro, sulle esecuzioni di `risposte/`. È fatta quando ogni
esecuzione di ogni versione c'è ed è finita bene. Gli esiti della coppia si
stampano e non la fanno fallire. Quando tutto è in ordine, le ultime due righe
sono «Fatto: ogni esecuzione è stata messa alla prova; gli esiti sono qui
sopra.» e «VERIFICA OK M7-D04: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica dice che manca un'esecuzione, o che uno stream non è finito: una
  chiamata si è fermata a metà. Ricominciate da capo:
  `tools/reset_esercizio.sh M7-D04`.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M7-D04`.
- «non distinguibile» o «non confermata in questa esecuzione»: sono esiti, non
  errori: leggete le chiamate delle due versioni che il controllo stampa.
- `prova.py` dice che il server non si prepara: serve `uv` (la rete la prima
  volta); rilanciate `tools/verifica_ambiente.sh`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, il server MCP del banco, nessuno strumento integrato:
una chiamata per versione e per esecuzione; la prova del docente ne fa sei. Nella
registrazione del corso (9 novembre 2026, Claude Code 2.1.319, `_docente/live.sh`
sull'account del docente), dal `result` di ogni stream: da 2 a 3 turni e da 4,1
a 5,3 secondi a chiamata; da 3.847 a 6.326 token per la versione vaga, circa
8.100 per la chiara (entrata, cache e uscita); tutte le sei chiamate: «chiamate
agli strumenti 11, turni 17, 28,5 s», 40.509 token. Sono misure del lavoro, non
un prezzo e non quanta parte del vostro piano occupano.

Ogni chiamata del banco ha `--no-session-persistence`: nessuna sessione resta
salvata. Rifarla da soli costa un'esecuzione, due chiamate.

## Per approfondire

- La guida alla definizione degli strumenti:
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
- Scrivere strumenti per gli agenti:
  https://www.anthropic.com/research/writing-tools-for-agents
- Il banco di prova, nel repository delle esercitazioni:
  `progetti/assistenza-clienti/banco/README.md`
