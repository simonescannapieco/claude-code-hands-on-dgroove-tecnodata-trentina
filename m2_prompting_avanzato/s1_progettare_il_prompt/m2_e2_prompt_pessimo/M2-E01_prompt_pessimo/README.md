# M2-E01 — Il prompt pessimo: misura, riscrivi, rimisura

Esercitazione del Modulo 2, nella pratica «Il prompt pessimo». È il primo
lavoro del modulo che fate in Claude Code.

## Obiettivo

Mettere alla prova una frase della guida di Anthropic sui prompt: «Più
precisamente spieghi cosa vuoi, migliore sarà il risultato.» Misurate un
prompt pessimo, lo riscrivete con gli ingredienti del template e lo
rimisurate, con i controlli scritti in codice e con un giudice, un subagent
che verifica le affermazioni di una rubrica. Prima di fidarvi del giudice
lo mettete alla prova: sulla risposta di v0 giudica due volte.

## Tempo

30 minuti: quattro per la consegna e i primi passi, sette per scrivere la
nuova versione del prompt (sei di scrittura), dodici per misurare,
confrontare e compilare il registro, sette per il confronto dal vivo.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- `claude --version` 2.1.293 o successiva: il giudice gira su Haiku, e con
  le versioni precedenti l'alias `haiku` punta a un modello più vecchio.
- Python 3, che lo stesso controllo verifica: lo usano `misura.sh` e la
  verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-E01)

Lo spazio di lavoro `~/corso-claude-code/M2-E01/` con:

- `prompt/v0.md`: il prompt pessimo, «scrivi risposta al cliente», e sotto
  il segnaposto `{{messaggio}}`;
- `dati/messaggio.md`: il messaggio di un cliente business, la
  Falegnameria Fittizia di Rovereto, rimasta senza centralino;
- `dati/procedure.md`: gli estratti della base di conoscenza
  dell'assistenza che valgono per le sue richieste (indennizzi, deviazione
  d'emergenza delle chiamate, offerte);
- `rubrica.md`: le affermazioni che il giudice verifica sulla risposta;
- `controlli.tsv`: i controlli scritti in codice (il telefono del cliente,
  i segnaposto da completare, la lunghezza);
- `misura.sh`, `strumenti/kit.py`, `schema-giudizio.json` e
  `.claude/agents/giudice.md`: gli attrezzi della misura;
- `registro.md`: il registro delle versioni, da compilare, con la colonna
  «pratica».

