# M7-D01 — Cambia solo il system prompt

Demo del Modulo 7, nella parte «Anatomia di un assistente». In aula la esegue
il docente; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Vedere due cose. La prima: che cosa cambia in una risposta quando cambia
soltanto il system prompt. Lo stesso messaggio di una cliente dell'operatore
inventato CiaspoLink (dati sintetici) va a Claude due volte: con una riga
neutra come system prompt, e con il ruolo di assistente clienti di CiaspoLink
e la richiesta di restare in tre righe. La seconda: che un modello non ricorda
niente da solo. Una parola in codice detta in una prima chiamata si chiede poi
in una chiamata nuova e, con `--resume`, nella stessa sessione.

## Tempo

4 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M7-D01)

Lo spazio di lavoro `~/corso-claude-code/M7-D01/` con:

- `system-generico.md` e `system-ciaspolink.md`: i due system prompt, una riga
  ciascuno, che trovate qui sotto;
- `messaggio.txt`: il messaggio della cliente, inventato;
- `primo.txt` e `seguito.txt`: i due messaggi della parte sulla memoria;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_sistema.py`: il controllo, che legge gli stream di `claude -p`.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e
   fa partire la demo:

       tools/prepara_esercizio.sh M7-D01
       m7_assistenti_llm/s5_anatomia_e_strumenti/m7_2_anatomia/M7-D01_cambia_il_system_prompt/demo/in_classe.sh ~/corso-claude-code/M7-D01

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata è una
   sessione nuova di `claude -p`, su Sonnet con effort low, in una cartella
   temporanea vuota, con nessuno strumento integrato (`--tools ""`) e nessun
   server MCP (`--strict-mcp-config`).

2. La prima parte: lo stesso messaggio con due system prompt. Le due chiamate
   differiscono soltanto nel file di `--system-prompt-file`. Il messaggio è un
   testo sotto prova e resta così com'è:

   <!-- prompt messaggio -->

       Buongiorno, sono Giulia Campione. La fibra di casa continua a cadere e il router ha una luce rossa fissa. L'ho già spento e riacceso due volte. Che cosa posso fare?

   <!-- /prompt messaggio -->

   Il system prompt neutro, `system-generico.md`:

   <!-- prompt generico -->

       Sei un assistente disponibile e rispondi in italiano.

   <!-- /prompt generico -->

   Quello con il ruolo, `system-ciaspolink.md`:

   <!-- prompt ciaspolink -->

       Sei l'assistente clienti di CiaspoLink, operatore di connettività in fibra e radio nelle valli del Trentino, e dai del lei al cliente. Rispondi al massimo in tre righe.

   <!-- /prompt ciaspolink -->

3. La seconda parte, la memoria: una prima chiamata con la parola in codice
   (`primo.txt`, una parola diversa a ogni esecuzione al posto di
   `@@PAROLA@@`), che resta salvata; poi la stessa domanda (`seguito.txt`) in
   una chiamata nuova, senza `--resume`, e con `--resume` nella sessione della
   prima chiamata, che dopo viene tolta. I tre messaggi usano il system prompt
   neutro: la domanda è sempre la stessa, cambia solo se la chiamata riprende
   la sessione.

   <!-- prompt primo -->

       La parola in codice di questa prova è @@PAROLA@@. Rispondi solo: ricevuto.

   <!-- /prompt primo -->

   <!-- prompt seguito -->

       Qual è la parola in codice di questa prova?

   <!-- /prompt seguito -->

4. In sala si guarda ciò che stampa `controlla_sistema.py` su ogni esecuzione:
   le righe di ogni risposta, i token della prima richiesta, il confronto fra i
   due system prompt, la parola con e senza `--resume`.

La prova del docente è di tre esecuzioni per parte, quindici chiamate: il
`_docente/live.sh` dell'elemento, che lancia lo stesso script con
`PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: il confronto vuole due
chiamate che partono ognuna da zero, con il solo system prompt diverso, e lo
stream dice che cosa è successo, token compresi; così uno script legge ogni
esecuzione. La stessa prova, a mano, si fa con `claude --system-prompt-file
system-generico.md` e poi con l'altro file, in una cartella vuota.

## Che cosa osservare

### Che cosa dice Anthropic

