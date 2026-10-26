# M2-D06 — La galleria degli orrori

Demo del Modulo 2, nella parte «La galleria degli orrori». In aula la
esegue il docente, e prima di ogni coppia indovinate a voce che cosa
succederà; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova quattro affermazioni della documentazione di Anthropic
sul modo di scrivere un prompt. Per ognuna, una coppia di prompt sullo
stesso messaggio di un cliente: un «orrore» e la sua cura, che cambiano in
una cosa sola. Uno script conta nelle risposte ciò che l'affermazione
permette di controllare, e dice se questa esecuzione la conferma.

## Tempo

8 minuti in aula; per rifarla da soli, una decina di minuti, quasi tutti
per leggere le risposte: nella registrazione del corso le nove chiamate
durano 73 secondi in tutto.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D06)

Lo spazio di lavoro `~/corso-claude-code/M2-D06/` con il messaggio della
Falegnameria Fittizia (`messaggio.md`, che non contiene importi in euro) e
nove prompt: quattro orrori, le loro cure e, per il divieto, lo stesso
riepilogo senza indicazioni sul formato. Ogni prompt, tranne
`orrore-4-memoria.md`, è un'istruzione, una riga vuota e il messaggio.

- **La richiesta vaga.** `orrore-1-vaga.md`: «Fammi un documento carino
  su questo messaggio.»; `cura-1-vaga.md`: «Scrivi per il tecnico di turno
  una scheda di questo messaggio in tre righe, che cominciano con
  «Problema:», «Quando:» e «Richieste:», in non più di 60 parole in
  tutto.»
- **Il divieto.** Lo stesso compito, «Scrivi per il team un riepilogo di
  questo messaggio: che cosa è successo, che cosa chiede il cliente e che
  cosa fare.», tre volte: `base-2-formato.md` senza altro;
  `orrore-2-divieto.md` con «Non usare markdown nella tua risposta.»;
  `cura-2-divieto.md` con «La tua risposta dovrebbe essere composta da
  paragrafi di prosa scorrevole.»
- **Una stima senza dati.** `orrore-3-stima.md`: «Proponi tre azioni per
  il team, ciascuna con una stima dei costi.»; `cura-3-stima.md`: la
  stessa frase, più «Usa solo le informazioni del messaggio: dove un dato
  manca, scrivi «non indicato nel messaggio».»
- **La memoria presunta.** `orrore-4-memoria.md`: «Come ti ho detto ieri,
  riscrivi la risposta al cliente con lo stesso formato che abbiamo
  concordato.», senza il messaggio; `cura-4-memoria.md`: «Scrivi la
  risposta al cliente con il formato concordato: al massimo tre righe in
  tutto, firma compresa, e in fondo la firma «L'assistenza clienti di
  CiaspoLink».», con il messaggio.

E poi `istruzione.txt` («Rispondi in italiano.», l'istruzione di sistema
di tutte le prove), `misura_orrori.py` (legge il JSON di una prova e ne
stampa la riga di `orrori.tsv`) e `leggi_json.py` (legge il JSON di una
risposta e ne stampa un dato).

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D06
       cd ~/corso-claude-code/M2-D06

2. Le nove prove su Sonnet, una chiamata ciascuna: il JSON di ogni
   risposta va in `risposte/`, la sua riga in `orrori.tsv`.

       mkdir -p risposte
       python3 misura_orrori.py --intestazione > orrori.tsv
       for p in orrore-1-vaga cura-1-vaga base-2-formato orrore-2-divieto \
           cura-2-divieto orrore-3-stima cura-3-stima orrore-4-memoria \
           cura-4-memoria; do
         echo "== $p"
         claude -p "$(cat "$p.md")" --model sonnet --effort low --tools "" \
           --strict-mcp-config --setting-sources project,local \
           --permission-mode dontAsk --permission-prompts none \
           --output-format json --no-session-persistence \
           --system-prompt "$(cat istruzione.txt)" > "risposte/$p.json"
         python3 misura_orrori.py "$p" < "risposte/$p.json" >> orrori.tsv
       done

   Le nove chiamate cambiano soltanto nel prompt; le opzioni sono quelle
   della registrazione del corso. Tre contano per la demo, come le
   descrive il riferimento della CLI: `--tools ""` disabilita tutti gli
   strumenti integrati; `--system-prompt` sostituisce l'intero prompt di
   sistema, qui con la riga di `istruzione.txt`; con
   `--no-session-persistence` la sessione non viene salvata su disco e non
   si può riprendere.

3. Una risposta per intero, con i suoi a capo (qui quella della richiesta
   vaga):

       python3 -c 'import json,sys; print(json.load(sys.stdin)["result"])' \
         < risposte/orrore-1-vaga.json

