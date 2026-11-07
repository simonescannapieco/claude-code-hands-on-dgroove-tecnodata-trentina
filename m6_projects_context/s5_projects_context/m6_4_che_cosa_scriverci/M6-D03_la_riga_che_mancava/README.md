# M6-D03 — Il comando dei test: Claude andrebbe a cercarlo?

Demo del Modulo 6, nella parte «Che cosa scriverci, e che cosa no». Il docente
la fa girare in aula; potete rifarla da soli quando volete, con lo stesso
comando.

## Obiettivo

Mettere alla prova il criterio che Anthropic dà per un `CLAUDE.md`: scrivere
soltanto ciò che Claude non trova leggendo il repository, o che altrimenti
riscoprirebbe a ogni sessione. La riga sotto prova è il comando dei test del
gestionale di CiaspoLink: c'è già, nel README del gestionale, ma Claude
andrebbe a cercarlo? La stessa richiesta va in due copie del gestionale che
differiscono in una cosa sola, un `CLAUDE.md` di quattro righe con il comando;
uno script legge i comandi che Claude ha eseguito e dice se la suite ha girato.

## Tempo

3 minuti in aula, la demo del docente: due chiamate, da 5 a 15 secondi
ciascuna. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Docker, oppure PHP 8.3 con Composer: `tools/php.sh` usa quello che trova.
  La prima esecuzione scarica le dipendenze del gestionale, e serve la rete.
- Python 3, git e tar, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M6-D03)

Lo spazio di lavoro `~/corso-claude-code/M6-D03/` con:

- `progetti/gestionale-php/`: il gestionale, senza `vendor/` e senza
  `CLAUDE.md`. Il suo README dice, sotto «Primo avvio», come si eseguono i test
  con `../../tools/php.sh`;
- `tools/php.sh`: lo stesso script della radice del repository, che esegue PHP,
  Composer e PHPUnit con PHP o con Docker;
- `richiesta.txt`: la richiesta;
- `con-la-riga/CLAUDE.md`: il `CLAUDE.md` del secondo braccio, le quattro righe;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_comandi.py`: il controllo, che legge gli stream.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M6-D03
       m6_projects_context/s5_projects_context/m6_4_che_cosa_scriverci/M6-D03_la_riga_che_mancava/demo/in_classe.sh ~/corso-claude-code/M6-D03

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata gira in una
   copia nuova dello spazio di lavoro, in una cartella temporanea: un
   repository git con un solo commit, senza `vendor/`, così ogni esecuzione
   parte dal primo `composer install`. La copia sparisce appena la chiamata è
   finita. Prima girano le chiamate senza la riga, poi quelle con la riga:

   | braccio | che cosa c'è nella copia |
   |---|---|
   | `senza` | `progetti/gestionale-php/`, `tools/php.sh` e `.claude/settings.json` |
   | `con` | lo stesso, e il `CLAUDE.md` di `con-la-riga/` in `progetti/gestionale-php/` |

   Il `CLAUDE.md` del braccio `con`, un titolo e due righe, nella forma che la
   documentazione consiglia per questi file:

       # Gestionale CiaspoLink

       - Test, da questa cartella: `../../tools/php.sh phpunit`.
       - Senza `vendor/`, prima: `../../tools/php.sh composer install`.

2. In ognuno dei due bracci, una sessione nuova di `claude -p` che parte da
   `progetti/gestionale-php`, come chi lavora sul gestionale: Sonnet con effort
   low, gli strumenti Read, Glob, Grep e Bash, Bash consentito per intero nella
   copia usa e getta tranne `sudo`, `git push`, `curl` e `wget`; nessun server
   MCP, l'auto memory, la memoria automatica del Modulo 4, spenta
   (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) e la stessa richiesta. La richiesta è
   un testo sotto prova, e resta così com'è:

   <!-- prompt 1 -->

       Esegui la suite di test del gestionale e dimmi quanti test passano e quanti falliscono.

   <!-- /prompt 1 -->

3. In sala si guarda ciò che stampa `controlla_comandi.py`, dalla copia degli
   stream in `risposte/`: i comandi di ogni esecuzione, se Claude ha letto il
   README, se la suite ha girato, la risposta, la coppia.

La prova del docente è di tre esecuzioni per braccio, sei chiamate: il
`_docente/live.sh` dell'elemento, che lancia lo stesso script con
`PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: ogni braccio deve partire
da una sessione nuova, nella sua copia, e lo stream dice ogni comando che
Claude ha eseguito e il suo risultato; così uno script decide ogni esecuzione
da ciò che è successo. La stessa prova, a mano: `claude` in
`progetti/gestionale-php` di uno spazio di lavoro appena preparato e la
richiesta; poi, in una copia nuova, le quattro righe in
`progetti/gestionale-php/CLAUDE.md`, una sessione nuova e la stessa richiesta.

