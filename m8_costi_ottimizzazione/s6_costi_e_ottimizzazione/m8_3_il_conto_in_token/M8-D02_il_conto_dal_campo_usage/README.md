# M8-D02 — Il conto dal campo usage

Demo del Modulo 8, nella parte «Il conto in token». In aula la esegue il
docente; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Leggere il conto di una risposta dai numeri che `claude -p` scrive da sé: i
token in entrata e in uscita, il costo stimato; e rifare il conto a mano, con la
formula di Anthropic e i prezzi di un file. La stessa domanda di assistenza
tecnica viene posta due volte, chiedendo la risposta in una riga e in sei
sezioni: le due chiamate differiscono soltanto nella richiesta sul formato, e il
controllo confronta, coppia per coppia, i token in uscita e il costo.

## Tempo

3 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M8-D02)

Lo spazio di lavoro `~/corso-claude-code/M8-D02/` con:

- `domanda.txt`: la domanda, che qui sotto trovate per intero;
- `formato-breve.txt` e `formato-lungo.txt`: le due richieste sul formato, una
  riga sola e una relazione in sei sezioni;
- `sistema.txt`: il system prompt, una riga;
- `listino.json`: i prezzi a listino di Haiku, Sonnet e Opus in dollari per
  milione di token, con la data e la pagina da cui vengono: per aggiornarli si
  cambia questo file;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_conto.py`: il controllo, che legge i JSON di `claude -p`;
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M8-D02
       m8_costi_ottimizzazione/s6_costi_e_ottimizzazione/m8_3_il_conto_in_token/M8-D02_il_conto_dal_campo_usage/demo/in_classe.sh ~/corso-claude-code/M8-D02

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata è una
   sessione nuova di `claude -p`, da una cartella temporanea vuota, su Haiku
   con effort low, con nessuno strumento integrato (`--tools ""`), nessun
   server MCP (`--strict-mcp-config`) e un system prompt di una riga
   (`--system-prompt`). Con `--output-format json` il risultato è un JSON:
   il testo della risposta sta nel campo `result`, i token nel campo `usage`.

2. Per prima cosa lo script lancia `/context`, nella forma di una chiamata che
   non è una domanda: mostra di che cosa è fatto il contesto di partenza, il
   system prompt e il messaggio; lo stesso comando dei due bracci, con
   `/context` al posto del prompt. Non c'è nulla da digitare, è il primo comando
   che lo script mostra; per rifarlo a mano si parte dallo spazio di lavoro, dove
   c'è `sistema.txt`:

       claude -p --model haiku --permission-mode dontAsk --permission-prompts none --output-format json --setting-sources project,local --tools '' --system-prompt "$(cat sistema.txt)" --effort low --strict-mcp-config --no-session-persistence -- /context

3. Poi la stessa domanda, due volte, con il formato diverso. Il messaggio è
   sempre quello di `domanda.txt`, seguito da una riga vuota e da una delle due
   richieste; tutte e tre sono testi sotto prova, così come sono:

   <!-- prompt domanda -->

       Perché la connessione in fibra di un cliente cade ogni sera verso le nove e torna da sola dopo pochi minuti? Di giorno non succede, il router resta acceso e gli altri clienti della zona non segnalano nulla.

   <!-- /prompt domanda -->

   Nel braccio «breve»:

   <!-- prompt formato-breve -->

       Rispondi in una riga sola: la causa più probabile e il primo controllo da fare.

   <!-- /prompt formato-breve -->

   Nel braccio «lunga»:

   <!-- prompt formato-lungo -->

       Rispondi con una relazione in sei sezioni, ciascuna con il suo titolo: sintomo, cause possibili, controlli da fare, strumenti, quando aprire un guasto, come evitarlo in futuro.

   <!-- /prompt formato-lungo -->

   Il system prompt di tutte le chiamate, `sistema.txt`:

   <!-- prompt sistema -->

       Sei un tecnico dell'assistenza di un operatore di connettività e rispondi in italiano.

   <!-- /prompt sistema -->

4. In sala si guarda ciò che stampa `controlla_conto.py`: per ogni chiamata i
   token e i due costi, poi il confronto fra le risposte.

La prova del docente è di tre coppie di chiamate: il `_docente/live.sh`
dell'elemento, che lancia lo stesso script con `PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: il confronto vuole chiamate
che partono ognuna da zero, con la sola richiesta sul formato diversa, e il JSON
dice i token di ognuna, così un controllo può leggerli. La stessa cosa, a mano,
sono due sessioni con la stessa domanda e le due richieste, lette con `/usage`:
«Show session cost, plan usage limits, and activity stats.»
(https://code.claude.com/docs/en/commands).

## Che cosa osservare

### Che cosa dice Anthropic

- La raccomandazione messa alla prova: «Ask for the answer you will read, not
  the one that looks thorough.»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence).
