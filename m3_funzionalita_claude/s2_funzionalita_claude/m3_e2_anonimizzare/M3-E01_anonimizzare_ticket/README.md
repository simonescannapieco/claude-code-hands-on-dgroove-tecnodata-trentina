# M3-E01 — Anonimizzare la settimana di ticket

Esercitazione del Modulo 3, nel laboratorio «Anonimizzare con Claude
Code». È la prima del laboratorio, e la prima del modulo che fate in Claude
Code: il file anonimo che produce serve a M3-E02 e a M3-E03.

## Obiettivo

Claude Code anonimizza la settimana di ticket dell'assistenza clienti di
CiaspoLink **senza mai leggere il file**: scrive `anonimizza.py` dal
dizionario delle colonne, lo esegue, esegue un controllo dei dati personali
e corregge lo script finché il controllo passa; poi scrive `profilo.py`,
che calcola gli indicatori della settimana. Il controllo conosce i dati
personali solo come impronte, e a Claude dice quanti ne restano e dove, mai
quali. Mettete alla prova la guida di Claude Code: «Give Claude a check it
can run: tests, a build, a screenshot to compare.»

## Tempo

16 minuti: uno per l'obiettivo, uno per il prompt, uno per il controllo,
dodici di lavoro, uno per la verifica.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3.8 o successivo, il comando `python3`, che
  `tools/verifica_ambiente.sh` controlla: lo usano gli script che Claude
  scrive, il controllo dei dati personali e la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M3-E01)

Lo spazio di lavoro `~/corso-claude-code/M3-E01/` con:

- `dati/ticket-settimana.csv`: la settimana di ticket, 343 segnalazioni,
  con dati personali inventati e messi apposta (nomi, telefoni, e-mail,
  indirizzi, familiari, codici, informazioni sulla salute), e
  `dati/README.md`, il dizionario delle colonne. Sono copie identiche dei
  file di `progetti/assistenza-clienti/dati/`; i comandi «Rigenerare e
  verificare» del dizionario valgono nel progetto, non qui;
- `kpi_definizioni.md`: gli indicatori del profilo, con le regole di
  calcolo e di arrotondamento; li usano anche M3-E02 e M3-E03;
- `controlla_pii.py` e `impronte.json`: il controllo dei dati personali
  che Claude esegue (sotto, «Che cosa misura il controllo»);
