# M4-E01 — Un file mai visto

Esercitazione del Modulo 4, il riscaldamento del laboratorio: un file del
gestionale che non avete mai aperto, spiegato da Claude Code in dieci righe
e messo alla prova con un test del suo caso limite, eseguito davvero. Il
docente lo fa per primo, sullo schermo condiviso; poi lo ripetete voi, nel
vostro spazio di lavoro.

## Obiettivo

Il file è `src/Copertura/VerificaCopertura.php` del gestionale di
CiaspoLink: dice se un indirizzo è coperto, e con quale tecnologia. Con tre
prompt Claude Code:

1. ve lo spiega in dieci righe al massimo, dice chi lo chiama e scrive la
   spiegazione in `spiegazione.md`;
2. aggiunge un test per il caso limite in cui la copertura diventa
   disponibile proprio il giorno della verifica, e lo esegue;
3. vi mostra il comando che ha eseguito e il suo output.

Mettete alla prova una frase della documentazione di Claude Code: quando
scrive test, Claude guarda quelli che il progetto ha già. Il prompt del
test chiede che cosa provare, non come scriverlo: se il test somiglia agli
altri del progetto, lo decide la verifica, sul file.

## Tempo

20 minuti: 2 per l'esercizio e le frasi di Anthropic, 4 per la prova del
docente, 8 per la vostra, 3 per guardare la sessione e verificare, 3 per
il confronto a voce.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- Docker, oppure PHP 8.3 o successivo con Composer: i test del gestionale
  girano con `tools/php.sh` (`PRIMA_DEL_CORSO.md`, «Docker, oppure PHP e
  Composer»).
- Python 3.8 o successivo, il comando `python3`: lo usa la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M4-E01)

Lo spazio di lavoro `~/corso-claude-code/M4-E01/` con:

- `progetti/gestionale-php/`: il gestionale, con i suoi test PHPUnit in
  `tests/` e le regole del team in `docs/convenzioni.md`;
- `tools/php.sh`: una copia di `tools/php.sh` del repository, così i
  comandi di questo esercizio, e quelli del README del gestionale
  (`../../tools/php.sh …` dalla sua cartella), funzionano anche qui;
