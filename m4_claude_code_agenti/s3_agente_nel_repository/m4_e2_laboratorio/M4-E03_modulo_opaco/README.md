# M4-E03 — Un modulo opaco: documentarlo e proporre il refactoring

Laboratorio del Modulo 4, traccia (b), in due parti. Un modulo del vecchio
gestionale di CiaspoLink che nessuno vuole toccare: Claude Code lo fa
mappare da due subagent, lo documenta, ne fissa il comportamento con i
test e propone come rifattorizzarlo a piccoli passi, senza cambiarne una
riga.

## Obiettivo

`legacy/chiusura_mese.inc.php` del gestionale fa la chiusura di fine
mese: una funzione sola, `chiusura_mese()`, di 278 righe (dalla 24 alla
301), con sei compiti in fila, variabili globali, numeri scritti nel
codice, nomi in due lingue, un blocco commentato e, in testa, l'avvertenza
«non spezzare in piu funzioni». Alla fine avete:

- `progetti/gestionale-php/docs/chiusura_mese.md`, la documentazione del
  modulo, con sei sezioni fisse;
- i test di caratterizzazione, in PHPUnit, che fissano ciò che la
  chiusura fa adesso: verdi sul modulo così com'è, rossi su una copia che
  la verifica rompe apposta;
- `PROPOSTA.md`, il refactoring proposto in passi numerati, ciascuno con
  il controllo che prova che il comportamento non cambia.

Il modulo non si modifica: lo protegge una regola `deny` delle
impostazioni. Mettete alla prova ciò che Anthropic dice dei subagent per
le ricerche ampie, della documentazione, del refactoring a piccoli passi
e del «giudice» che va validato (sotto, «Che cosa osservare»).

## Tempo

87 minuti, in due parti. Prima parte, 52 minuti: 6 per la presentazione
delle tre tracce; 44 di lavoro, 4 per preparare lo spazio di lavoro, 10
per la mappa con i due subagent, 23 per la documentazione e i test, 7 per
rileggere e per la nota; 2 per chiudere la parte, con il commit della
nota. Seconda parte, 35 minuti: 2 per ciò che resta, traccia per
traccia; 33 di lavoro, circa 13 per riprendere dalla nota, 15 per la
proposta in plan mode, 5 per la verifica.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- Docker, oppure PHP 8.3 o successivo con Composer: `tools/php.sh` sceglie
  da sé (`progetti/gestionale-php/README.md`). La prima installazione
  delle dipendenze scarica PHPUnit da internet.
- git, per un commit a ogni passo.
- Le parti del modulo su permessi e plan mode (M4-D04, «Tre gradini, tre
  garanzie») e sui subagent (M4-D06, «Delegare la lettura») spiegano gli
  strumenti che qui si usano.

## Punto di partenza (tools/prepara_esercizio.sh M4-E03)

Lo spazio di lavoro `~/corso-claude-code/M4-E03/` con:

- `progetti/gestionale-php/`: il gestionale, senza il materiale del
  docente. Il modulo è `legacy/chiusura_mese.inc.php` e lo lancia
  `bin/chiusura-mese.php`; le regole del team stanno in
  `docs/convenzioni.md` (la sezione 9 sul codice legacy, la 10 sui test);
- `tools/php.sh`: la copia dello script del repository che esegue PHP,
  Composer e PHPUnit, anche con Docker;