- `.claude/settings.json`: le impostazioni di progetto dello spazio di
  lavoro. Tengono le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e ne aggiungono quattro:
  - una regola `deny` di `Read` su `dati/ticket-settimana.csv` e su
    `anonimo/ticket-anonimi.csv`: gli strumenti di Claude per i file non li
    aprono;
  - una regola `deny` di `Edit` su `controlla_pii.py` e su `impronte.json`:
    gli strumenti con cui Claude modifica i file non cambiano il controllo
    e le sue impronte, «Edit rules apply to all built-in tools that edit
    files.» (https://code.claude.com/docs/en/permissions);
  - una regola `allow` per i tre comandi dell'esercizio, `python3
    anonimizza.py`, `python3 controlla_pii.py` (anche con `--forme`) e
    `python3 profilo.py`: Claude li esegue senza chiedervelo;
  - `defaultMode` `default`, il valore della modalità Manual, quella che
    chiede conferma per ogni azione: ogni scrittura di file e ogni comando
    fuori dai tre lo vedete e lo approvate voi (sotto, «La modalità di
    partenza»).

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`, poi aprite Claude Code su Sonnet con effort medium:

       tools/prepara_esercizio.sh M3-E01
       cd ~/corso-claude-code/M3-E01
       claude --model sonnet --effort medium

   Le due opzioni valgono per questa sessione e non restano: l'effort
   impostato con `--effort` «does not persist». Con `/model`, nella
   sessione, la scelta diventerebbe invece quella delle sessioni nuove.

2. Incollate questo prompt:

   <!-- prompt -->

       Leggi dati/README.md, il dizionario delle colonne di
       dati/ticket-settimana.csv, e kpi_definizioni.md. Non aprire
       dati/ticket-settimana.csv né anonimo/ticket-anonimi.csv e non
       stamparne il contenuto con nessun comando: contengono dati
       personali, che non devono entrare in questa conversazione.
       Esegui ogni comando da solo, uno alla volta: mai concatenato
       ad altri con && o con ;, e senza echo.

       Scrivi anonimizza.py (Python 3.8 o successivo, solo libreria
       standard): legge dati/ticket-settimana.csv e scrive
       anonimo/ticket-anonimi.csv, UTF-8 senza BOM, fine riga LF, con
       tutte le righe nell'ordine originale e queste 17 colonne in
       quest'ordine: id_ticket, aperto_il, chiuso_il, canale, cliente,
       tipo_cliente, comune, tecnologia, categoria, priorita, stato,
       oggetto, descrizione, team, minuti_prima_risposta,
       minuti_risoluzione, soddisfazione. Togli nome_cliente, telefono,
       email e id_linea. In cliente metti uno pseudonimo al posto di
       id_cliente: C-001, C-002, … in ordine di prima comparsa, lo
       stesso codice sempre con lo stesso pseudonimo, vuoto se il codice
       è vuoto. In oggetto e descrizione sostituisci con [OMESSO] ogni
       dato personale, senza cambiare il resto del testo: telefoni,
       e-mail, indirizzi, nomi di persone e di clienti, indirizzi MAC e
       IP, codici cliente e di linea, utenze PPPoE, informazioni sulla
       salute. Le altre colonne restano come sono. Eseguilo con
       python3 anonimizza.py.

       Poi esegui python3 controlla_pii.py e correggi anonimizza.py
       finché il controllo esce con 0: l'esito è nella sua ultima
       riga, «uscita: 0» oppure «uscita: 1», e si legge lì, non con
       $?. Il controllo conosce i dati personali solo come impronte:
       per ogni classe dice quanti ne restano e in quali
       segnalazioni, mai i valori; con --forme mostra la forma di
       ciascuno (lettere x, cifre 9).

       Infine scrivi profilo.py, che legge anonimo/ticket-anonimi.csv e
       scrive anonimo/profilo.json: la chiave "kpi" con gli indicatori
       di kpi_definizioni.md e, accanto, quello che trova una
       profilazione del file (campi vuoti, comuni scritti in modi
       diversi, segnalazioni doppie). Eseguilo con python3 profilo.py.

   <!-- /prompt -->

   La versione breve, quella della slide, chiede le stesse cose in meno
   parole:

       Leggi dati/README.md e kpi_definizioni.md. Non aprire né stampare
       dati/ticket-settimana.csv e anonimo/ticket-anonimi.csv.
       Esegui ogni comando da solo, mai concatenato con &&, ; o echo.
       Scrivi anonimizza.py (Python 3.8+, libreria standard): scrive
       anonimo/ticket-anonimi.csv, UTF-8, LF, tutte le righe in ordine,
       colonne id_ticket, aperto_il, chiuso_il, canale, cliente,
       tipo_cliente, comune, tecnologia, categoria, priorita, stato,
       oggetto, descrizione, team, minuti_prima_risposta,
       minuti_risoluzione, soddisfazione. Via nome_cliente, telefono,
       email, id_linea; cliente = C-001, C-002… per id_cliente, in
       ordine di prima comparsa. In oggetto e descrizione ogni dato
       personale diventa [OMESSO], il resto non cambia. Eseguilo con
       python3 anonimizza.py. Poi esegui python3 controlla_pii.py e
       correggi finché l'ultima riga dice uscita: 0; --forme mostra le
       forme, mai i valori. Poi scrivi profilo.py: anonimo/profilo.json
       con "kpi" come in kpi_definizioni.md, più campi vuoti, comuni
       scritti in più modi, doppioni. Eseguilo con python3 profilo.py.

   - **Percorso A, un vostro CSV:** un'esportazione come quelle del vostro
     lavoro, ma con dati inventati al posto di quelli veri (le regole di
     `progetti/README.md`: mai persone, aziende o sistemi reali). Mettete
     il file in `dati/`, scrivete il suo dizionario delle colonne in
     `dati/README.md`, aggiungete una regola `deny` di `Read` anche per il
     vostro CSV e, nel prompt, mettete i vostri nomi di file e di colonne
     al posto di quelli della settimana. Il controllo vuole una colonna
     `id_ticket` (senza, esce con 2) e segnala nell'intestazione le colonne
     `nome_cliente`, `telefono`, `email`, `id_linea` e `id_cliente`; le sue
     impronte sono quelle della settimana del corso, quindi sul vostro file
     controlla soltanto la forma e quelle colonne, non i vostri dati: i
     valori che avete inventato li cercate voi nel file anonimo. Anche gli
     indicatori di `profilo.py` sono quelli della settimana: per il vostro
     file chiedete a Claude i vostri, scritti in `kpi_definizioni.md`, e
     controllateli voi, perché il controllo del profilo del corso non li
     conosce. La verifica automatica è quella del percorso B: il vostro
     file non lo verifica.
   - **Percorso B, la settimana di CiaspoLink:** i file di `dati/` così
     come sono. La prova del docente e la verifica sono su questo.

3. Mentre Claude lavora, leggete le sue richieste. Prima di approvare la
   scrittura o una correzione di `anonimizza.py` e di `profilo.py`,
   leggete la modifica: i tre comandi `python3` dell'esercizio girano
   senza chiedere niente, e ciò che lo script farà lo approvate lì. Per
   le modifiche dei file, mai la risposta che non chiede più. Rispondete
   **No** a ogni comando che stamperebbe i due CSV, come un `python3 -c`
   che li apre: è lì che i dati entrerebbero nella conversazione. `cat` e
   `head` su quei due file li ferma già la regola `deny`, senza chiedere;
   un programma che apre il file da sé no (vedi «La regola `deny` è una
   guardia, non un muro», più sotto). Le regole `deny` di `Edit` fermano
   anche gli strumenti con cui Claude modificherebbe `controlla_pii.py` e
   `impronte.json`: si corregge lo script, non il controllo.
   Checkpoint: `python3 controlla_pii.py` uscito con 0, poi
   `anonimo/profilo.json` scritto.

4. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M3-E01

## Che cosa osservare

### Che cosa dice Anthropic

- **Perché Claude non apre il file.** Claude Code gira sul vostro
  computer, ma la conversazione passa dalla rete: «Claude Code runs
  locally. To interact with the LLM, Claude Code sends data over the
  network. This data includes all user prompts and model outputs»
  (https://code.claude.com/docs/en/data-usage). E resta su disco, in
  chiaro: «These files are plaintext. Anything that passes through a tool
  is written to a transcript on disk: file contents, command output,
  pasted text.», finché non diventa più vecchia di `cleanupPeriodDays`:
  «Claude Code deletes the files in the paths below once they're older
  than cleanupPeriodDays … The default is 30 days»
  (https://code.claude.com/docs/en/claude-directory). Le condizioni per i
  consumatori valgono anche in Claude Code: «These updates apply to users
  on our Claude Free, Pro, and Max plans, including when they use Claude
  Code from accounts associated with those plans.»
  (https://www.anthropic.com/news/updates-to-our-consumer-terms). Per
  questo il file lo legge lo script, sul vostro computer, e il controllo
  dice a Claude quanti dati personali restano e dove, mai quali; nella
  conversazione entra comunque ciò che Claude legge e ciò che un comando
  stampa. È la risposta giusta dell'esempio 3 della guida all'esame
  Claude Certified Associate, dove si deve caricare un foglio con nomi e
  numeri di conto dei clienti: «B. Remove or anonymize the personal
  identifiers before uploading, consistent with policy. … Sample 3: B.»
  (https://everpath-course-content.s3-accelerate.amazonaws.com/instructor%2F6nizmqk8tpzpfjvt6qmmav7rh%2Fpublic%2F1783542847%2FClaude+Certified+Associate+%E2%80%93+Foundations+Exam+Guide.pdf).
- **La regola `deny` è una guardia, non un muro.** Ferma gli strumenti di
  Claude per i file: «To block Claude’s file tools from reading a file or
  directory, add a Read deny rule for its path, such as Read(./.env) or
  Read(./secrets/)» (https://code.claude.com/docs/en/permissions), e i
  comandi di file che Claude Code riconosce: «Read and Edit deny rules
  apply to Claude's built-in file tools, to file commands Claude Code
  recognizes in Bash, such as cat, head, tail» (la stessa pagina). Vale in
  ogni modalità: «Deny rules block in every mode, including
  bypassPermissions.» (https://code.claude.com/docs/en/permission-modes).
  Ma non tutto passa di lì: «They don’t apply to a command that reads
  files without naming them, such as grep -r pattern .», né a un
  programma che apre il file da sé: «They don't apply to … arbitrary
  subprocesses that read or write files indirectly, like a Python or Node
  script that opens files itself.» (https://code.claude.com/docs/en/permissions).
  È così che `anonimizza.py` legge il CSV, ed è ciò che serve; un comando
  che lo stampa, invece, lo fermate voi, rispondendo No.
- **La modalità di partenza.** Dalla versione 2.1.283 una sessione
  interattiva parte in auto mode, dove un classificatore rivede le azioni
  al posto vostro: «With Claude Code v2.1.283 or later, auto mode is the
  built-in starting permission mode for interactive terminal and VS Code
  sessions.» Un progetto sceglie la modalità di partenza delle sue
  sessioni con `defaultMode` in `.claude/settings.json`; la documentazione
  lo mostra con plan mode: «To make plan mode the default for a project’s
  terminal sessions, set defaultMode to plan in .claude/settings.json».
  Qui il valore è `default`, cioè Manual: «The mode that reviews every
  action is named Manual in the CLI … Its config value is default»
  (https://code.claude.com/docs/en/permission-modes).
- **Il controllo che Claude esegue.** La guida di Claude Code raccomanda:
  «Give Claude a check it can run: tests, a build, a screenshot to
  compare.» Un controllo è qualsiasi segnale che Claude legge nella
  conversazione, anche uno script che confronta l'uscita con un
  riferimento: «The check is anything that returns a signal Claude can
  read in the conversation: … a script that diffs output against a
  fixture». Senza, Claude si ferma quando il lavoro sembra finito:
  «Claude stops when the work looks done. Without a check it can run,
  "looks done" is the only signal available». Con il controllo, il ciclo
  che la guida descrive, e che questo esercizio mette alla prova: «Claude
  does the work, runs the check, reads the result, and iterates until the
  check passes.» (https://code.claude.com/docs/en/best-practices).
- **Con il controllo, un risultato migliore?** I consigli d'uso di Claude
  Code: «Giving Claude a way to verify its work will markedly improve the
  quality of the final result.»
  (https://support.claude.com/en/articles/14554000-claude-code-power-user-tips).
  È un confronto: lo decide la coppia registrata del corso, sotto, non la
  vostra sessione.
- **Il file che Claude non legge porta anche un testo rivolto a un
  assistente:** la descrizione di TK-2026-04268, che non ha dati personali
  e resta nel file anonimo; ci torna il confronto che chiude il
  laboratorio, dopo M3-E03, con l'avvertimento del supporto di Anthropic:
  «It is possible for a bad actor to inconspicuously add instructions via
  external files or websites that trick Claude into»
  (https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude).

### Che cosa misura il controllo

- `controlla_pii.py` conosce i dati personali della settimana solo come
  impronte: `impronte.json` contiene, per undici classi (nomi, familiari,
  indirizzi, telefoni, e-mail, utenze PPPoE, MAC, IP, codici cliente,
  codici di linea, salute), lo SHA-256 di un sale più la forma
  normalizzata di ogni valore, mai i valori, e allo stesso modo le parti
  dei nomi di persona (ogni parola di almeno tre lettere di nomi e
  cognomi). Cerca in ogni cella del file i candidati di ogni classe, li
  normalizza allo stesso modo e ne confronta l'impronta. Per ultimo cerca
  i nomi rimasti a metà: una parola con l'iniziale maiuscola accanto a un
  `[OMESSO]`, con soltanto spazi in mezzo, che è il nome o il cognome di
  una persona della settimana, come in «Nome [OMESSO]» o «[OMESSO]
  Cognome», conta come un dato rimasto. Stampa per classe quanti ne
  restano e in quali segnalazioni; con `--forme` anche la colonna e la
  forma di ciascuno: lettere x o X, cifre 9, il resto com'è, per esempio
  `+99 999 999 9999`. Esce con 0 se non resta niente, con 1 se resta
  qualcosa o se l'intestazione ha ancora una colonna da togliere, con 2
  se non può girare (il file manca, o non è un CSV con la colonna
  `id_ticket`). L'esito lo scrive anche nella sua ultima riga, per esempio
  `uscita: 0 (nessun dato personale rimasto)` o `uscita: 1 (restano dati
  personali: vedi sopra)`: chi lo esegue lo legge lì, con il comando da
  solo, senza `echo $?`. L'intestazione del file spiega le classi e le
  forme.
- Ogni esecuzione aggiunge una riga a `anonimo/controlli.log`: l'ora UTC,
  l'uscita, i residui. La scrive il controllo ogni volta che gira,
  chiunque lo esegua: dice quante volte il controllo ha girato e come è
  uscito, non chi l'ha eseguito.
- `tools/verifica.sh M3-E01` non si fida delle copie dello spazio di
  lavoro, che Claude può cambiare: ricalcola i dati personali rimasti con
  il controllo originale dell'elemento, nomi a metà compresi, e il profilo
  con i suoi indicatori veri. Poi stampa due dati che non decidono
  l'uscita. Per trovarli, il controllo originale cerca i dati del corso
  nel testo grezzo e la verifica allinea il testo anonimo con quello
  grezzo: i dati del corso rimasti in parte, cioè con un pezzo fuori dagli
  `[OMESSO]` (il tipo di via o il numero civico di un indirizzo, il
  dominio di un'e-mail: da guardare; un nome rimasto a metà è già un
  residuo del controllo), e le omissioni che non coprono nessun dato del
  corso, cioè testo tolto senza che ce ne fosse bisogno. Stampa anche, come
  dato, le esecuzioni registrate in `anonimo/controlli.log` e se il
  `controlla_pii.py` dello spazio di lavoro è diverso dall'originale, e
  sul ciclo della guida non dà un esito: il registro lo scrive il
  controllo a ogni esecuzione, e che l'abbia eseguito Claude lo dicono le
  sue chiamate nella sessione, non il registro.
- La coppia del docente, con e senza il controllo: lo stesso prompt senza
  il paragrafo «Poi esegui python3 controlla_pii.py …», in uno spazio di
  lavoro senza `controlla_pii.py` né `impronte.json`, contro il prompt
  intero; per ogni sessione, il file anonimo misurato con il controllo
  originale: prima la forma giusta del file, poi meno dati personali
  rimasti. Confermata se il file con il controllo è migliore, non
  distinguibile se sono uguali, non confermata in questa esecuzione se è
  peggiore; se un file manca, la coppia non decide. Nella registrazione
  del corso (21 ottobre 2026, Claude Code 2.1.306, Sonnet con effort
  medium, tre coppie) le sessioni sono `claude -p` in modalità `dontAsk`,
  che «denies every call that would otherwise prompt»
  (https://code.claude.com/docs/en/headless): nessuna approvazione, e ciò
  che la chiederebbe è negato. Con il
  controllo, 0 dati personali rimasti in tutte e tre le sessioni; senza,
  2, 9 e 6, nomi e informazioni sulla salute. Confermata 3 su 3. Il ciclo
  della guida, dalle chiamate di ogni sessione con il controllo: il
  controllo eseguito 4, 5 e 4 volte, l'ultima con uscita 0; confermata 3
  su 3. In nessuna delle sei sessioni una chiamata di strumento ha
  nominato il file grezzo, se non per eseguire gli script dell'esercizio.

## Verifica (tools/verifica.sh M3-E01)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M3-E01

Controlla il file anonimo (UTF-8 senza BOM, fine riga LF; le 17 colonne
nell'ordine; le 343 righe nell'ordine originale, con le stesse segnalazioni
per giorno; le colonne che restano come sono; gli pseudonimi di
`cliente`; in `oggetto` e `descrizione` il testo originale con `[OMESSO]`
al posto di qualche tratto e nient'altro di cambiato), i dati personali
rimasti (devono essere 0, nomi a metà compresi) e la chiave `kpi` di
`anonimo/profilo.json`, chiave per chiave, con la regola di
`kpi_definizioni.md`: stampa per ogni indicatore il valore atteso, quello
trovato e se va bene. Stampa anche, come dato: quante `[OMESSO]` ci sono e
quanta parte del testo resta; i dati del corso rimasti in parte, per
classe, e le omissioni senza un dato del corso; le esecuzioni del
controllo registrate, senza un esito sul ciclo della guida. Esce con 0 se
il file, i dati personali rimasti e il profilo sono quelli attesi, con 1
se qualcosa manca o non torna (e dice che cosa), con 2 se non può
partire.

## Se qualcosa va storto

- `python3 controlla_pii.py` esce con 2 perché manca
  `anonimo/ticket-anonimi.csv`: `anonimizza.py` non l'ha ancora scritto, o
  lo scrive altrove. Esce con 2 anche se il file non è un CSV regolare,
  per esempio un campo con una virgola senza virgolette: il modulo `csv`
  di Python le mette da sé.
- Claude concatena i comandi, con `&&` o `;`, o aggiunge un `echo $?` per
  leggere l'uscita: chiedetegli di eseguire ogni comando da solo, come
  dice il prompt. L'esito del controllo è nella sua ultima riga.
- Claude dice che non può leggere il file: è la regola `deny` che
  funziona. Ricordategli che il dizionario è `dati/README.md` e che il
  controllo dice classi, segnalazioni e forme.
- Claude prova a cambiare `controlla_pii.py` o `impronte.json` e la regola
  `deny` di `Edit` ferma lo strumento: si corregge `anonimizza.py`, non il
  controllo.
- Il controllo trova un residuo di `nomi` e `--forme` mostra una parola
  sola, come `Xxxxx`: è un nome rimasto a metà, il nome o il cognome
  accanto a un `[OMESSO]`. Va sostituito il nome intero.
- La verifica stampa dati del corso rimasti in parte, o omissioni senza
  un dato del corso: non la fanno fallire, ma guardate se lo script toglie
  solo un pezzo di un indirizzo o di un'e-mail, o testo che non è un dato
  personale.
- Il controllo continua a trovare la stessa classe: chiedete a Claude di
  guardare le forme con `--forme` e le segnalazioni elencate, e di rendere
  la regola più generale invece di aggiungere un caso alla volta.
- La verifica dice che un testo non è l'originale con `[OMESSO]`: lo
  script ha cambiato anche altro (spazi, maiuscole, un'altra parola al
  posto di `[OMESSO]`). Si sostituisce il dato personale, e il resto del
  testo resta com'è.
- La verifica dice che una colonna è cambiata: lo script ha corretto
  qualcosa, per esempio i comuni scritti in modi diversi. Le colonne che
  non si anonimizzano restano come sono; le scritture diverse vanno nel
  profilo, non nel file.
- La verifica dice che un indicatore non torna: confrontatelo con
  `kpi_definizioni.md` (la mediana con un numero pari di valori, gli
  arrotondamenti, le sette chiavi di `per_giorno`).
- Le richieste di permesso sono troppe: per un comando che torna, la
  risposta che non chiede più salva la regola nello spazio di lavoro,
  «Claude Code saves the rule to .claude/settings.local.json at the root
  of the git repository» (https://code.claude.com/docs/en/permissions).
  Mai per un comando che legge i due CSV, né per le modifiche dei file.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-E01`.

## Impronta d'uso sul piano Pro

Una sessione interattiva su Sonnet, effort medium: un messaggio con il
prompt e, se serve, qualche richiesta in più; nessun subagent. Il
controllo dei dati personali e la verifica sono
script, senza chiamate al modello. I limiti sono gli stessi di claude.ai:
«These limits are shared across Claude and Claude Code, meaning all
activity in both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan),
e fra ciò che pesa ci sono il modello e l'effort: «Additional factors that
affect your usage limits include: … Tool usage (e.g., Research, web
search) | Model choice | Effort level»
(https://support.claude.com/en/articles/9797557-usage-limit-best-practices).
Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,
Sonnet con effort medium, sull'account del docente, `claude -p` senza
approvazioni, il prompt in un solo messaggio), le tre sessioni con il
controllo: 20, 34 e 24 turni (`num_turns`) in 150,1, 131,4 e 119,4
secondi; nel JSON delle risposte, token in entrata 32, 42 e 34, scritti
in cache 24.254, 42.831 e 28.742, letti dalla cache 436.082, 853.480 e
507.090, in uscita 11.816, 15.808 e 14.867. Alla fine, `/exit`.

## Per approfondire

- Le best practice di Claude Code:
  https://code.claude.com/docs/en/best-practices
- I consigli d'uso di Claude Code del supporto:
  https://support.claude.com/en/articles/14554000-claude-code-power-user-tips
- Che cosa Claude Code invia e conserva:
  https://code.claude.com/docs/en/data-usage ·
  https://code.claude.com/docs/en/claude-directory
- Le regole di permesso e le modalità:
  https://code.claude.com/docs/en/permissions ·
  https://code.claude.com/docs/en/permission-modes
