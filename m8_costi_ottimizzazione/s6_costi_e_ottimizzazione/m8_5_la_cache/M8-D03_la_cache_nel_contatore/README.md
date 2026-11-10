# M8-D03 — La cache, vista nel contatore

Demo del Modulo 8, nella parte «La cache». In aula la esegue il docente;
potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Vedere la cache del prompt di Claude Code nei numeri che ogni esecuzione lascia
nel JSON, nel campo `usage`. Lo stesso prefisso lungo (due procedure
dell'assistenza di CiaspoLink, l'operatore inventato del corso, con dati
sintetici) e la stessa domanda vanno a Claude in cinque chiamate di `claude -p`,
ognuna una sessione nuova, che cambiano una cosa per volta: la prima su Haiku,
la stessa chiamata ripetuta, la stessa con la cache spenta, la stessa su Sonnet
e di nuovo la stessa su Haiku. Lo script che controlla legge il JSON di ogni
chiamata e dice se ciò che Anthropic afferma sulla cache di Claude Code vale in
questa serie.

## Tempo

3 minuti in aula, la demo del docente. Per rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M8-D03)

Lo spazio di lavoro `~/corso-claude-code/M8-D03/` con:

- `progetti/assistenza-clienti/`: il progetto dell'assistenza, di cui la demo
  usa due procedure della base di conoscenza, `kb/kb-10-trasloco.md` e
  `kb/kb-13-telefono-di-casa-muto.md`;
- `domanda.txt`: la domanda, una riga;
- `in_classe.sh`: le cinque chiamate, una dopo l'altra, con ogni comando a
  schermo;
- `controlla_cache.py`: il controllo, che legge i JSON di `claude -p`;
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e
   fa partire la demo:

       tools/prepara_esercizio.sh M8-D03
       m8_costi_ottimizzazione/s6_costi_e_ottimizzazione/m8_5_la_cache/M8-D03_la_cache_nel_contatore/demo/in_classe.sh ~/corso-claude-code/M8-D03

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata è una
   sessione nuova di `claude -p`, con effort low, nessuno strumento (`--tools
   ""`), nessun server MCP (`--strict-mcp-config`) e l'output JSON, tutte
   dalla stessa cartella temporanea vuota, fuori dallo spazio di lavoro.

