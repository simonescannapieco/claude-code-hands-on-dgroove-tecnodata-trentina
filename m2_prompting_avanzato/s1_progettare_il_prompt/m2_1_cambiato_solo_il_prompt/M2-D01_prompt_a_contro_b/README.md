# M2-D01 — Prompt A contro prompt B

Demo del Modulo 2, nella parte «È cambiato solo il prompt». In aula la
esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova una raccomandazione di Anthropic: Claude risponde bene
a istruzioni chiare ed esplicite. Lo stesso messaggio di un cliente, sullo
stesso modello, una volta con «Riassumi.», una volta con un prompt di
cinque righe che chiede una scheda precisa; il controllo legge, una per
una, cinque istruzioni del secondo prompt.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D01)

Lo spazio di lavoro `~/corso-claude-code/M2-D01/` con:

- `messaggio.md`: il messaggio di un cliente business, la Falegnameria
  Fittizia di Rovereto: il centralino fermo venerdì, ordini persi, il numero
  della segnalazione perso, una domanda sull'indennizzo, una sulla linea di
  riserva, un telefono per richiamare;
- `prompt-a.md`: «Riassumi.» e il messaggio;
- `prompt-b.md`: cinque righe (ruolo, contesto, istruzione, formato,
  vincoli) e il messaggio tra i tag `<messaggio>`;
- `istruzione.txt`: il system prompt delle due chiamate, «Rispondi in
  italiano.»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato;
- `controlla_istruzioni.py`: il controllo che esegue
  `tools/verifica.sh M2-D01`, da leggere se volete sapere che cosa conta
  come tabella, come parola, come nome.

Il messaggio è inventato, come tutti i dati del corso.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D01
       cd ~/corso-claude-code/M2-D01

2. Le due chiamate, su Sonnet, con le stesse opzioni:

       chiedi() {
         claude -p "$(cat "$1")" --model sonnet --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --output-format json
       }
       a="$(chiedi prompt-a.md)"
       b="$(chiedi prompt-b.md)"

3. Raccogliete token e risposte in `confronto.tsv`:

       riga() {
         printf '%s\t%s\t%s\t%s\n' "$1" \
           "$(python3 leggi_json.py token_entrata <<< "$2")" \
           "$(python3 leggi_json.py token_uscita <<< "$2")" \
           "$(python3 leggi_json.py result <<< "$2")" | tee -a confronto.tsv
       }
       printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\n' > confronto.tsv
       riga A "$a"; riga B "$b"

## Che cosa osservare

### Che cosa dice Anthropic

- La guida «Best practice per il prompting», nella sezione «Sii chiaro e
  diretto»: «Claude risponde bene a istruzioni chiare ed esplicite. Essere
  specifici sull'output desiderato può aiutare a migliorare i risultati.»
  Poco sotto: «Sii specifico sul formato di output e sui vincoli che
  desideri.»
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices

  Sono raccomandazioni: dicono che cosa aiuta, non promettono che ogni
  risposta rispetti ogni istruzione. Il prompt B le segue: le righe
  «Formato» e «Vincoli» dicono la forma della scheda e i suoi limiti.
- La guida al prompt caching, sul conteggio dei token: «La risposta di
  utilizzo include tre campi separati per i token di input che insieme
  rappresentano il tuo input totale». Sono `input_tokens`,
  `cache_creation_input_tokens` e `cache_read_input_tokens`;
  `leggi_json.py token_entrata` ne fa la somma.
  https://platform.claude.com/docs/it/build-with-claude/prompt-caching

### Che cosa misura il controllo

Il controllo legge `confronto.tsv` e stampa, per A e per B, i token in
entrata e in uscita, le parole e che cosa contiene la risposta: la
tabella, «non indicato», il nome e il telefono del cliente. Per A sono
soltanto dati: «Riassumi.» non chiede niente di tutto questo.

Poi dà un esito a cinque istruzioni del prompt B, «rispettata» oppure
«non rispettata in questa esecuzione»:

- le colonne: la prima tabella della risposta ha le colonne Problema,
  Quando, Impatto, Priorità, Team proposto, in quest'ordine e nessun'altra
  (il grassetto e le maiuscole non contano; «Priorità» può continuare con
  «(bassa/media/alta/urgente)»);
- «non indicato»: la formula compare almeno una volta. Il controllo non sa
  dove manca un dato: guarda soltanto se la formula chiesta c'è;
- niente nome: non compaiono «Franco», «Fittizio» né «Fittizia», con la
  maiuscola, cioè chi scrive e la sua azienda;
- niente telefono: non compare 000 000 0103, con o senza spazi, punti o
  trattini fra i gruppi;
- al massimo 120 parole: una parola è una sequenza di lettere o cifre, e
  un apostrofo la unisce alla seguente («l'assistenza» è una parola); i
  segni della tabella e del grassetto non contano.

Sono raccomandazioni: un esito «non rispettata» si legge, e la verifica
non fallisce. Le altre richieste di B (una riga per problema, le righe
«Richieste del cliente» e «Dati mancanti», il tono neutro, i valori della
priorità) il controllo non le giudica: le guardate voi.

Una garanzia, invece, decide l'uscita: B manda più token in entrata di A.
B ha lo stesso messaggio e lo stesso system prompt di A, con cinque righe
al posto di «Riassumi.»: il suo input è più lungo, a ogni esecuzione. Se
non torna, la verifica esce con 1.

Nella registrazione del corso (16 ottobre 2026, Claude Code 2.1.301,
Sonnet, una chiamata per prompt): quattro istruzioni su cinque rispettate;
«al massimo 120 parole» non rispettata, con 131 parole. La garanzia
confermata: 937 token in entrata per A, 1.211 per B; in uscita 475 e 452.
Il riassunto di A, 157 parole, riporta il nome e il telefono del cliente.
Una chiamata dice che cosa è successo quella volta, non che cosa succede
sempre.

## Verifica (tools/verifica.sh M2-D01)

Dalla cartella `esercitazioni`, `tools/verifica.sh M2-D01` esegue il
controllo descritto qui sopra e ne stampa i numeri e gli esiti. Esce con 0
quando in `confronto.tsv` ci sono le due risposte e la garanzia è
confermata; l'ultima riga è allora «Fatto: ogni affermazione è stata messa
alla prova; gli esiti sono qui sopra.» Esce con 1 quando manca una
risposta o un numero di token, o la garanzia non è confermata; con 2
quando non può partire (manca lo spazio di lavoro o python3,
`confronto.tsv` non si legge).

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Un JSON vuoto: rilanciate la chiamata di quel prompt
  (`a="$(chiedi prompt-a.md)"` o `b="$(chiedi prompt-b.md)"`), poi
  `riga A "$a"; riga B "$b"` su un `confronto.tsv` ricreato con la sua
  intestazione.
- Un'istruzione «non rispettata in questa esecuzione»: non è un errore, è
  l'esito di quella risposta, e la verifica lo riporta senza fallire.
- «più token in entrata per B che per A: non confermata in questa
  esecuzione»: controllate di non avere scambiato le righe (A è
  «Riassumi.», B il prompt di cinque righe) e che le due chiamate abbiano
  le stesse opzioni.
- Token molto diversi da quelli registrati: le vostre impostazioni utente
  di Claude Code (per esempio un hook o un `CLAUDE.md` personale) entrano
  anche in queste chiamate, e pesano allo stesso modo in tutte e due.
  Cambiano i numeri, non la garanzia, che confronta B con A.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D01`.

## Impronta d'uso sul piano Pro

Due chiamate brevi su Sonnet, con effort low, nessuno strumento e nessun
subagent.

## Per approfondire

- La guida «Prompting best practices» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La lezione «Effective prompting techniques» del corso AI Fluency della
  Claude Academy:
  https://academy.claude.com/courses/ai-fluency-framework-foundations/effective-prompting-techniques