- `.claude/settings.json`, le impostazioni di progetto. Tengono le regole
  prudenti del repository (`.env`, `secrets/`, chiavi) e aggiungono:
  - una regola `deny` di `Edit(/progetti/gestionale-php/legacy/**)`: gli
    strumenti con cui Claude modifica i file non toccano il codice
    legacy, «Edit rules apply to all built-in tools that edit files.»
    (https://code.claude.com/docs/en/permissions);
  - una regola `deny` di `Edit(/tools/php.sh)`: lo script dei test non
    si cambia;
  - una regola `allow` per il comando dei test, `tools/php.sh php
    progetti/gestionale-php/vendor/bin/phpunit …`: «Allow rules let
    Claude Code use the specified tool without manual approval.» (stessa
    pagina);
  - `defaultMode` `default`, cioè Manual: ogni altra scrittura e ogni
    altro comando che non è di sola lettura li vedete e li approvate voi;
    i comandi di sola lettura, di regola, girano senza chiedere
    (https://code.claude.com/docs/en/permissions). «The mode that reviews
    every action is named Manual in the CLI … Its config value is
    default» (https://code.claude.com/docs/en/permission-modes);
  - `plansDirectory` `piani`: i piani di plan mode finiscono in `piani/`
    dello spazio di lavoro, «Choose where Claude Code stores the plan
    files it writes in plan mode. Claude Code resolves the path relative
    to the project root.»
    (https://code.claude.com/docs/en/settings-reference).

La regola `allow` vale dopo che avete dato fiducia alla cartella, le
regole `deny` subito: «permissions.allow rules,
permissions.additionalDirectories, extraKnownMarketplaces, and most env
values apply only after each teammate trusts the folder … deny and ask
rules apply right away» (https://code.claude.com/docs/en/settings).

Le due regole `deny` aggiunte cominciano con `/`. Nella pagina sui
permessi: «`path` or `./path` | Path relative to current directory |
`Read(*.env)` | `<cwd>/*.env`» e «`/path` | Path relative to the settings
source | `Edit(/src/**/*.ts)` | `<primary working directory>/src/**/*.ts`
in project settings» (https://code.claude.com/docs/en/permissions):
senza la barra il percorso vale rispetto alla cartella corrente, con la
barra rispetto allo spazio di lavoro. Nelle prove del corso di M4-D04,
dopo un `cd` una regola senza la barra non ha più coperto il suo file,
quella con la barra sì.

Dalla cartella `esercitazioni` si prepara lo spazio di lavoro, ci si entra
e, una volta sola, si installano le dipendenze del gestionale (PHPUnit):

    tools/prepara_esercizio.sh M4-E03
    cd ~/corso-claude-code/M4-E03
    tools/php.sh composer install -d progetti/gestionale-php

## Passi in Claude Code

### Prima parte

1. Aprite Claude Code nello spazio di lavoro, su Sonnet con effort
   medium:

       claude --model sonnet --effort medium

   Le due opzioni valgono per questa sessione: l'effort impostato con
   `--effort` «does not persist»
   (https://code.claude.com/docs/en/cli-reference).

   Alla prima apertura Claude Code vi chiede se vi fidate della cartella:
   «In an interactive session, Claude Code shows the workspace trust
   dialog when you start it in a folder you haven't trusted.»
   (https://code.claude.com/docs/en/security). Rispondete sì: la regola
   `allow` del comando dei test vale soltanto dopo (il paragrafo sulla
   fiducia, nel «Punto di partenza»). La prova del corso, fatta con
   `claude -p` e senza quella domanda, a ogni chiamata ha scritto
   «Ignoring 1 permissions.allow entry from .claude/settings.json: this
   workspace has not been trusted».

2. **La mappa, con due subagent.** Incollate:

   <!-- prompt 1 -->

       Usa due subagent Explore in parallelo, nello stesso messaggio, per
       mappare progetti/gestionale-php/legacy/chiusura_mese.inc.php senza
       leggere tu tutto il progetto:
       (a) chi chiama chiusura_mese() nel progetto e come: file e riga, chi
       la chiama, con quali argomenti e opzioni;
       (b) quali tabelle del database la funzione legge e quali scrive,
       anche attraverso le funzioni del legacy che chiama.
       Ciascuno risponda con un riassunto breve in questo formato, al
       massimo 12 righe:
       (a) una riga per chiamata: «file:riga | chi chiama | argomenti e
       opzioni»;
       (b) una riga per tabella: «tabella | legge, scrive o tutti e due |
       dove: riga o funzione».
       Poi mostrami i due riassunti così come sono.

   <!-- /prompt 1 -->

   Traguardo: due subagent Explore lavorano insieme e tornano due
   riassunti nel formato chiesto. Se Claude legge da sé invece di
   delegare, chiedeteglielo di nuovo: delegare lo decide lui (sotto,
   «Che cosa osservare»).

3. **La documentazione.** Incollate:

   <!-- prompt 2 -->

       Scrivi la documentazione di chiusura_mese() in
       progetti/gestionale-php/docs/chiusura_mese.md, in italiano, dai due
       riassunti e dal codice del modulo, con queste sezioni, in
       quest'ordine, come titoli «## »: Che cosa fa · Ingressi e uscite ·
       Tabelle lette e scritte · Effetti collaterali · Le sei
       responsabilità · Rischi.
       Descrivi che cosa fa il codice così com'è, senza giudicarlo e senza
       proporre correzioni: le proposte vengono dopo. In «Tabelle lette e
       scritte» tutte le tabelle del riassunto (b), ciascuna con il suo nome
       nel database; in «Le sei responsabilità» una voce per ciascuna,
       nell'ordine in cui la funzione le esegue, con le righe del file.
       Non modificare niente in progetti/gestionale-php/legacy/. Alla fine
       rileggi il file e controlla che abbia le sei sezioni, in
       quell'ordine, ognuna con il suo testo. Poi fai il commit del file,
       con un messaggio come quelli della regola 11.1 di
       progetti/gestionale-php/docs/convenzioni.md, un comando per volta.

   <!-- /prompt 2 -->

   Traguardo: il file ha le sei sezioni e un commit lo contiene
   (`git log --oneline`).

4. **I test di caratterizzazione.** Incollate:

   <!-- prompt 3 -->

       Scrivi i test di caratterizzazione di chiusura_mese() in
       progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php, con
       PHPUnit, come i test che il progetto ha già (sezioni 9 e 10 di
       progetti/gestionale-php/docs/convenzioni.md). Un test di
       caratterizzazione fissa ciò che il codice fa adesso, anche dove
       sembra strano: se un test non passa, si corregge il test, non il
       modulo.
       I test girano su un database di prova con pochi dati scritti dal
       test e passano sempre la data di riferimento nelle opzioni, come
       progetti/gestionale-php/bin/chiusura-mese.php. Eseguono la chiusura
       vera, senza simulazione, e controllano che cosa scrive nel database:
       le fatture che diventano scadute, i clienti e le linee sospesi e
       riattivati, le note di credito degli indennizzi con le righe e gli
       importi; e che cosa restituisce. In più un test in simulazione.
       Esegui i test con questo comando, da solo, senza concatenarlo ad
       altri, e correggi i test finché passano:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php
       Non modificare niente in progetti/gestionale-php/legacy/. Poi fai il
       commit del test, un comando per volta.

   <!-- /prompt 3 -->

   Il comando dei test gira senza chiedervelo, per la regola `allow`;
   le modifiche dei file le approvate voi. Se Claude prova a cambiare il
   modulo, la regola `deny` lo ferma: si corregge il test. Traguardo:
   l'ultima riga di PHPUnit dice `OK`.

5. **Prima di chiudere la prima parte.** Incollate:

   <!-- prompt 4 -->

       Scrivi NOTA.md nella radice dello spazio di lavoro: che cosa è
       fatto, che cosa resta per la seconda parte (la proposta di
       refactoring, in plan mode) e i comandi per riprendere e per
       eseguire i test. Poi fai il commit di NOTA.md, un comando per volta.

   <!-- /prompt 4 -->

   Poi uscite con `/exit`.

### Seconda parte

6. Si riparte dalla nota, in una sessione nuova: «Sessions are
   independent. Each new session starts with a fresh context window,
   without the conversation history from previous sessions.»
   (https://code.claude.com/docs/en/how-claude-code-works). Partite dalla
   cartella `esercitazioni`, come nel punto di partenza: in un terminale
   nuovo, `cd ~/esercitazioni` se avete clonato il repository nella
   cartella di casa, come chiede `PRIMA_DEL_CORSO.md` in WSL 2, altrimenti
   il suo percorso. Poi entrate nello spazio di lavoro e aprite Claude
   Code:

       cd ~/corso-claude-code/M4-E03
       claude --model sonnet --effort medium

   In alternativa `claude --continue` riprende la conversazione della
   prima parte: «This resumes the most recent session in the current
   directory» (https://code.claude.com/docs/en/common-workflows); dopo
   un'interruzione lunga, sul piano Pro, può comparire una richiesta di
   conferma: «On Pro and Max plans, the dialog can appear when you resume
   a long conversation after a long break or on a different model.»
   (https://code.claude.com/docs/en/sessions).

7. **La proposta, in plan mode.** Entrate in plan mode: «Enter plan mode
   by pressing Shift+Tab or prefixing a single prompt with /plan.»
   (https://code.claude.com/docs/en/permission-modes). Con Shift+Tab le
   modalità girano così: «From auto, the first press switches to default,
   and the cycle then runs default → acceptEdits → plan.» (stessa
   pagina); oppure scrivete `/plan` e uno spazio davanti al prompt.
   Incollate:

   <!-- prompt 5 -->

       Leggi NOTA.md, progetti/gestionale-php/docs/chiusura_mese.md e
       progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php.
       Proponi il refactoring di chiusura_mese() in passi piccoli, ciascuno
       con lo stesso comportamento e con il controllo che lo prova: i test
       di caratterizzazione. Tieni conto delle regole del team sul codice
       legacy (sezione 9 di progetti/gestionale-php/docs/convenzioni.md),
       del commento del modulo «non spezzare in piu funzioni» e di chi
       chiama la funzione. Il codice legacy non si modifica: la proposta lo
       descrive soltanto.
       Il piano è il contenuto di PROPOSTA.md, nella radice dello spazio di
       lavoro, in questo formato: un titolo «## Passo N — titolo» per
       passo, numerati da 1, almeno tre; per ogni passo che cosa cambia e
       perché, in poche righe; e una riga «Controllo: » con il comando dei
       test da eseguire dopo il passo e che cosa deve dire.
       Quando approvo il piano, scrivi PROPOSTA.md, esegui una volta il
       controllo del primo passo, da solo, e fai il commit di PROPOSTA.md,
       un comando per volta.

   <!-- /prompt 5 -->

   Claude esplora, scrive il piano in `piani/` e ve lo presenta. In plan
   mode non modifica niente finché non approvate: «Plan mode tells Claude
   to research and propose changes without making them. … edits stay
   blocked until you approve the plan.»
   (https://code.claude.com/docs/en/permission-modes). Leggete il piano:
   se un passo non ha il suo controllo, o tocca il modulo, chiedete di
   cambiarlo; poi approvatelo. Traguardo: `PROPOSTA.md` c'è, il
   controllo del passo 1 è verde, un commit la contiene.

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate. `~/esercitazioni` è la cartella in cui `PRIMA_DEL_CORSO.md`
   fa clonare il repository in WSL 2; se l'avete clonato altrove, usate il
   suo percorso:

       cd ~/esercitazioni
       tools/verifica.sh M4-E03

## Che cosa osservare

### Che cosa dice Anthropic

- **Un subagent per una ricerca ampia.** Nella pagina «Best practices
  for Claude Code»: «Broad codebase searches go to the built-in Explore
  agent.» Fra i casi in cui un subagent ripaga: «Keeping long output,
  like a full test run or a wide search, out of your main conversation».
  E per spendere meno: «Ask for short summaries back, so twenty results
  don't fill your context anyway.»
  (https://code.claude.com/docs/en/best-practices). Explore ha soltanto
  strumenti di lettura, «Tools: read-only tools; Write and Edit are
  denied»; lo si chiede per nome e decide Claude, «Natural language: name
  the subagent in your prompt; Claude decides whether to delegate»; due
  ricerche indipendenti vanno bene insieme: «Each subagent explores its
  area independently, then Claude synthesizes the findings. This works
  best when the research paths don't depend on each other.»
  (https://code.claude.com/docs/en/sub-agents). Il tool che lancia un
  subagent si chiama Agent: «In version 2.1.63, the Task tool was
  renamed to Agent.» (stessa pagina).
- **La documentazione.** Nella pagina «Common workflows» la ricetta parte
  dal codice senza documentazione e finisce con un controllo: «find
  functions without proper JSDoc comments in the auth module…check if the
  documentation follows our project standards»
  (https://code.claude.com/docs/en/common-workflows). Qui lo standard
  sono le sei sezioni fisse: le controlla Claude alla fine del prompt 2,
  poi la verifica.
- **Il refactoring.** Nella stessa pagina: «refactor utils.js to use
  ES2024 features while maintaining the same behavior…Do refactoring in
  small, testable increments». La proposta è fatta di passi piccoli,
  ciascuno con il suo controllo.
- **Il giudice, validato.** Nell'articolo di Anthropic sulle migrazioni
  del codice con Claude Code: «Run it against the original code to
  confirm it passes. Then run it against deliberately broken code to
  confirm it fails» (https://claude.com/resources/articles/ai-code-migration).
  I test di caratterizzazione sono il giudice del refactoring: la
  verifica li esegue sul modulo com'è e su una copia rotta apposta.
- **Il legacy non si tocca.** Il plugin di Anthropic per modernizzare il
  codice: «Nothing edits your legacy source.…Start with one module or one
  unit as a pilot, not the whole estate.»
  (https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-modernization).
  Qui il modulo pilota è uno, e lo protegge la regola `deny`: «Deny rules
  block in every mode, including bypassPermissions.»
  (https://code.claude.com/docs/en/permission-modes); le regole le fa
  rispettare Claude Code, non il modello: «Permission rules are enforced
  by Claude Code, not by the model.»
  (https://code.claude.com/docs/en/permissions).

Un limite da sapere: la regola copre gli strumenti di Claude Code e i
comandi di file che riconosce, «Read and Edit deny rules apply to
Claude's built-in file tools, to file commands Claude Code recognizes in
Bash, such as cat, head, tail»; per un blocco del sistema operativo serve
il sandbox, «For OS-level enforcement that blocks all processes from
accessing a path, enable the sandbox»
(https://code.claude.com/docs/en/permissions). Per questo la verifica
controlla anche, con git, che `legacy/` sia rimasto com'era.

### Che cosa misura il controllo

- **La documentazione:** `progetti/gestionale-php/docs/chiusura_mese.md`
  ha le sei sezioni, come titoli `## ` (anche numerati), nell'ordine del
  prompt 2, ognuna con il suo testo; «Tabelle lette e scritte» nomina
  ogni tabella che la chiusura legge o scrive, anche attraverso le
  funzioni del legacy che chiama (la verifica le conosce e dice quali
  mancano); «Le sei responsabilità» ha almeno sei voci, in elenco o come
  titoli `### `.
- **La proposta:** `PROPOSTA.md` ha almeno tre passi `## Passo N`,
  numerati 1, 2, 3, …; ogni passo ha la sua riga `Controllo:` e il
  controllo esegue i test (`phpunit`).
- **I test di caratterizzazione:** i file `*Test.php` nuovi o cambiati
  sotto `progetti/gestionale-php/tests/` rispetto al primo commit. La
  verifica non li esegue nello spazio di lavoro: copia il progetto in una
  cartella temporanea, con `legacy/` com'era nel primo commit, e lì i test
  devono passare; poi in una seconda copia cambia una riga del modulo, la
  29, in `$simula = true;`, così la chiusura vera non scrive più niente,
  come in simulazione, e lì i test devono fallire. È la prova del
  giudice: un test che passa anche sulla copia rotta non fissa ciò che la
  chiusura scrive nel database. PHP gira con `tools/php.sh` del
  repository, non con la copia dello spazio di lavoro.
- **Il modulo legacy:** `progetti/gestionale-php/legacy/` uguale al primo
  commit: un file cambiato, nel commit o fuori, o un file nuovo è una
  segnalazione, qualunque cosa l'abbia cambiato.
- **Come dati, mai come esito:** se la regola `deny` è ancora nelle
  impostazioni; se c'è `NOTA.md`; i piani in `piani/`; i commit dopo il
  primo; e, dalle trascrizioni delle sessioni di Claude Code di questo
  spazio di lavoro, le chiamate al tool Agent con il tipo di
  subagent, quante sono partite nello stesso messaggio, le trascrizioni
  dei subagent, i piani presentati per l'approvazione e le chiamate di
  Edit o Write su `legacy/`, quelle che la regola `deny` ferma. Le
  trascrizioni stanno sul vostro computer: «By default, Claude Code
  stores transcripts as JSONL at
  ~/.claude/projects/<project>/<session-id>.jsonl»
  (https://code.claude.com/docs/en/sessions); quelle dei subagent in
  `subagents/`, «Each transcript is stored as agent-{agentId}.jsonl.»
  (https://code.claude.com/docs/en/sub-agents). Ma il loro formato non è
  un'interfaccia: «The entry format is internal to Claude Code and
  changes between versions, so scripts that parse these files directly
  can break on any release.» (https://code.claude.com/docs/en/sessions).
  Per questo i subagent si contano e si stampano, e non decidono
  l'uscita: delegare lo decide Claude.
- **La prova del docente:** `_docente/live.sh` rifà i passi con
  `claude -p`, su Sonnet con effort medium e senza server MCP: i prompt
  1–4 in una sessione, ripresa a ogni turno con `--resume`; poi, in una
  sessione nuova, il prompt 5 in plan mode e il messaggio «Il piano è
  approvato: procedi come dice il piano.», al posto dell'approvazione che
  voi date con un clic. Poi lancia la verifica, come fareste voi: se dice
  «Non ancora», un turno in più passa a Claude quelle righe e gli chiede
  di sistemarle, una volta sola; poi la verifica di nuovo. Consente Read,
  Write, Edit, il comando dei test, `git add` e `git commit`; in modalità
  `dontAsk` il resto che chiederebbe un permesso viene negato:
  «Auto-denies every call that would otherwise prompt»
  (https://code.claude.com/docs/en/permissions). Il JSON di ogni
  chiamata resta fuori dallo spazio di lavoro, accanto, in
  `M4-E03.prova_dal_vivo/`: la sessione della seconda parte non lo vede,
  come nel vostro spazio di lavoro.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `_docente/live.sh` sull'account del docente, con il JSON
di ogni chiamata fuori dallo spazio di lavoro): dopo i prompt la verifica
ha detto «Non ancora», perché i controlli dei passi 5–7 di `PROPOSTA.md`
non eseguivano i test; il turno in più con quelle righe li ha sistemati.
Poi «VERIFICA OK»: le sei sezioni, le 9 tabelle e sei responsabilità; 8
passi, ognuno con il suo controllo; `legacy/` com'era; i test verdi sul
codice originale, «OK (14 tests, 31 assertions)», e rossi sulla copia
rotta, «Tests: 14, Assertions: 21, Failures: 10.». Come dati: la regola
`deny` c'era; nessun piano in `piani/`; 5 commit; 2 sessioni; «chiamate
Agent: 2 (Explore 2); nello stesso messaggio: 2», con 2 trascrizioni di
subagent; nessun `ExitPlanMode`; nessuna chiamata di Edit o Write su
`legacy/`.

## Verifica (tools/verifica.sh M4-E03)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M4-E03

Esce con 0 quando la documentazione e la proposta sono complete, i test di
caratterizzazione passano sul modulo com'era e falliscono sulla copia
rotta, e `legacy/` è com'era; l'ultima riga è allora «Fatto:
documentazione e proposta complete, i test fissano il comportamento e
legacy/ è com'era.». Esce con 1 se qualcosa manca o non torna, e lo dice
riga per riga, «Non ancora: …». Esce con 2 se non può partire, per
esempio se mancano le dipendenze del gestionale o PHP non parte. Non
scrive niente nello spazio di lavoro.

## Se qualcosa va storto

- `tools/php.sh composer install` non riesce: Docker non è avviato
  (`docker info` deve rispondere), oppure manca la rete per scaricare
  PHPUnit la prima volta.
- La verifica esce con 2 e dice che manca `vendor/bin/phpunit`: eseguite
  il comando del punto di partenza, `tools/php.sh composer install -d
  progetti/gestionale-php`, dalla radice dello spazio di lavoro.
- PHPUnit dice che un test «printed output»: la chiusura stampa
  l'avanzamento se l'opzione `verbose` non è falsa, e il progetto fa
  fallire i test che stampano (`phpunit.xml.dist`). Chiedete a Claude di
  passare `'verbose' => false`.
- I test si fermano senza il riepilogo di PHPUnit: una query del legacy è
  fallita e il modulo ha chiuso il processo. Di solito al database di
  prova manca un dato che la query cerca.
- La verifica dice che i test passano anche sulla copia rotta: i test non
  controllano ciò che la chiusura vera scrive nel database. Chiedete un
  test che esegue la chiusura senza simulazione e legge le tabelle.
- La verifica dice «Non ancora» per la proposta o la documentazione:
  incollate a Claude quelle righe, seguite da «Sistema questi punti, un
  comando per volta, senza modificare niente in
  progetti/gestionale-php/legacy/, e fai il commit di ciò che cambi.»,
  poi verificate di nuovo. Nella prova del corso è servito per i
  controlli dei passi di `PROPOSTA.md` che non eseguivano i test.
- La verifica dice che `legacy/` è cambiato: guardate che cosa con
  `git diff $(git rev-list --max-parents=0 HEAD) --
  progetti/gestionale-php/legacy`, e riportatelo com'era con
  `git checkout $(git rev-list --max-parents=0 HEAD) --
  progetti/gestionale-php/legacy`; un file nuovo lì dentro si cancella a
  mano.
- Claude prova a modificare il modulo e la regola `deny` lo ferma: è la
  regola che funziona. Si corregge il test, non il modulo.
- Claude chiede di approvare una riga che unisce più comandi (`&&`, `;`):
  rispondete No e chiedetegli di eseguirne uno per volta.
- `git commit` si ferma con «Please tell me who you are»: git non sa chi
  firma i commit. Dallo spazio di lavoro, una volta: `git config
  user.name "Partecipante"` e `git config user.email
  partecipante@example.org`.
- Claude non lancia i subagent: delegare lo decide lui. Chiedeteglielo di
  nuovo, nominando i due subagent Explore.
- Non trovate plan mode: premete Shift+Tab fino a plan mode, con il ciclo
  del passo 7, oppure scrivete `/plan` davanti al prompt.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-E03`.

## Impronta d'uso sul piano Pro

Una sessione per parte, su Sonnet con effort medium: nella prova del
corso 64 turni del modello in tutto, 28 soltanto per i test (sotto). Due
subagent Explore nella prima parte, che usano il modello della
conversazione principale, «Model: the main conversation's model»
(https://code.claude.com/docs/en/sub-agents), e costano soprattutto
token: «What they cost you is mostly tokens, since every subagent sends
its own requests and they count against the same usage as your main
conversation.» (https://code.claude.com/docs/en/best-practices). Plan
mode nella seconda parte. I test e la verifica girano senza chiamate al
modello. I limiti sono quelli di claude.ai: «These limits are shared
across Claude and Claude Code, meaning all activity in both tools counts
against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan).
`/usage` mostra quanto pesano i subagent: «On Pro, Max, Team, and
Enterprise it breaks your usage down by skill, subagent, plugin, and MCP
server.» (https://code.claude.com/docs/en/best-practices). Alla fine di
ogni parte, `/exit`.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `claude -p` sull'account del docente), dal JSON di ogni
chiamata: sette chiamate, i cinque prompt, l'approvazione del piano e il
turno in più per sistemare la proposta, con 1, 10, 28, 4, 10, 5 e 6
turni del modello (`num_turns`); 11,1, 69,4, 183,9, 24,1, 106,6, 47,7 e
19,3 secondi; token in entrata della conversazione principale, cache
compresa, 21.555, 269.773, 1.190.420, 359.040, 200.884, 317.660 e
265.139. Nella prima chiamata i due subagent Explore portano il totale di
tutti i modelli a 193.122 token in entrata.

## Per approfondire

- «Best practices for Claude Code», quando un subagent ripaga e quanto
  costa: https://code.claude.com/docs/en/best-practices
- «Common workflows», la documentazione e il refactoring:
  https://code.claude.com/docs/en/common-workflows
- «Create custom subagents», Explore e gli altri subagent:
  https://code.claude.com/docs/en/sub-agents
- «Choose a permission mode», plan mode e le regole `deny`:
  https://code.claude.com/docs/en/permission-modes
- L'articolo di Anthropic sulle migrazioni del codice con Claude Code, con
  il giudice da validare:
  https://claude.com/resources/articles/ai-code-migration
- Il plugin di Anthropic per modernizzare il codice legacy:
  https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-modernization
- Il video di Anthropic «Claude Code modernizes a legacy COBOL codebase»:
  https://www.youtube.com/watch?v=OwMu0pyYZBc
- Anthropic Academy, «Introduction to subagents»:
  https://academy.claude.com/courses/introduction-to-subagents
