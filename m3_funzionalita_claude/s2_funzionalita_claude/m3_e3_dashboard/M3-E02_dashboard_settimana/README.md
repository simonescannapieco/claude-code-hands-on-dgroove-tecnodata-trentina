# M3-E02 — La dashboard della settimana

Esercitazione del Modulo 3, nel laboratorio, dopo M3-E01: la settimana di
ticket anonimizzata in Claude Code va in claude.ai, dove Claude ne calcola
gli indicatori e poi ne fa una dashboard. La fate voi, in claude.ai, con il
vostro account Pro; il terminale serve a preparare il file e a verificare i
numeri.

## Obiettivo

Caricare in claude.ai il file anonimo della settimana, far calcolare a
Claude **prima i numeri**, con il codice sul file, e verificarli con uno
script; **poi la dashboard**, come artifact, con i numeri verificati; e
tenerla privata. Seguite tre indicazioni di Anthropic: far interrogare
una tabella con il codice invece di incollarla, verificare i calcoli che
contano, chiedere l'artifact in modo esplicito. La prima è un confronto,
e la mette alla prova la coppia registrata del corso («Che cosa misura il
controllo»): la vostra chat fa una strada sola, e i suoi numeri sono un
dato.

## Tempo

19 minuti: uno per l'obiettivo, uno per il file e la chat, uno per i
numeri, uno per la dashboard, quattordici di lavoro, uno per la
condivisione. Con una sola modifica della dashboard bastano 16 minuti.

## Prerequisiti

