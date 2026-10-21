# M3-D03 — Che cosa vede Claude in un progetto

Demo del Modulo 3, una prova guidata nella parte «Projects o chat». La
fate voi, in claude.ai, ciascuno con il proprio account Pro: un progetto
di prova, tre
chat brevi con la stessa domanda, e uno script che legge le risposte che
copiate nello spazio di lavoro.

## Obiettivo

Mettere alla prova tre garanzie che Anthropic dà sui progetti di
claude.ai: Claude non vede la descrizione del progetto; usa le istruzioni
del progetto in tutte le chat del progetto; quelle istruzioni valgono solo
per le chat del progetto. La stessa frase, «Inizia ogni risposta con la
parola in codice …», sta prima nella descrizione del progetto (prova A),
poi nelle sue istruzioni (prova B); la prova C è una chat fuori dal
progetto. A e B differiscono soltanto per il campo in cui sta la frase, B
e C soltanto per il posto della chat. La parola in codice è nuova per ogni
spazio di lavoro e non si scrive mai in una chat: se compare in una
risposta, Claude l'ha avuta dal progetto.

## Tempo

7 minuti in aula: uno per dire a voce che cosa vi aspettate, sei per le
tre prove. Da soli, una decina di minuti, pulizia compresa.

## Prerequisiti

- Un account claude.ai con il piano Pro, nel browser: i progetti sono
  inclusi nel Pro.
- Python 3 nel terminale (Linux, o WSL 2 su Windows), per generare
  la parola e per la verifica: `tools/verifica_ambiente.sh` lo controlla
  (`PRIMA_DEL_CORSO.md`).
- Nessuna sessione di Claude Code.
- La prova crea sul vostro account un progetto e tre chat, che alla fine
  cancellate. Chi preferisce non crearli segue la registrazione del corso.

## Punto di partenza (tools/prepara_esercizio.sh M3-D03)

Lo spazio di lavoro `~/corso-claude-code/M3-D03/` con:

- `nuova_parola.py`: genera la parola in codice, nuova per ogni spazio di
  lavoro (per esempio `GENZIANA-4817`: una parola di montagna e quattro
  cifre a caso), e la scrive in `parola.txt`, con la frase da incollare in
  `frase.txt`;
- `domanda.txt`: la domanda delle tre prove, «Scrivi una frase su un
  guasto di rete.»;
- `controlla_progetto.py`: legge `parola.txt` e le tre risposte e dice
  l'esito delle tre garanzie.

Le risposte le copiate voi da claude.ai in tre file nuovi dello spazio di
lavoro: `risposta-A.txt`, `risposta-B.txt`, `risposta-C.txt`.

## Passi in Claude Code (qui, in claude.ai)

Questa demo non usa Claude Code: i progetti di cui parla sono quelli di
claude.ai, il tema di questo modulo. Il terminale serve a generare la
parola e a verificare.

**Quale claude.ai avete.** La nuova esperienza di claude.ai arriva
gradualmente sui piani Pro e Max: se la casella del messaggio mostra
ancora le opzioni «Chat» e «Cowork», avete quella precedente. I passi
valgono per tutte e due; dove un comando sta in un posto diverso, lo dice
il passo.

1. **La parola.** Dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M3-D03
       cd ~/corso-claude-code/M3-D03
       python3 nuova_parola.py

   Lo script stampa la parola, la frase da incollare (`cat frase.txt` la
   mostra di nuovo) e dove va in ogni prova. Non scrivete mai la parola in
   una chat: deve arrivare a Claude solo dai campi del progetto. Prima di
   andare avanti, dite a voce: la parola nella descrizione del progetto,
   Claude la vedrà?

2. **Prova A, il progetto.** Andate su claude.ai/projects e cliccate
   «+ New Project», in alto a destra. Nome: «Prova del corso».
   Descrizione: la frase di `frase.txt`. Le istruzioni del progetto
   restano vuote, e nel progetto non caricate file. Nella nuova
   esperienza (come nella registrazione del corso) il pulsante si chiama
   «New project» e apre la finestra «Create a project»: il nome va in
   «What are you working on?», la descrizione in «What are you trying to
   achieve?»; poi «Create project».

3. **Prova A, la chat.** Aprite una chat nuova dentro il progetto (nella
   nuova esperienza la si apre dalla casella del messaggio della pagina
   del progetto, «New session in Prova del corso»). Prima di scrivere,
   aprite il menu «+» della casella del messaggio (in basso a sinistra
   della casella; nella nuova esperienza il pulsante «+» sta sotto il
   campo di input) e spegnete «Memory»: va fatto prima del primo
   messaggio, perché dopo non si cambia più. Incollate la domanda di
   `domanda.txt` e inviate. Dopo l'invio, accanto al titolo della chat
   compare l'icona della memoria barrata (nella nuova esperienza il suo
   suggerimento dice «Memory is off for this chat»): se non c'è, la
   memoria era accesa, e la prova va rifatta in una chat nuova.

