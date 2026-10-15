# M1-D02 — Stessa frase, due lingue

Demo del Modulo 1, nella parte «Token e finestra di contesto». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Misurare quanti token pesa per Claude la stessa frase in italiano e in
inglese, leggendo i conteggi che Claude Code riporta. Il tokenizer di
Claude non è pubblico: i conteggi si leggono dalle risposte, non da una
tabella.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D02)

Lo spazio di lavoro `~/corso-claude-code/M1-D02/` con quattro file:

- `frase_it.txt`: «La riunione è stata rinviata a causa dello sciopero dei
  trasporti.»;
- `frase_en.txt`: la sua traduzione inglese;
- `istruzione.txt`: l'istruzione di sistema, «Rispondi solo: ok»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

## Passi in Claude Code

Con `--output-format json`, `claude -p` restituisce un JSON che riporta
anche l'uso: i token in entrata sono la somma di `input_tokens`,
`cache_creation_input_tokens` e `cache_read_input_tokens`. Oltre alla frase
il modello riceve sempre qualcosa d'altro, per esempio l'istruzione di
sistema. Per isolare il peso della frase si manda la frase da sola, poi la
stessa frase due volte: la differenza è la frase.

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M1-D02
       cd ~/corso-claude-code/M1-D02

2. Una previsione: quanti token pesa la frase italiana? E l'inglese?

3. Le quattro chiamate, su Haiku:

       it="$(cat frase_it.txt)"; en="$(cat frase_en.txt)"
       printf 'modello\ttesto\ttoken_entrata\n' > conteggi.tsv
       for t in it it-doppia en en-doppia; do
         case "$t" in
           it) testo="$it" ;;  it-doppia) testo="$it $it" ;;
           en) testo="$en" ;;  en-doppia) testo="$en $en" ;;
         esac
         n="$(claude -p "$testo" --model haiku --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --no-session-persistence --output-format json \
           | python3 leggi_json.py token_entrata)"
         printf 'haiku\t%s\t%s\n' "$t" "$n" | tee -a conteggi.tsv
       done

   `leggi_json.py`, nello spazio di lavoro, legge il JSON e stampa la
   somma dei token in entrata.

4. Il peso di ogni frase è la crescita dal testo singolo al doppio:
   `it-doppia` meno `it`, `en-doppia` meno `en`. Lo calcola anche la
   verifica.

## Che cosa osservare

- Nelle registrazioni del corso la frase italiana pesa 27 token e quella
  inglese 17, il 59 % in più, con gli stessi numeri su Haiku, Sonnet e
  Opus.
- Lo stesso testo costa più token in italiano che in inglese: i token sono
  anche il metro dei costi e dei limiti d'uso.
- Quanti token produce lo stesso testo dipende dal tokenizer del modello:
  il tokenizer di un altro produttore dà altri numeri.

## Verifica (tools/verifica.sh M1-D02)

`conteggi.tsv` contiene i quattro conteggi di almeno un modello, e per
ciascun modello completo la frase italiana pesa più di quella inglese, che
pesa più di zero. La verifica stampa i due pesi.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Un conteggio vuoto: rilanciate solo quella chiamata, senza
  `| python3 leggi_json.py token_entrata`, e guardate il JSON.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D02`.

## Impronta d'uso sul piano Pro

Quattro chiamate brevi su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent: ciascuna manda meno di 700 token.

## Per approfondire

- Il tutorial dell'Academy «Tokens: why some inputs cost more than
  others»: https://academy.claude.com/tutorials/tokens-and-embeddings
- La pagina «Context windows» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/context-windows
