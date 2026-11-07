# M6-D01 — Il documento che nessun modello ha letto

Demo del Modulo 6, nella parte «Perché il contesto è tutto». Il docente la fa
girare in aula; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Vedere che Claude risponde con ciò che ha nel contesto. La domanda riguarda un
documento che nessun modello ha mai letto: la carta dei servizi di CiaspoLink,
l'operatore inventato dei progetti del corso, scritta per il corso e fatta di
dati sintetici. La stessa domanda va in due cartelle che differiscono in una
cosa sola: nella prima la carta non c'è; nella seconda c'è un `CLAUDE.md` che
la importa. Uno script legge le risposte e dice se ci sono le cifre
dell'articolo che risponde alla domanda.

## Tempo

4 minuti in aula, la demo del docente: due chiamate brevi. Per rifarla da
soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3, git e tar, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M6-D01)

Lo spazio di lavoro `~/corso-claude-code/M6-D01/` con:

- `carta-servizi.md`: la carta dei servizi, sette articoli. L'Art. 4 dice i
  tempi degli interventi sugli apparati in quota; gli altri articoli hanno
  altri numeri, così una citazione si può controllare;
- `domanda.txt`: la domanda;
- `con-la-carta/CLAUDE.md`: il `CLAUDE.md` del secondo braccio, che importa la
  carta;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_documento.py`: il controllo, che legge gli stream.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M6-D01
       m6_projects_context/s5_projects_context/m6_2_il_contesto_e_tutto/M6-D01_documento_mai_letto/demo/in_classe.sh ~/corso-claude-code/M6-D01

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata gira in una
   copia nuova dello spazio di lavoro, in una cartella temporanea, che è un
   repository git con un solo commit e sparisce appena la chiamata è finita.
   Prima girano le chiamate senza la carta, poi quelle con la carta:

   | braccio | che cosa c'è nella copia |
   |---|---|
   | `senza` | soltanto `.claude/settings.json`: la carta non c'è |
   | `con` | anche il `CLAUDE.md` di `con-la-carta/` e la carta, in `docs/carta-servizi.md` |

   Il `CLAUDE.md` del braccio `con` è di tre righe, un titolo e l'import:

       # CiaspoLink

       - La carta dei servizi di CiaspoLink: @docs/carta-servizi.md

2. In ognuno dei due bracci, una sessione nuova di `claude -p` su Sonnet con
   effort low, con gli stessi strumenti di lettura, Read, Glob e Grep, senza
   server MCP, con l'auto memory, la memoria automatica del Modulo 4, spenta
   (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) e la stessa domanda. La domanda è un
   testo sotto prova, e resta così com'è:

   <!-- prompt 1 -->

       Entro quanti giorni lavorativi va fatto un intervento su un ponte radio in quota?

   <!-- /prompt 1 -->

3. In sala si guarda ciò che stampa `controlla_documento.py`, dalla copia degli
   stream in `risposte/`: che cosa ha cercato Claude, la risposta, le cifre,
   gli articoli citati, la coppia.

La prova del docente è di tre esecuzioni per braccio, sei chiamate: il
`_docente/live.sh` dell'elemento, che lancia lo stesso script con
`PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: ogni braccio deve partire
da una sessione nuova, con il solo contesto della sua cartella, e lo stream dice
che cosa ha fatto Claude, strumento per strumento; così uno script decide ogni
esecuzione da ciò che è successo. La stessa prova, a mano: `claude` in una
cartella vuota e la domanda; poi, in quella cartella, il `CLAUDE.md` qui sopra
e la carta in `docs/`, una sessione nuova e la stessa domanda.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella lezione «Working Memory» del corso dell'Academy «AI capabilities and
  limitations»: «The model doesn't learn from your corrections. It only
  responds to what's currently in context.» La stessa lezione propone tre
  prove da fare in chat; questa demo rifà la prima in Claude Code: «Probe 1:
  Cold start vs. context.»
  https://academy.claude.com/courses/ai-capabilities-and-limitations/working-memory
- In «Reduce hallucinations»: «Even the most advanced language models, such
  as Claude, can sometimes generate text that is factually incorrect or
  inconsistent with the given context.» E fra le tecniche della pagina:
  «Allow Claude to say "I don't know": Explicitly give Claude
  permission to admit uncertainty.» La domanda della demo questo permesso non
  lo dà: è la domanda come la farebbe chiunque.
  https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- Nella pagina sui file `CLAUDE.md`, l'import: «CLAUDE.md files can import
  additional files using @path/to/import syntax.» E il suo costo: «Imports
  help you organize a long file but don't reduce its context cost, because
  imported files load together with the CLAUDE.md that imports them.»
  https://code.claude.com/docs/en/memory
- Come si conta la prima richiesta: «total_input_tokens =
  cache_read_input_tokens + cache_creation_input_tokens + input_tokens».
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching

### Che cosa misura il controllo

`controlla_documento.py` legge gli stream di `risposte/`, una cartella per
esecuzione (`senza-<n>/`, `con-<n>/`), e stampa per ognuna:

- gli strumenti che Claude ha chiamato e che cosa hanno trovato; un percorso
  fuori dalla copia è segnato «fuori dalla cartella»;
- la risposta;
- se ci sono le cifre dell'Art. 4, 5 e 9 giorni lavorativi;
- i numeri della risposta, fuori dalle citazioni di articoli e dalle date.
  Senza la carta sono numeri che nessun documento ha dato a Claude: si
  stampano come dato, perché la frase di Anthropic dice «can sometimes», e un
  numero inventato, o la sua assenza, in poche esecuzioni non la mette in
  discussione;