## Che cosa osservare

### Che cosa dice Anthropic

In «Best practices for Claude Code», https://code.claude.com/docs/en/best-practices:

- il criterio: «Only write down what Claude can't find by reading the repo, or
  what it would otherwise spend time rediscovering every session.»
- che cosa tenere, fra l'altro: «How to confirm work in this repo: the exact
  test, typecheck, and lint commands, and how to run a single test file»;
- le due domande prima di scrivere una riga: «Could it find this by reading
  the code?» e «Would it actually go and look?»; e poi: «If both are yes,
  leave it out.»

Sulla forma del file, nella pagina sui `CLAUDE.md`: «Structure: group related
instructions under markdown headers and bullets. Organized sections are
easier for Claude to follow than dense paragraphs.»
https://code.claude.com/docs/en/memory

Su Bash consentito per intero: le chiamate della demo passano
`--permission-mode dontAsk`, e «dontAsk: Claude Code denies every call that
would otherwise prompt, which is useful for locked-down CI runs, though a mod
you installed can still approve some of those calls.»
(https://code.claude.com/docs/en/headless). Le quattro regole deny non fanno da
recinto: «a deny or ask rule covers the invocation Claude usually produces and
isn’t a security boundary around the program»
(https://code.claude.com/docs/en/permissions). Per questo la demo gira in una
copia usa e getta, in una cartella temporanea.

### Che cosa misura il controllo

`controlla_comandi.py` legge gli stream di `risposte/`, una cartella per
esecuzione (`senza-<n>/`, `con-<n>/`), e stampa per ognuna, come dati:

- i passi, nell'ordine: ogni comando Bash e ogni altro strumento chiamato;
- se Claude ha letto il README del gestionale, e a quale passo: lì il comando
  c'è, quindi è la risposta, esecuzione per esecuzione, alla seconda delle due
  domande;
- se ha usato `tools/php.sh`;
- se un risultato di Bash ha il riepilogo di PHPUnit, cioè se la suite ha
  girato, e quale;
- la risposta, e i suoi numeri contro quel riepilogo: i test che passano e
  quelli che falliscono;
- i token della prima richiesta, e turni, secondi e token della chiamata,
  sommati su ogni segmento.

Poi la coppia, esecuzione per esecuzione: con la riga la suite ha girato e
senza no, «confermata»; ha girato in tutte e due, «non distinguibile»; con la
riga non ha girato, «non confermata in questa esecuzione». Poi «confermata n su
N», e, per braccio, quante volte la suite ha girato e il README è stato letto,
con turni, secondi e token. Nessun esito decide l'uscita del controllo.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni per braccio, `_docente/live.sh` sull'account del
docente):

- senza la riga, in due esecuzioni su tre Claude è andato a cercare nel README:
  al secondo passo un `grep` di «test» in `README.md`, poi `ls ../../tools/`,
  poi `tools/php.sh` per `composer install` e PHPUnit, e «la suite: ha
  girato, «OK (44 tests, 107 assertions)»», con «i numeri della risposta: 44
  passati sì, 0 falliti sì». Nella terza ha guardato `composer.json` e
  `which phpunit php composer`, non ha aperto il README e ha risposto «Non
  posso eseguire la suite di test: nell'ambiente mancano `php`, `phpunit` e
  `composer`, e non c'è la cartella `vendor`.» Per il braccio: «senza: la
  suite ha girato 2 su 3, il README letto 2 su 3;» e «turni 14, 30,6 s,
  108.791 token»;
- con la riga, in tutte e tre la suite ha girato, con `tools/php.sh`, e il
  README non è stato aperto: «con: la suite ha girato 3 su 3, il README letto
  0 su 3;» e «turni 9, 23,1 s, 64.822 token»;
- la coppia: «esecuzione 1: non distinguibile (la suite ha girato anche
  senza)», lo stesso nella 2, «esecuzione 3: confermata (con la riga la suite
  ha girato; senza, no)», e «confermata 1 su 3»;
- la prima richiesta, con la riga: +225, +223 e +225 token.

Il criterio di Anthropic è una raccomandazione, e la registrazione la mette
alla prova su questo repository: la riga è una di quelle che Claude può
trovare, e in due esecuzioni su tre è andato a cercarla, con più passi, più
secondi e più token che con la riga davanti.

Gli stream sono nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M6-D03)