Ogni criterio, in `rubrica.md` e in `controlli.tsv`, porta tra parentesi
quadre (in `controlli.tsv`, nell'ultima colonna) la pratica che lo legge:
`chiarezza` per tutti, tranne l'affermazione `fatti`, che porta
`contesto`. I criteri sono fissati prima di ogni prompt e restano gli
stessi per tutte le versioni.

`misura.sh` mette al posto di ogni `{{nome}}` il file `dati/<nome>.md`:
così ogni versione del prompt lavora sugli stessi dati, e cambia una cosa
sola, il testo. Il messaggio e le procedure sono inventati, come tutti i
dati del corso.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`, poi aprite Claude Code su Sonnet:

       tools/prepara_esercizio.sh M2-E01
       cd ~/corso-claude-code/M2-E01
       claude --model sonnet

2. Misurate il prompt di partenza. Nella sessione, una riga che comincia
   con `!` è un comando di shell: gira senza passare da Claude, e il suo
   output entra nella conversazione.

       ! ./misura.sh v0

   `misura.sh` stampa ogni comando prima di eseguirlo e su v0 fa quattro
   passi: la risposta di Sonnet al prompt, con `claude -p`; i controlli di
   `controlli.tsv`; il giudizio del subagent `giudice`, su Haiku, con un
   JSON vincolato dallo schema; un secondo giudizio della stessa risposta.
   Leggete la risposta, i due elenchi di ✓ e ✗, ognuno con la sua pratica,
   e la riga «Giudice su v0»: su quante affermazioni i due giudizi danno lo
   stesso esito.

3. Scrivete nel registro la pratica di v1 prima di riscrivere il prompt:
   nella riga di v1 di `registro.md`, colonna «pratica», `chiarezza`.
   L'elenco delle pratiche, ognuna con la frase di Anthropic che mette
   alla prova:

       ! ./misura.sh --pratiche

4. Scrivete la nuova versione, sei minuti. Copiate la vecchia:

       ! cp prompt/v0.md prompt/v1.md

   e riscrivete `prompt/v1.md` nel vostro editor, con le righe del
   template come domande: chi scrive e a chi (ruolo); che cosa deve sapere
   (contesto: il messaggio e le procedure, con `{{procedure}}`); che cosa
   deve fare (istruzione); in che forma (lunghezza, firma); con quali
   limiti (che cosa si può promettere, che cosa si fa dei dati
   personali); e, se volete, un esempio (una frase nel tono giusto). Fra
   doppie graffe c'è un segnaposto: `misura.sh` ci mette il file di
   `dati/` con quel nome. Mettete i dati tra tag:
   `<messaggio>` `{{messaggio}}` `</messaggio>`. Se qualcosa non è chiaro,
   chiedete a Claude di farvi domande sul compito prima di scrivere.
   - **Percorso A, un vostro caso:** sostituite `dati/messaggio.md` con il
     messaggio di un vostro cliente, con i dati sostituiti da valori
     inventati. Adattate poi ciò che è legato al caso di CiaspoLink:
     `controlli.tsv` (il telefono da cercare è quello del vostro
     messaggio), `dati/procedure.md` (le vostre regole, oppure togliete
     `{{procedure}}` dal prompt) e le affermazioni di `rubrica.md` che
     nominano le procedure o CiaspoLink, con la loro pratica; poi
     rimisurate v0. I criteri si cambiano prima di misurare v0, non dopo.
   - **Percorso B, il caso di CiaspoLink:** il messaggio della
     Falegnameria, così com'è. La prova del docente è su questo.

5. Misurate la nuova versione e confrontatela con v0:

       ! ./misura.sh v1
       ! ./misura.sh --confronta v0 v1
       ! git diff --no-index prompt/v0.md prompt/v1.md

   Il confronto stampa la pratica di v1 con la frase di Anthropic, ogni
   criterio prima e dopo, l'esito della pratica, poi i totali e i token.
   Leggetelo con Claude:

       Confronta giudizi/v0.json e giudizi/v1.json: quali affermazioni sono cambiate, e con quale motivo del giudice?

6. Compilate `registro.md`, le righe di v0 e di v1: che cosa avete
   cambiato e i totali della riga «totali» del confronto (controlli
   superati, affermazioni rispettate). Con l'editor, o dettandoli a Claude.

7. Se avete tempo, la rimisura: v1 di nuovo, senza toccarla. Nella riga di
   v2 del registro scrivete la pratica `rimisura`, poi:

       ! cp prompt/v1.md prompt/v2.md
       ! ./misura.sh v2
       ! ./misura.sh --confronta v1 v2

   Checkpoint: v0 e v1 misurate, registro compilato.

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M2-E01

## Che cosa osservare

### Che cosa dice Anthropic

- La pratica di v1, `chiarezza`, mette alla prova due frasi della guida
  «Best practice per il prompting», sezione «Sii chiaro e diretto»: «Più
  precisamente spieghi cosa vuoi, migliore sarà il risultato.» e «Sii
  specifico sul formato di output desiderato e sui vincoli.» La stessa
  sezione chiede di pensare a Claude «come a un dipendente brillante ma
  nuovo, che non ha contesto sulle tue norme e sui tuoi flussi di lavoro»:
  v0 non spiega niente, la vostra v1 spiega che cosa serve.
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Il giudice si mette alla prova prima di usarlo. La pagina sui criteri di
  successo e sulle valutazioni, della valutazione con un modello: «Testa
  prima per garantire l'affidabilità, poi scala.»
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- L'articolo di Anthropic sulle valutazioni descrive, fra i controlli
  delle prime esecuzioni, la prova che `misura.sh` fa su v0: «Claude
  esegue il valutatore due volte sullo stesso output e riferisce se il
  verdetto è cambiato» (traduzione nostra). E del modello giudice: «non
  dovrebbe essere il modello che state valutando» (traduzione nostra).
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- Il giudizio arriva con `--json-schema`. Il riferimento della CLI:
  «Ottieni output JSON convalidato corrispondente a uno JSON Schema dopo
  che l'agente completa il suo flusso di lavoro (solo modalità print).» La
  pagina sull'esecuzione programmatica: «Se un'esecuzione termina senza un
  output strutturato valido, ad esempio perché Claude ha rifiutato la
  richiesta, la risposta non contiene il campo `structured_output`.»
  https://code.claude.com/docs/it/cli-reference ·
  https://code.claude.com/docs/it/headless
- La rimisura del passo 7 mette alla prova il glossario: «Anche con la
  temperatura impostata a 0, i risultati non saranno completamente
  deterministici e input identici possono produrre output diversi tra le
  chiamate API.»
  https://platform.claude.com/docs/it/about-claude/glossary

### Che cosa misura il controllo

- I criteri vengono prima del prompt, come nella pagina sulle valutazioni:
  un'applicazione «inizia con la definizione chiara dei tuoi criteri di
  successo e poi con la progettazione di valutazioni per misurare le
  prestazioni rispetto a essi». I controlli di `controlli.tsv` li decide
  il codice (il telefono che non deve comparire, anche con spazi, punti o
  trattini fra le cifre; nessun segnaposto; al massimo 150 parole): sulla
  stessa risposta danno sempre lo stesso esito.
  Le affermazioni di `rubrica.md` le decide il giudice, un modello: se ne
  trovate una ambigua, riscrivetela e misurate di nuovo tutte le versioni.
- La prova del giudice: su v0 lo stesso giudice giudica due volte la
  stessa risposta. Un'affermazione su cui i due giudizi non concordano è
  «instabile»: in v0 conta come non rispettata, e negli esiti delle
  pratiche non conta, perché il suo cambiamento non è una prova.
- `./misura.sh --confronta v0 v1` legge nel registro la pratica di v1 e ne
  dice l'esito, in questa misura, confrontando le due versioni: conta i
  criteri segnati `chiarezza` che hanno un esito in v0 e in v1, senza le
  affermazioni instabili, e quanti ne rispetta ciascuna. Confermata se v1
  ne rispetta più di v0; non decisa se lo stesso numero, perché questa
  coppia non lo dice; non confermata in questa misura se meno. Il
  confronto stampa i due conteggi, poi i criteri che v1 non rispetta.
  Resta non decisa anche se nessun criterio la legge, se la leggono solo
  affermazioni instabili, o se da v0 a v1 è cambiato anche altro (il
  modello, l'effort, i dati: li registra `misura.sh` in
  `risposte/<versione>.opzioni`). Una pratica non confermata è un
  risultato, come una confermata. La rimisura è confermata se le due
  risposte sono diverse; se sono identiche, resta non decisa.
- Il confronto avvisa quando la risposta e il giudizio vengono dallo
  stesso modello (il campo `modelUsage` dei due JSON), e stampa i token:
  la v1 di riferimento porta anche le procedure, un testo più lungo.
- La verifica stampa le misure e l'esito di ogni pratica, e mette alla
  prova la garanzia di `--json-schema`: ogni giudizio che porta
  `structured_output` lo porta conforme a `schema-giudizio.json`; se uno
  no, scrive «la documentazione garantisce …: in questa esecuzione no» ed
  esce con 1.
- Nella prova del docente del 20 ottobre 2026, con Claude Code 2.1.305,
  una esecuzione per versione: v0 0 controlli su 3 e 2 affermazioni
  rispettate su 5, con i due giudizi d'accordo su 5 affermazioni su 5; la
  v1 di riferimento 3 su 3 e 3 su 5. `chiarezza` confermata: i criteri
  segnati `chiarezza` rispettati sono 2 su 7 in v0 e 6 su 7 in v1; in v1
  resta non rispettato «impegni» (il giudice cita il ricontatto del
  commerciale, che le procedure prevedono solo per offerte o preventivi).
  La rimisura confermata: le due risposte sono diverse (96 parole contro
  106, misura 6 contro 7 su 8). Come dato, senza esito: «Il telefono del
  cliente nella risposta di v2: assente». I token in entrata 926 contro
  1932; giudizi conformi allo schema 4 su 4.

## Verifica (tools/verifica.sh M2-E01)

Controlla il lavoro, non l'esito: v0 misurata e giudicata due volte
(`giudizi/v0.json` e `giudizi/v0-bis.json`), v1 misurata e diversa da v0,
ogni versione misurata completa (risposta, controlli e giudizio con un
esito per ogni affermazione), e in `registro.md` la riga di ogni versione
misurata, compilata e con la sua pratica (`partenza` per v0, una
dell'elenco di `./misura.sh --pratiche` per le altre). Poi stampa le
misure e l'esito di ogni pratica; stampa anche, come dato e senza esito,
se la risposta dell'ultima versione ripete il telefono del cliente
(quello del caso di CiaspoLink: sul percorso A il vostro lo cerca
`controlli.tsv`). Una pratica non confermata non vi ferma: è un
risultato. Esce con 1 se manca qualcosa, o se un giudizio strutturato non
rispetta lo schema.

## Se qualcosa va storto

- `misura.sh` dice che il prompt usa un segnaposto che in `dati/` non c'è:
  controllate il nome tra le doppie graffe, per esempio `{{procedure}}`.
- `misura.sh` si ferma perché il prompt composto è troppo lungo: i file di
  `dati/` sono troppo lunghi per una chiamata (oltre 100 000 byte, e il
  messaggio dice quanti ne ha ciascuno); accorciateli.
- `misura.sh` si ferma perché la consegna al giudice è troppo lunga: la
  rubrica, i file di `dati/` e la risposta insieme superano lo stesso
  limite; accorciate i file di `dati/` o la rubrica, o chiedete nel prompt
  una risposta più breve.
- `misura.sh` si ferma perché i controlli non sono riusciti, o rifiuta
  una pratica: una riga di `controlli.tsv` o di `rubrica.md` non si legge,
  e il messaggio dice quale. Tra parentesi quadre si scrive `chiarezza`,
  `contesto`, `ruolo` o `tag`; correggete e rilanciate la misura.
- `--confronta` dice «non decisa» perché la pratica è da scrivere:
  scrivetela nella colonna «pratica» di `registro.md` e rilanciate il
  confronto, senza misurare di nuovo.
- La verifica chiede di misurare di nuovo una versione: un file della sua
  misura è incompleto, per v0 anche `giudizi/v0-bis.json`; lanciate il
  comando che la verifica stampa. Una nuova misura cancella prima quella
  vecchia della stessa versione: se si ferma, la versione resta da
  misurare.
- Il giudizio arriva senza esito strutturato: rilanciate la misura della
  stessa versione. Se succede ancora, controllate che
  `.claude/agents/giudice.md` sia quello di partenza.
- La verifica scrive «la documentazione garantisce …: in questa esecuzione
  no»: un giudizio strutturato non rispetta lo schema. Misurate di nuovo
  quella versione e avvisate il docente.
- Una risposta riporta il vostro nome, che nessun prompt né dato
  contiene: prima di mostrarla in aula, toglietelo. Nei file di
  `soluzione/` un nome così è sostituito da «(identità dell'account,
  omessa)».
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E01`.

## Impronta d'uso sul piano Pro

Chiamate brevi `claude -p`, senza strumenti: tre su v0 (la risposta e due
giudizi), due su v1 (la risposta e un giudizio), cinque in tutto; sette
con la rimisura. La risposta gira su Sonnet con effort low
(926 e 1932 token in entrata, v0 e v1, nella prova del docente), i
giudizi su Haiku con effort low
(da 2951 a 3506 token in entrata e da 622 a 1648 in uscita per giudizio,
nella stessa prova). Più la
sessione interattiva su Sonnet, di quattro o cinque turni. Il giudice gira
in una sua chiamata `claude -p`, non come subagent dentro la sessione.
Niente Opus, niente Fable. Alla fine, `/exit`.

## Per approfondire

- La guida «Best practice per il prompting» della documentazione:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La pagina sui criteri di successo e sulle valutazioni:
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- I subagent in Claude Code:
  https://code.claude.com/docs/en/sub-agents
- L'articolo «Automating eval design and hillclimbing with Claude», sul
  blog degli sviluppatori di Anthropic:
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