4. L'esito, dalla cartella `esercitazioni`:

       tools/verifica.sh M2-D06

## Che cosa osservare

### Che cosa dice Anthropic

- **La richiesta vaga.** Nella guida «Best practice per il prompting»,
  sezione «Sii chiaro e diretto»: «Claude risponde bene a istruzioni
  chiare ed esplicite. Essere specifici sull'output desiderato può aiutare
  a migliorare i risultati.» E, fra i consigli della stessa sezione: «Sii
  specifico sul formato di output e sui vincoli che desideri.»
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- **Il divieto.** Nella stessa guida, sezione «Controlla il formato delle
  risposte», il primo dei «modi particolarmente efficaci per orientare la
  formattazione dell'output»: «Di' a Claude cosa fare invece di cosa non
  fare». L'esempio: «Invece di: "Non usare markdown nella tua risposta"»,
  «Prova: "La tua risposta dovrebbe essere composta da paragrafi di prosa
  scorrevole."». Il divieto e la cura usano queste parole.
- **Una stima senza dati.** Nella guida «Ridurre le allucinazioni», alla
  voce «Consenti a Claude di dire "Non lo so"»: «Concedi esplicitamente a
  Claude il permesso di ammettere l'incertezza. Questa tecnica può
  ridurre drasticamente le informazioni false.» E alla voce «Limitazione
  della conoscenza esterna»: «Istruisci esplicitamente Claude a
  utilizzare solo le informazioni provenienti dai documenti forniti e non
  la sua conoscenza generale.» Con un avvertimento: «sebbene queste tecniche
  riducano significativamente le allucinazioni, non le eliminano del
  tutto».
  https://platform.claude.com/docs/it/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- **La memoria presunta.** Nella pagina «Utilizzo della Messages API»,
  sezione «Turni conversazionali multipli»: «La Messages API è stateless
  (senza stato), il che significa che invii sempre l'intera cronologia
  della conversazione all'API.»
  https://platform.claude.com/docs/it/build-with-claude/working-with-messages

### Che cosa misura il controllo

`misura_orrori.py` legge il JSON di ogni prova e ne scrive la riga in
`orrori.tsv`; `verifica.sh` legge `orrori.tsv`, stampa i numeri e, per
ogni affermazione, una riga: «confermata», «non confermata in questa
esecuzione» oppure «non distinguibile», con il perché. Nessuna risposta si
giudica a occhio. Le regole, coppia per coppia:

- **La richiesta vaga.** La cura chiede una scheda con tre vincoli: tre
  righe non vuote; la prima comincia con «Problema:», la seconda con
  «Quando:», la terza con «Richieste:» (vale anche in grassetto o in
  corsivo); al massimo 60 parole, contate come pezzi di testo fra spazi o
  a capo. Si contano i vincoli che rispetta ciascuna delle due risposte,
  che differiscono soltanto nell'istruzione: confermata se la scheda ne
  rispetta più della risposta alla richiesta vaga; non distinguibile se
  anche questa li rispetta tutti e tre, perché allora non c'è niente da
  migliorare; altrimenti non confermata in questa esecuzione. Della
  richiesta vaga si stampano anche titoli, voci di elenco, righe di
  tabella e grassetti, come dati.
- **Il divieto.** Si contano gli elementi di Markdown: le righe di titolo
  (da uno a sei `#` in testa), le voci di elenco (una riga che comincia
  con `-`, `*`, `+`, `•` o con un numero seguito da `.` o `)`), le righe
  di tabella (fra due `|`) e i tratti in grassetto (fra `**` e `**`).
  L'affermazione mette a confronto due modi di chiedere la stessa cosa,
  «Invece di» e «Prova», e l'orrore e la cura differiscono soltanto in
  quella riga: confermata se la cura ha meno elementi dell'orrore; non
  distinguibile se l'orrore non ne ha nessuno, perché allora non c'è
  niente da migliorare; altrimenti non confermata in questa esecuzione.
  Il conto del riepilogo senza indicazioni sul formato, e se la cura non
  ha nessun elemento, si stampano come dati e non decidono l'esito.
- **Una stima senza dati.** Prima di tutto `misura_orrori.py` controlla
  che `messaggio.md` e i due prompt della stima non contengano importi in
  euro, ed esce con 2 se ne trova uno: così ogni importo in una risposta
  è inventato. Un importo è un numero seguito da `€`, «euro» o «EUR»,
  anche con una grandezza in mezzo («5 mila euro», «12 k€», «1,5 milioni
  di euro», «3 mln €»), oppure `€` o «EUR» seguiti da un numero, con
  maiuscole o minuscole. Secondo Anthropic queste tecniche riducono le
  allucinazioni, ma «non le eliminano del tutto»: l'affermazione è un
  confronto, e l'orrore e la cura differiscono soltanto nella frase che le
  applica. Confermata se la cura ha meno importi dell'orrore; non
  distinguibile se l'orrore non ne ha nessuno, perché allora non c'è
  niente da ridurre; altrimenti non confermata in questa esecuzione. Se la
  cura non ha nessun importo, e se scrive «non indicato», si stampano come
  dati e non decidono l'esito.
