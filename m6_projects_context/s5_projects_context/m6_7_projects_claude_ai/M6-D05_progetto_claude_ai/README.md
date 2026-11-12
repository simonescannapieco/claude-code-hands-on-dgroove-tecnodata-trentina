# M6-D05 — La stessa domanda, in un progetto di claude.ai

Demo del Modulo 6, nella parte sui Projects di claude.ai, e una prova che
potete rifare sul vostro account, se volete. La stessa domanda sulla carta dei
servizi di CiaspoLink, l'operatore inventato del corso, un documento che nessun
modello ha letto: prima in una chat nuova, senza niente, poi in un progetto che
ha la carta nella sua conoscenza. In aula la fa il docente dal vivo; le sue
schermate sono il ripiego.

## Obiettivo

Mettere alla prova una frase di Anthropic sui progetti di claude.ai: «Anything
you upload to this space will be used across all of your chats within that
project.» Le due chat sono tutte e due nuove, con la memoria spenta prima del
primo messaggio; cambia soltanto il posto: la prima fuori dai progetti, senza
allegati, la seconda in un progetto con la carta nella conoscenza e due righe di
istruzioni. Le cifre dell'Art. 4 della carta, 5 giorni lavorativi da maggio a
ottobre e 9 da novembre ad aprile, non stanno altrove: le istruzioni non le
dicono, e la carta l'ha scritta il corso. Per questo, se in una risposta ci sono
tutte e due, con l'Art. 4, la carta è arrivata a Claude.

È l'altro significato di «Projects» del modulo, ed è per questo che qui si
lavora su claude.ai e non in Claude Code: in Claude Code la stessa carta la
porta un CLAUDE.md (M6-D01).

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

## Punto di partenza (tools/prepara_esercizio.sh M6-D05)

Lo spazio di lavoro `~/corso-claude-code/M6-D05/` con:

- `carta-servizi.md`: la carta dei servizi di CiaspoLink, sette articoli, tutti i
  dati sintetici; va nella conoscenza del progetto;
- `domanda.txt`: la domanda delle due chat;
- `istruzioni-progetto.txt`: le istruzioni del progetto;
- `controlla_risposte.py`: legge la carta e le due risposte, e dice che cosa c'è
  della carta in ciascuna;
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

       tools/prepara_esercizio.sh M6-D05
       cd ~/corso-claude-code/M6-D05
       cat domanda.txt

2. **La chat, senza progetto.** In claude.ai aprite una chat nuova, fuori da ogni
   progetto. Prima di scrivere, aprite il menu «+» della casella del messaggio e
   spegnete «Memory»: va fatto prima del primo messaggio, perché dopo non si
   cambia più. Non allegate niente. Incollate la domanda e inviate:

   <!-- prompt 1 -->

       Entro quanti giorni lavorativi va fatto un intervento su un ponte radio in quota?

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
   project»). Nome: «Prova del corso, la carta dei servizi»; la descrizione può
   restare vuota. Poi, nella pagina del progetto:
   - la conoscenza, sulla destra: con il pulsante «+» caricate
     `carta-servizi.md`, dallo spazio di lavoro (nella nuova esperienza la
     voce si chiama «Context», con il suo «Add»; nella prova del corso il file
     `.md` è stato accettato, «Context · 1 file»);
   - le istruzioni: «Set project instructions» (nella nuova esperienza
     «Instructions», «Add»), incollate il testo qui sotto
     (`cat istruzioni-progetto.txt`) e «Save instructions».

   <!-- prompt 2 -->

       <instructions>
       Rispondi in base alla carta dei servizi caricata nel progetto, carta-servizi.md.
       </instructions>

       <format>
       Cita l'articolo da cui prendi la risposta.
       </format>

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
       tools/verifica.sh M6-D05

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
la ricerca nelle chat passate portano la carta da una chat all'altra.

