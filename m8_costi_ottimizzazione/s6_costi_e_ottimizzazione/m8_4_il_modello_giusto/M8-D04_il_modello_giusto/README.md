# M8-D04 — Il modello giusto per il lavoro

Demo del Modulo 8, nella parte «Il modello giusto». In aula la esegue il
docente; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Mettere alla prova, su un lavoro verificabile, che cosa si guadagna e che cosa
si paga scegliendo il modello. Otto ticket dell'assistenza di CiaspoLink,
l'operatore inventato del corso (dati sintetici), con l'etichetta che ognuno
dovrebbe avere, vanno a Claude nello stesso prompt tre volte: con Haiku, con
Sonnet e con Opus. Lo script che controlla legge il JSON di ogni chiamata e
stampa quante etichette sono giuste, i token, il costo ricalcolato dal listino,
il costo per ticket giusto e il tempo dell'API.

## Tempo

3 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M8-D04)

Lo spazio di lavoro `~/corso-claude-code/M8-D04/` con:

- `ticket.jsonl`: gli otto ticket, con l'etichetta attesa;
- `prompt.txt`: la richiesta, con `@@TICKET@@` al posto dei ticket;
- `schema-etichette.json`: lo schema della risposta, otto etichette;
- `listino.json`: i prezzi per milione di token, con la data di lettura e
  gli indirizzi delle pagine;
