# M3-D04 — Una chat senza memoria

Demo del Modulo 3, una prova guidata nella parte «Memoria, cronologia e
dati». La fate voi, in claude.ai, con il vostro account Pro: una chat
chiede a Claude di ricordare un codice di prova, poi due chat nuove gli
chiedono quale fosse, una con la memoria e una senza. Uno script legge
le due risposte, che copiate nello spazio di lavoro. Alla fine il codice
si toglie dalla memoria.

## Obiettivo

Mettere alla prova due affermazioni di Anthropic sulla memoria di
claude.ai. Una garanzia: in una chat avviata con la memoria spenta, Claude
non usa la memoria e non cerca nelle chat passate. E un «può»: Claude può
ricordare il contesto delle chat e portarlo nelle conversazioni nuove. Le
due chat con la domanda differiscono in una cosa sola, l'interruttore
della memoria. Il codice è inventato, nuovo per ogni spazio di lavoro, e
non compare nei dati del corso: se torna in una risposta, Claude l'ha
avuto dalla chat in cui gli avete chiesto di ricordarlo.

## Tempo

5 minuti in aula: tre chat brevi e la verifica; poi la pulizia della
memoria, da non saltare. Da soli, una decina di minuti.

## Prerequisiti

- Un account claude.ai con il piano Pro, nel browser: la memoria è
  inclusa nel Pro e, sui piani Free, Pro e Max, è attiva per impostazione
  predefinita.
- Python 3 nel terminale (Linux o WSL 2 su Windows), per generare il
  codice e per la verifica: `tools/verifica_ambiente.sh` lo controlla
  (`PRIMA_DEL_CORSO.md`).
- Nessuna sessione di Claude Code.
- La prova scrive nella vostra memoria di claude.ai un codice inventato,
  che alla fine togliete (passo 7). Chi preferisce non toccare la propria
  memoria segue la registrazione del corso.

## Punto di partenza (tools/prepara_esercizio.sh M3-D04)

Lo spazio di lavoro `~/corso-claude-code/M3-D04/` con:

- `nuovo_codice.py`: genera il codice della linea di prova, nuovo per
  ogni spazio di lavoro (per esempio `LP-QZKW-37`: quattro lettere e due
  cifre a caso), e lo scrive in `codice.txt`, con la frase da mandare a
  Claude in `frase-da-ricordare.txt`;
- `domanda.txt`: la domanda delle due chat di prova, «Quale codice della
  linea di prova del corso ti ho chiesto di ricordare? Rispondi solo con
  il codice, oppure NON LO SO.»;
- `controlla_memoria.py`: legge `codice.txt` e le due risposte e dice
  l'esito delle due affermazioni.

Le risposte le copiate voi da claude.ai in due file nuovi dello spazio di
lavoro: `risposta-con-memoria.txt` e `risposta-senza-memoria.txt`.

## Passi in Claude Code (qui, in claude.ai)

Questa demo non usa Claude Code: la memoria di cui parla è quella di
claude.ai, il tema di questo modulo. Il terminale serve a generare il
codice e a verificare.

**Quale claude.ai avete.** La nuova esperienza di claude.ai arriva
gradualmente sui piani Pro e Max: se la casella del messaggio mostra
ancora le opzioni «Chat» e «Cowork», avete quella precedente. I passi
valgono per tutte e due; dove un comando sta in un posto diverso, lo dice
il passo. Anche le impostazioni hanno un layout aggiornato e uno
precedente: nel primo la memoria sta in Settings > Your Claude, nel layout
precedente delle impostazioni in Settings > Memory. Dove i due layout
differiscono, i passi li danno tutti e due.

1. **La memoria accesa.** In claude.ai, in Settings > Your Claude,
   «Memory from chats» dev'essere acceso (nel layout precedente delle
   impostazioni: in Settings > Memory, «Generate memory from chats»). La
   memoria non dev'essere in pausa: con «Pause memory» Claude conserva la
   memoria che ha, ma non la usa e non ne crea di nuova. «Search and
   reference chats», la ricerca nelle chat passate, può restare com'è: se
   è accesa, il codice può tornare anche da lì.

2. **Il codice.** Dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M3-D04
       cd ~/corso-claude-code/M3-D04
       python3 nuovo_codice.py

   Lo script stampa il codice e la frase da mandare a Claude
   (`cat frase-da-ricordare.txt` la mostra di nuovo).

3. **La chat da ricordare.** Aprite una chat nuova fuori da ogni progetto
   (un progetto ha una memoria sua), con la memoria accesa: il menu «+»
   non si tocca. Incollate la frase di `frase-da-ricordare.txt` e inviate.
   Nella registrazione del corso, nella nuova esperienza, sopra la
   risposta è comparso il passo «Updated memory». Se volete, guardate in
   Settings > Your Claude, con «Manage» accanto a «Your memory» (nel
   layout precedente delle impostazioni, in Settings > Memory): sotto
   «Topics» c'è tutto ciò che Claude ricorda (nella nuova esperienza gli
   argomenti stanno sotto «Areas»); vedete se c'è il codice.