La verifica fa girare `controlla_comandi.py` dell'elemento, non la copia dello
spazio di lavoro, sugli stream di `risposte/`, quelli che lo script vi ha
copiato. È fatta quando ogni esecuzione di ogni coppia c'è ed è lo stream-json
riuscito di `claude -p`. Gli esiti della coppia si stampano e non la fanno
fallire. Quando tutto è in ordine, le ultime due righe sono «Fatto: ogni
esecuzione è stata messa alla prova; gli esiti sono qui sopra.» e «VERIFICA OK
M6-D03: fatto.»

## Se qualcosa va storto

- Lo script dice «servono PHP 8.3 o Docker»: installate Docker (o PHP 8.3 con
  Composer) e rilanciate `tools/verifica_ambiente.sh`.
- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo;
  gli stream vanno in `risposte/` soltanto quando l'ultima chiamata è finita.
- La verifica esce con 1 e dice che manca un'esecuzione, o che uno stream non
  finisce con il risultato: una chiamata si è fermata a metà. Ricominciate da
  capo, come qui sotto.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M6-D03`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- Con la riga la suite non ha girato: guardate i passi di quell'esecuzione e il
  risultato di `tools/php.sh`. Un `composer install` che non scarica niente è
  quasi sempre la rete o Docker fermo.
- «non distinguibile» e «non confermata in questa esecuzione» sono esiti, non
  errori: dicono che cosa ha fatto Claude in quell'esecuzione.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent. Un'esecuzione sono due chiamate di
`claude -p`, una per braccio; la prova del docente ne fa sei. Rifarla da soli
costa un'esecuzione. Il modello predefinito di Claude Code sul Pro è un altro:
«Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). Il corso fissa Sonnet perché
la registrazione e le vostre prove girino sullo stesso modello.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, un piano Max), dal
`result` di ogni stream, sommato su ogni segmento: senza la riga da 3 a 6
turni, da 5,2 a 13,2 secondi e da 20.972 a 48.813 token a chiamata; con la
riga da 2 a 4 turni, da 7,0 a 8,7 secondi e da 14.695 a 28.730 token. I token
sono quelli di `modelUsage`: «Use modelUsage, or model_usage in Python, for
whole-tree token accounting; the usage field undercounts as soon as nesting
occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking). Sono
entrata, cache e uscita di ogni chiamata, compreso il contesto letto dalla
cache: dicono quanto lavoro è stato, non un prezzo, e non quanta parte del
vostro piano occupa.

Nessuna sessione resta salvata: ogni chiamata ha `--no-session-persistence`, che
in `claude --help` è «Disable session persistence - sessions will not be saved
to disk and cannot be resumed (only works with --print)».

## Per approfondire

- «Best practices for Claude Code», che cosa mettere in un `CLAUDE.md`:
  https://code.claude.com/docs/en/best-practices
- La pagina sui file `CLAUDE.md`: https://code.claude.com/docs/en/memory
- I permessi di Claude Code: https://code.claude.com/docs/en/permissions
- `claude -p` e lo stream-json: https://code.claude.com/docs/en/headless
