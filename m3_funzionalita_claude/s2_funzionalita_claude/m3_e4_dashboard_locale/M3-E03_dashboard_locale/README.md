# M3-E03 — La stessa dashboard in Claude Code

Esercitazione del Modulo 3, nel laboratorio, dopo M3-E02: la stessa
dashboard della settimana, fatta questa volta in Claude Code come pagina
HTML locale, con un controllo che Claude esegue da sé. Parte dai file che
produce M3-E01.

## Obiettivo

Claude Code scrive `genera_dashboard.py`, che legge il file anonimo della
settimana **senza che Claude lo legga**, ne calcola gli indicatori e scrive
`dashboard.html`: un file solo, che si apre nel browser senza rete. Poi
Claude esegue un controllo che confronta i numeri della pagina con il
profilo di M3-E01, e corregge lo script finché il controllo passa. Mettete
alla prova la guida di Claude Code: «Give Claude a check it can run:
tests, a build, a screenshot to compare.» Alla fine, il confronto con la
dashboard di M3-E02.

## Tempo

12 minuti: uno per l'obiettivo, uno per il prompt e il controllo, nove di
lavoro, uno per la verifica.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3.8 o successivo, il comando `python3`: lo usano lo script che
  Claude scrive, il controllo e la verifica.
- Un browser, per aprire la pagina.
- M3-E01 fatto, con `tools/verifica.sh M3-E01` uscito con 0, per usare il
  vostro file anonimo e il vostro profilo. Altrimenti si usano le copie di
  riferimento di questo elemento.

## Punto di partenza (tools/prepara_esercizio.sh M3-E03)

Lo spazio di lavoro `~/corso-claude-code/M3-E03/` con:

- `anonimo/ticket-anonimi.csv` e `anonimo/profilo.json`: il file anonimo
  della settimana e il suo profilo, nelle stesse cartelle di M3-E01. Sono
  le copie di riferimento, uguali a quelle che produce la soluzione di
  M3-E01; chi ha fatto M3-E01 e l'ha visto passare la verifica le
  sostituisce con le proprie (passo 1);
- `kpi_definizioni.md`: i dieci indicatori, con le regole di calcolo e di
  arrotondamento, gli stessi di M3-E01 e di M3-E02;
- `controlla_dashboard.py`: il controllo che Claude esegue (sotto, «Che
  cosa misura il controllo»);
