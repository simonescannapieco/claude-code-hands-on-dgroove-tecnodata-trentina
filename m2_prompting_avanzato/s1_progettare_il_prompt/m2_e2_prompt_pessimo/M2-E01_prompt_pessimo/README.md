# M2-E01 — Il prompt pessimo: misura, riscrivi, rimisura

Esercitazione del Modulo 2, nella pratica «Il prompt pessimo». È il primo
lavoro del modulo che fate in Claude Code.

## Obiettivo

Misurare un prompt pessimo, riscriverlo con gli ingredienti del template e
rimisurarlo: con i controlli scritti in codice e con un giudice, un
subagent che verifica le affermazioni di una rubrica.

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
- `registro.md`: il registro delle versioni, da compilare.

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

   `misura.sh` fa tre passi e stampa ogni comando prima di eseguirlo: la
   risposta di Sonnet al prompt, con `claude -p`; i controlli di
   `controlli.tsv`; il giudizio del subagent `giudice`, su Haiku, con un
   JSON vincolato dallo schema. Leggete la risposta e i due elenchi di ✓
   e ✗.

3. Scrivete la nuova versione, sei minuti. Copiate la vecchia:

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
     nominano le procedure o CiaspoLink; poi rimisurate v0.
   - **Percorso B, il caso di CiaspoLink:** il messaggio della
     Falegnameria, così com'è. La prova del docente è su questo.

4. Misurate la nuova versione:

       ! ./misura.sh v1

5. Confrontate le due versioni, poi chiedete a Claude di leggerle:

       ! ./misura.sh --confronta v0 v1
       ! git diff --no-index prompt/v0.md prompt/v1.md

       Confronta giudizi/v0.json e giudizi/v1.json: quali affermazioni sono migliorate, quali no, e che cosa cambieresti nel prompt?

6. Compilate `registro.md`, le righe di v0 e di v1: che cosa avete
   cambiato e i totali che stampa `misura.sh` (controlli superati,
   affermazioni rispettate). Con l'editor, o dettandoli a Claude.

7. Se avete tempo, un altro ciclo: `prompt/v2.md`, poi
   `! ./misura.sh v2`. Checkpoint: v0 e v1 misurate, registro compilato.

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M2-E01

## Che cosa osservare

- In v0 ogni ingrediente che manca è una decisione che ha preso il
  modello: la lunghezza, i segnaposto da completare, il numero di telefono
  ricopiato, le promesse fatte a nome dell'azienda.
- Nelle registrazioni del corso, v0: nessun controllo superato su tre, una
  sola affermazione rispettata su cinque. La versione riscritta con ruolo,
  contesto, procedure tra tag, formato e firma: tre controlli su tre,
  quattro affermazioni su cinque. Quella che resta riguarda il ricontatto
  del commerciale, che le procedure prevedono solo per chi chiede
  un'offerta: nella registrazione il giudice l'ha segnata sotto «fatti»,
  in un'altra prova sotto «impegni». È un buon esercizio per v2.
- Il giudice è anch'esso un modello: leggete i suoi motivi. Quando non
  siete d'accordo, decidete voi, e se serve riscrivete l'affermazione della
  rubrica perché sia verificabile senza ambiguità.
- I token: la nuova versione ne manda di più (le procedure), e di solito
  ne riceve di meno (una risposta più breve).
- Una sola esecuzione non è una misura: rilanciando la stessa versione la
  risposta, e il giudizio, possono cambiare.
- Una risposta può riportare il vostro nome: nella prova del docente, la
  risposta a v0 conteneva una nota per il titolare dell'account, con il
  suo nome (nei file di `soluzione/` è sostituita da «(identità
  dell'account, omessa)»). Controllate le risposte prima di mostrarle in
  aula.

## Verifica (tools/verifica.sh M2-E01)

Controlla che v0 e v1 siano misurate (risposta, controlli e giudizio con un
esito per ogni affermazione), che `prompt/v1.md` sia diverso da
`prompt/v0.md`, che l'ultima versione misurata superi v0 nella somma di
controlli superati e affermazioni rispettate, che la sua risposta non
ripeta il numero di telefono del cliente (quello del caso di CiaspoLink:
sul percorso A, il vostro lo cerca `controlli.tsv`), e che le righe di v0
e v1 di `registro.md` siano compilate.

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
- `misura.sh` si ferma perché i controlli non sono riusciti: una riga di
  `controlli.tsv` non si legge, e il messaggio dice quale; correggetela e
  rilanciate la misura.
- La verifica chiede di misurare di nuovo una versione: un file della sua
  misura è incompleto; lanciate il comando che la verifica stampa. Una
  nuova misura cancella prima quella vecchia della stessa versione: se si
  ferma, la versione resta da misurare.
- Il giudizio arriva senza esito strutturato: rilanciate la misura della
  stessa versione. Se succede ancora, controllate che
  `.claude/agents/giudice.md` sia quello di partenza.
- La verifica dice che l'ultima versione non migliora: un altro ciclo, con
  il giudizio sotto gli occhi.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E01`.

## Impronta d'uso sul piano Pro

Ogni misura sono due chiamate brevi senza strumenti: la risposta su Sonnet
con effort low (tra mille e duemila token in entrata) e il giudizio su
Haiku con effort low. Due o tre misure, più la sessione interattiva su
Sonnet, di quattro o cinque turni. Il giudice gira in una sua chiamata
`claude -p`, non come subagent dentro la sessione. Niente Opus, niente
Fable. Alla fine, `/exit`.

## Per approfondire

- La guida «Prompting best practices» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La pagina sui criteri di successo e sulle valutazioni:
  https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- I subagent in Claude Code:
  https://code.claude.com/docs/en/sub-agents
- L'articolo «Automating eval design and hillclimbing with Claude», sul
  blog per gli sviluppatori di Anthropic:
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
