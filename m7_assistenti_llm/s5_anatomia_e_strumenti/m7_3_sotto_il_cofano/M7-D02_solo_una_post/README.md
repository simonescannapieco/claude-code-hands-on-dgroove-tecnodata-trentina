# M7-D02 — Solo una POST

Demo del Modulo 7, nella parte «Sotto il cofano». La fa il docente, dal vivo,
con la sua chiave API: i partecipanti vedono il comando sullo schermo e la
risposta sulla slide. Il piano Pro non include l'API, quindi non è un passo
per voi: «The Pro plan does not include API usage through the Claude Console.»
(https://support.claude.com/en/articles/8325606-what-is-the-pro-plan).

## Obiettivo

Vedere che cosa c'è sotto un assistente costruito su Claude: una richiesta
HTTP, nient'altro. Una POST con un corpo JSON che porta il modello, il massimo
di token da generare e i messaggi; una risposta JSON che porta il testo, il
motivo per cui Claude si è fermato e quanti token ha usato. Le istruzioni e gli
strumenti del Modulo 7 stanno in questa stessa richiesta, nel campo `system` e
nelle definizioni degli strumenti.

## Tempo

2 minuti in aula, la demo del docente: una sola chiamata.

## Prerequisiti

- La chiave API del docente, nella variabile d'ambiente `ANTHROPIC_API_KEY`.
  Senza, `_docente/live.sh` e `demo/chiama.sh` si fermano subito e non
  chiamano nulla.
- `curl`, Python 3 e git, che lo script verifica.
- Questa demo non usa Claude Code e non consuma il piano Pro.

## Punto di partenza (tools/prepara_esercizio.sh M7-D02)

Lo spazio di lavoro `~/corso-claude-code/M7-D02/` con:

- `corpo.json`: il corpo della richiesta, quello che si vede sulla slide;
- `chiama.sh`: la POST con curl, con il comando sullo schermo prima che giri;
- `controlla_risposta.py`: il controllo, che legge la risposta campo per
  campo.

Dopo la chiamata compare `risposte/`, con `risposta.json`, il corpo della
risposta, e `stato.txt`, lo stato HTTP. La chiave non si scrive mai in nessun
file.

## Passi in Claude Code

Qui Claude Code non serve: questa è la chiamata nuda all'API, quella che
un'applicazione fa da sé. Il docente, dalla cartella `esercitazioni`:

1. Prepara lo spazio di lavoro e mette la chiave nell'ambiente, senza farla
   vedere: `read -rs` la legge senza mostrarla e senza scriverla nella
   cronologia della shell.

       tools/prepara_esercizio.sh M7-D02
       read -rs ANTHROPIC_API_KEY; export ANTHROPIC_API_KEY

2. Lancia la demo:

       m7_assistenti_llm/s5_anatomia_e_strumenti/m7_3_sotto_il_cofano/M7-D02_solo_una_post/demo/chiama.sh ~/corso-claude-code/M7-D02

   Lo script mostra il corpo della richiesta, che è tutto qui:

   ```json
   {
     "model": "claude-haiku-5-5",
     "max_tokens": 100,
     "messages": [
       {
         "role": "user",
         "content": "In una frase: che differenza c'è fra una linea FTTH e una linea FWA?"
       }
     ]
   }
   ```

   Poi mostra il comando curl prima di eseguirlo: una POST verso
   `https://api.anthropic.com/v1/messages`, con le intestazioni
   `anthropic-version` e `content-type` e il corpo letto da `corpo.json`.
   L'autorizzazione, la riga `Authorization: Bearer …`, sta in una
   configurazione che arriva a curl sullo STDIN (`--config -`): non è fra gli
   argomenti, quindi non si vede con `ps` né nella cronologia, e non finisce
   in un file.

3. In sala si guarda ciò che stampa `controlla_risposta.py`, una riga per
   campo: lo stato HTTP, `stop_reason`, `usage`.

La prova del docente è `_docente/live.sh`, che lancia lo stesso script e poi
la verifica; si ferma con uscita 2 se la chiave non c'è.

Perché `curl` e non un SDK: per far vedere che sotto non c'è altro. I client
SDK di Anthropic sono proprio questo: «General-purpose Messages API clients for
Python, TypeScript, C#, Go, Java, PHP, and Ruby.»
(https://platform.claude.com/docs/en/cli-sdks-libraries/overview).

## Che cosa osservare

### Che cosa dice Anthropic

- La chiamata: «Send messages to Claude for conversational interactions (POST
  /v1/messages)» (https://platform.claude.com/docs/en/api/overview).
- L'autorizzazione e le intestazioni, nella stessa pagina: «Bearer <token>,
  where <token> is your API key … Legacy fallback for Authorization, still
  supported» e «anthropic-version | API version (for example, 2026-10-21) |
  Yes … content-type | application/json | Yes». La vecchia `x-api-key` è il
  fallback di cui parla la frase.
- Il corpo: «max_tokens: number … messages: array of MessageParam … model:
  Model … system: optional string or array of TextBlockParam»
  (https://platform.claude.com/docs/en/api/messages/create). Il `system`
  qui non c'è, ed è facoltativo: il system prompt del Modulo 7 è un campo di
  questa stessa richiesta, quando c'è. Di `max_tokens` la pagina dice: «The
  maximum number of tokens to generate before stopping. … Note that our
  models may stop before reaching this maximum.»
- Il motivo per cui si ferma: «The stop_reason field is part of every
  successful Messages API response. … stop_reason tells you why Claude
  completed its response generation.», e i valori possibili sono «end_turn |
  max_tokens | stop_sequence | tool_use | pause_turn | refusal |
  model_context_window_exceeded»
  (https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons).
- Il modello: `claude-haiku-5-5`, il suo nome nell'API, dalla pagina dei modelli
  (https://platform.claude.com/docs/en/models/overview).
- Che cosa porta la richiesta: «Everything in the request counts toward the
  context window: the system prompt, every message in messages … and your tool
  definitions.»
  (https://platform.claude.com/docs/en/build-with-claude/context-windows).

### Che cosa misura il controllo

`controlla_risposta.py` legge `risposte/stato.txt` e `risposte/risposta.json`
e stampa, una riga per campo: lo stato HTTP; `stop_reason`; `usage`, con
`input_tokens` e `output_tokens` ed eventuali altre voci come dato; il modello,
l'`id` e il testo della risposta. È una dimostrazione di ciò che la
documentazione dice e che la risposta mostra; decide una cosa sola: la risposta
è un successo, stato 200, e ha `stop_reason` e `usage`? Se non lo è stampa
il tipo e il messaggio dell'errore, con ogni cosa che somiglia a una chiave
mascherata. Il testo della risposta non si giudica.

Nella registrazione del corso, in `soluzione/risposte/` (nel repository del
corso; la copia senza soluzioni non l'ha), una chiamata fatta dal docente con
questo script: il LEGGIMI della cartella dice data, stato, `stop_reason` e i
token di quella chiamata.

## Verifica (tools/verifica.sh M7-D02)

La verifica fa girare `controlla_risposta.py` dell'elemento, non la copia dello
spazio di lavoro, su `risposte/`: esce 0 se lo stato è 200 e la risposta ha
`stop_reason` e `usage`, e allora l'ultima riga è «Fatto: la risposta è
riuscita; stato, stop_reason e usage sono qui sopra.»; 1 se `risposte/` non c'è
o la risposta non è un successo. Sul punto di partenza intatto esce 1. Non
chiama niente: nessuna rete e nessuna chiave.

## Se qualcosa va storto

- «ANTHROPIC_API_KEY non è impostata»: mettetela nell'ambiente come al passo
  1 e rilanciate; la demo è del docente, e senza la chiave non parte.
- «curl non è riuscito»: la richiesta non è arrivata (rete, proxy,
  certificati). Se in aula la rete non c'è, si mostra la risposta registrata
  sulla slide.
- Uno stato diverso da 200, per esempio 401: la chiamata è arrivata ma non è
  riuscita. Il controllo stampa il tipo e il messaggio dell'errore, che dicono
  perché; la chiave non si stampa mai. La verifica esce 1.
- «risposte/ c'è già», oppure «non è lo spazio di lavoro»: per ricominciare,
  `tools/reset_esercizio.sh M7-D02`, poi `tools/prepara_esercizio.sh M7-D02`.

## Impronta d'uso sul piano Pro

Nessuna: la chiamata usa la chiave del docente, non il piano Pro. Una sola
richiesta su `claude-haiku-5-5`, con al massimo 100 token in uscita, al di
fuori di Claude Code; i token della chiamata registrata sono nel campo `usage`
di `soluzione/risposte/risposta.json` (nel repository del corso; la copia senza
soluzioni non l'ha).

## Per approfondire

- La pagina sulle richieste e sulle intestazioni:
  https://platform.claude.com/docs/en/api/overview
- Il corpo della richiesta:
  https://platform.claude.com/docs/en/api/messages/create
- I motivi per cui Claude si ferma:
  https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons
- I modelli e i loro nomi nell'API:
  https://platform.claude.com/docs/en/models/overview
