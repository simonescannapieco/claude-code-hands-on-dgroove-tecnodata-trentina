# M8-E01 — Quanto costa una risposta

Esercitazione del Modulo 8, nella parte sul conto in token: una chiamata di
`claude -p` su Haiku, il suo JSON e uno script, scritto con Claude Code, che ne
fa il conto ai prezzi di listino e calcola un mese di ticket.

## Obiettivo

Imparare a leggere il conto di una risposta dal campo `usage` del JSON di
`claude -p`: i cinque conteggi di token, ciascuno con il suo prezzo, e la somma,
da confrontare con `total_cost_usd` dello stesso JSON. Claude Code scrive lo
script, `conto.py`; voi guardate i numeri e rifate il conto su un mese di
ticket.

Alla fine avete, nello spazio di lavoro:

- `risposte/prima.json`: il JSON della chiamata;
- `conto.py`: lo script che stampa il conto.

Il lavoro si fa in una sessione di Claude Code, che scrive lo script, più una
sola chiamata di `claude -p`: è il modo più semplice di avere, per una
risposta, tutti i suoi token in un file che uno script sa leggere. «With
--output-format json, the response payload includes total_cost_usd and a
per-model cost breakdown» (https://code.claude.com/docs/en/headless).

## Tempo

6 minuti in aula.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`): controlla anche che nell'ambiente non ci sia
  `ANTHROPIC_API_KEY`, perché la chiamata del passo 2 deve usare l'abbonamento.
- Python 3 e git, che `tools/verifica_ambiente.sh` controlla.
- Su Windows, WSL 2.

## Punto di partenza (tools/prepara_esercizio.sh M8-E01)

Lo spazio di lavoro `~/corso-claude-code/M8-E01/`, un repository git con un
primo commit, con:

- `messaggio.txt`: il messaggio di una cliente di CiaspoLink, l'operatore
  inventato del corso: è il testo che manderete a Claude;
- `listino.json`: i prezzi di Haiku, Sonnet e Opus, in dollari per milione di
  token, con la data e le pagine da cui vengono;
- `volume.txt`: l'ipotesi del conto del mese, 10.000 ticket, 1.000 token in
  entrata e 150 in uscita per ticket, al prezzo base di Haiku, senza cache;
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro ed entrateci:

       tools/prepara_esercizio.sh M8-E01
       cd ~/corso-claude-code/M8-E01

2. La chiamata. Prima la cartella delle risposte, poi una sola chiamata di
   `claude -p`, su Haiku con effort low, senza strumenti né server MCP, con il
   JSON in un file, senza salvare la sessione:

       mkdir -p risposte
       claude -p "$(cat messaggio.txt)" \
         --model haiku --effort low --output-format json \
         --tools "" --strict-mcp-config \
         --setting-sources project,local \
         --permission-mode dontAsk --permission-prompts none \
         --no-session-persistence > risposte/prima.json

   Che cosa fanno le opzioni, dalla guida di `claude --help`: `--tools ""`
   toglie tutti gli strumenti integrati («Use "" to disable all tools»),
   `--strict-mcp-config` lascia fuori ogni server MCP che non è indicato («Only
   use MCP servers from --mcp-config, ignoring all other MCP configurations»),
   `--no-session-persistence` non salva la sessione («Disable session
   persistence - sessions will not be saved to disk and cannot be resumed
   (only works with --print)»). Il messaggio è un testo sotto prova e resta
   così com'è:

   <!-- prompt messaggio -->

       Buongiorno, sono Marta Modello. Da qualche giorno la connessione di casa la sera diventa lentissima: le videochiamate si bloccano e la TV si ferma ogni pochi minuti, mentre di mattina va bene. Ho già riavviato il router due volte. Potete dirmi da che cosa dipende e che cosa posso fare?

   <!-- /prompt messaggio -->

   La risposta non è il punto: aprite `risposte/prima.json` e guardate il
   campo `usage`.

3. Lo script. In un altro terminale, nello spazio di lavoro, aprite una
   sessione di Claude Code su Haiku con effort low:

       cd ~/corso-claude-code/M8-E01
       claude --model haiku --effort low

   Alla prima apertura vi chiede se vi fidate della cartella: «In an
   interactive session, Claude Code shows the workspace trust dialog when you
   start it in a folder you haven’t trusted.»
   (https://code.claude.com/docs/en/security). Rispondete sì: scendete con la
   freccia su «Yes, I trust this folder» e date Invio. Poi incollate la
   richiesta:

   <!-- prompt richiesta -->

       Scrivi conto.py: legge risposte/prima.json e listino.json e stampa, con sei decimali, il costo della chiamata, con i cinque conteggi di usage (input, scrittura in cache a 5 minuti e a 1 ora, lettura dalla cache, output) ciascuno al suo prezzo di haiku, total_cost_usd per confronto e il costo di un mese ai volumi di volume.txt.

   <!-- /prompt richiesta -->

   Se Claude Code chiede il permesso di scrivere il file, leggete e approvate;
   se lo chiede per leggere un file o per un comando, leggete che cosa chiede e
   decidete. Poi, nel terminale del passo 2, nello spazio di lavoro:

       python3 conto.py

   Controllate che ci siano il costo della chiamata, `total_cost_usd` e il
   costo del mese. Se manca qualcosa, chiedetelo a Claude nella stessa
   sessione.

4. Tornate nella cartella `esercitazioni`, e la verifica:

       cd -
       tools/verifica.sh M8-E01

## Che cosa osservare

### Che cosa dice Anthropic

- **La formula.** «Price each of the five token counts in a response’s usage
  at its own rate»
  (https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence).
  I cinque conteggi, nel JSON di Claude Code:

  | conteggio | dove sta | Haiku 5.5, dollari per milione di token |
  |---|---|---|
  | input, non in cache | `usage.input_tokens` | 0,10 |
  | scrittura in cache, 5 minuti | `usage.cache_creation.ephemeral_5m_input_tokens` | 0,125 |
  | scrittura in cache, 1 ora | `usage.cache_creation.ephemeral_1h_input_tokens` | 0,20 |
  | lettura dalla cache | `usage.cache_read_input_tokens` | 0,01 |
  | output | `usage.output_tokens` | 0,50 |

  Le due scritture hanno due campi: «Claude Code reports one-hour cache writes
  under ephemeral_1h_input_tokens and five-minute cache writes under
  ephemeral_5m_input_tokens.»
  (https://code.claude.com/docs/en/prompt-caching). I prezzi sono di
  `listino.json`, letti il 10 novembre 2026: per Haiku 5.5, per i prompt fino
  a 100.000 token, su https://platform.claude.com/docs/en/models/haiku-5-5/overview,
  e sulla pagina dei prezzi il moltiplicatore della scrittura a un'ora: «1-hour
  cache write | 2x base input price | Cache valid for 1 hour»
  (https://platform.claude.com/docs/en/about-claude/pricing).
- **Quanto entra davvero.** «Total input tokens in a request is the summation
  of input_tokens, cache_creation_input_tokens, and cache_read_input_tokens.»
  (https://platform.claude.com/docs/en/api/messages/create). `input_tokens` da
  solo può essere una cifra piccola anche quando il contesto è di migliaia di
  token.
- **Da dove viene la cifra in dollari.** Del JSON: «With --output-format json,
  the response payload includes total_cost_usd and a per-model cost breakdown»
  e «Both figures are client-side estimates and can differ from your actual
  bill.» (https://code.claude.com/docs/en/headless). Della cifra che Claude
  Code mostra in `/usage`: «Claude Code computes the dollar figure locally from
  token counts at list price» (https://code.claude.com/docs/en/costs). Il
  vostro conto rifà quel calcolo a mano, e la verifica dice quanto si
  discosta da `total_cost_usd`: è una dimostrazione del metodo, non un
  giudizio sul modello.
- **Sul piano Pro.** Della cifra in dollari di `/usage`, in un abbonamento:
  «so on a subscription it is a guide to how much work you did, not a bill.»
  (https://claude.dev/blog/what-a-task-costs-on-opus-5-5/). Quei dollari
  dicono quanto lavoro è stato, non sono una fattura.

### Che cosa misura il controllo

`tools/verifica.sh M8-E01` legge `risposte/prima.json`, `listino.json` e
`volume.txt` e ricalcola da sé il conto: stampa la tabella dei cinque conteggi,
il totale ricalcolato e, come dati, nelle righe «(dato)», i token in entrata
(i tre campi sommati), `total_cost_usd` e la differenza dal ricalcolo, con la
riga «il calcolo riproduce total_cost_usd» se la differenza sta entro un
centesimo di centesimo di dollaro (0,0001 $), «il calcolo non riproduce
total_cost_usd» se no. Quella riga è un dato: non decide l'uscita, e non dice
niente del modello.

Poi lancia il vostro `conto.py` due volte. La prima così com'è: nella sua
uscita devono esserci il costo della chiamata, entro lo stesso centesimo di
centesimo, e il costo del mese, entro un centesimo, numeri con il punto o con
la virgola. La seconda su una copia dello spazio di lavoro con altri numeri
negli stessi tre file (altri conteggi, un altro `total_cost_usd`, altri prezzi,
un altro volume): i due numeri devono cambiare come devono. Serve a questo:
sulla chiamata vera il conto calcolato e `total_cost_usd` sono uguali, e soltanto
con numeri diversi si vede se lo script fa il conto o ricopia la cifra del JSON.

### Nella prova del corso

Nella registrazione del corso (10 novembre 2026, Claude Code 2.1.322, Haiku con
effort low, `_docente/live.sh` sull'account del docente, che fa il passo 2 come
sopra e usa `conto.py` di riferimento al posto della sessione interattiva), la
verifica ha stampato:

    input_tokens                        2 × 0,100 = 0,000000 $
    scrittura in cache, 5 min           0 × 0,125 = 0,000000 $
    scrittura in cache, 1 ora         767 × 0,200 = 0,000153 $
    lettura dalla cache              3133 × 0,010 = 0,000031 $
    output_tokens                    1950 × 0,500 = 0,000975 $
    totale ricalcolato                        0,001160 $
    (dato) token in entrata, i tre campi sommati: 3902
    (dato) total_cost_usd del JSON: 0,001160 $
    (dato) differenza dal ricalcolo: 0,000000 $
           il calcolo riproduce total_cost_usd entro un centesimo
           di centesimo (0,0001 $)

Il mese, a 10.000 ticket da 1.000 token in entrata e 150 in uscita, ai prezzi
base di Haiku: 1,75 $. La scrittura è tutta nella cache a un'ora: su un
abbonamento «Unless you choose a TTL yourself, Claude Code requests the
one-hour TTL only on a Claude subscription within your plan's included usage.»
(https://code.claude.com/docs/en/prompt-caching). In `modelUsage` c'è anche
`costBasis`, che nella registrazione vale `list`: «Each entry's costBasis says
which price table priced that model's latest request»
(https://code.claude.com/docs/en/agent-sdk/cost-tracking). Le vostre cifre
saranno altre: quella è una chiamata, la vostra un'altra. Il JSON della
registrazione è nella cartella `soluzione/risposte/` di questo elemento (nel
repository del corso; la copia senza soluzioni non l'ha).

## Verifica (tools/verifica.sh M8-E01)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M8-E01

Esce con 0 quando `risposte/prima.json` è una chiamata riuscita, su Haiku, e
`conto.py` stampa il costo della chiamata e quello del mese, anche sulla copia
con altri numeri: le ultime righe sono «Fatto: conto.py stampa il conto della
chiamata e quello del mese;», «il confronto con total_cost_usd è qui sopra,
come dato.» e «VERIFICA OK   M8-E01: fatto.». Con 1 quando manca
`risposte/prima.json` o `conto.py`, quando la chiamata non è riuscita o non è su
Haiku, quando `conto.py` non gira, non finisce entro venti secondi o non stampa
i due numeri: dice che cosa manca. Con 2 quando non può partire: uno spazio di
lavoro che non c'è, `listino.json` o `volume.txt` che mancano o non vanno, un
file che non si legge. Il controllo non chiama nessun modello: il confronto con
`total_cost_usd` è un dato.

## Se qualcosa va storto

- La verifica dice che manca `risposte/prima.json`: la chiamata del passo 2 non
  è stata fatta, o avete lanciato il comando da un'altra cartella: il file va
  nello spazio di lavoro, in `risposte/`.
- La verifica dice che `risposte/prima.json` non è un JSON, o che la chiamata
  non è finita bene: il comando è fallito, per esempio per i limiti del piano.
  Aspettate qualche minuto, poi rifate il passo 2, che riscrive il file.
- La verifica dice che la chiamata non è su Haiku: nel comando manca `--model
  haiku`; il controllo vuole quel modello perché il listino del passo 3 è
  quello di Haiku. Rifate il passo 2.
- La verifica dice che manca `conto.py`: Claude può averlo scritto in un'altra
  cartella. Deve stare nello spazio di lavoro, accanto a `listino.json`.
- «conto.py non gira»: lanciatelo a mano, `python3 conto.py`, leggete l'errore
  e chiedete a Claude di correggerlo nella stessa sessione. La verifica lo
  lancia con `python3 -B -I`: soltanto la libreria standard di Python.
- «conto.py non stampa il costo della chiamata» e il numero più vicino sembra
  giusto: a due decimali un costo di un millesimo di dollaro si legge zero. La
  richiesta del passo 3 chiede sei decimali.
- «con altri numeri negli stessi file»: `conto.py` scrive i numeri nel codice,
  o ricopia `total_cost_usd`. Deve leggere i tre file e sommare i cinque
  conteggi.
- La riga «il calcolo non riproduce total_cost_usd»: un dato, non un errore.
  Guardate i cinque conteggi e il listino: i prezzi di `listino.json` hanno una
  data.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M8-E01`.

## Impronta d'uso sul piano Pro

Haiku con effort low, nessuno strumento al passo 2, nessun subagent: una
chiamata di un turno, e una richiesta in una sessione interattiva breve. Il
modello predefinito di Claude Code sul Pro è un altro: «Pro, Max, Ultra, Team,
Enterprise, and Anthropic API: defaults to Opus 5.5»
(https://code.claude.com/docs/en/model-config). Il corso fissa Haiku per tenere
piccolo il consumo.

La chiamata del passo 2, nella registrazione del corso (10 novembre 2026, Claude
Code 2.1.322, sull'account del docente): un turno, 12 secondi, 3.902 token in
entrata (2 in `input_tokens`, 767 scritti nella cache a un'ora, 3.133 letti
dalla cache) e 1.950 in uscita. La richiesta del passo 3 si fa in una sessione interattiva breve, su Haiku con
effort low: il suo consumo dipende da quanti turni fa Claude e non è misurato qui.
Le vostre cifre saranno altre. I token dicono quanto lavoro è stato, non
quanta parte del vostro piano occupa; il consumo si legge con `/usage`: «when
you’re signed in with your Claude plan, the Claude Agent SDK and claude -p
still draw from your subscription limits.»
(https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan).

## Per approfondire

- La pagina sui costi, con la formula: https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- I prezzi: https://platform.claude.com/docs/en/about-claude/pricing, e quelli
  di Haiku 5.5: https://platform.claude.com/docs/en/models/haiku-5-5/overview
- `claude -p` e il JSON: https://code.claude.com/docs/en/headless
- I costi in Claude Code e `/usage`: https://code.claude.com/docs/en/costs
- La cache in Claude Code: https://code.claude.com/docs/en/prompt-caching
