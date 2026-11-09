# M7-D10 — L'assistente in un progetto di claude.ai

Demo del Modulo 7, nella parte sulla conoscenza dell'assistente, e una prova che
potete rifare sul vostro account, se volete. La stessa domanda di un cliente di
CiaspoLink, il fornitore di connettività inventato del corso, prima in una chat
nuova, senza niente, poi in un progetto che ha nella conoscenza alcune procedure
dell'assistenza e nelle istruzioni l'assistente riprogettato. In aula la fa il
docente dal vivo; le sue schermate sono il ripiego.

## Obiettivo

Mettere alla prova una frase di Anthropic sui progetti di claude.ai: «Anything
you upload to this space will be used across all of your chats within that
project.» Le due chat sono tutte e due nuove, con la memoria spenta prima del
primo messaggio; cambia soltanto il posto: la prima fuori dai progetti, senza
allegati, la seconda in un progetto con quattro procedure di CiaspoLink nella
conoscenza e le istruzioni dell'assistente. Il codice della procedura che
risponde, KB-12, e il numero dell'Assistenza Prioritaria, +39 000 000 2000, non
stanno altrove: CiaspoLink è inventato e le procedure le ha scritte il corso. Per
questo, se nella risposta ci sono codice e numero, le procedure sono arrivate a
Claude.

È lo stesso assistente di Claude Code, questa volta dove lo vede un utente di
claude.ai, senza server MCP e senza `claude -p`: per questo qui si lavora su
claude.ai e non nel terminale.

## Tempo

3 minuti in aula, la demo del docente, che prepara prima il progetto e le due
chat, con «Memory» spenta e la domanda incollata, non inviata: dal vivo, i due
invii. Da soli, qualche minuto, la pulizia compresa.

## Prerequisiti