- `componi.py`: mette i ticket numerati nel prompt;
- `in_classe.sh`: le chiamate, una per modello, con ogni comando a schermo;
- `controlla_modello.py`: il controllo, che legge i JSON di `claude -p`;
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e
   fa partire la demo:

       tools/prepara_esercizio.sh M8-D04
       m8_costi_ottimizzazione/s6_costi_e_ottimizzazione/m8_4_il_modello_giusto/M8-D04_il_modello_giusto/demo/in_classe.sh ~/corso-claude-code/M8-D04

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata è una
   sessione nuova di `claude -p`, con effort low, nessuno strumento (`--tools
   ""`), nessun server MCP (`--strict-mcp-config`), `--system-prompt` di una
   riga, l'output JSON e `--json-schema`: «To get output conforming to a
   specific schema, use --output-format json with --json-schema and a JSON
   Schema definition.» (https://code.claude.com/docs/en/headless). La risposta
   è in un campo del JSON: «The response includes metadata about the request
   (session ID, usage, etc.) with the structured output in the structured_output
   field.» (stessa pagina).

2. Il prompt è lo stesso per i tre modelli, un testo sotto prova che resta così
   com'è, con al posto di `@@TICKET@@` gli otto ticket numerati:

   <!-- prompt richiesta -->

       Classifica ciascuno dei ticket numerati qui sotto in una sola categoria fra guasto, lentezza, fattura, attivazione, secondo il problema che il cliente chiede di risolvere. Scrivi le etichette nell'ordine dei ticket, una per ticket.

       @@TICKET@@

   <!-- /prompt richiesta -->

   Due ticket usano parole che portano altrove: il numero 4 parla di canone e
   di fattura, ma il cliente chiede che torni la connessione; il numero 7 parla
   di spie e di una linea che non naviga, ma è un'attivazione mai finita. Le
   etichette attese stanno in `ticket.jsonl`, e nessuna va nel prompt.

3. Le chiamate: una per ogni modello, con `--model haiku`, `--model sonnet` e
   `--model opus` e nient'altro di diverso. Lo schema chiede esattamente otto
   etichette fra le quattro categorie.

4. In sala si guarda ciò che stampa `controlla_modello.py`: per ogni modello ed
   esecuzione le etichette giuste, i token, il costo, il tempo.

La prova del docente è di tre esecuzioni per modello, nove chiamate: il
`_docente/live.sh` dell'elemento, che lancia lo stesso script con
`PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: il confronto vuole lo stesso
prompt su tre modelli, un elenco di etichette che uno script può leggere dal JSON
e i conteggi di `usage` di ogni chiamata.

`--tools ""` toglie gli strumenti integrati: in `claude --help`, «Specify the
list of available tools from the built-in set. Use "" to disable all tools».

## Che cosa osservare

### Che cosa dice Anthropic

Sulla scelta del modello:

- «High-volume work with outputs you can check | Try Claude Haiku 5.5 first»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence).
  La classificazione di otto ticket con l'etichetta attesa è un lavoro di
  questo genere: gli esiti si controllano uno a uno.
- «Run your examples through Haiku first. If the quality holds, you're done»
  (https://academy.claude.com/courses/claude-platform-101/choosing-the-right-model).
- «The lowest latency and price | Claude Haiku 5.5»
  (https://platform.claude.com/docs/en/about-claude/models/choosing-a-model) e,
  per il tempo, la riga comparativa della documentazione: «Comparative latency
  | Moderate | Moderate | Fast | Fastest»
  (https://platform.claude.com/docs/en/models/overview).
- «Compare models on cost per completed task, not per token, because you pay
  for completed tasks.» (la stessa pagina sui costi); «the right model is the
  cheapest one whose output you'd actually ship.» (la lezione dell'Academy).

Sul conto:

- «Price each of the five token counts in a response’s usage at its own rate»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence):
  il controllo lo fa da `usage`, con i prezzi di `listino.json`.
- «Claude Code computes the dollar figure locally from token counts at list
  price» (https://code.claude.com/docs/en/costs): il `total_cost_usd` del JSON è
  una stima: «Both figures are client-side estimates and can differ from your
  actual bill.» (https://code.claude.com/docs/en/headless). Il confronto fra
  `total_cost_usd` e il ricalcolo è una dimostrazione della formula: un dato,
  non una garanzia.

### Che cosa misura il controllo

`controlla_modello.py` legge i JSON di `risposte/`, una cartella per modello ed
esecuzione, e stampa per ognuna:

- le etichette giuste, contro quelle attese di `ticket.jsonl` (da
  `structured_output`);
- i token in entrata, la somma dei tre campi di `usage`, e quelli in uscita;
- `total_cost_usd`, il costo ricalcolato da `listino.json` e la loro differenza;
- `duration_api_ms`, come dato, e accanto si legge
  la riga comparativa della documentazione;
- il costo per ticket giusto: il costo ricalcolato diviso per le etichette
  giuste, la misura per task completato.

Poi, per ogni esecuzione, il confronto sul costo per ticket giusto: quello di
Haiku è minore di quello di Sonnet e di quello di Opus? «Confermata» oppure «non
confermata in questa esecuzione», n su N. Le esecuzioni di una coppia, stesso
prompt e tre modelli, differiscono soltanto nel modello. L'accuratezza è un
dato: quante giuste per modello e, sullo stesso conteggio, in quante esecuzioni
Haiku fa pari o meglio degli altri due, senza nessuna soglia. Tutto questo non
decide l'uscita: una raccomandazione non fa fallire la demo.

Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322, tre
esecuzioni per modello, `_docente/live.sh` sull'account del docente):

- le etichette: 8/8 in ogni esecuzione di ogni modello, 24 su 24 ciascuno;
- il confronto sul costo per ticket giusto: «Il costo per ticket giusto di Haiku è
  il più basso: confermata 3 su 3.»;
  il costo ricalcolato di una chiamata va da 0,000221 a 0,000267 $ su Haiku, da
  0,002334 a 0,003088 $ su Sonnet, da 0,004636 a 0,004776 $ su Opus, e coincide
  con `total_cost_usd` nei limiti dell'arrotondamento (0,000000 di differenza su
  ogni riga);
- il costo per ticket giusto, in media: 0,000030 $ su Haiku, 0,000323 $ su
  Sonnet, 0,000585 $ su Opus; i token in entrata da 1.816 a 1.842, in uscita da
  90 a 367;
- `duration_api_ms`, in media: 2.077 ms su Haiku, 1.399 su Sonnet, 1.078 su
  Opus. È un dato: nove chiamate e un
  output che cambia da un modello all'altro; il controllo non decide niente sul
  tempo.

Questi costi sono con gran parte del prompt già in cache: in ognuna delle nove
chiamate 1.498 token sono stati letti da una prova precedente sullo stesso modello
(`cache_read_input_tokens`). Una prima esecuzione quei token li scrive invece di
leggerli, e costa di più; il confronto fra i modelli resta sui costi della stessa
esecuzione.

I JSON sono nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M8-D04)

La verifica fa girare `controlla_modello.py` dell'elemento, non la copia dello
spazio di lavoro, sui JSON di `risposte/`. È fatta quando ogni esecuzione di ogni
modello c'è, è finita bene e ha l'output strutturato. Quando tutto è in ordine,
le ultime due righe sono «Fatto: ogni esecuzione è stata messa alla prova; gli
esiti sono qui sopra.» e «VERIFICA OK M8-D04: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica esce con 1 e dice che manca un'esecuzione o che non ha l'output
  strutturato: una chiamata si è fermata a metà, oppure Claude non ha chiuso con
  le etichette. Ricominciate da capo: `tools/reset_esercizio.sh M8-D04`.
- «non confermata in questa esecuzione», o meno etichette giuste su un modello
  rispetto alla registrazione: sono esiti, non errori. Leggete la tabella.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M8-D04`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Haiku, Sonnet e Opus con effort low, nessuno strumento, nessun subagent. Ogni
esecuzione è fatta di tre chiamate, una per modello; la prova del docente ne fa
nove. Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322,
`_docente/live.sh` sull'account del docente), dal JSON di ogni chiamata: due
turni a chiamata (`num_turns`), da 1,1 a 2,4 secondi e da 1.906 a 2.209 token a
chiamata (entrata, cache e uscita); «Come dati, tutte le 9 chiamate: turni 18;
token in entrata 16.435, in uscita 1.571; 14,6 s.» I token sono quelli di `usage`
di ogni chiamata: dicono quanto lavoro è stato, non un prezzo, e non quanta
parte del vostro piano occupa.

Il modello predefinito di Claude Code sul Pro è un altro: «Pro, Max, Ultra,
Team, Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). La demo fissa i modelli perché
la registrazione e le vostre prove girino sugli stessi.

## Per approfondire

- Come ottimizzare costi e qualità:
  https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- Come scegliere il modello:
  https://platform.claude.com/docs/en/about-claude/models/choosing-a-model
- I prezzi: https://platform.claude.com/docs/en/about-claude/pricing
- La lezione dell'Academy «Choosing the right model»:
  https://academy.claude.com/courses/claude-platform-101/choosing-the-right-model
- L'output strutturato con `claude -p`:
  https://code.claude.com/docs/en/headless