- `.claude/settings.json`: le impostazioni di progetto dello spazio di
  lavoro. Tengono le regole prudenti del repository (`.env`, `secrets/`,
  chiavi) e ne aggiungono tre:
  - una regola `allow` per il comando dei test,
    `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit`, con i
    suoi argomenti: Claude lo esegue senza chiedervelo;
  - una regola `deny` di `Edit` su `tools/php.sh`, `Edit(/tools/php.sh)`:
    «Edit rules apply to all built-in tools that edit files.»
    (https://code.claude.com/docs/en/permissions); si scrive il test, non
    si cambia lo strumento che lo esegue;
  - `defaultMode` `default`, la modalità Manual: «The mode that reviews
    every action is named Manual in the CLI … Its config value is
    default» (https://code.claude.com/docs/en/permission-modes). Ogni
    scrittura e ogni comando che non è di sola lettura, fuori da quello
    dei test, li vedete e li approvate voi; i comandi di sola lettura, di
    regola, girano senza chiedere (sotto, «Tre cose da guardare, e una
    quarta»).

La regola `deny` comincia con `/`. Nella pagina sui permessi: «`path` or
`./path` | Path relative to current directory | `Read(*.env)` |
`<cwd>/*.env`» e «`/path` | Path relative to the settings source |
`Edit(/src/**/*.ts)` | `<primary working directory>/src/**/*.ts` in
project settings» (https://code.claude.com/docs/en/permissions): senza la
barra il percorso vale rispetto alla cartella corrente, con la barra
rispetto allo spazio di lavoro. Nelle prove del corso di M4-D04, dopo un
`cd` una regola senza la barra non ha più coperto il suo file, quella con
la barra sì.

## Passi in Claude Code

1. Il docente fa i passi da 2 a 5 per primo; voi guardate le tre cose di
   «Che cosa osservare». Poi tocca a voi, dalla cartella `esercitazioni`:
   preparate lo spazio di lavoro, entrateci, installate le dipendenze del
   gestionale (PHPUnit e PHP_CodeSniffer; con Docker, la prima volta
   `tools/php.sh` scarica le immagini) e aprite Claude Code su Sonnet con
   effort medium:

       tools/prepara_esercizio.sh M4-E01
       cd ~/corso-claude-code/M4-E01
       tools/php.sh composer install -d progetti/gestionale-php
       claude --model sonnet --effort medium

   Le due opzioni valgono per questa sessione e non restano: l'effort
   impostato con `--effort` «does not persist»
   (https://code.claude.com/docs/en/cli-reference).

   Alla prima apertura Claude Code vi chiede se vi fidate della cartella:
   «In an interactive session, Claude Code shows the workspace trust
   dialog when you start it in a folder you haven't trusted.»
   (https://code.claude.com/docs/en/security). Rispondete sì: la regola
   `allow` del comando dei test vale soltanto dopo, «permissions.allow
   rules, permissions.additionalDirectories, extraKnownMarketplaces, and
   most env values apply only after each teammate trusts the folder …
   deny and ask rules apply right away»
   (https://code.claude.com/docs/en/settings), e da lì «Allow rules let
   Claude Code use the specified tool without manual approval.»
   (https://code.claude.com/docs/en/permissions). La prova del corso,
   fatta con `claude -p` e senza quella domanda, a ogni chiamata ha
   scritto «Ignoring 1 permissions.allow entry from .claude/settings.json:
   this workspace has not been trusted».

2. La spiegazione. Incollate:

   <!-- prompt 1 -->

       Spiegami in dieci righe al massimo che cosa fa
       progetti/gestionale-php/src/Copertura/VerificaCopertura.php e chi lo
       chiama nel progetto. Poi scrivi la stessa spiegazione in
       spiegazione.md, nella cartella in cui siamo, non dentro il progetto.

   <!-- /prompt 1 -->

   Prima di approvare la scrittura di `spiegazione.md`, leggetela: è giusta?
   Aprite il file e controllate almeno una frase.

3. Il test del caso limite. Incollate:

   <!-- prompt 2 -->

       Aggiungi un test per il caso limite in cui la copertura diventa
       disponibile proprio il giorno della verifica: disponibile_dal uguale
       al giorno controllato, e l'indirizzo deve risultare coperto. Poi
       esegui il test con questo comando, seguito dal percorso del file di
       test, da solo, senza concatenarlo ad altri:
       tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php

   <!-- /prompt 2 -->

   Leggete il test prima di approvarne la scrittura. Il comando dei test
   gira senza chiedervi niente: lo consente la regola `allow`. Se Claude vi
   chiede di approvare una modifica di `VerificaCopertura.php`, rispondete
   **No**: l'esercizio chiede un test, non una regola diversa.

4. Le prove. Incollate:

   <!-- prompt 3 -->

       Mostrami il comando che hai eseguito e il suo output.

   <!-- /prompt 3 -->

   Confrontate l'output che vi mostra con quello che avete visto passare
   nella sessione.

5. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M4-E01

## Che cosa osservare

### Che cosa dice Anthropic

- **I test che ci sono già.** La guida dei flussi di lavoro di Claude
  Code: «Claude examines your existing test files to match the style,
  frameworks, and assertion patterns already in use.»
  (https://code.claude.com/docs/en/common-workflows). Il prompt del test
  non dice come scriverlo: è la frase che la verifica mette alla prova,
  sul file che vi resta.
- **Legge prima di scrivere.** «Claude starts every task by reading your
  code, and current models are very good at this.»
  (https://code.claude.com/docs/en/best-practices)
- **Esegue invece di dire «dovrebbe funzionare».** «Claude stops when
  the work looks done.» e «If it has nothing to run that tells it whether
  the work actually is done, "looks done" is all it has to go on.»
  (https://code.claude.com/docs/en/best-practices). Qui il controllo c'è:
  il comando dei test.
- **Le prove.** «Whichever option you use, ask Claude for evidence: the
  command it ran and its output, or the screenshot.» e, subito dopo, «"All
  tests pass" on its own tells you very little»
  (https://code.claude.com/docs/en/best-practices). È il prompt 3.
- **L'agente non firma.** Da Anthropic, sugli agenti che scrivono codice:
  «whereas automated testing helps verify functionality, human review
  remains crucial for ensuring solutions align with broader system
  requirements.» (https://www.anthropic.com/research/building-effective-agents).
  La spiegazione e il test li firmate voi, dopo averli letti.

### Tre cose da guardare, e una quarta

- **Legge prima di scrivere:** prima del test, apre `VerificaCopertura.php`
  e i test che ci sono, per esempio
  `tests/Integrazione/VerificaCoperturaTest.php`? Su macOS, Linux e WSL
  Claude Code lascia Glob e Grep fuori dagli strumenti predefiniti, e
  cerca dentro Bash: «Claude searches with find and grep through the Bash
  tool instead.» (https://code.claude.com/docs/en/tools-reference). Quei
  comandi, di regola, non vi chiedono permesso, perché sono fra quelli di
  sola lettura: «Claude Code recognizes a built-in set of Bash commands as
  read-only and runs them without a permission prompt in every mode,
  except as permissions.blockReadsOutsideWorkingDirectories changes for
  paths outside your working directories. The set includes ls, cat, echo,
  pwd, head, tail, grep, find, wc, which, diff, stat, du, cd, and
  read-only forms of git.» (https://code.claude.com/docs/en/permissions).
- **Esegue il test:** nella sessione c'è il comando con il suo output, non
  un «dovrebbe funzionare».
- **Chiede prima di toccare una regola:** se il test non passa, Claude
  corregge il test o vi propone di cambiare la regola di
  `VerificaCopertura.php`? Una regola del dominio la decidete voi.
- **La quarta:** la spiegazione è utile solo se qualcuno la verifica.
  Confrontatela con il codice.

### Che cosa misura la verifica

- `tools/verifica.sh M4-E01` legge lo spazio di lavoro con git, a partire
  dal suo primo commit: conta anche il lavoro che avete già messo in un
  commit. Cerca `spiegazione.md` non vuoto, ne stampa le righe e non le
  giudica: la spiegazione la legge una persona.
- Cerca i file di test nuovi o cambiati sotto
  `progetti/gestionale-php/tests/`, con almeno un metodo di test nuovo, e
  li esegue con `tools/php.sh` del repository, non con la copia dello
  spazio di lavoro.
- Controlla, una riga per ciascuna, le convenzioni dei test che il
  progetto ha già: `declare(strict_types=1)`; il namespace
  `CiaspoLink\Gestionale\Tests\…` che rispecchia la cartella; `final class
  …Test extends TestCase`; le asserzioni scritte `self::assert…`, come in
  tutti gli altri test; i metodi nuovi `public function testInCamelCase():
  void`, nomi che si leggono come frasi (regola 10.3 di
  `docs/convenzioni.md`); il database dei test di integrazione,
  `DatabaseDiProva`, usato da `tests/Integrazione` (regola 10.1). Se
  valgono tutte, la frase della guida è «confermata» per questo file;
  altrimenti «non confermata in questa esecuzione». È un esito sul
  comportamento di Claude in questa sessione, non decide l'uscita. Come
  dato stampa anche se il test fissa la data invece di usare quella del
  computer (regola 10.4).
- Come dato, non come uscita: in una copia del gestionale al primo commit,
  con «`<=`» cambiato in «`<`» nella riga di `VerificaCopertura.php` che
  confronta `disponibile_dal` con il giorno, esegue il vostro test e dice
  se cade. Se cade, il test prova davvero il caso limite; è una prova che
  la verifica costruisce da sé, sul vostro test. Prima esegue il test
  sulla stessa copia senza la modifica: se lì non passa, per esempio
  perché è verde solo con un file di `src/` cambiato, il dato è «non
  provato».
- Come dato, i file cambiati fuori da `tests/` e da `spiegazione.md`.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `_docente/live.sh` sull'account del docente, tre volte
in tre spazi di lavoro nuovi, con la regola scritta allora senza la barra
iniziale, equivalente dalla radice dello spazio di lavoro): in tutte e
tre Claude ha aggiunto il test a
`tests/Integrazione/VerificaCoperturaTest.php`, con ogni convenzione
«sì», e la frase della guida è stata «confermata» sul file, 3 su 3. Il
test è passato, «OK (6 tests, 19 assertions)», «OK (7 tests, 21
assertions)» e «OK (6 tests, 19 assertions)». Come dati, in tutte e tre:
il test cade con il confine spostato di un giorno; nessun file cambiato
fuori da `tests/` e da `spiegazione.md`; `spiegazione.md` di 13, 12 e 12
righe non vuote, dove il prompt ne chiedeva al massimo dieci.

## Verifica (tools/verifica.sh M4-E01)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M4-E01

Esce con 0 se `spiegazione.md` c'è e non è vuoto e un test nuovo, o un
test cambiato con almeno un metodo nuovo, passa; con 1 se qualcosa manca o
il test non passa (e dice che cosa); con 2 se non può partire, per esempio
se mancano le dipendenze del gestionale.

## Se qualcosa va storto

- `tools/php.sh composer install` si ferma con «servono PHP >= 8.3 o
  Docker» o con «il demone Docker non risponde»: rivedete
  `PRIMA_DEL_CORSO.md`, «Docker, oppure PHP e Composer».
- La verifica esce con 2 e dice che mancano le dipendenze del gestionale:
  dalla cartella dello spazio di lavoro,
  `tools/php.sh composer install -d progetti/gestionale-php`.
- Claude esegue `tools/php.sh phpunit` dalla cartella dello spazio di
  lavoro e riceve «vendor/bin/phpunit non trovato»: ricordategli il
  comando del prompt, che funziona da qui.
- Claude vi chiede di approvare una riga che unisce più comandi, per
  esempio con `cd … &&`: rispondete **No** e chiedetegli un comando per
  volta, quello del prompt. Una regola `allow` non copre una riga
  composta: «Claude Code is aware of shell operators, so a rule like
  Bash(safe-cmd *) won't give it permission to run the command safe-cmd
  && other-cmd.» (https://code.claude.com/docs/en/permissions)
- Il test non passa: leggete l'output con Claude. Il test deve usare un
  indirizzo e una data dei dati di esempio: il giorno da cui ogni civico è
  coperto è la colonna `disponibile_dal` di
  `progetti/gestionale-php/database/dati/02_rete.sql`.
- Claude vuole cambiare `VerificaCopertura.php` per far passare il test:
  rispondete **No**. Se l'avete approvato, la verifica lo elenca fra i
  file cambiati fuori da `tests/`; `git diff` mostra che cosa è cambiato.
- La verifica dice che il test non cade con il confine spostato: il test
  passa, ma non prova il giorno stesso. Chiedete a Claude di usare come
  giorno della verifica proprio la data di `disponibile_dal`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-E01`.

## Impronta d'uso sul piano Pro

Una sessione interattiva su Sonnet, effort medium: tre prompt. Nella
prova del corso, fatta tre volte, 6, 15 e 11 turni del modello in tutto;
nessun subagent chiesto, ma Claude ne ha avviati da sé: due Explore nella
prima prova, al primo e al secondo prompt, uno nella terza, al primo,
nessuno nella seconda. I test e la verifica girano sul vostro
computer, senza chiamate al modello. I limiti sono gli stessi di
claude.ai: «These limits are shared across Claude and Claude Code, meaning
all activity in both tools counts against the same limits.»
(https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan),
e fra ciò che pesa ci sono il modello e l'effort: «Additional factors that
affect your usage limits include: … Tool usage (e.g., Research, web
search) | Model choice | Effort level»
(https://support.claude.com/en/articles/9797557-usage-limit-best-practices).
Alla fine, `/exit`.

Nella prova del corso (28 ottobre 2026, Claude Code 2.1.312, Sonnet con
effort medium, `claude -p` sull'account del docente), dal JSON di ogni
chiamata, prompt per prompt: nella prima prova 2, 3 e 1 turni del
modello (`num_turns`), 10,5, 10,1 e 3,4 secondi, 43.503, 61.315 e 31.525
token in entrata della conversazione principale, cache compresa; nella
seconda 6, 8 e 1 turni, 21,2, 31,1 e 4,1 secondi, 99.446, 195.635 e
31.403 token; nella terza 2, 8 e 1 turni, 11,1, 23,3 e 5,1 secondi,
43.996, 167.724 e 34.502 token. Al primo prompt della prima e della
terza prova, con i subagent, il totale di tutti i modelli sale a 126.756
e 140.278 token in entrata.

## Per approfondire

- I flussi di lavoro di Claude Code, con i test:
  https://code.claude.com/docs/en/common-workflows
- La pagina delle best practice di Claude Code, con le prove da chiedere:
  https://code.claude.com/docs/en/best-practices
- Le regole di permesso e le modalità:
  https://code.claude.com/docs/en/permissions ·
  https://code.claude.com/docs/en/permission-modes
- Gli strumenti di Claude Code: https://code.claude.com/docs/en/tools-reference
- Building effective agents, di Anthropic:
  https://www.anthropic.com/research/building-effective-agents
