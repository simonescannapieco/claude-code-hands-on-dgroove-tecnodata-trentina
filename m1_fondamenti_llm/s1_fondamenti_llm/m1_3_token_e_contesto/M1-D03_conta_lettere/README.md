# M1-D03 — Contare le lettere

Demo del Modulo 1, nella parte «Token e finestra di contesto». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Misurare quanti token pesa per Claude una parola e confrontarli con le sue
lettere: «interconnessione», 16 lettere; la stessa parola scritta lettera
per lettera, con gli spazi in mezzo; «strawberry», 10 lettere. Così si
mettono alla prova tre affermazioni che il controllo ricava dalle pagine
di Anthropic su come il testo arriva al modello (le pagine e le loro
frasi sono in «Che cosa osservare»). Il tokenizer di
Claude non è pubblico: i conteggi si leggono dalle risposte di Claude Code,
come in M1-D02.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D03)

Lo spazio di lavoro `~/corso-claude-code/M1-D03/` con sei file:

- `parola.txt`: «interconnessione»;
- `compitata.txt`: la stessa parola con le lettere separate da spazi,
  «i n t e r c o n n e s s i o n e»;
- `strawberry.txt`: «strawberry»;
- `istruzione.txt`: l'istruzione di sistema, «Rispondi solo: ok»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato;
- `controlla_pesi.py`: calcola i pesi e mette alla prova le tre
  affermazioni.

## Passi in Claude Code

Con `--output-format json`, `claude -p` restituisce un JSON che riporta
anche l'uso: i token in entrata sono la somma di `input_tokens`,
`cache_creation_input_tokens` e `cache_read_input_tokens`. Oltre al testo
il modello riceve sempre qualcosa d'altro, per esempio l'istruzione di
sistema. Per isolare il peso di un testo si manda il testo da solo, poi lo
stesso testo due volte, separato da uno spazio: la differenza è il testo.
È il metodo di M1-D02. Nel testo doppio la seconda copia arriva dopo lo
spazio, quindi il peso di «interconnessione» misurato così è quello di
« interconnessione», con lo spazio davanti.

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M1-D03
       cd ~/corso-claude-code/M1-D03

2. Una previsione: «interconnessione» pesa più o meno di 16 token? E
   scritta lettera per lettera?

3. Le sei chiamate, su Haiku: ogni testo da solo e ripetuto due volte.

       printf 'modello\ttesto\ttoken_entrata\n' > conteggi.tsv
       for m in haiku; do
         for f in parola compitata strawberry; do
           t="$(cat "$f.txt")"
           for etichetta in "$f" "$f-doppia"; do
             testo="$t"
             if [[ "$etichetta" == "$f-doppia" ]]; then testo="$t $t"; fi
             n="$(claude -p "$testo" --model "$m" --effort low --tools "" \
               --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
               --no-session-persistence --output-format json \
               | python3 leggi_json.py token_entrata)"
             printf '%s\t%s\t%s\n' "$m" "$etichetta" "$n" | tee -a conteggi.tsv
           done
         done
       done

   Con `for m in haiku sonnet opus` le chiamate diventano diciotto, sei per
   modello, e si mette alla prova anche la terza affermazione. Le chiamate
   del docente e quelle della registrazione del corso mandano gli stessi
   testi con le stesse opzioni, più `--setting-sources project,local`,
   `--permission-mode dontAsk` e `--permission-prompts none`.

4. I pesi e le tre affermazioni:

       python3 controlla_pesi.py

   Per ogni modello e ogni testo stampa i token del singolo e del doppio,
   il peso (il doppio meno il singolo) e le lettere, che conta da sé; poi
   i token per lettera della parola compitata, un dato senza verdetto, e
   una riga per affermazione. Lo stesso controllo lo fa la verifica.

## Che cosa osservare

### Che cosa dice Anthropic

- Il glossario della documentazione, alla voce «Token»
  (https://platform.claude.com/docs/it/about-claude/glossary):
  - «Quando a Claude viene fornito un testo da valutare, il testo
    (costituito da una serie di caratteri) viene codificato in una serie
    di token che il modello elabora.»
  - I token «sono le unità individuali più piccole di un modello
    linguistico e possono corrispondere a parole, sottoparole, caratteri o
    persino byte (nel caso di Unicode)».
  - «Token più grandi migliorano l'efficienza dei dati durante
    l'inferenza e il preaddestramento (e vengono utilizzati quando
    possibile), mentre token più piccoli consentono a un modello di
    gestire parole insolite o mai viste prima.»