- `.claude/settings.json`: le impostazioni di progetto dello spazio di
  lavoro. Tengono le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e ne aggiungono quattro:
  - una regola `deny` di `Read` su `anonimo/ticket-anonimi.csv`: gli
    strumenti di Claude per i file non lo aprono, perché la pagina la
    costruisce lo script e i dati non devono passare dal modello;
  - una regola `deny` di `Edit` su `controlla_dashboard.py`: gli
    strumenti con cui Claude modifica i file non cambiano il controllo,
    «Edit rules apply to all built-in tools that edit files.»
    (https://code.claude.com/docs/en/permissions);
  - una regola `allow` per i due comandi dell'esercizio, `python3
    genera_dashboard.py` e `python3 controlla_dashboard.py` (anche con il
    nome della pagina): Claude li esegue senza chiedervelo;
  - `defaultMode` `default`, il valore della modalità Manual, quella che
    chiede conferma per ogni azione: ogni scrittura di file e ogni comando
    fuori dai due lo vedete e lo approvate voi.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`; se `tools/verifica.sh M3-E01` è uscito con 0, copiate i
   vostri due file al posto delle copie di riferimento (tutti e due, perché
   il profilo è quello del vostro file), altrimenti tenete quelle; poi
   aprite Claude Code su Sonnet con effort medium:

       tools/prepara_esercizio.sh M3-E03
       cd ~/corso-claude-code/M3-E03
       cp ~/corso-claude-code/M3-E01/anonimo/{ticket-anonimi.csv,profilo.json} anonimo/
       claude --model sonnet --effort medium

   Le due opzioni valgono per questa sessione e non restano: l'effort
   impostato con `--effort` «does not persist».

2. Incollate questo prompt:

   <!-- prompt -->

       Leggi kpi_definizioni.md. Non aprire anonimo/ticket-anonimi.csv e
       non stamparne il contenuto con nessun comando: lo legge lo script.

       Scrivi genera_dashboard.py (Python 3.8 o successivo, solo libreria
       standard): legge anonimo/ticket-anonimi.csv, calcola i dieci
       indicatori di kpi_definizioni.md con le sue regole e scrive
       dashboard.html, la dashboard della settimana. Un file solo, che si
       apre senza rete: CSS e grafici dentro la pagina, per esempio barre
       in SVG, e niente da fuori, né script, né fogli di stile, né font,
       né immagini. I numeri sono scritti nel testo della pagina, non
       generati da JavaScript, e tutti e dieci gli indicatori stanno
       anche in un blocco <script type="application/json" id="kpi">, con
       le chiavi di kpi_definizioni.md. Eseguilo con
       python3 genera_dashboard.py.

       Poi esegui python3 controlla_dashboard.py e correggi
       genera_dashboard.py finché il controllo esce con 0: confronta i
       numeri del blocco kpi con anonimo/profilo.json e cerca nella
       pagina ciò che arriverebbe da fuori. Esegui ogni comando da solo,
       senza concatenarlo ad altri, e leggi l'uscita del controllo nella
       sua ultima riga.

   <!-- /prompt -->

   La versione breve, quella della slide, chiede le stesse cose in meno
   parole:

       Leggi kpi_definizioni.md. Non aprire né stampare
       anonimo/ticket-anonimi.csv: lo legge lo script.
       Scrivi genera_dashboard.py (Python 3.8+, libreria standard):
       legge anonimo/ticket-anonimi.csv, calcola gli indicatori di
       kpi_definizioni.md e scrive dashboard.html. Un file solo, che si
       apre senza rete: CSS e barre SVG nella pagina, niente da fuori.
       I numeri scritti nel testo della pagina e, tutti e dieci, anche in
       <script type="application/json" id="kpi">, con le chiavi di
       kpi_definizioni.md. Eseguilo con python3 genera_dashboard.py.
       Poi esegui python3 controlla_dashboard.py e correggi finché esce
       0. Ogni comando da solo, senza concatenarlo ad altri: l'uscita del
       controllo è nella sua ultima riga.

   - **Percorso A, un vostro CSV anonimo:** il file con dati inventati che
     avete anonimizzato nel percorso A di M3-E01, in `anonimo/`, con i
     vostri indicatori scritti in `kpi_definizioni.md` e i loro valori
     nella chiave `kpi` di `anonimo/profilo.json`. Il controllo confronta
     il blocco `kpi` della pagina con le chiavi del vostro profilo, quali
     che siano: il ciclo con il controllo vale anche per voi. Il resto del
     prompt vale com'è,
     con i vostri indicatori al posto dei dieci della settimana. La
     verifica automatica è quella del percorso B: il vostro file non lo
     verifica.
   - **Percorso B, la settimana di CiaspoLink:** i file di `anonimo/` della
     settimana, i vostri di M3-E01 o le copie di riferimento. La prova del
     docente e la verifica sono su questo.

3. Mentre Claude lavora, leggete le sue richieste. Prima di approvare la
   scrittura o una correzione di `genera_dashboard.py`, leggete la
   modifica: i due comandi `python3` dell'esercizio girano senza chiedere
   niente, e ciò che lo script farà lo approvate lì. Per le modifiche dei
   file, mai la risposta che non chiede più. Rispondete **No** a ogni
   comando che stamperebbe il file anonimo, come un `python3 -c` che lo
   apre; `cat` e `head` li ferma già la regola `deny`, senza chiedere:
   «Read and Edit deny rules apply to Claude's built-in file tools, to
   file commands Claude Code recognizes in Bash, such as cat, head, tail»
   (https://code.claude.com/docs/en/permissions). La regola `deny` di
   `Edit` ferma anche gli strumenti con cui Claude modificherebbe
   `controlla_dashboard.py`: si corregge lo script, non il controllo. Se
   Claude vi chiede di approvare una riga che unisce più comandi (con
   `&&`, `;` o un `echo $?` in coda), rispondete No e chiedetegli di
   eseguirne uno per volta, come dice il prompt: l'uscita del controllo è
   nella sua ultima riga. Checkpoint: l'ultima riga del controllo dice
   `uscita: 0`.

4. Aprite `dashboard.html` nel browser, dallo spazio di lavoro: su Linux
   `xdg-open dashboard.html`; su Windows con WSL 2 `explorer.exe .`, che
   apre la cartella in Esplora file, e poi un doppio clic sulla pagina.
   Confrontatela con la dashboard di M3-E02.

5. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M3-E03

## Che cosa osservare

### Che cosa dice Anthropic

- **Il controllo che Claude esegue.** La guida di Claude Code: «Give
  Claude a check it can run: tests, a build, a screenshot to compare.» Il
  controllo è qualunque segnale che Claude legge nella conversazione,
  anche uno script che confronta il risultato con un riferimento: «The
  check is anything that returns a signal Claude can read in the
  conversation: … a script that diffs output against a fixture». Qui il
  riferimento è `anonimo/profilo.json`, il profilo che ha scritto
  M3-E01. Senza un controllo: «Claude stops when the work looks done.
  Without a check it can run, "looks done" is the only signal available».
  Con il controllo, il ciclo che l'esercizio mette alla prova: «Claude
  does the work, runs the check, reads the result, and iterates until the
  check passes.» (https://code.claude.com/docs/en/best-practices).
- **Perché Claude non apre il file.** Claude Code gira sul vostro
  computer, ma la conversazione passa dalla rete: «Claude Code runs
  locally. To interact with the LLM, Claude Code sends data over the
  network. This data includes all user prompts and model outputs»
  (https://code.claude.com/docs/en/data-usage). Il file lo legge lo
  script, sul vostro computer; nella conversazione entra ciò che Claude
  legge e ciò che un comando stampa: le definizioni, il codice e l'uscita
  del controllo, che porta gli indicatori, non le righe del file.
- **La regola `deny` è una guardia, non un muro.** «To block Claude’s file
  tools from reading a file or directory, add a Read deny rule for its
  path, such as Read(./.env) or Read(./secrets/)»
  (https://code.claude.com/docs/en/permissions), e vale in ogni modalità:
  «Deny rules block in every mode, including bypassPermissions.»
  (https://code.claude.com/docs/en/permission-modes). Ma non ferma un
  programma che apre il file da sé, ed è proprio ciò che fa
  `genera_dashboard.py`; e non ferma un comando che legge i file senza
  nominarli: «They don’t apply to a command that reads files without
  naming them, such as grep -r pattern .»
  (https://code.claude.com/docs/en/permissions). Un comando che stampa il
  file lo fermate voi, rispondendo No.
- **La modalità di partenza.** «With Claude Code v2.1.283 or later, auto
  mode is the built-in starting permission mode for interactive terminal
  and VS Code sessions.» Un progetto sceglie la modalità di partenza con
  `defaultMode` in `.claude/settings.json`: «To make plan mode the default
  for a project’s terminal sessions, set defaultMode to plan in
  .claude/settings.json». Qui il valore è `default`, cioè Manual: «The
  mode that reviews every action is named Manual in the CLI … Its config
  value is default» (https://code.claude.com/docs/en/permission-modes).

### Che cosa misura il controllo

- `controlla_dashboard.py` legge la pagina con il modulo `html.parser`
  della libreria standard e vi cerca **un solo** blocco
  `<script type="application/json" id="kpi">`. Il riferimento è la chiave
  `kpi` di `anonimo/profilo.json`, con le chiavi che ha, le dieci della
  settimana o le vostre: il blocco deve avere le stesse chiavi, ciascuna
  con il valore giusto secondo la regola di `kpi_definizioni.md`, e il
  controllo stampa per ogni indicatore il valore atteso, quello trovato e
  se va bene. Poi cerca ciò che la pagina caricherebbe da fuori: script,
  fogli di stile, font o immagini dalla rete (`http:`, `https:`, `//`), o
  da un altro file accanto alla pagina, e uno script scritto nella pagina
  che chiama la rete (`fetch(`, `import(`, `XMLHttpRequest`, `WebSocket`,
  `EventSource`, `sendBeacon` o un indirizzo `http://` o `https://`).
  L'ultima riga dice sempre l'uscita, con il suo significato: `uscita: 0`
  i numeri sono quelli del profilo e la pagina non carica niente da fuori;
  `uscita: 1` almeno una differenza; `uscita: 2` il controllo non può
  girare (manca la pagina o il profilo). Ogni esecuzione aggiunge una riga
  a `controlli_dashboard.log`: l'ora UTC, l'uscita, le differenze. La
  scrive il controllo ogni volta che gira, chiunque lo esegua: dice quante
  volte ha girato e come è uscito, non chi l'ha eseguito.
- `tools/verifica.sh M3-E03` non si fida degli script dello spazio di
  lavoro, che Claude può cambiare: ricalcola gli indicatori veri dal file
  anonimo con lo script dell'elemento `kpi_veri.py`, e legge la pagina
  con la copia originale del controllo, senza scrivere nel registro.
  Stampa anche, come dato: se i numeri singoli (segnalazioni, aperte,
  annullate, mediana, voti, soddisfazione media, clienti ricorrenti)
  compaiono nel testo della pagina, con il punto o la virgola; se
  `genera_dashboard.py` c'è; le esecuzioni registrate in
  `controlli_dashboard.log` e se il `controlla_dashboard.py` dello spazio
  di lavoro è diverso dall'originale. Sul ciclo della guida non dà un
  esito: il registro lo scrive il controllo a ogni esecuzione, e che
  l'abbia eseguito Claude lo dicono le sue chiamate nella sessione, non il
  registro.
- Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,
  Sonnet con effort medium, tre sessioni, il prompt in un solo messaggio)
  le sessioni sono `claude -p` in modalità `dontAsk`, che «denies every
  call that would otherwise prompt … though a mod you installed can still
  approve some of those calls»
  (https://code.claude.com/docs/en/headless): nessuna approvazione a
  mano, e ciò che la chiederebbe è negato, salvo ciò che una mod
  installata può ancora approvare. In tutte e tre la verifica è uscita
  con 0: i dieci indicatori del blocco `kpi` quelli veri, i sette numeri
  singoli nel testo della pagina, niente da fuori. Il ciclo della guida,
  dalle chiamate di ogni sessione: il controllo eseguito una, due e una
  volta, l'ultima con uscita 0; confermata 3 su 3.

### Il confronto con M3-E02

Tre domande per il confronto, sui fatti dei due prodotti, non su chi ha
lavorato meglio:

- **Chi la apre?** L'artifact di M3-E02 si apre con un account Claude:
  «Everyone needs a Claude account. People without one can't open a
  shared artifact, even with the link. The only exception is a legacy
  artifact» (https://support.claude.com/en/articles/9547008-share-artifacts).
  La pagina di M3-E03 è un file: si apre in qualunque browser, da
  chiunque lo riceva.
- **Dove sono andati i dati?** In M3-E02 il file intero è stato caricato:
  «The content you submit to the Services through these interactions,
  including … content you choose to upload … are your “Inputs”.»
  (https://www.anthropic.com/legal/privacy). In M3-E03 il file è rimasto
  sul vostro computer, ma ciò che Claude Code ha letto e scritto è
  passato dalla rete, come dice la prima citazione qui sopra.
- **E la settimana prossima?** In claude.ai, una chat nuova con il file
  nuovo; qui `python3 genera_dashboard.py` sul file nuovo, e il controllo
  per accorgersi se qualcosa non torna.

## Verifica (tools/verifica.sh M3-E03)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M3-E03

Controlla che `dashboard.html` ci sia, che il suo blocco `kpi` abbia i
dieci indicatori veri, ricalcolati dal file anonimo, con la regola di
`kpi_definizioni.md`, e che la pagina non carichi niente dalla rete né da
altri file, nemmeno con uno script scritto nella pagina. Stampa per ogni
indicatore il valore atteso, quello trovato e
se va bene, e poi i dati descritti sopra. Esce con 0 se la pagina, i suoi
numeri e l'assenza di risorse esterne sono quelli attesi; con 1 se
qualcosa manca o non torna (e dice che cosa); con 2 se non può partire,
per esempio se manca il file anonimo.

## Se qualcosa va storto

- `python3 controlla_dashboard.py` esce con 2 perché manca
  `dashboard.html`: `genera_dashboard.py` non l'ha ancora scritta, o la
  scrive altrove. Esce con 2 anche se manca `anonimo/profilo.json`:
  ricopiatelo da M3-E01, o ripartite.
- Il controllo dice «dalla rete»: la pagina prende una libreria per i
  grafici o un font da internet. Chiedete a Claude di disegnare le barre
  in SVG dentro la pagina e di usare i font del sistema. Se dice
  «`<script>` nella pagina», uno script della pagina chiama la rete: i
  numeri li scrive nella pagina `genera_dashboard.py`, senza JavaScript
  che li vada a prendere. Dice «da un altro file»: il CSS o il JavaScript
  stanno in file a parte; vanno dentro la pagina.
- Il controllo dice che un indicatore non torna: confrontatelo con
  `kpi_definizioni.md` (la data di `aperto_il` così come è scritta, la
  mediana con un numero pari di valori, gli arrotondamenti, le sette
  chiavi di `per_giorno`).
- Il controllo passa e la verifica no, perché i KPI del blocco `kpi` non
  tornano: il controllo confronta la pagina con il vostro
  `anonimo/profilo.json`, e quel profilo non è giusto. Ripartite con le
  copie di riferimento: `tools/reset_esercizio.sh M3-E03`.
- Claude prova a cambiare `controlla_dashboard.py` e la regola `deny` di
  `Edit` ferma lo strumento: si corregge `genera_dashboard.py`, non il
  controllo.
- Claude vi chiede di approvare una riga che unisce uno dei due comandi
  ad altri, per esempio con `&&` o con un `echo $?` in coda: rispondete
  No e chiedetegli di eseguire un comando per volta e di leggere l'uscita
  nell'ultima riga del controllo.
- Claude dice che non può leggere il file anonimo: è la regola `deny` che
  funziona. Ricordategli che il file lo legge lo script, e che le colonne
  che servono sono quelle di `kpi_definizioni.md`.
- Le richieste di permesso sono troppe: per un comando che torna, la
  risposta che non chiede più salva la regola nello spazio di lavoro,
  «Claude Code saves the rule to .claude/settings.local.json at the root
  of the git repository» (https://code.claude.com/docs/en/permissions).
  Mai per un comando che stampa il file anonimo, né per le modifiche dei
  file.
- La verifica dice «no» per qualche numero nel testo della pagina: è un
  dato, non fa fallire la verifica. Di solito il numero è scritto in
  un'altra forma, o lo genera JavaScript.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-E03`.

## Impronta d'uso sul piano Pro

Una sessione interattiva su Sonnet, effort medium: un messaggio con il
prompt e, se serve, qualche richiesta in più; nessun subagent. Il
controllo e la verifica sono script, senza chiamate al
modello. I limiti sono gli stessi di claude.ai: «These limits are shared
across Claude and Claude Code, meaning all activity in both tools counts
against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan),
e fra ciò che pesa ci sono il modello e l'effort: «Additional factors that
affect your usage limits include: … Tool usage (e.g., Research, web
search) | Model choice | Effort level»
(https://support.claude.com/en/articles/9797557-usage-limit-best-practices).
Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,
Sonnet con effort medium, sull'account del docente, `claude -p` senza
approvazioni, il prompt in un solo messaggio), le tre sessioni: 8, 10 e 8
turni (`num_turns`) in 35,6, 50,3 e 38,7 secondi; nel JSON delle
risposte, token in entrata 12, 18 e 14, scritti in cache 24.868, 16.745 e
25.718, letti dalla cache 150.297, 203.525 e 190.896, in uscita 4.907,
5.623 e 5.778. Alla fine, `/exit`.

## Per approfondire

- Le best practice di Claude Code, con il controllo che Claude esegue:
  https://code.claude.com/docs/en/best-practices
- Che cosa Claude Code invia in rete:
  https://code.claude.com/docs/en/data-usage
- Le regole di permesso e le modalità:
  https://code.claude.com/docs/en/permissions ·
  https://code.claude.com/docs/en/permission-modes
- Chi apre un artifact condiviso:
  https://support.claude.com/en/articles/9547008-share-artifacts