- gli articoli citati, i token della prima richiesta, e turni, secondi e token
  della chiamata, sommati su ogni segmento.

Se, senza la carta, il risultato di uno strumento contiene una riga della
carta, il controllo lo dice: la carta è arrivata da un'altra parte, ed è la
fuga da cercare.

Poi il controllo delle citazioni, una dimostrazione: lo fa lo script da sé, e
non dice niente su Claude. Ogni articolo che la risposta cita si cerca nella
carta, con i suoi numeri, e i numeri della risposta si cercano in quegli
articoli.

Poi la coppia, esecuzione per esecuzione: con la carta le cifre dell'Art. 4 e
senza no, «confermata»; le cifre anche senza la carta, «non distinguibile»,
una fuga da cercare; con la carta senza le cifre, «non confermata in questa
esecuzione». Poi «confermata n su N». Nessun esito decide il codice d'uscita
del controllo.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni per braccio, `_docente/live.sh` sull'account del
docente):

- senza la carta, in tutte e tre le esecuzioni Claude ha cercato nella
  cartella, prima con Grep e poi con Glob, per esempio «Grep «ponte
  radio|ponti radio» in .: nessun risultato» e «Glob «**/*» in .: 27 righe».
  In tutte e tre «le cifre
  dell'Art. 4, 5 e 9 giorni lavorativi: no». Le risposte: «Non so rispondere
  con certezza. Nel repository non c'è nulla sull'argomento», «Non ho quindi
  una fonte da cui ricavare un termine in giorni lavorativi, e preferisco non
  darle un numero inventato.», «Non conosco nemmeno un termine standard valido
  in generale.»;
- con la carta, nessuno strumento; in tutte e tre la risposta comincia con
  «Secondo l'Art. 4 della Carta dei servizi», dice «**5 giorni lavorativi**»
  da maggio a ottobre e «**9 giorni lavorativi**» da novembre ad aprile, e
  cita anche l'Art. 5, per l'indennizzo. Il controllo delle citazioni, in
  tutte e tre: «i numeri della risposta negli articoli citati: tutti»;
- la coppia: «confermata 3 su 3»;
- la prima richiesta: «con 6.006, senza 4.876 token (+1.130)», e +1.135 nelle
  altre due esecuzioni. Le due cartelle differiscono soltanto nella carta e
  nel `CLAUDE.md` che la importa.

Gli stream sono nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M6-D01)

La verifica fa girare `controlla_documento.py` dell'elemento, non la copia
dello spazio di lavoro, sugli stream di `risposte/`, quelli che lo script vi ha
copiato. È fatta quando ogni esecuzione di ogni coppia c'è ed è lo stream-json
riuscito di `claude -p`. Gli esiti della coppia si stampano e non la fanno
fallire. Quando tutto è in ordine, le ultime due righe sono «Fatto: ogni
esecuzione è stata messa alla prova; gli esiti sono qui sopra.» e «VERIFICA OK
M6-D01: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo;
  gli stream vanno in `risposte/` soltanto quando l'ultima chiamata è finita.
- La verifica esce con 1 e dice che manca un'esecuzione, o che uno stream non
  finisce con il risultato: una chiamata si è fermata a metà. Ricominciate da
  capo, come qui sotto.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M6-D01`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- «non distinguibile»: le cifre ci sono anche senza la carta. Guardate gli
  strumenti di quell'esecuzione: una riga «è la fuga da cercare», o un
  percorso «fuori dalla cartella», dicono da dove è arrivata.
- «non confermata in questa esecuzione» è un esito, non un errore: in
  quell'esecuzione, con la carta nel contesto, le cifre non ci sono. Leggete
  la risposta che il controllo stampa.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent, solo strumenti di lettura. Un'esecuzione
sono due chiamate di `claude -p`, una per braccio; la prova del docente ne fa
sei. Rifarla da soli costa un'esecuzione. Il modello predefinito di Claude Code
sul Pro è un altro: «Pro, Max, Ultra, Team, Enterprise, and Anthropic API:
defaults to Opus 5.5» (https://code.claude.com/docs/en/model-config). Il corso
fissa Sonnet perché la registrazione e le vostre prove girino sullo stesso
modello.

Nella registrazione del corso (7 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, un piano Max), dal
`result` di ogni stream, sommato su ogni segmento: senza la carta da 3 a 4
turni e da 8,0 a 16,3 secondi a chiamata; con la carta un turno e da 2,7 a 7,0
secondi; «Come dati, tutte le 6 chiamate: turni 13; token 57.606; 47,2 s.» I
token sono quelli di `modelUsage`: «Use modelUsage, or model_usage in Python,
for whole-tree token accounting; the usage field undercounts as soon as
nesting occurs.» (https://code.claude.com/docs/en/agent-sdk/cost-tracking).
Sono entrata, cache e uscita di ogni chiamata, compreso il contesto letto dalla
cache: dicono quanto lavoro è stato, non un prezzo, e non quanta parte del
vostro piano occupa.

Nessuna sessione resta salvata: ogni chiamata ha `--no-session-persistence`, che
in `claude --help` è «Disable session persistence - sessions will not be saved
to disk and cannot be resumed (only works with --print)».

## Per approfondire

- «Working Memory», nel corso dell'Academy «AI capabilities and limitations»:
  https://academy.claude.com/courses/ai-capabilities-and-limitations/working-memory
- «Reduce hallucinations»:
  https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- La pagina sui file `CLAUDE.md` e sugli import:
  https://code.claude.com/docs/en/memory
- `claude -p` e lo stream-json: https://code.claude.com/docs/en/headless
