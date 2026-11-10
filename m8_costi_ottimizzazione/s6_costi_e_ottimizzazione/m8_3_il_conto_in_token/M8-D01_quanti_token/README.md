# M8-D01 — Quanti token pesa una frase

Demo del Modulo 8, nella parte «Il conto in token». La fa il docente, dal vivo,
con la sua chiave API: i partecipanti vedono il comando sullo schermo e il
conteggio sulla slide. Il piano Pro non include l'API, quindi non è un passo per
voi: «The Pro plan is a paid plan for our Claude chat experience. … The Pro plan
does not include API usage through the Claude Console.»
(https://support.claude.com/en/articles/8325606-what-is-the-pro-plan).

## Obiettivo

Vedere quanti token pesa un testo prima di spedirlo a Claude. Una richiesta HTTP
all'endpoint di conteggio dei token, che risponde con un numero e non crea
niente. Lo stesso messaggio di un cliente, in italiano e in inglese: il
significato è lo stesso, i token no. Con lo stesso script il docente conta anche
altri file: è così che, nel debrief del laboratorio sui token, si misura un
prompt prima e dopo.

## Tempo

2 minuti in aula, la demo del docente: due chiamate.

## Prerequisiti

- La chiave API del docente, nella variabile d'ambiente `ANTHROPIC_API_KEY`.
  Senza, `_docente/live.sh` e `demo/chiama.sh` si fermano subito e non
  chiamano nulla.
- `curl`, Python 3 e git, che lo script verifica.
- Questa demo non usa Claude Code e non consuma il piano Pro.

## Punto di partenza (tools/prepara_esercizio.sh M8-D01)

Lo spazio di lavoro `~/corso-claude-code/M8-D01/` con:

- `testi/frase-it.txt` e `testi/frase-en.txt`: le due frasi da contare, una
  richiesta di un cliente e la sua traduzione;
- `chiama.sh`: le POST con curl, con ogni comando sullo schermo prima che giri;
- `controlla_conteggi.py`: il controllo, che legge i file delle risposte.

Dopo le chiamate compare `risposte/`, con tre file per ogni testo:
`<nome>.richiesta.json`, il corpo della richiesta; `<nome>.json`, il corpo della
risposta; `<nome>.stato`, lo stato HTTP. La chiave non si scrive mai in nessun
file.

## Passi in Claude Code

Qui Claude Code non serve: è l'API, quella che un'applicazione chiama da sé. Con
`claude -p` i token si leggono nel campo `usage` quando il messaggio è ormai
stato spedito, e lo fa la demo M8-D02; questo conteggio arriva prima. Il docente,
dalla cartella `esercitazioni`:

1. Prepara lo spazio di lavoro e mette la chiave nell'ambiente, senza farla
   vedere: `read -rs` la legge senza mostrarla e senza scriverla nella
   cronologia della shell.

       tools/prepara_esercizio.sh M8-D01
       read -rs ANTHROPIC_API_KEY; export ANTHROPIC_API_KEY

   Alla fine della demo: `unset ANTHROPIC_API_KEY`, perché la chiave non resti
   nell'ambiente delle demo che seguono.

2. Lancia la demo:

       m8_costi_ottimizzazione/s6_costi_e_ottimizzazione/m8_3_il_conto_in_token/M8-D01_quanti_token/demo/chiama.sh ~/corso-claude-code/M8-D01

   Per ogni testo lo script costruisce il corpo della richiesta e mostra il
   comando curl prima di eseguirlo: una POST verso
   `https://api.anthropic.com/v1/messages/count_tokens`, con le intestazioni
   `anthropic-version` e `content-type`. Il corpo, per la frase italiana, è
   questo:

   ```json
   {
     "model": "claude-haiku-5-5",
     "messages": [
       {
         "role": "user",
         "content": "La connessione cade ogni sera verso le nove: potete controllare la linea?"
       }
     ]
   }
   ```

   L'autorizzazione, la riga `Authorization: Bearer …`, sta in una
   configurazione che arriva a curl sullo STDIN (`--config -`): non è fra gli
   argomenti, quindi non si vede con `ps` né nella cronologia, e non finisce
   in un file.

3. In sala si guarda la tabella che stampa `controlla_conteggi.py`: per ogni
   testo il numero di caratteri e `input_tokens`; poi la differenza fra
   l'italiano e l'inglese, un dato.

4. Nel debrief del laboratorio sui token, il docente conta anche i prompt dei
   partecipanti: lo stesso script, con i file dopo lo spazio di lavoro. Ogni
   file va per intero in un messaggio utente, così com'è, con i suoi
   segnaposto se ne ha, e `<nome>` è il nome del file senza l'ultima
   estensione:

       m8_costi_ottimizzazione/s6_costi_e_ottimizzazione/m8_3_il_conto_in_token/M8-D01_quanti_token/demo/chiama.sh ~/corso-claude-code/M8-D01 ~/corso-claude-code/M8-E02/prompt/v0.md ~/corso-claude-code/M8-E02/prompt/v1.md

La prova del docente è `_docente/live.sh`, che lancia lo stesso script sui due
testi della demo e poi la verifica; si ferma con uscita 2 se la chiave non c'è.

## Che cosa osservare

### Che cosa dice Anthropic

- A che cosa serve: «Count tokens in a message before sending to manage costs
  and rate limits (POST /v1/messages/count_tokens)»
  (https://platform.claude.com/docs/en/api/overview).
- Che cosa accetta: «accepts the same structured list of inputs for creating a
  message, including support for system prompts, tools, images, and PDFs»
  (https://platform.claude.com/docs/en/build-with-claude/token-counting).
- Che non crea niente: «can be used to count the number of tokens in a
  Message, including tools, images, and documents, without creating it»
  (https://platform.claude.com/docs/en/api/messages/count_tokens).
- Che è una stima: «The token count is an estimate. … the actual number of
  input tokens used when creating a message might differ by a small amount.»
  (https://platform.claude.com/docs/en/build-with-claude/token-counting).
- Quanto costa: «Token counting is free to use but subject to requests per
  minute rate limits based on your usage tier.», nella stessa pagina.
- La cache: «token counting provides an estimate without using caching logic …
  prompt caching only occurs during actual message creation.», nella stessa
  pagina.
- L'autorizzazione e le intestazioni: «Bearer <token>, where <token> is your
  API key … Legacy fallback for Authorization, still supported» e
  «anthropic-version | API version (for example, 2026-10-21) | Yes …
  content-type | application/json | Yes»
  (https://platform.claude.com/docs/en/api/overview).
- Il modello: `claude-haiku-5-5`, il suo nome nell'API, dalla pagina dei modelli
  (https://platform.claude.com/docs/en/models/overview).

### Che cosa misura il controllo

`controlla_conteggi.py` legge i file di `risposte/`, testo per testo, e stampa
la tabella: il nome del file, i caratteri del testo, `input_tokens`. Quando ci
sono le due frasi della demo, stampa anche quanti token ha l'italiano in più o
in meno dell'inglese: una misura, nessun verdetto. Decide soltanto ciò che
l'endpoint promette, sulle risposte salvate: ogni testo ha un conteggio, un
intero positivo, con stato HTTP 200, e la risposta non porta `id`, `content`,
`stop_reason` né `usage`, i campi di un messaggio creato: contare non ha creato
niente. Se un conteggio manca, non è un intero positivo o la risposta è un
messaggio, l'uscita è 1. Che il conteggio sia una stima e che differisca di poco
dal numero di token di un messaggio creato lo dice la pagina: la demo non crea
il messaggio, quindi non lo confronta.

Nella registrazione del corso, in `soluzione/risposte/` (nel repository del
corso; la copia senza soluzioni non l'ha), i conteggi delle due frasi fatti dal
docente con questo script: il LEGGIMI della cartella dice la data, gli stati e i
due numeri.

## Verifica (tools/verifica.sh M8-D01)

La verifica fa girare `controlla_conteggi.py` dell'elemento, non la copia dello
spazio di lavoro, su `risposte/`: esce 0 se ogni testo ha il suo conteggio, un
intero positivo, e nessuna risposta è un messaggio, e allora l'ultima riga è
«Fatto: ogni testo ha il suo conteggio; la tabella è qui sopra.»; 1 se
`risposte/` non c'è o non ha testi contati, oppure se un conteggio manca o non
è valido. Sul punto di partenza intatto esce 1. Non chiama niente: nessuna rete
e nessuna chiave.

## Se qualcosa va storto

- «ANTHROPIC_API_KEY non è impostata»: mettetela nell'ambiente come al passo
  1 e rilanciate; la demo è del docente, e senza la chiave non parte.
- «curl non è riuscito»: la richiesta non è arrivata (rete, proxy,
  certificati): lo script toglie ciò che ha scritto, e si può rilanciare. Se
  in aula la rete non c'è, si mostrano i conteggi registrati sulla slide.
- Uno stato diverso da 200, per esempio 401: la chiamata è arrivata ma non è
  riuscita. Il controllo stampa il tipo e il messaggio dell'errore, che dicono
  perché; la chiave non si stampa mai. La verifica esce 1.
- «il testo … non si può contare»: il file è vuoto o non è in UTF-8.
- «c'è già: quel testo è già contato»: un testo già in `risposte/` non si
  riconta: `tools/reset_esercizio.sh M8-D01`, oppure un file con un altro nome.
- `chiama.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 2, oppure date `PN_HANDSON_ROOT`.

## Impronta d'uso sul piano Pro

Nessuna: la demo non usa Claude Code e le chiamate vanno con la chiave del
docente, non con il piano Pro. Sono due richieste all'endpoint di conteggio,
più una per ogni file dato nel debrief; per il prezzo vale la frase citata qui
sopra su «free to use».

## Per approfondire

- Il conteggio dei token:
  https://platform.claude.com/docs/en/build-with-claude/token-counting
- L'endpoint, parametro per parametro:
  https://platform.claude.com/docs/en/api/messages/count_tokens
- Le richieste e le intestazioni dell'API:
  https://platform.claude.com/docs/en/api/overview
- I modelli e i loro nomi nell'API:
  https://platform.claude.com/docs/en/models/overview