4. **Prova A, la risposta.** Copiate il testo della risposta di Claude e
   salvatelo in `risposta-A.txt`, nello spazio di lavoro: con un editor di
   testo semplice, oppure dal terminale con

       cat > risposta-A.txt

   poi incollate, premete Invio e infine Ctrl+D.

5. **Prova B.** Nel progetto cambiate la descrizione in «Progetto di prova
   del corso» e incollate la frase di `frase.txt` nelle istruzioni del
   progetto («Set project instructions»). Nella nuova esperienza la
   descrizione si cambia dal menu accanto al nome del progetto («Edit
   details», campo «Description», poi «Save»), le istruzioni dal
   riquadro a destra della pagina del progetto (Instructions, «Add»: si
   apre «Set project instructions»; poi «Save instructions»). Poi una
   chat nuova dentro il progetto, di nuovo con «Memory» spenta dal menu
   «+» prima del primo messaggio, la stessa domanda, e la risposta in
   `risposta-B.txt`.

6. **Prova C.** Lasciate le istruzioni del progetto come sono e aprite
   una chat nuova fuori dal progetto, sempre con «Memory» spenta dal menu
   «+» prima del primo messaggio; la stessa domanda, e la risposta in
   `risposta-C.txt`.

7. **La verifica**, dalla cartella `esercitazioni` (`cd -` vi riporta lì
   dallo spazio di lavoro):

       cd -
       tools/verifica.sh M3-D03

   Nello spazio di lavoro, `python3 controlla_progetto.py` stampa gli
   stessi dati e gli stessi esiti.

8. **La pulizia.** Cancellate le tre chat di prova: si cancellano dalla
   barra laterale, o da «Chats and tasks», con «Delete» (nella nuova
   esperienza la lista delle conversazioni si chiama «Recents»). Poi
   cancellate il progetto di prova (nella nuova esperienza: il menu
   accanto al nome del progetto, «Delete»).

## Che cosa osservare

### Che cosa dice Anthropic

Nell'articolo del supporto «How can I create and manage projects?»
(https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects):

- sulla descrizione: «Give your project a name and description (note
  that Claude will not have access to these details).» (traduzione
  nostra: «Date al progetto un nome e una descrizione: Claude non avrà
  accesso a questi dettagli.»);
- sulle istruzioni: «Add instructions for how you'd like Claude to behave
  and respond … Claude will use these instructions for all the chats
  within the project.» («Aggiungete le istruzioni su come volete che
  Claude si comporti e risponda … Claude userà queste istruzioni in tutte
  le chat del progetto.»).

Nell'articolo «Understanding Claude's personalization features»
(https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features):
«Project instructions help Claude understand the specific context and
requirements for a particular project. These instructions only apply to
chats within that project.» («Le istruzioni di progetto aiutano Claude a
capire il contesto e i requisiti di un progetto. Valgono solo per le chat
di quel progetto.»).

Sono garanzie del prodotto: devono valere a ogni esecuzione.

Perché ogni prova è una chat nuova con la memoria spenta: secondo
l'articolo «Use Claude's chat search and memory to build on previous
context»
(https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context),
in una chat avviata così «Claude doesn't use memory in that chat, doesn’t
search your past chats from it, and doesn’t save anything from it to
memory.», e «A chat started with memory off in a project doesn't use your
memory or the project's memory.». E l'articolo sui progetti avverte: «Note:
Context is not shared across chats within a project unless the
information is added into the project knowledge base.». Così né la
memoria, né la ricerca nelle chat, né un'altra chat del progetto possono
portare la parola da una prova all'altra: a Claude arriva soltanto dal
campo in cui sta.

La pagina «What are projects?»
(https://support.claude.com/en/articles/9517075-what-are-projects)
annuncia una nuova versione dei progetti, in beta, e precisa: «Other
existing projects in chat and Cowork stay on the current version for now,
and we’ll move them as the rollout expands.». Questa prova riguarda la
versione attuale, quella dei progetti nelle chat di claude.ai.

### Che cosa misura il controllo

`controlla_progetto.py` legge la parola di `parola.txt` e le tre
risposte, così come le avete copiate. Di ogni risposta stampa l'inizio (i
primi 120 caratteri) e due dati: se contiene la parola, e se comincia con
la parola. Non contano le maiuscole, il tipo di trattino (anche uno spazio
al posto del trattino) e, all'inizio della risposta, gli spazi, il
markdown (asterischi, trattini bassi, cancelletti, il segno >, i segni di
un elenco) e le virgolette. Poi le tre garanzie:

- «Claude non vede la descrizione del progetto» (prova A): confermata se
  la risposta non contiene la parola;
- «Claude usa le istruzioni del progetto in tutte le sue chat» (prova B):
  confermata se la risposta contiene la parola. Se comincia con la
  parola, come chiede la frase, resta un dato: Anthropic dice che Claude
  usa le istruzioni, non quanto le segue alla lettera;