4. **La chat con la memoria.** Un'altra chat nuova, fuori da ogni
   progetto, con la memoria accesa. Incollate la domanda di `domanda.txt`
   e inviate. Copiate il testo della risposta di Claude e salvatelo in
   `risposta-con-memoria.txt`, nello spazio di lavoro: con un editor di
   testo semplice, oppure dal terminale con

       cat > risposta-con-memoria.txt

   poi incollate, premete Invio e infine Ctrl+D. Quando Claude cerca nelle
   chat passate, nella chat lo vedete come una chiamata a uno strumento:
   guardate se c'è. Nella registrazione del corso il passo era «Read
   memory», e nessuna ricerca nelle chat.

5. **La chat senza memoria.** Un'altra chat nuova, fuori da ogni
   progetto. Prima di scrivere, aprite il menu «+» della casella del
   messaggio (in basso a sinistra della casella; nella nuova esperienza il
   pulsante «+» sta sotto il campo di input) e spegnete «Memory»: va fatto
   prima del primo messaggio, perché dopo non si cambia più. Incollate la
   stessa domanda e inviate: accanto al titolo della chat compare l'icona
   della memoria barrata. La risposta va in `risposta-senza-memoria.txt`,
   come al passo 4.

6. **La verifica**: tornate nella cartella `esercitazioni` e verificate:

       cd -
       tools/verifica.sh M3-D04

   Nello spazio di lavoro, `python3 controlla_memoria.py` stampa gli
   stessi dati e gli stessi esiti.

7. **La pulizia, da non saltare.** In Settings > Your Claude, con
   «Manage» accanto a «Your memory» (nel layout precedente delle
   impostazioni, in Settings > Memory), sotto «Topics» (nella nuova
   esperienza «Areas»), aprite l'argomento che contiene il codice e, con
   l'icona di modifica, togliete il codice dall'argomento; se l'argomento
   non contiene nient'altro, cancellatelo con «Delete» (nella nuova
   esperienza chiede conferma: «Delete this memory?»). Fatela con la
   memoria accesa: le singole memorie si cancellano finché la memoria è
   attiva. Cancellare le chat non basta: le voci di memoria nate da una
   chat restano anche quando la chat viene cancellata.
   Poi, se volete, cancellate le tre chat: si cancellano dalla barra
   laterale, o da «Chats and tasks», con «Delete» (nella nuova esperienza
   la lista delle conversazioni si chiama «Recents»).

## Che cosa osservare

### Che cosa dice Anthropic

Nell'articolo del supporto «Use Claude's chat search and memory to build
on previous context»
(https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context):

- sulla memoria fra le chat: «Claude can also remember context from your
  chats and carry it into new conversations and Cowork tasks.»
  (traduzione nostra: «Claude può anche ricordare il contesto delle
  vostre chat e portarlo nelle conversazioni nuove e nei task di
  Cowork.»). È un «può»: dice che può succedere, e l'esito di una sola
  prova non decide;
- su come si salva: «Claude saves on its own, and you can also tell
  Claude to "remember this" to save something directly.» («Claude salva
  da sé, e potete anche dirgli "ricordati questo" per salvare qualcosa
  direttamente.»): è ciò che fa la frase del passo 3. E: «Tell Claude what
  you'd like it to remember, change, or forget, and the update applies to
  your next conversation.» («… e l'aggiornamento vale dalla conversazione
  successiva»): per questo le due domande stanno in chat nuove;
- sulla chat senza memoria: «To run a single chat or Cowork task without
  memory, open a new chat, click the “+” menu, and turn off "Memory."»;
  «You need to turn memory off before you send the first message. Once
  the chat starts, the setting can't be changed.»; e in quella chat
  «Claude doesn't use memory in that chat, doesn’t search your past chats
  from it, and doesn’t save anything from it to memory.» («Claude non usa
  la memoria in quella chat, non cerca da lì nelle vostre chat passate e
  non ne salva niente in memoria.»). È una garanzia del prodotto: deve
  valere a ogni esecuzione;
- sulla ricerca nelle chat passate: «When Claude searches your previous
  chats, you will see this reflected in your current chat as a tool
  call.»;
- sulla pulizia: «Select any topic to read it, then use the edit icon to
  change it or select "Delete" to remove it.»; e «When a conversation is
  deleted, including under a retention period, memory entries generated
  from it aren’t removed, but you can delete individual memories while
  memory is on.».

### Che cosa misura il controllo

`controlla_memoria.py` legge il codice di `codice.txt` e le due risposte,
così come le avete copiate. Di ogni risposta stampa l'inizio (i primi 120
caratteri) e due dati: se contiene il codice, e se contiene «NON LO SO».
Il codice si cerca senza badare alle maiuscole, al tipo di trattino
(anche uno spazio al posto del trattino) e al prefisso `LP-`: basta la
parte estratta a caso. Poi le due affermazioni:

- «Claude può ricordare il contesto delle chat e portarlo nelle
  conversazioni nuove» (chat con la memoria): confermata se la risposta
  contiene il codice, altrimenti «non confermata in questa esecuzione». È
  un «può»: l'esito si stampa e non fa fallire la verifica. Il codice può
  tornare dalla memoria o dalla ricerca nelle chat passate: il controllo
  non sa quale delle due, la ricerca la vedete nella chat;