- **La memoria presunta.** Si cerca la firma concordata, «L'assistenza
  clienti di CiaspoLink», con maiuscole o minuscole e con l'apostrofo
  dritto o tipografico. Nell'orrore deve mancare: né il prompt di una riga
  né l'istruzione di sistema la contengono, e il comando non usa
  `--continue` né `--resume`, che riprendono una conversazione. È l'unica
  garanzia della demo: se la firma c'è, `verifica.sh` esce con 1. Nella
  cura, che manda nel prompt il formato concordato, la firma deve
  esserci: è una raccomandazione, e la decide soltanto la firma. Le righe
  non vuote della cura, e se sono al massimo tre, si stampano come dati.
  Si stampano anche i token in entrata delle due chiamate, cioè quanto ha
  ricevuto ciascuna.

Le raccomandazioni non confermate si stampano e non fanno uscire
`verifica.sh` con 1.

Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.305,
Sonnet con effort low, tre esecuzioni per prova e una sola per la
richiesta vaga):

- la richiesta vaga, un'esecuzione sola: 537 parole in 51 righe, nessuna
  etichetta al suo posto, vincoli della scheda rispettati 0 su 3; come
  dati, 7 titoli, 22 voci di elenco, 7 righe di tabella e 13 grassetti.
  La scheda: vincoli rispettati 3 su 3 in ogni esecuzione; confermata 3
  su 3;
- il divieto: elementi di Markdown 6, 9 e 9 con il divieto, 1, 1 e 1 con
  la prosa chiesta in positivo (un grassetto ogni volta); confermata 3 su
  3. Come dati: 35, 36 e 34 elementi senza indicazioni sul formato, e la
  prosa senza nessun elemento 0 volte su 3;
- la stima: importi in euro 13, 9 e 10 nell'orrore, 0, 0 e 0 nella cura;
  confermata 3 su 3. Come dati: la cura senza nessun importo 3 volte su
  3, e con «non indicato» 3 su 3;
- la memoria: firma assente nell'orrore 3 su 3 (la garanzia); firma nella
  cura 3 su 3, confermata 3 su 3; come dati, la cura in 2 righe ogni
  volta; token in entrata 578 nell'orrore e 977 nella cura.

## Verifica (tools/verifica.sh M2-D06)

In `orrori.tsv` ci sono le nove risposte e, nella risposta della memoria
presunta, la firma concordata manca: è la garanzia, e se non tiene la
verifica esce con 1. Le altre affermazioni sono raccomandazioni: la
verifica ne stampa l'esito e non fallisce per loro. Quando tutto è in
ordine, l'ultima riga è «Fatto: ogni affermazione è stata messa alla
prova; gli esiti sono qui sopra.»

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- `misura_orrori.py` parla di un importo in euro ed esce con 2: è cambiato
  `messaggio.md` o un prompt della stima. Rimetteteli com'erano, per
  esempio ricominciando da capo.
- Una prova senza risposta (`misura_orrori.py` stampa un errore e la sua
  riga non arriva in `orrori.tsv`): rilanciate solo quella, con
  `p=<nome della prova>` e le due righe `claude -p …` e
  `python3 misura_orrori.py …` del ciclo. La riga nuova va in fondo a
  `orrori.tsv`, e la verifica legge l'ultima di ogni prova.
- La verifica dice «in questa esecuzione no» sulla memoria presunta:
  controllate che il comando sia quello del passo 2, senza `--continue` né
  `--resume`, che riprendono una conversazione precedente.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D06`.

## Impronta d'uso sul piano Pro

Nove chiamate su Sonnet, una per prova, con effort low, nessuno strumento
e nessun subagent, un turno ciascuna. Nella registrazione del corso: in
entrata da 578 a 991 token, in uscita da 131 a 1705.

## Per approfondire

- La guida «Best practice per il prompting», con «Sii chiaro e diretto» e
  «Controlla il formato delle risposte»:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La guida «Ridurre le allucinazioni»:
  https://platform.claude.com/docs/it/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- «Utilizzo della Messages API», sui turni conversazionali multipli:
  https://platform.claude.com/docs/it/build-with-claude/working-with-messages
- Le opzioni della CLI (`--tools`, `--system-prompt`,
  `--no-session-persistence`, `--continue`, `--resume`):
  https://code.claude.com/docs/it/cli-reference
- La memoria e la cronologia delle chat in claude.ai:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