- «Le istruzioni valgono solo per le chat del progetto» (prova C):
  confermata se la risposta non contiene la parola.

Una garanzia che non tiene è «non confermata in questa esecuzione», con la
frase «La documentazione garantisce …: in questa esecuzione …», e fa
fallire la verifica: è un esito da far vedere al docente. La prova B fa
anche da controllo delle altre due: se nella sua risposta la parola non
c'è, la frase non è arrivata a Claude nemmeno dalle istruzioni, dove
doveva arrivare, e allora A e C, senza la parola, non mostrano niente: si
stampano «non distinguibile», con il perché, invece di «confermata».
Che cosa scrive
Claude sul guasto di rete non conta: il controllo non lo giudica. Il
controllo decide dalle risposte e non scrive niente.

Nella registrazione del corso (21 ottobre 2026, claude.ai nella nuova
esperienza, sull'account del docente, con il modello che l'account aveva
selezionato, Haiku con effort low; una chat nuova per prova, ognuna con
«Memory» spenta prima del primo messaggio, e una sola esecuzione per
prova, perché sono garanzie): nella prova A la risposta («Un guasto di
rete è stato causato da un’interruzione nel collegamento tra i
dispositivi…») non contiene la parola; nella prova B la parola c'è, e
anzi la risposta comincia con la parola («MARMOTTA-9103 Un guasto di
rete è un’interruzione o un malfunzionamento…»); nella prova C la parola
non c'è. Le tre garanzie:
confermate. Le tre risposte, la parola e la frase sono nella cartella
`soluzione/` di questo elemento.

## Verifica (tools/verifica.sh M3-D03)

`tools/verifica.sh M3-D03` fa girare `controlla_progetto.py`
dell'elemento, non la copia dello spazio di lavoro, su `parola.txt` e
sulle tre risposte. Esce con 0 quando le tre risposte ci sono e le tre
garanzie tengono, e l'ultima riga è «Fatto: ogni affermazione è stata
messa alla prova; gli esiti sono qui sopra.»; con 1 quando manca
`parola.txt` o una risposta (e dice quale), o quando una garanzia non
tiene; con 2 quando un file non si legge o non è testo UTF-8, o quando
`parola.txt` non ha più la forma che gli dà `nuova_parola.py`.

## Se qualcosa va storto

- Avete inviato la domanda prima di spegnere «Memory», o accanto al
  titolo non c'è l'icona della memoria barrata: in quella chat la memoria
  era accesa, e non si cambia più. Aprite una chat nuova e rifate la
  prova.
- La verifica dice che la parola è comparsa nella prova A o nella prova
  C: controllate prima che quella chat avesse la memoria spenta (l'icona
  barrata) e che la parola non l'abbiate scritta voi in una chat. Se è
  tutto in ordine, è un esito da segnalare al docente: la documentazione
  lo esclude.
- La verifica dice che nella risposta della prova B la parola non c'è:
  controllate che la frase sia nelle istruzioni del progetto e che
  la chat sia dentro il progetto, poi rifate la prova B in una chat nuova.
  Se la frase c'era, è un esito da segnalare al docente.
- `controlla_progetto.py` dice che manca `parola.txt`: lanciate
  `python3 nuova_parola.py` nello spazio di lavoro. Per una parola nuova,
  `python3 nuova_parola.py --nuova`, e rifate le tre prove con la frase
  nuova (nel progetto cambiano la descrizione e le istruzioni).
- Una risposta vuota o che manca: copiatela di nuovo nel file che il
  controllo nomina.
- «non è testo UTF-8»: salvate il file come testo UTF-8, per esempio con
  `cat >` come al passo 4.
- La pagina dei progetti non è come la descrivono i passi (per esempio
  non trovate la descrizione o le istruzioni del progetto): una nuova
  versione dei progetti è in rilascio graduale. Ditelo al docente e
  seguite la registrazione del corso.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-D03`. Cancella lo
  spazio di lavoro, con la parola e le risposte; il progetto e le chat su
  claude.ai restano, e si cancellano come al passo 8.

## Impronta d'uso sul piano Pro

Tre chat brevi in claude.ai, una domanda ciascuna: tre turni, con il
modello e l'effort che trovate selezionati (li vedete accanto al pulsante
di invio). Nessun file caricato, nessuna sessione di Claude Code, nessun
subagent. I limiti d'uso sono condivisi: l'uso di claude.ai e quello di
Claude Code contano sullo stesso limite.

## Per approfondire

- Creare e gestire i progetti:
  https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects
- Che cosa sono i progetti, e la nuova versione in beta:
  https://support.claude.com/en/articles/9517075-what-are-projects
- Le istruzioni di progetto fra le funzioni di personalizzazione:
  https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features
- La memoria, la ricerca nelle chat e una chat senza memoria:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
- La lezione «Introduction to projects» del corso Claude 101 della Claude
  Academy: https://academy.claude.com/courses/claude-101/introduction-to-projects