- «In una chat senza memoria Claude non usa la memoria e non cerca nelle
  chat passate» (chat senza memoria): confermata se la risposta non
  contiene il codice. È una garanzia: se il codice c'è, la verifica
  fallisce con la frase «La documentazione garantisce …: in questa
  esecuzione il codice è comparso.», ed è un esito da far vedere al
  docente. La chat con la memoria fa anche da controllo di questa: se la
  sua risposta non contiene il codice, il codice non è arrivato alla
  memoria; se manca, non si sa se c'è arrivato. In tutti e due i casi la
  chat senza memoria non può mostrare che da lì non arriva: si stampa
  «non distinguibile», con il perché, invece di «confermata».

«NON LO SO» è un dato: la domanda lo permette, e il controllo non lo
giudica. Il controllo decide dalle risposte e non scrive niente.

Nella registrazione del corso (21 ottobre 2026, claude.ai nella nuova
esperienza, sull'account del docente, con il modello che l'account aveva
selezionato, Haiku con effort low; nel layout precedente delle
impostazioni, «Generate memory from chats» e «Search and reference chats»
accesi): la chat da ricordare ha mostrato il
passo «Updated memory»; nella chat con la memoria, il passo «Read memory»
e la risposta «LP-FKYJ-14», il codice: «confermata» per il «può»; nella
chat senza memoria, nessun passo di strumenti e la risposta «NON LO SO»:
la garanzia, confermata. Alla pulizia l'argomento della memoria conteneva
soltanto il codice, ed è stato cancellato. Il codice, la frase e le due
risposte sono nella cartella `soluzione/` di questo elemento.

## Verifica (tools/verifica.sh M3-D04)

`tools/verifica.sh M3-D04` fa girare `controlla_memoria.py`
dell'elemento, non la copia dello spazio di lavoro, su `codice.txt` e
sulle due risposte. Esce con 0 quando le due risposte ci sono e la
garanzia tiene, qualunque sia l'esito del «può», e l'ultima riga è
«Fatto: ogni affermazione è stata messa alla prova; gli esiti sono qui
sopra.»; con 1 quando manca `codice.txt` o una risposta (e dice quale), o
quando la garanzia non tiene; con 2 quando un file non si legge o non è
testo UTF-8, o quando `codice.txt` non ha più la forma che gli dà
`nuovo_codice.py`.

## Se qualcosa va storto

- Avete inviato la domanda prima di spegnere «Memory», o accanto al
  titolo non c'è l'icona della memoria barrata: in quella chat la memoria
  era accesa, e non si cambia più. Aprite una chat nuova e rifate la chat
  senza memoria.
- La verifica dice che il codice è comparso nella chat senza memoria:
  controllate prima l'icona della memoria barrata accanto al titolo di
  quella chat. Se c'è, è un esito da segnalare al docente: la
  documentazione lo esclude.
- La risposta con la memoria non contiene il codice: è un esito anche
  questo, e la verifica non fallisce. Guardate in Settings > Your Claude,
  con «Manage» accanto a «Your memory» (nel layout precedente delle
  impostazioni, in Settings > Memory), se il codice è fra i «Topics», e se
  la memoria è accesa e non in pausa.
- Avete fatto le chat dentro un progetto: un progetto ha una memoria sua.
  Rifatele fuori da ogni progetto.
- `controlla_memoria.py` dice che manca `codice.txt`: lanciate
  `python3 nuovo_codice.py` nello spazio di lavoro. Per un codice nuovo,
  `python3 nuovo_codice.py --nuovo`: rifate le tre chat con la frase
  nuova, e alla fine togliete dalla memoria anche il codice vecchio.
- Una risposta vuota o che manca: copiatela di nuovo nel file che il
  controllo nomina.
- «non è testo UTF-8»: salvate il file come testo UTF-8, per esempio con
  `cat >` come al passo 4.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-D04`. Cancella lo
  spazio di lavoro, non la memoria di claude.ai: la pulizia del passo 7
  resta da fare.

## Impronta d'uso sul piano Pro

Tre chat brevi in claude.ai, un messaggio ciascuna (la frase da ricordare
e due volte la domanda): tre turni, con il modello e l'effort che trovate
selezionati (li vedete accanto al pulsante di invio). Nessun file
caricato, nessuna sessione di Claude Code, nessun subagent. I limiti d'uso
sono condivisi: l'uso di claude.ai e quello di Claude Code contano sullo
stesso limite.

## Per approfondire

- La memoria, la ricerca nelle chat e una chat senza memoria:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
- Le note di rilascio, con la memoria fatta di argomenti («Topics»):
  https://support.claude.com/en/articles/12138966-release-notes
- Le chat incognito, che non usano la memoria che Claude ha già:
  https://support.claude.com/en/articles/12260368-use-incognito-chats
- Cancellare o rinominare una conversazione:
  https://support.claude.com/en/articles/8230524-delete-or-rename-a-conversation