La ricerca sul web: «If you have the new Claude experience, there's no web
search toggle. Claude searches the web when it helps.»
(https://support.claude.com/en/articles/10684626-enable-and-use-web-search) La
carta l'ha inventata il corso.

La conoscenza, in «What are projects?»
(https://support.claude.com/en/articles/9517075-what-are-projects): «You can
upload relevant documents, text, code, or other files to a project's knowledge
base, which Claude will use to better understand the context»; quando cresce,
«When your project knowledge approaches context limits, Claude seamlessly
enables RAG mode to expand capacity by up to 10x while maintaining response
quality.» Con il RAG, «you'll see Claude using a project knowledge search tool
when it needs to find relevant information from your uploaded content»
(https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects).
La carta è di sette articoli, meno di duemila caratteri. Nello stesso articolo:
«Use clear, descriptive filenames» e «When asking questions, you can reference
specific documents by name to help Claude focus its search.»: per questo le
istruzioni nominano `carta-servizi.md`.

La pagina «What are projects?» annuncia una nuova versione dei progetti, in
beta: «Other existing projects in chat and Cowork stay on the current version
for now, and we’ll move them as the rollout expands.» Questa demo riguarda la
versione attuale, quella dei progetti nelle chat di claude.ai. La stessa pagina
dice che alcuni sono già stati spostati: «We've started moving existing projects
for some Pro, Max, and Ultra users to the new version.» Su quegli account i
progetti sono la versione nuova, e i passi qui sopra possono essere diversi.

### Sullo schermo

Ciò che fa claude.ai si giudica a occhio:

- **La chat senza progetto.** Che cosa risponde, senza la carta: dice che non
  lo sa, chiede di quale documento parliamo, cerca sul web, dà delle cifre? Se
  dà delle cifre, da dove dice di prenderle?
- **La chat nel progetto.** La risposta ha i 5 giorni lavorativi da maggio a
  ottobre e i 9 da novembre ad aprile, e cita l'Art. 4? Sopra la risposta c'è
  una ricerca nella conoscenza del progetto?

### Che cosa fa il controllo

`controlla_risposte.py` è una dimostrazione: legge le due risposte come le avete
salvate, non ciò che è successo su claude.ai. Della carta prende gli articoli e
le cifre dell'Art. 4, «Interventi sugli apparati in quota», 5 e 9 giorni
lavorativi. Di ogni risposta stampa l'inizio e, come dati: se ha ciascuna cifra,
in cifre o in lettere; se dice «giorni lavorativi»; gli articoli che cita, e per
ciascuno se la carta lo ha e con quale titolo, così un articolo inventato si
vede. Poi, come dato, in quale delle due risposte ci sono tutte le cifre.
Nessuna di queste righe decide il codice d'uscita della verifica, e nessuna dice
se la frase di Anthropic tiene: quello si guarda sullo schermo.

### Nella prova del corso

La demo del docente, il 7 novembre 2026, sull'account del docente, nella nuova
esperienza di claude.ai, con Sonnet 5.5 scelto dal menu del modello e
«Memory» spenta dal menu «+» prima del primo messaggio in tutte e due le chat
(la pagina diceva «Memory is off for this chat»). Le due risposte, copiate
così come claude.ai le mostrava, sono in `soluzione/risposte/` (nel repository
del corso; la copia senza soluzioni non le ha).

- La chat fuori dai progetti, senza allegati, ha cercato sul web (una
  ricerca) e ha risposto che un termine unico non c'è: ha citato i 5 giorni
  lavorativi di un capitolato di gara pubblico trovato in rete, non della
  carta, e nessun articolo.
- La chat nel progetto, con la carta nella conoscenza («Context · 1 file») e
  le istruzioni, non ha cercato sul web e ha risposto con l'Art. 4: 5 giorni
  lavorativi da maggio a ottobre, 9 da novembre ad aprile, con i mezzi da
  neve; ha citato anche l'Art. 5.

Il controllo su quelle due risposte ha stampato:

    risposte/chat.txt, la chat, senza progetto: «Non esiste un termine unico di legge per questo tipo di intervento. […]»
      (dato) le cifre dell'art. 4: 5: sì; 9: no; «giorni lavorativi»: sì
      (dato) gli articoli citati: nessuno
    risposte/progetto.txt, la chat nel progetto con la carta: «Dipende dalla stagione. Secondo l’Art. 4 — Interventi sugli apparati in quota, […]»
      (dato) le cifre dell'art. 4: 5: sì; 9: sì; «giorni lavorativi»: sì
      (dato) gli articoli citati: art. 4, nella carta: «Interventi sugli apparati in quota»; art. 5, nella carta: «Indennizzi»

    (dato) tutte le cifre dell'art. 4: la chat, senza progetto: no; la chat nel progetto con la carta: sì

Il 5 della chat senza progetto viene dal web, non dalla carta: per questo il
controllo guarda tutte e due le cifre e l'articolo. Alla fine la chat del
progetto, la chat senza progetto e il progetto sono stati cancellati.

## Verifica (tools/verifica.sh M6-D05)

`tools/verifica.sh M6-D05` fa girare `controlla_risposte.py` dell'elemento, non la
copia dello spazio di lavoro, che vi stampa gli stessi dati. È fatta quando le
due risposte ci sono e non sono vuote: le ultime due righe sono «Fatto: …» e
«VERIFICA OK   M6-D05: fatto.» Esce con 1 quando una risposta manca o è vuota, e
dice quale; con 2 quando un file non si legge o non è testo UTF-8, o quando
manca la carta.

## Se qualcosa va storto

- Avete inviato la domanda prima di spegnere «Memory», o accanto al titolo non
  c'è l'icona della memoria barrata: in quella chat la memoria era accesa, e non
  si cambia più. Aprite una chat nuova e rifate la prova.
- Nel menu «+» non c'è «Memory»: la memoria è spenta per tutto l'account, e la
  chat è già senza.
- Il sito non accetta `carta-servizi.md`: fra i documenti che Claude legge,
  «Upload files to Claude» elenca «TXT», e non nomina il Markdown
  (https://support.claude.com/en/articles/8241126-upload-files-to-claude).
  Copiatela con un altro nome, `cp carta-servizi.md carta-servizi.txt`, e caricate
  quella: è lo stesso testo. Nelle istruzioni del progetto cambiate anche il nome
  del file: `carta-servizi.txt` al posto di `carta-servizi.md`.
- La pagina dei progetti non è come la descrivono i passi: una nuova versione
  dei progetti è in rilascio graduale. Seguite la demo del docente.
- La verifica dice che una risposta manca o è vuota: copiatela di nuovo nel file
  che nomina, come al passo 3.
- «non è testo UTF-8»: salvate il file come testo UTF-8, per esempio con
  `cat >` come al passo 3.
- Per ricominciare da capo: `tools/reset_esercizio.sh M6-D05`. Cancella lo spazio
  di lavoro con le risposte; il progetto e le chat su claude.ai restano, e si
  cancellano come al passo 8.

## Impronta d'uso sul piano Pro

Due chat di un messaggio ciascuna e un progetto con un file di sette articoli:
nessuna sessione di Claude Code, nessun subagent. Il modello si sceglie dal menu
accanto al pulsante di invio: «The model menu next to the send button controls
three settings: which Claude model you're chatting with, how much effort it puts
into each response, and whether it uses thinking.»
(https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings);
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