- Sul system prompt, nella Messages API: «A system prompt is a way of providing
  context and instructions to Claude, such as specifying a particular goal or
  role.» (https://platform.claude.com/docs/en/api/messages/create). Il controllo
  legge se l'istruzione «al massimo tre righe», data in quel system prompt, è
  stata seguita. La frase sul ruolo, nelle best practice di prompting («Setting
  a role in the system prompt focuses Claude's behavior and tone…»), è contesto:
  il controllo non la misura.
- Sulla memoria, nella guida ai messaggi della Messages API: «The Messages API
  is stateless, which means that you always send the full conversational
  history to the API.»
  https://platform.claude.com/docs/en/build-with-claude/working-with-messages
- In `claude -p` una conversazione si riprende con `--resume`: «Use --continue
  to continue the most recent conversation, or --resume with a session ID to
  continue a specific conversation.»
  https://code.claude.com/docs/en/headless
- `--system-prompt-file` sostituisce il system prompt di Claude Code con il
  contenuto del file: «--system-prompt | Replaces the entire default prompt …
  --system-prompt-file | Replaces with file contents».
  https://code.claude.com/docs/en/cli-reference
- `--tools ""` toglie tutti gli strumenti integrati: in `claude --help`,
  «Specify the list of available tools from the built-in set. Use "" to
  disable all tools».
- Come si conta la prima richiesta: «total_input_tokens =
  cache_read_input_tokens + cache_creation_input_tokens + input_tokens».
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching

L'istruzione data nel system prompt è ciò che la demo mette alla prova,
confrontando le due chiamate di ogni esecuzione: dice soltanto che cosa ha trovato
nella registrazione. Che la Messages API sia senza stato è una
proprietà del prodotto: per questo le due righe sulla parola in codice decidono
l'uscita del controllo.

### Che cosa misura il controllo

`controlla_sistema.py` legge gli stream di `risposte/`, una cartella per
esecuzione, e stampa per ognuna:

- la risposta, il numero di righe (non vuote) e di parole;
- i token della prima richiesta, quelli di `usage` del primo messaggio
  dell'assistente: il contesto di partenza, che è il system prompt, il
  messaggio e ciò che Claude Code aggiunge da sé; fra le due varianti (il
  “braccio” del controllo) di un'esecuzione cambia solo il system prompt;
- turni, secondi e token della chiamata.

Poi, sulla parte 1, la riga «al massimo tre righe», la soglia che il secondo
system prompt nomina (non di Anthropic), in ogni variante, «n su N»; poi la
coppia, esecuzione per esecuzione: «confermata» se la soglia è rispettata con
il ruolo e non con il system prompt neutro; «non distinguibile» se è
rispettata in tutti e due; «non confermata in questa esecuzione» se non è
rispettata con il ruolo. Questi esiti si stampano e non decidono l'uscita.

Sulla parte 2, per ogni esecuzione, la parola in codice nelle due risposte alla
stessa domanda:

- senza `--resume` la risposta non contiene la parola, perché quella chiamata
  non riceve la conversazione di prima: una garanzia, «confermata» oppure
  «non confermata in questa esecuzione», e allora l'uscita è 1;
- con `--resume` la risposta contiene la parola: anche questa decide
  l'uscita;
- la prima richiesta della chiamata ripresa, in token, accanto a quella della
  chiamata nuova: la sessione ripresa porta anche la conversazione di prima
  (un dato).

Nella registrazione del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni per parte, `_docente/live.sh` sull'account del
docente):

- parte 1: con il system prompt neutro 19, 17 e 17 righe, da 335 a 360 parole;
  con il ruolo e la riga sulle tre righe 2 righe ogni volta, da 73 a 100
  parole. La riga rispettata: «generico 0 su 3, ciaspolink 3 su 3». La coppia:
  «confermata 3 su 3»;
- la prima richiesta: 669 token con il system prompt neutro, da 718 a 720 con
  il ruolo (da +49 a +51): le due chiamate differiscono soltanto nel system
  prompt;
- parte 2: nelle tre prove la parola non c'è nella risposta alla chiamata
  nuova e c'è in quella alla chiamata con `--resume`, e le due garanzie sono
  confermate 3 su 3; la prima richiesta della chiamata ripresa pesa da 662 a
  664 token, quella della chiamata nuova 615 o 616 (da +46 a +49).

Gli stream sono nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M7-D01)

La verifica fa girare `controlla_sistema.py` dell'elemento, non la copia dello
spazio di lavoro, sugli stream di `risposte/`. È fatta quando ogni esecuzione
di ogni parte c'è, è finita bene e le due garanzie sulla parola valgono; il
confronto fra i due system prompt si stampa e non la fa fallire. Quando tutto
è in ordine, le ultime due righe sono «Fatto: ogni esecuzione è stata messa
alla prova; gli esiti sono qui sopra.» e «VERIFICA OK M7-D01: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica esce con 1 e dice che manca un'esecuzione, o che uno stream non
  finisce con il risultato: una chiamata si è fermata a metà. Ricominciate da
  capo: `tools/reset_esercizio.sh M7-D01`.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M7-D01`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- «non distinguibile» o «non confermata in questa esecuzione» sulla parte 1
  sono esiti, non errori: leggete le risposte che il controllo stampa.
- Una garanzia della parte 2 «non confermata in questa esecuzione»: l'uscita
  è 1, e lo stream dice che cosa è successo. Controllate che le tre chiamate
  siano partite dalla stessa cartella: `--resume` trova la sessione solo da
  lì.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessuno strumento, nessun subagent: chiamate di un turno
solo. Un'esecuzione è fatta di cinque chiamate (due della parte 1, tre della
parte 2); la prova del docente ne fa quindici. Nella registrazione del corso (9
novembre 2026, Claude Code 2.1.319, `_docente/live.sh` sull'account del
docente), dal `result` di ogni stream: da 1,0 a 9,9 secondi e da 643 a 1.742
token a chiamata; «Come dati, tutte le 15 chiamate: turni 15; token 14.437; 51,9
s.» I token sono quelli di `usage` di ogni chiamata, entrata, cache e uscita:
dicono quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano
occupa. Per la chiamata con `--resume` è `usage`, non `modelUsage`: «When you
continue an earlier conversation with --continue or --resume, the run reports
the conversation's whole total, earlier runs' spend included.»
(https://code.claude.com/docs/en/headless).

Il modello predefinito di Claude Code sul Pro è un altro: «Pro, Max, Ultra,
Team, Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). Il corso fissa Sonnet perché
la registrazione e le vostre prove girino sullo stesso modello.

Le chiamate della parte 1 e la chiamata nuova della parte 2 hanno
`--no-session-persistence`, che in `claude --help` è «Disable session
persistence - sessions will not be saved to disk and cannot be resumed (only
works with --print)». La prima chiamata della parte 2 invece resta salvata,
perché la si riprende con `--resume`: lo script toglie la sessione appena la
prova è finita.

## Per approfondire

- Le best practice di prompting, il ruolo nel system prompt:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La guida ai messaggi della Messages API:
  https://platform.claude.com/docs/en/build-with-claude/working-with-messages
- `claude -p` e `--resume`: https://code.claude.com/docs/en/headless
- Le opzioni della riga di comando:
  https://code.claude.com/docs/en/cli-reference