- Il tutorial dell'Academy «Tokens: why some inputs cost more than others»
  (https://academy.claude.com/tutorials/tokens-and-embeddings): al modello
  il testo arriva come numeri, «non un numero per carattere da una tabella
  fissa: un numero per pezzo di testo, da un vocabolario che il modello ha
  imparato»; e «un pezzo di testo con il suo ID numerico si chiama token»
  (traduzione nostra).
- La pagina dei prezzi, nelle domande frequenti
  (https://platform.claude.com/docs/it/about-claude/pricing): «Claude 4.7 e
  i modelli successivi e Claude Mythos Preview utilizzano un tokenizer più
  recente che produce circa il 30 percento di token in più per lo stesso
  testo rispetto ai modelli precedenti.»
- La pagina «Configurazione del modello» di Claude Code
  (https://code.claude.com/docs/it/model-config): «Gli alias `opus`,
  `sonnet` e `haiku` si risolvono nella versione più recente sull'API
  Anthropic»: nella sua tabella, Opus 5.5, Sonnet 5.5 e Haiku 5.5. Tutti e
  tre vengono dopo la 4.7, quindi usano lo stesso tokenizer.

### Che cosa misura il controllo

`controlla_pesi.py`, e con lui la verifica, legge `conteggi.tsv` e i tre
testi. Per ogni modello calcola il peso di ogni testo, il doppio meno il
singolo; le lettere le conta da sé, solo le lettere: 16 in
«interconnessione», 16 nella parola compitata, 10 in «strawberry».
Stampa i numeri letti, poi una riga per affermazione:

- «Ogni parola pesa meno token delle sue lettere»: confermata se
  «interconnessione» e «strawberry» pesano meno token delle loro lettere,
  su ogni modello.
- «La parola compitata pesa più token della parola intera»: confermata se,
  su ogni modello, la parola compitata pesa più token di
  «interconnessione». Le lettere sono le stesse: i due testi differiscono
  solo negli spazi. Il glossario descrive token più grandi, usati quando
  possibile, e token più piccoli per le parole non comuni o mai viste
  prima.
- «Gli stessi pesi su ogni modello»: confermata se i tre pesi sono uguali
  su tutti i modelli. Con un solo modello, come nei passi qui sopra, è «non
  distinguibile».

Le tre sono trattate come garanzie: la verifica passa solo se ogni
affermazione messa alla prova è confermata. I token per lettera della
parola compitata il controllo li stampa come dato, senza verdetto:
nessuna delle tre affermazioni ne fissa il numero.

Nella registrazione del corso del 20 ottobre 2026, con Claude Code
2.1.305, sei chiamate per modello su Haiku, Sonnet e Opus:
«interconnessione» pesa 5 token, la parola compitata 16, «strawberry» 4,
gli stessi pesi sui tre modelli; confermate tutte e tre le affermazioni.
Il dato senza verdetto: la parola compitata pesa 16 token per 16 lettere,
su ogni modello.

## Verifica (tools/verifica.sh M1-D03)

La verifica esegue `controlla_pesi.py` sullo spazio di lavoro e ne stampa
i numeri e gli esiti: passa se `conteggi.tsv` ha i sei conteggi di ogni
modello presente e ogni affermazione messa alla prova è confermata.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Un conteggio vuoto: rilanciate solo quella chiamata, senza
  `| python3 leggi_json.py token_entrata`, e guardate il JSON.
- Un peso che non è positivo, cioè il doppio che non pesa più del singolo:
  rifate le due chiamate di quel testo, dalla cartella dello spazio di
  lavoro.
- Un'affermazione «non confermata» non è un vostro errore: è un esito.
  Segnalatelo al docente, con l'uscita della verifica.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D03`.

## Impronta d'uso sul piano Pro

Sei chiamate brevi su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent. Nella registrazione del corso ognuna
manda al più 588 token in entrata. Con `for m in haiku sonnet opus` le
chiamate sono diciotto. Niente Fable: sul piano Pro funziona solo con i
crediti d'uso (usage credits), a pagamento.

## Per approfondire

- Il glossario della documentazione, alla voce «Token»:
  https://platform.claude.com/docs/it/about-claude/glossary
- Il tutorial dell'Academy «Tokens: why some inputs cost more than
  others»: https://academy.claude.com/tutorials/tokens-and-embeddings
- M1-D02, «Stessa frase, due lingue»: lo stesso metodo, sulla stessa frase
  in italiano e in inglese.