- Un account claude.ai con il piano Pro, nel browser: «Projects are available to
  all users, including those with free Claude accounts.»
  (https://support.claude.com/en/articles/9517075-what-are-projects)
- La memoria attiva sull'account, come di solito: «Memory is on by default for
  Free, Pro, Max, and Ultra plans on the web, Claude Desktop, and Claude
  Mobile.»
  (https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects)
  Senza, «Memory» nel menu «+» non c'è, e la chat è già senza memoria.
- Python 3 nel terminale (Linux o WSL 2 su Windows), per la verifica:
  `tools/verifica_ambiente.sh` lo controlla (`PRIMA_DEL_CORSO.md`).
- Nessuna sessione di Claude Code.
- La prova crea sul vostro account un progetto e due chat, che alla fine
  cancellate. Chi preferisce non crearli guarda la demo del docente.

## Punto di partenza (tools/prepara_esercizio.sh M7-D10)

Lo spazio di lavoro `~/corso-claude-code/M7-D10/` con:

- `conoscenza/`: quattro procedure dell'assistenza di CiaspoLink, le stesse del
  progetto del corso, KB-08, KB-10, KB-11 e KB-12, tutti dati sintetici; vanno
  nella conoscenza del progetto;
- `domanda.txt`: la domanda delle due chat;
- `istruzioni-progetto.txt`: le istruzioni del progetto, una versione breve
  dell'assistente riprogettato;
- `controlla_risposte.py`: legge la procedura KB-12 e le due risposte, e dice
  che cosa c'è di quella procedura in ciascuna;
- `risposte/`: la cartella, vuota, dove salvate le due risposte,
  `risposte/chat.txt` e `risposte/progetto.txt`.

## Passi in Claude Code (qui, in claude.ai)

Questa demo non usa Claude Code: i progetti di cui parla sono quelli di
claude.ai. Il terminale serve a preparare i file e a verificare.

**Quale claude.ai avete.** La nuova esperienza di claude.ai arriva gradualmente:
«If you're on a Pro, Max, or Ultra plan and your message box still shows "Chat"
and "Cowork" options, you don't have it yet.»
(https://support.claude.com/en/articles/16761823-claude-cowork-and-chat-are-one-claude)
I passi valgono per tutte e due; dove un pulsante ha un altro nome, il passo dà
quello che la prova del corso ha visto nella nuova esperienza.

1. **I file.** Dalla cartella `esercitazioni`:

       tools/prepara_esercizio.sh M7-D10
       cd ~/corso-claude-code/M7-D10
       cat domanda.txt

2. **La chat, senza progetto.** In claude.ai aprite una chat nuova, fuori da ogni
   progetto. Prima di scrivere, aprite il menu «+» della casella del messaggio e
   spegnete «Memory»: va fatto prima del primo messaggio, perché dopo non si
   cambia più. Non allegate niente. Incollate la domanda e inviate:

   <!-- prompt 1 -->

       A quale numero devo chiamare per l'Assistenza Prioritaria di CiaspoLink?

   <!-- /prompt 1 -->

   Dopo l'invio, accanto al titolo della chat compare l'icona della memoria
   barrata: se non c'è, la memoria era accesa, e la prova va rifatta in una chat
   nuova.

3. **La risposta della chat.** Copiate il testo della risposta e salvatelo in
   `risposte/chat.txt`, nello spazio di lavoro: con un editor di testo semplice,
   oppure dal terminale con

       cat > risposte/chat.txt

   poi incollate, premete Invio e infine Ctrl+D.

4. **Il progetto.** Andate su claude.ai/projects e cliccate «+ New Project», in
   alto a destra (nella nuova esperienza «New project», che apre «Create a
   project»). Nome: «Prova del corso, l'assistente di CiaspoLink»; la descrizione
   può restare vuota. Poi, nella pagina del progetto:
   - la conoscenza, sulla destra: con il pulsante «+» caricate i quattro file di
     `conoscenza/` (nella nuova esperienza la voce si chiama «Context», con il
     suo «Add»);
   - le istruzioni: «Set project instructions» (nella nuova esperienza
     «Instructions», «Add»), incollate il testo qui sotto
     (`cat istruzioni-progetto.txt`) e «Save instructions».

   <!-- prompt 2 -->

       <role>
       Sei l'assistente virtuale dell'assistenza clienti di CiaspoLink, un operatore di connettività, e rispondi ai clienti che scrivono in chat.
       </role>

       <context>
       Le procedure di CiaspoLink sono i file kb-NN nella conoscenza di questo progetto. Il cliente si regola su quello che gli rispondi.
       </context>

       <instructions>
       1. Trova nella conoscenza del progetto la procedura che riguarda la domanda del cliente.
       2. Rispondi con ciò che dice la procedura e scrivi il suo codice, nella forma KB-NN.
       3. Prima di rispondere, controlla che il codice sia quello del file da cui prendi la risposta.
       </instructions>

       <format>
       Al massimo quattro frasi, in italiano, dando del lei al cliente.
       </format>

       <constraints>
       Se la conoscenza del progetto non contiene la risposta, scrivi che non lo sai.
       </constraints>

   <!-- /prompt 2 -->

5. **La chat nel progetto.** Aprite una chat nuova dentro il progetto, di nuovo
   con «Memory» spenta dal menu «+» prima del primo messaggio, incollate la stessa
   domanda e inviate.

6. **La risposta del progetto.** Salvatela in `risposte/progetto.txt`, come al
   passo 3:

       cat > risposte/progetto.txt

7. **La verifica**, dalla cartella `esercitazioni` (`cd -` vi riporta lì dallo
   spazio di lavoro):

       cd -
       tools/verifica.sh M7-D10

8. **La pulizia, da non saltare.** Cancellate le due chat: nella barra laterale,
   o in «Chats and tasks», il pulsante «⋮» della chat e «Delete» (nella nuova
   esperienza la lista delle conversazioni si chiama «Recents»), e confermate
   nella finestra che si apre. Poi cancellate il progetto: dalla pagina dei
   progetti, il pulsante «...» del progetto, «Delete» e la conferma, «Yes,
   delete».

## Che cosa osservare

### Che cosa dice Anthropic

Nell'articolo «How can I create and manage projects?»
(https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects):

- sulla conoscenza: «Anything you upload to this space will be used across all
  of your chats within that project.» È la frase che la demo mette alla prova;
- sulle istruzioni: «Add instructions for how you'd like Claude to behave and
  respond … Claude will use these instructions for all the chats within the
  project.»;
- sul nome e la descrizione: «Give your project a name and description (note
  that Claude will not have access to these details).»;
- fra le chat dello stesso progetto: «Note: Context is not shared across chats
  within a project unless the information is added into the project knowledge
  base.»;
- sulla memoria, per una chat sola: «You can turn memory off for a single chat …
  by turning off "Memory" in the "+" menu before you send your first message.»,
  e in un progetto: «A project chat started this way doesn't use or add to the
  project's memory.»

Nell'articolo sulla memoria
(https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context):
«You need to turn memory off before you send the first message. Once the chat
starts, the setting can't be changed.»; una chat così «doesn't search your past
chats from it, and doesn't save anything from it to memory. Unlike incognito
chats, they stay in your chat history.»; e «After you send your first message, a
crossed-out memory icon appears next to the chat title.» Così né la memoria né
la ricerca nelle chat passate portano le procedure da una chat all'altra.

La ricerca sul web: «If you have the new Claude experience, there's no web
search toggle. Claude searches the web when it helps.»
(https://support.claude.com/en/articles/10684626-enable-and-use-web-search) Le
procedure di CiaspoLink le ha inventate il corso: il web non le ha.

Le istruzioni e la conoscenza, in «What are projects?»
(https://support.claude.com/en/articles/9517075-what-are-projects): «In addition,
you can define project instructions for each project to further tailor Claude's
responses.» e, quando la conoscenza cresce, «When your project knowledge approaches
context limits, Claude seamlessly enables RAG mode to expand capacity by up to
10x while maintaining response quality.» La stessa cosa nell'articolo sul RAG
(https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects):
«When your project knowledge approaches the context window limit, Claude will
automatically enable RAG mode to expand your project's capacity by up to 10x»; e
con il RAG «you'll see Claude using a project knowledge search tool when it needs
to find relevant information from your uploaded content». Le quattro procedure
sono poche pagine, lontane da quel limite. Nello stesso articolo: «Use clear,
descriptive filenames … Well-named files help Claude understand and retrieve the
right information more effectively.»: per questo i file portano nel nome il codice
e l'argomento, `kb-12-orari-e-canali.md`.

La pagina «What are projects?» annuncia una nuova versione dei progetti, in
beta: «Other existing projects in chat and Cowork stay on the current version
for now, and we’ll move them as the rollout expands.» Questa demo riguarda la
versione attuale, quella dei progetti nelle chat di claude.ai.

### Sullo schermo

Ciò che fa claude.ai si giudica a occhio:

- **La chat senza progetto.** Che cosa risponde, senza le procedure: dice che non
  lo sa, chiede di quale azienda parliamo, cerca sul web, dà un numero? Se dà un
  numero, da dove dice di prenderlo?
- **La chat nel progetto.** La risposta ha il numero +39 000 000 2000 e il codice
  KB-12? Sopra la risposta c'è una ricerca nella conoscenza del progetto?

### Che cosa fa il controllo

`controlla_risposte.py` è una dimostrazione: legge le due risposte come le avete
salvate, non ciò che è successo su claude.ai. Della procedura KB-12 prende il
codice e il numero dell'Assistenza Prioritaria. Di ogni risposta stampa l'inizio
e, come dati: se ha il codice, se ha il numero, con o senza spazi, e i codici KB-NN
che cita, per ciascuno se è fra le procedure caricate, così un codice inventato si
vede. Poi, come dato, in quale delle due risposte ci sono il codice e il numero
insieme. Nessuna di queste righe decide il codice d'uscita della verifica, e nessuna
dice se la frase di Anthropic tiene: quello si guarda sullo schermo.

### Nella prova del corso

La demo del docente su claude.ai, il 9 novembre 2026, con Sonnet 5.5 scelto dal
menu del modello e «Memory» spenta prima del primo messaggio nelle due chat: le
due risposte stanno in `soluzione/risposte/` (nel repository del corso; la copia
senza soluzioni non le ha). La chat fuori dai progetti ha cercato sul web e ha
risposto che non trovava CiaspoLink e che non aveva un numero affidabile da dare:
nella risposta non ci sono né il codice né il numero. La chat nel progetto ha
risposto «Il numero dedicato all'Assistenza Prioritaria è +39 000 000 2000
(KB-12)»: il controllo, sui due file, stampa «il codice e il numero insieme: la
chat, senza progetto: no; la chat nel progetto con le procedure: sì», un dato
di queste due risposte.

## Verifica (tools/verifica.sh M7-D10)

`tools/verifica.sh M7-D10` fa girare `controlla_risposte.py` dell'elemento, non la
copia dello spazio di lavoro, che vi stampa gli stessi dati. È fatta quando le
due risposte ci sono e non sono vuote: le ultime due righe sono «Fatto: …» e
«VERIFICA OK M7-D10: fatto.». Che cosa c'è nelle risposte è un dato: stampato,
mai un verdetto.

## Se qualcosa va storto

- Nel menu «+» non c'è «Memory»: la memoria è spenta per l'account, e allora la
  chat è già senza memoria: «If memory is already off for your account or your
  organization, or your plan doesn't include it, you won't see "Memory" in the
  "+" menu.»
  (https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context)
- Il pulsante «+ New Project» non c'è, o i progetti si aprono in un'altra
  interfaccia: la vostra claude.ai può essere già la nuova esperienza, e i
  progetti possono essere la nuova versione: «Other existing projects in chat and
  Cowork stay on the current version for now, and we’ll move them as the rollout
  expands.» Seguite la demo del docente.
- La verifica dice che una risposta manca o è vuota: copiatela di nuovo nel file
  che nomina, come al passo 3.
- «non è testo UTF-8»: salvate il file come testo UTF-8, per esempio con
  `cat >` come al passo 3.
- Per ricominciare da capo: `tools/reset_esercizio.sh M7-D10`. Cancella lo spazio
  di lavoro con le risposte; il progetto e le chat su claude.ai restano, e si
  cancellano come al passo 8.

## Impronta d'uso sul piano Pro

Due chat di un messaggio ciascuna e un progetto con quattro file di poche pagine:
nessuna sessione di Claude Code, nessun subagent. Il modello si sceglie dal menu
accanto al pulsante di invio: «The model menu next to the send button controls
three settings: which Claude model … how much effort … and whether it uses
thinking.» (https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings);
il corso usa Sonnet, lo stesso modello delle altre prove del modulo. La verifica
gira sul vostro computer e non chiama nessun modello.

## Per approfondire

- «How can I create and manage projects?», creare un progetto, la conoscenza, le
  istruzioni e la memoria:
  https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects
- «What are projects?», e la nuova versione in beta:
  https://support.claude.com/en/articles/9517075-what-are-projects
- «Retrieval augmented generation (RAG) for projects», quando la conoscenza
  cresce:
  https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects
- «Use Claude’s chat search and memory to build on previous context», la memoria
  e una chat senza memoria:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
- La lezione «Introduction to projects» del corso Claude 101 della Claude
  Academy: https://academy.claude.com/courses/claude-101/introduction-to-projects
