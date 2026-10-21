# M1-D02 — Stessa frase, due lingue

Demo del Modulo 1, nella parte «Token e finestra di contesto». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Misurare quanti token pesa per Claude la stessa frase in italiano e in
inglese, leggendo i conteggi che Claude Code riporta. Il tokenizer di
Claude non è pubblico: i conteggi si leggono dalle risposte, non da una
tabella. La documentazione di Anthropic dice che il numero di token, e i
caratteri che un token rappresenta, dipendono dalla lingua: la demo lo
mette alla prova su una frase.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica: lo usano `leggi_json.py` e la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D02)

Lo spazio di lavoro `~/corso-claude-code/M1-D02/` con quattro file:

- `frase_it.txt`: «La riunione è stata rinviata a causa dello sciopero dei
  trasporti.», 66 caratteri;
- `frase_en.txt`: la sua traduzione inglese, «The meeting has been
  postponed because of the transport strike.», 63 caratteri;
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

### Che cosa dice Anthropic

- Il glossario della documentazione, alla voce «Token»: «Per Claude, il
  numero di caratteri rappresentato da un token dipende dal modello e
  dalla lingua.» (https://platform.claude.com/docs/it/about-claude/glossary)
- La pagina dei prezzi: «Il numero di token prodotti dallo stesso testo
  dipende dal tokenizer del modello, dalla lingua e dal tipo di
  contenuto.» (https://platform.claude.com/docs/it/about-claude/pricing)

La demo tiene fermi il modello e il tipo di contenuto, una frase, e cambia
soltanto la lingua: la stessa frase in italiano e in inglese.

### Che cosa misura il controllo

`verifica.sh` legge `conteggi.tsv`. Per ogni modello con i quattro
conteggi calcola il peso delle due frasi, la crescita dal testo singolo al
doppio, e i caratteri per token: i caratteri li conta in `frase_it.txt` e
in `frase_en.txt`, senza l'a capo finale. Poi, per ogni modello, un
verdetto per ciascuna affermazione:

- il numero di token: «confermata» se le due frasi pesano un numero di
  token diverso;
- i caratteri per token: «confermata» se sono diversi; «non
  distinguibile» se manca uno dei due file.

Le due affermazioni dicono «dipende»: su una frase sola una differenza lo
mostra, valori uguali non lo smentiscono. Con valori uguali il verdetto è
allora «non dimostrata in questa esecuzione». «Dipende» non dice quale
lingua pesi di più: l'uscita della verifica non la decidono i verdetti, e
nemmeno il verso della differenza. Esce con 0 quando almeno un modello ha
i quattro conteggi e ogni modello completo ha i due pesi positivi; con 1
quando nessun modello è completo, oppure quando un peso non è positivo:
una misura da rifare. Il verso si stampa come confronto con la
registrazione del corso, un dato: «Nella registrazione del corso la frase
italiana pesa più di quella inglese (27 contro 17): in questa esecuzione
sì», oppure «no».

Nella registrazione del corso dell'11 ottobre 2026 (Claude Code 2.1.296),
su questa frase l'italiano costa più token dell'inglese: 27 contro 17, il
59 % in più, con gli stessi numeri su Haiku, Sonnet e Opus. I caratteri
per token: 2,4 in italiano (66 su 27), 3,7 in inglese (63 su 17). Le due
affermazioni: confermate su tutti e tre i modelli.

## Verifica (tools/verifica.sh M1-D02)

La verifica stampa i due pesi, i caratteri per token, i verdetti di «Che
cosa misura il controllo» e il confronto con la registrazione. Quando
`conteggi.tsv` contiene i quattro conteggi di almeno un modello, e ogni
modello completo ha i due pesi positivi, esce con 0, e la sua ultima riga
è: «Fatto: ogni affermazione è stata messa alla prova; gli esiti sono qui
sopra.»

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Un conteggio vuoto: rilanciate solo quella chiamata, senza
  `| python3 leggi_json.py token_entrata`, e guardate il JSON.
- Un peso che non è positivo, cioè il doppio che non pesa più del singolo
  («Da rifare»): rifate le quattro chiamate di quel modello, dalla cartella
  dello spazio di lavoro.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D02`.

## Impronta d'uso sul piano Pro

Quattro chiamate brevi su Haiku, il modello più leggero, con effort low,
nessuno strumento e nessun subagent: ciascuna manda meno di 700 token.

## Per approfondire

- Il tutorial dell'Academy «Tokens: why some inputs cost more than
  others»: https://academy.claude.com/tutorials/tokens-and-embeddings
- La pagina «Context windows» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/context-windows