2. Il prefisso: `in_classe.sh` lo compone in `risposte/<serie>-prefisso.md`
   con una riga in testa, «Marcatore di questa serie: …» con un codice nuovo a
   ogni serie, e sotto le due procedure. Va a Claude come system prompt, con
   `--system-prompt-file`, che sostituisce il system prompt di Claude Code:
   «--system-prompt | Replaces the entire default prompt … --system-prompt-file
   | Replaces with file contents» (https://code.claude.com/docs/en/cli-reference).
   Il marcatore in testa cambia tutto il prefisso, e così ogni serie parte a
   cache fredda: «Prompt caching references the entire prompt: tools, system, and
   messages (in that order), up to and including the block designated with
   cache_control.»
   (https://platform.claude.com/docs/en/build-with-claude/prompt-caching). Le
   due procedure servono a superare la lunghezza minima di un prefisso che può
   stare in cache: «512 tokens for Claude Fable 5.2 … Claude Opus 5.5, Claude
   Opus 5, Claude Sonnet 5.5 … and Claude Haiku 5.5»; sotto, «Shorter prompts
   cannot be cached, even if marked with cache_control. … processed without
   caching, and no error is returned.» (stessa pagina).

3. La domanda è sempre la stessa, un testo sotto prova che resta così com'è:

   <!-- prompt domanda -->

       Una cliente dice che il telefono di casa è muto ma internet funziona: qual è il primo controllo da farle fare? Rispondi in una riga.

   <!-- /prompt domanda -->

4. Le cinque chiamate, ogni volta la domanda e lo stesso prefisso:

   | nome | che cosa cambia |
   |---|---|
   | `prima` | niente: prima chiamata, su Haiku |
   | `seconda` | niente: la stessa chiamata |
   | `senza-cache` | `DISABLE_PROMPT_CACHING=1` nell'ambiente, una variabile sola |
   | `sonnet` | `--model sonnet` al posto di `--model haiku` |
   | `haiku-di-nuovo` | niente: la stessa chiamata della prima, ancora su Haiku |

   I JSON vanno in `risposte/<serie>-<nome>/risposta.json`: una cartella per
   chiamata, con il numero della serie e il nome qui sopra.

5. In sala si guarda ciò che stampa `controlla_cache.py`: la tabella dei
   conteggi di `usage` di ogni chiamata e le garanzie della serie.

La prova del docente è di tre serie, quindici chiamate: il `_docente/live.sh`
dell'elemento, che lancia lo stesso script con `PN_ESECUZIONI=3` e un marcatore
per serie.

Perché `claude -p` e non una sessione aperta a mano: servono cinque chiamate
uguali che differiscono in una cosa sola, e il JSON di ognuna dice quanti token
sono stati scritti e letti; così uno script legge ogni chiamata e decide.

`--tools ""` toglie gli strumenti integrati: in `claude --help`, «Specify the
list of available tools from the built-in set. Use "" to disable all tools».
`--no-session-persistence` non salva la sessione: «Disable session persistence
- sessions will not be saved to disk and cannot be resumed (only works with
--print)».

## Che cosa osservare

### Che cosa dice Anthropic

Sulla cache in Claude Code, nella pagina
https://code.claude.com/docs/en/prompt-caching:

- «Claude Code manages prompt caching automatically.» È la prima cosa che la
  demo prova: nessuno ha chiesto la cache, e la prima chiamata scrive, la
  seconda legge.
- «Each model has its own cache.» La quarta chiamata cambia modello (con
  `--model`, in una chiamata nuova): `cache_read_input_tokens` deve essere zero e
  `cache_creation_input_tokens` maggiore di zero, una cache tutta nuova.
- «DISABLE_PROMPT_CACHING | Disable for all models». La terza chiamata accende
  la variabile: la cache non viene né scritta né letta.
- «Claude Code reports one-hour cache writes under ephemeral_1h_input_tokens
  and five-minute cache writes under ephemeral_5m_input_tokens.» La divisione
  dei token scritti fra un'ora e cinque minuti che il controllo stampa è questa,
  dal JSON: un dato, non una garanzia.

Come si leggono i campi, in
https://platform.claude.com/docs/en/build-with-claude/prompt-caching:

- «cache_creation_input_tokens: Number of tokens written to the cache when
  creating a new entry»: la colonna «scritti»;
- «cache_read_input_tokens: Number of tokens retrieved from the cache for this
  request»: la colonna «letti»;
- «input_tokens: Number of input tokens that were not read from or used to
  create a cache»: la colonna «input»;
- per dire se la cache è stata usata: «if both cache_creation_input_tokens and
  cache_read_input_tokens are 0, the prompt was not cached».

E la somma, nella
pagina della Messages API, https://platform.claude.com/docs/en/api/messages/create:
«Total input tokens in a request is the summation of input_tokens,
cache_creation_input_tokens, and cache_read_input_tokens.»: la colonna
«totale». «A high read-to-creation ratio means caching is working well. If
creation stays high turn after turn, something is changing in your prefix.»
(https://code.claude.com/docs/en/prompt-caching).

### Che cosa misura il controllo

`controlla_cache.py` legge i JSON di `risposte/`, una cartella per chiamata, e
stampa per ogni serie:

- la tabella delle cinque chiamate: modello, `input_tokens`, token scritti e
  letti, il totale in entrata, l'output e la divisione della scrittura fra un'ora
  e cinque minuti: dati;
- quanti token la seconda chiamata ha letto rispetto a quelli scritti dalla
  prima: un dato, perché il prefisso può tornare solo in parte;
- le cinque garanzie, ciascuna «confermata» oppure «non confermata in questa
  esecuzione»: una che non vale fa uscire 1.

Le garanzie, chiamata per chiamata:

| chiamata | garanzia |
|---|---|
| `prima` | scrive (`cache_creation_input_tokens` > 0) e non legge (`cache_read_input_tokens` = 0) |
| `seconda` | legge (`cache_read_input_tokens` > 0: non per forza tutto il prefisso) |
| `senza-cache` | niente in cache (`cache_creation_input_tokens` = 0 e `cache_read_input_tokens` = 0), il prefisso in `input_tokens` (> 0) |
| `sonnet` | su un altro modello non legge (`cache_read_input_tokens` = 0) e scrive di nuovo (`cache_creation_input_tokens` > 0) |
| `haiku-di-nuovo` | la cache di Haiku c'è ancora: legge di nuovo (`cache_read_input_tokens` > 0) |

Nessuna durata della cache è messa alla prova: le chiamate si succedono a pochi
secondi di distanza, e la demo guarda soltanto se il prefisso uguale torna.

Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322, tre serie,
`_docente/live.sh` sull'account del docente) le cinque garanzie valgono in ogni
serie, 15 su 15:

- la prima chiamata di ogni serie scrive da 2.609 a 2.612 token e non ne legge
  nessuno;
- la seconda legge da 2.609 a 2.612 token e non ne scrive nessuno: in queste tre
  serie rilegge tutto il prefisso, ma la garanzia chiede soltanto letti > 0;
- con `DISABLE_PROMPT_CACHING=1` da 2.611 a 2.614 token stanno tutti in
  `input_tokens`, e la cache resta a zero;
- su Sonnet: letti 0, scritti da 2.588 a 2.591;
- di nuovo su Haiku: letti da 2.609 a 2.612.

La divisione della scrittura: tutti i token scritti sono nella colonna «1 h»
(`ephemeral_1h_input_tokens`), un dato che il controllo stampa e non giudica. I
JSON sono nella cartella `soluzione/risposte/` di questo elemento (nel repository
del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M8-D03)

La verifica fa girare `controlla_cache.py` dell'elemento, non la copia dello
spazio di lavoro, sui JSON di `risposte/`. È fatta quando ogni chiamata di ogni
serie c'è, è finita bene e le garanzie valgono. Quando tutto è in ordine, le
ultime due righe sono «Fatto: ogni serie è stata messa alla prova; gli esiti
sono qui sopra.» e «VERIFICA OK M8-D03: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica esce con 1 e dice che manca una chiamata: lo script si è fermato
  a metà. Ricominciate da capo: `tools/reset_esercizio.sh M8-D03`.
- Una riga «non confermata in questa esecuzione»: l'uscita è 1, e il JSON dice
  che cosa è successo. La tabella mostra quale modello ha risposto e i conteggi
  di ogni chiamata; controllate che nella shell non ci fosse già
  `DISABLE_PROMPT_CACHING` (lo script la toglie, tranne nella terza chiamata) e
  che ogni chiamata della serie sia partita dalla stessa cartella: lo script lo
  fa da sé.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M8-D03`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Haiku e Sonnet con effort low, nessuno strumento, nessun subagent: chiamate di
un turno solo. Una serie è fatta di cinque chiamate, quattro su Haiku e una su
Sonnet; la prova del docente ne fa tre, quindici chiamate. Nella registrazione
del corso (10 novembre 2026, Claude Code 2.1.322, `_docente/live.sh` sull'account
del docente), dal JSON di ogni chiamata: da 1,1 a 3,1 secondi e da 2.668 a 2.902
token a chiamata (entrata, cache e uscita); «Come dati, tutte le 15 chiamate:
turni 15; token in entrata 39.122, in uscita 1.439; 23,4 s.» I token sono quelli
di `usage` di ogni chiamata: dicono quanto lavoro è stato, non un prezzo, e non
quanta parte del vostro piano occupa.

Il modello predefinito di Claude Code sul Pro è un altro: «Pro, Max, Ultra,
Team, Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). La demo fissa i modelli perché
la registrazione e le vostre prove girino sugli stessi.

## Per approfondire

- La prompt caching in Claude Code:
  https://code.claude.com/docs/en/prompt-caching
- La prompt caching nella Claude API:
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Il campo `usage` della Messages API:
  https://platform.claude.com/docs/en/api/messages/create