- Un account claude.ai con il piano Pro, nel browser. L'esecuzione di
  codice è attiva per impostazione predefinita: «Free, Pro, and Max plans:
  … Code execution and file creation is enabled by default»
  (https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude).
  Gli artifact ne hanno bisogno: «Artifacts require Cloud code execution
  and file creation to be turned on in Settings > Capabilities (Free, Pro,
  Max)»
  (https://support.claude.com/en/articles/17153992-what-are-artifacts-and-how-do-i-use-them).
- Python 3 nel terminale (Linux, o WSL 2 su Windows), per la verifica:
  `tools/verifica_ambiente.sh` lo controlla (`PRIMA_DEL_CORSO.md`).
- M3-E01 fatto, con `tools/verifica.sh M3-E01` uscito con 0, per usare il
  vostro file anonimo. Chi non l'ha finito, o la cui verifica non è
  passata, usa la copia di riferimento di questo elemento.
- Nessuna sessione di Claude Code.

## Punto di partenza (tools/prepara_esercizio.sh M3-E02)

Lo spazio di lavoro `~/corso-claude-code/M3-E02/` con:

- `ticket-anonimi.csv`: la settimana di ticket anonimizzata, 343
  segnalazioni, circa 100 KB. È la copia di riferimento, uguale al file che
  produce la soluzione di M3-E01; chi ha fatto M3-E01 la sostituisce con il
  proprio (passo 1);
- `kpi_definizioni.md`: i dieci indicatori della settimana, con le regole
  di calcolo e di arrotondamento, gli stessi di M3-E01 e di M3-E03;
- `prompt-numeri.md` e `prompt-dashboard.md`: i due prompt, da incollare
  in claude.ai.

`kpi.json` non c'è: lo scrivete voi, con i numeri di claude.ai (passo 4).

## Passi in Claude Code (qui, in claude.ai)

Questa esercitazione si svolge in claude.ai, il tema del modulo: il
caricamento di un file, l'esecuzione di codice e gli artifact sono
funzioni di claude.ai. La stessa dashboard, fatta in Claude Code come
pagina locale, è M3-E03.

**Quale claude.ai avete.** La nuova esperienza arriva gradualmente: «The
new Claude experience is rolling out gradually, starting with Pro and Max
plans on web, desktop, and mobile.» Se la casella del messaggio mostra
ancora le opzioni «Chat» e «Cowork», avete quella precedente: «If you're
on a Pro or Max plan and your message box still shows "Chat" and "Cowork"
options, you don't have it yet.»
(https://support.claude.com/en/articles/16761823-claude-cowork-and-chat-are-one-claude).
I passi valgono per tutte e due; dove un comando sta in un posto diverso,
lo dice il passo. Le schermate delle slide sono della nuova esperienza.

1. **Il file.** Dalla cartella `esercitazioni`, da cui partono tutti i
   comandi di questa esercitazione:

       tools/prepara_esercizio.sh M3-E02

   Se avete fatto M3-E01 e la sua verifica è uscita con 0, mettete il
   vostro file anonimo al posto della copia di riferimento:

       cp ~/corso-claude-code/M3-E01/anonimo/ticket-anonimi.csv \
          ~/corso-claude-code/M3-E02/

   Su Windows con WSL 2 lo spazio di lavoro sta nel file system di Linux:
   se dal browser non lo raggiungete, copiate il file in una cartella di
   Windows e caricatelo da lì, per esempio
   `cp ~/corso-claude-code/M3-E02/ticket-anonimi.csv /mnt/c/Users/<utente>/Downloads/`,
   con il vostro nome utente di Windows al posto di `<utente>`.

2. **Una chat nuova, senza memoria.** In claude.ai aprite una chat nuova,
   fuori da ogni progetto. Prima di scrivere, aprite il menu «+» della
   casella del messaggio (in basso a sinistra della casella; nella nuova
   esperienza il pulsante «+» sta sotto il campo di input) e spegnete
   «Memory»: va fatto prima del primo messaggio. Così l'analisi della
   settimana non entra nella vostra memoria. Non usate una chat incognito:
   il centro assistenza dice che con la nuova esperienza si apre in quella
   precedente, dove Claude non esegue codice. Nel menu del modello
   scegliete Sonnet.

3. **Il caricamento.** Dal menu «+» scegliete «Add files or photos»
   (nella nuova esperienza «Upload or add files») e caricate
   `ticket-anonimi.csv` dello spazio di lavoro: nella casella compare una
   scheda con il nome del file e l'etichetta CSV.

4. **Prima i numeri.** Incollate il prompt di `prompt-numeri.md` e
   inviate:

   <!-- prompt: numeri -->

       Nel file ticket-anonimi.csv che ti ho caricato c'è una settimana
       di segnalazioni, una per riga: calcola con il codice, sul file,
       questi indicatori.

       Rispondi con un solo oggetto JSON, senza altro testo, con queste
       dieci chiavi. Un campo vuoto non vale zero e non entra nei conti;
       arrotonda con la metà per eccesso.
       - segnalazioni: le righe (intero)
       - per_giorno: le righe per giorno della settimana di aperto_il,
         data come è scritta, chiavi lun mar mer gio ven sab dom (interi)
       - aperte_fine_settimana: le righe con chiuso_il vuoto (intero)
       - annullate: le righe con stato annullato (intero)
       - per_categoria: le righe per ogni categoria presente (interi)
       - mediana_minuti_prima_risposta: la mediana (1 decimale)
       - media_minuti_risoluzione_per_tecnologia: la media per
         tecnologia, solo quelle con almeno un valore (1 decimale)
       - voti: le righe con soddisfazione non vuota (intero)
       - soddisfazione_media: la media (2 decimali)
       - clienti_ricorrenti: i clienti con almeno 3 righe (intero)

   <!-- /prompt: numeri -->

   Claude scrive ed esegue il codice sul file, nel suo ambiente di
   calcolo, e risponde con l'oggetto JSON. Copiatelo con il pulsante
   «Copy», il primo sotto la risposta, non selezionando il testo: nella
   registrazione del corso la risposta non stava in un blocco di codice, e
   il testo della pagina aveva le virgolette tipografiche “ ”, che in JSON
   non valgono, mentre il pulsante ha copiato quelle dritte. Incollatelo
   in `kpi.json`, nello spazio di lavoro: con un editor di testo semplice,
   oppure dal terminale, sempre dalla cartella `esercitazioni`, con

       cat > ~/corso-claude-code/M3-E02/kpi.json

   poi incollate, premete Invio e infine Ctrl+D. Se copiate anche il
   blocco di codice intorno (```` ```json ```` … ```` ``` ````), la
   verifica lo toglie da sé.

5. **La verifica dei numeri**, dalla cartella `esercitazioni`:

       tools/verifica.sh M3-E02

   Per ogni indicatore stampa il valore vero, calcolato dallo stesso file,
   quello di `kpi.json` e se corrisponde. Se un indicatore dice `NO`,
   ditelo a Claude nella stessa chat, per esempio «La mia verifica dà
   valori diversi per per_giorno e soddisfazione_media: ricontrolla con il
   codice e rispondi di nuovo con l'oggetto JSON intero.»; poi copiate di
   nuovo la risposta in `kpi.json`, con lo stesso comando del passo 4, e
   verificate di nuovo. Checkpoint: la verifica esce con 0 e ogni
   indicatore dice ok, cioè «Come dato: 10 KPI su 10 corrispondono.»: lo
   0 dice soltanto che `kpi.json` ha la forma giusta, e la dashboard parte
   dai numeri che dite verificati.

6. **Poi la dashboard.** Nella stessa chat incollate il prompt di
   `prompt-dashboard.md`:

   <!-- prompt: dashboard -->

       Crea come artifact una dashboard della settimana con esattamente
       i numeri del JSON qui sopra, quelli che ho verificato: le
       segnalazioni per giorno in barre, le categorie dalla più
       frequente, le aperte a fine settimana e le annullate, la mediana
       dei minuti alla prima risposta, la media dei minuti di
       risoluzione per tecnologia, la soddisfazione media con il numero
       dei voti, i clienti ricorrenti. Ogni numero scritto accanto al suo
       grafico, testi in italiano.

   <!-- /prompt: dashboard -->

   L'artifact si apre accanto alla conversazione. Confrontate a occhio i
   suoi numeri con quelli della verifica. Poi chiedete a Claude una o due
   modifiche, per esempio «Metti in alto quattro riquadri con
   segnalazioni, aperte, annullate e soddisfazione media, e usa un colore
   solo per tutte le barre.» Se l'artifact mostra un errore, usate il
   pulsante «Try fixing with Claude» vicino al messaggio d'errore.

7. **Tenerla privata.** Aprite la condivisione dell'artifact: nella nuova
   esperienza è il pulsante «Share» nell'intestazione dell'artifact. Sotto
   «General access» il selettore mostra «Only you»; aperto, offre due
   voci: «Only people invited», con il segno di spunta, e «Anyone with
   the link» («People with the link can view, but not edit.»). Lasciate
   «Only you», che nel selettore aperto è la voce con la spunta, «Only
   people invited»: chiudete il selettore e la finestra con Esc, senza
   condividere.

8. **La pulizia, se volete.** Cancellate la chat dal menu accanto al suo
   titolo, «Delete». Nella registrazione del corso l'artifact è rimasto nella
   pagina «Artifacts» (claude.ai/artifacts) anche dopo la cancellazione
   della chat: si cancella dal suo menu, «Delete».

- **Percorso A, un vostro CSV:** un'esportazione come quelle del vostro
  lavoro, con dati inventati al posto di quelli veri, come nel percorso A
  di M3-E01 (mai persone, aziende o sistemi reali: il file va in
  claude.ai). Gli stessi passi, con i vostri indicatori al posto di
  quelli di `prompt-numeri.md`. La verifica è quella del percorso B: il
  vostro file non lo verifica.
- **Percorso B, la settimana di CiaspoLink:** `ticket-anonimi.csv` dello
  spazio di lavoro, il vostro di M3-E01 o la copia di riferimento. La
  registrazione del corso e la verifica sono su questo.

## Che cosa osservare

### Che cosa dice Anthropic

- **Prima i numeri, con il codice.** La documentazione sui modelli, nella
  pagina sul costo e l'intelligenza: «When the model has to compute over a
  table … let the model query it with code execution instead of pasting
  it in.» E la misura di Anthropic: «Pasted into the prompt, the table is
  about 91,000 input tokens on every request, and Claude Sonnet 5 answered
  7 of 25 questions correctly.»; «Uploaded, with code execution, it
  answered all 25, and the run cost about a twelfth as much. Claude Opus 5
  showed the same pattern.»; nelle sue condizioni: «An
  Anthropic-constructed set of 25 aggregate questions over a 1,862-row
  slice of a public liquor-sales CSV … with thinking disabled»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence).
  È un confronto fra due strade: la vostra chat ne percorre una sola, il
  file caricato con il codice. Lo decide la coppia registrata del corso,
  sotto.
- **Il file caricato.** «You can also upload CSV, TSV, and other files for
  data analysis and visualization.»
  (https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude).
  Ciò che caricate arriva ad Anthropic: «The content you submit to the
  Services through these interactions, including … content you choose to
  upload … are your “Inputs”.» (https://www.anthropic.com/legal/privacy).
  Per questo si carica il file anonimo di M3-E01, non quello con i dati
  personali.
- **Perché si verificano i numeri.** Il supporto di Anthropic: «complex or
  mission-critical calculations should be verified using specialized
  mathematical software or manual methods.»
  (https://support.claude.com/en/articles/10366421-how-does-claude-handle-mathematical-equations-and-calculations).
  Qui il programma che verifica è `verifica.py`, e la dashboard parte solo
  dai numeri verificati.
- **La chat senza memoria.** «To run a single chat or Cowork task without
  memory, open a new chat, click the “+” menu, and turn off "Memory."»;
  «You need to turn memory off before you send the first message. Once the
  chat starts, the setting can't be changed.»; in quella chat «Claude
  doesn't use memory in that chat, doesn’t search your past chats from
  it, and doesn’t save anything from it to memory.»; e «After you send
  your first message, a crossed-out memory icon appears next to the chat
  title.»
  (https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context).
  Una chat incognito no, dice il centro assistenza: «Incognito chats still
  work, but they open in the previous experience, so Claude can't create
  files or run code in them.»
  (https://support.claude.com/en/articles/16761823-claude-cowork-and-chat-are-one-claude).
- **L'artifact.** Il corso Claude 101 dell'Academy: «If you want to ensure
  Claude creates an artifact, just say so: "Create this as an artifact."»
  (https://academy.claude.com/courses/claude-101/creating-with-artifacts);
  il prompt del passo 6 lo chiede così, in italiano. Il supporto: «It
  opens beside your conversation, and you can edit it, come back to it,
  and share it with others.»; per cambiarlo, «Ask Claude to change the
  artifact.»; e se dà un errore, «If an artifact generates an error, look
  for the "Try fixing with Claude" button near the error message.»
  (https://support.claude.com/en/articles/17153992-what-are-artifacts-and-how-do-i-use-them).
- **La condivisione.** «Artifacts start private to you. Nothing is shared
  until you share it.»; sul Pro: «Pro and Max plans: "Only you" or "Anyone
  with the link." To give specific people access, invite them by email.»;
  e per aprirlo: «Everyone needs a Claude account. People without one
  can't open a shared artifact, even with the link. The only exception is
  a legacy artifact» (https://support.claude.com/en/articles/9547008-share-artifacts).
  Si condivide l'artifact, non la chat: «Only the artifact is shared — your
  conversation stays private.»
  (https://academy.claude.com/courses/claude-101/creating-with-artifacts).
- **Il file porta anche un testo rivolto a un assistente:** la descrizione
  di TK-2026-04268, che non ha dati personali e resta nel file anonimo. Ci
  torna il confronto che chiude il laboratorio, dopo M3-E03, con
  l'avvertimento del supporto: «It is possible for a bad actor to
  inconspicuously add instructions via external files or websites that
  trick Claude into […]»
  (https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude).

### Che cosa misura il controllo

- `tools/verifica.sh M3-E02` legge `kpi.json` (senza il blocco di codice,
  se c'è) e calcola i dieci indicatori veri dal `ticket-anonimi.csv` dello
  spazio di lavoro, lo stesso file che avete caricato, con lo script
  dell'elemento `kpi_veri.py`, mai con una copia dello spazio di lavoro.
  Controlla la forma di `kpi.json`: un oggetto JSON con esattamente le
  dieci chiavi di `kpi_definizioni.md`, ognuna con il tipo giusto (un
  intero, un numero, `per_giorno` con le sette chiavi `lun` … `dom`). È la
  forma a decidere l'uscita.
- Poi stampa, per ogni indicatore, il valore atteso, quello trovato e se
  corrisponde, con la regola di `kpi_definizioni.md`: un intero se è
  uguale, un decimale se dista dal valore vero al più mezza unità del suo
  ultimo decimale. «n KPI su 10 corrispondono» è un dato: l'affermazione
  di Anthropic non dice quanti indicatori debbano tornare, e una chat sola
  non decide un confronto.
- La dashboard si giudica a occhio: nessuno script la legge.
- La coppia registrata del corso, in Claude Code: il prompt dei numeri, con un
  primo paragrafo che dice dove sta la tabella, una volta con il CSV
  incollato nel messaggio e nessuno strumento, una volta con il file nella
  cartella di lavoro e il solo `python3` per interrogarlo, un comando alla
  volta; tutte e due su Sonnet, con l'oggetto vincolato allo schema
  dei dieci indicatori, tre esecuzioni per parte. Per ogni coppia: confermata
  se con il file e il codice tornano più indicatori, non distinguibile se
  ne tornano tanti quanti, non confermata in questa esecuzione se ne
  tornano meno; i token in entrata si stampano come dato. Le condizioni
  non sono quelle di Anthropic: dieci indicatori su 343 righe, e il
  thinking acceso, perché su Sonnet 5.5, il modello dell'alias `sonnet`,
  non si spegne: «You can't turn thinking off on Opus 5.5, Sonnet 5.5,
  Haiku 5.5, or the Fable models.»
  (https://code.claude.com/docs/en/model-config). I numeri della coppia
  sono del corso, non quelli di Anthropic. Nella registrazione del corso
  (21 ottobre 2026, Claude Code 2.1.306, Sonnet con effort low):
  incollando 9, 10 e 10 indicatori giusti su dieci, con il file e il
  codice 10, 9 e 9, cioè confermata nella prima coppia e non confermata in
  questa esecuzione nelle altre due: confermata 1 su 3. L'indicatore
  sbagliato era `voti` (107 invece di 106) incollando, `clienti_ricorrenti`
  (28 invece di 27) due volte con il file. Come dato, i token in entrata:
  da 57.142 a 206.372 per esecuzione incollando, da 29.565 a 30.247 con il
  file.
- Nella registrazione del corso in claude.ai (21 ottobre 2026, nuova
  esperienza, Sonnet 5.5, la chat con la memoria spenta): la prima
  risposta, dopo il passo «Ran 3 commands», dava 9 indicatori su 10 che
  corrispondevano, con `clienti_ricorrenti` 28 invece di 27. Detto a
  Claude con la frase del passo 5, il passo «Recheck customer counts» e
  poi 10 su 10. Un indizio: contando come cliente il campo vuoto di
  `cliente`, che ha 25 righe, si ottiene proprio 28, mentre la regola del
  prompt dice che un campo vuoto non entra nei conti. La dashboard, un
  artifact con quei numeri, si è aperta accanto alla conversazione (la sua
  scheda, nella chat, portava l'etichetta «Dashboard»); dopo
  una modifica (quattro riquadri in alto, un colore solo) i numeri erano
  gli stessi, e la condivisione è rimasta su «Only you».

## Verifica (tools/verifica.sh M3-E02)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M3-E02

Esce con 0 quando `kpi.json` c'è ed è un oggetto JSON con le dieci chiavi
e i tipi giusti, qualunque sia il numero di indicatori che corrispondono
(lo stampa come dato); con 1 quando `kpi.json` manca, non è JSON, o ha
chiavi o tipi sbagliati, e dice quali; con 2 quando non può partire, per
esempio se manca `ticket-anonimi.csv` nello spazio di lavoro. Il
riferimento di `soluzione/kpi.json` non è una risposta di claude.ai: è
calcolato da `kpi_veri.py` sulla copia di riferimento del file.

## Se qualcosa va storto

- Avete inviato il primo messaggio prima di spegnere «Memory», o accanto
  al titolo della chat non c'è l'icona della memoria barrata: aprite una
  chat nuova e ricominciate dal passo 2.
- Claude risponde senza eseguire codice, o con numeri stimati: chiedetelo
  in modo esplicito, «Calcola con il codice, sul file caricato».
- La risposta ha del testo intorno al JSON: copiate soltanto l'oggetto,
  dalla `{` alla `}`, oppure chiedete «Rispondi soltanto con l'oggetto
  JSON».
- La verifica dice che `kpi.json` ha le virgolette tipografiche “ ”:
  avete copiato la risposta selezionandone il testo nella pagina.
  Ricopiatela con il pulsante «Copy» sotto la risposta.
- La verifica dice «non è un JSON valido»: l'oggetto è stato copiato a
  metà, o con del testo in più; ricopiatelo. Dice che manca una chiave, o
  che un valore ha il tipo sbagliato (per esempio un testo `"343"` al
  posto del numero `343`): chiedete a Claude di correggere l'oggetto.
- La verifica esce con 2 perché manca `ticket-anonimi.csv`: ricopiatelo da
  M3-E01 (passo 1), oppure ripartite con `tools/reset_esercizio.sh
  M3-E02`, che rimette la copia di riferimento e cancella anche
  `kpi.json`.
- L'artifact mostra un errore: il pulsante «Try fixing with Claude»,
  vicino al messaggio d'errore. Se i numeri della dashboard non sono
  quelli di `kpi.json`, chiedete a Claude di usare esattamente quelli.
- Su Windows il browser non trova il file: vedete il passo 1.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-E02`. Cancella lo
  spazio di lavoro, non la chat né l'artifact in claude.ai.

## Impronta d'uso sul piano Pro

Una chat in claude.ai su Sonnet, il modello che l'Academy indica per il
lavoro di tutti i giorni: «Sonnet is the daily driver. … If you're not
sure which model to pick, start here.»
(https://academy.claude.com/tutorials/choosing-the-right-claude-model).
Con la memoria spenta: un file caricato di circa 100 KB e da 3 a 5
messaggi, con l'esecuzione di codice e un artifact, che pesano più di una
domanda breve: «Note that creating files
will use more of your limit compared to normal chats with Claude.»
(https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude);
«Additional factors that affect your usage limits include: … Artifact
creation and usage | Multi-step tasks, like running code, creating files,
or browsing websites»
(https://support.claude.com/en/articles/9797557-usage-limit-best-practices).
Conta anche il file: «The number of messages you can send will vary based
on message length, including the length of files you attach»
(https://support.claude.com/en/articles/8325606-what-is-the-pro-plan). I
limiti sono gli stessi di Claude Code: «These limits are shared across
Claude and Claude Code, meaning all activity in both tools counts against
the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan).
Nessuna sessione di Claude Code, nessun subagent: la verifica è uno
script. Nella registrazione del corso, sull'account del docente: quattro
messaggi (i numeri, la correzione del passo 5, la dashboard, una
modifica). La sua durata non dice quella di un partecipante: ogni passo
è stato copiato e fotografato per il corso.

## Per approfondire

- Calcolare su una tabella, incollata o caricata:
  https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- L'esecuzione di codice e i file in claude.ai:
  https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude
- Gli artifact, e come si condividono:
  https://support.claude.com/en/articles/17153992-what-are-artifacts-and-how-do-i-use-them ·
  https://support.claude.com/en/articles/9547008-share-artifacts
- La lezione sugli artifact del corso Claude 101 dell'Academy:
  https://academy.claude.com/courses/claude-101/creating-with-artifacts
- Una chat senza memoria:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