- La formula del conto, nella stessa pagina: «Price each of the five token
  counts in a response’s usage at its own rate».
- Che il conto dei token in entrata è una somma: «Total input tokens in a
  request is the summation of input_tokens, cache_creation_input_tokens, and
  cache_read_input_tokens.»
  (https://platform.claude.com/docs/en/api/messages/create).
- Quanto pesa l'uscita, nella stessa pagina delle raccomandazioni: «Output tokens
  cost five times input tokens on Claude Haiku 5.5, Claude Sonnet 5.5, Claude
  Opus 5.5, Claude Fable 5.2, and Claude Fable 5.1». Il controllo stampa il
  rapporto calcolato da `listino.json`, come dato.
- Il JSON e che cosa vale: «With --output-format json, the response payload
  includes total_cost_usd and a per-model cost breakdown» e «Both figures are
  client-side estimates and can differ from your actual bill.»
  (https://code.claude.com/docs/en/headless). Il conto stesso: «Claude Code
  computes the dollar figure locally from token counts at list price»
  (https://code.claude.com/docs/en/costs). Sul piano in abbonamento la cifra
  in dollari: «so on a subscription it is a guide to how much work you did,
  not a bill.» (https://claude.dev/blog/what-a-task-costs-on-opus-5-5/).
- La cache nel campo `usage`: «Claude Code reports one-hour cache writes under
  ephemeral_1h_input_tokens and five-minute cache writes under
  ephemeral_5m_input_tokens.» (https://code.claude.com/docs/en/prompt-caching).
- Le opzioni: `--system-prompt` «Replaces the entire default prompt»
  (https://code.claude.com/docs/en/cli-reference); in `claude --help`, `--tools`
  «Specify the list of available tools from the built-in set. Use "" to
  disable all tools», `--no-session-persistence` «Disable session persistence -
  sessions will not be saved to disk and cannot be resumed (only works with
  --print)» e `--strict-mcp-config` «Only use MCP servers from --mcp-config,
  ignoring all other MCP configurations».

La raccomandazione è ciò che la demo mette alla prova: il controllo la decide
confrontando la coppia, e la conta «n su N»; la formula del conto e il rapporto
di prezzo fra uscita e entrata sono dati, che il controllo stampa e non giudica.

### Che cosa misura il controllo

`controlla_conto.py` legge i JSON di `risposte/` e `listino.json` e stampa, per
ogni chiamata:

- i token in entrata, la somma di `input_tokens`,
  `cache_creation_input_tokens` e `cache_read_input_tokens`, e i token in
  uscita;
- `total_cost_usd`, il costo ricalcolato dai cinque conteggi al loro prezzo
  (`input`, scrittura in cache a un'ora e a cinque minuti, lettura dalla cache,
  `output`) e la differenza fra i due: una dimostrazione, stampata come dato.

Poi il confronto, esecuzione per esecuzione: la lunghezza della risposta in
token e in costo, il rapporto fra la risposta lunga e quella breve, e
«confermata» se la risposta lunga ha più token in uscita e un costo ricalcolato
più alto; «non distinguibile» se i due numeri coincidono; «non confermata in
questa esecuzione» altrimenti. Una raccomandazione non fa fallire il controllo:
si conta «confermata n su N», e il risultato non decide l'uscita. Prima di
tutto, stampa la tabella di `/context` e i suoi turni, token e costo: i dati di una
chiamata che, nella prova del corso, non arriva al modello.

Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322, Haiku con
effort low, tre coppie di chiamate, `_docente/live.sh` sull'account del docente),
letta dai JSON con questo controllo:

- `/context`, prima delle domande: 0 turni, 0 token, 0 dollari, e un contesto
  di partenza di 52 token (system prompt 42, messaggi 10);
- il braccio breve: 694 token in entrata (2 di `input_tokens`, gli altri 692
  scritti in cache nella prima coppia, letti dalla cache nelle altre due), in
  uscita 218, 224 e 165 token, il costo ricalcolato 0,000248, 0,000119 e
  0,000090 dollari;
- il braccio lungo: 739 token in entrata (2 più 737 in cache), in uscita 2.662,
  2.464 e 2.455 token, il costo ricalcolato 0,001479, 0,001240 e 0,001235
  dollari;
- il costo ricalcolato dai cinque conteggi e `total_cost_usd` coincidono a sei
  decimali in tutte e sei le chiamate: la differenza più grande è 0,000000;
- il confronto: la risposta lunga ha da 11,0 a 14,9 volte i token in uscita
  della breve e costa da 6,0 a 13,8 volte di più: «confermata 3 su 3».

I JSON sono nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M8-D02)

La verifica fa girare `controlla_conto.py` dell'elemento, non la copia dello
spazio di lavoro, sui JSON di `risposte/`. È fatta quando ogni chiamata di ogni
coppia c'è ed è finita bene; il confronto fra le coppie si stampa e non la fa
fallire. Quando tutto è in ordine, le ultime due righe sono «Fatto: ogni
esecuzione è stata letta; il conto e il confronto sono qui sopra.» e «VERIFICA OK
M8-D02: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/` o nessuna esecuzione: eseguite il passo
  1 fino in fondo.
- La verifica esce con 1 e dice che manca un'esecuzione, o che una chiamata ha
  restituito un errore: una chiamata si è fermata a metà; ricominciate da capo:
  `tools/reset_esercizio.sh M8-D02`.
- La verifica dice che una chiamata non è su un solo modello Haiku: il JSON dice
  su che modello ha girato; la coppia va rifatta allo stesso modo, perché il
  listino della demo è quello di Haiku.
- «non distinguibile» o «non confermata in questa esecuzione» sono esiti, non
  errori: leggete i numeri che il controllo stampa.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M8-D02`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Haiku con effort low, nessuno strumento, nessun subagent: chiamate di un turno
solo, più il `/context` iniziale. In aula una esecuzione, due chiamate al
modello; la prova del docente ne fa sei, tre coppie. Nella registrazione del
corso (10 novembre 2026, Claude Code 2.1.322, `_docente/live.sh` sull'account del
docente), dal JSON di ogni chiamata: da 1,8 a 14,6 secondi e da 859 a 3.401 token
a chiamata, entrata e uscita; «Come dati, tutte le 6 chiamate: turni 6; token in
entrata 4.299, in uscita 8.188; 48,1 s.», e `/context`, che non ha fatto nessun
turno. I token dicono quanto lavoro è stato, non un prezzo e non quanta parte
del vostro piano occupa: la cifra in dollari, come dice la frase citata sopra, è
un'indicazione, «not a bill».

## Per approfondire

- Come controllare i costi: https://code.claude.com/docs/en/costs
- Il prezzo di ogni token, modello per modello:
  https://platform.claude.com/docs/en/about-claude/pricing
- Scegliere il modello, l'effort e i modi per spendere meno:
  https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- `claude -p` e il suo JSON: https://code.claude.com/docs/en/headless
- La cache in Claude Code: https://code.claude.com/docs/en/prompt-caching
