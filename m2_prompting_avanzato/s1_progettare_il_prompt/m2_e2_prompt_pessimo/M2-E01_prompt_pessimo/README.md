# M2-E01 — Il prompt pessimo: misura, riscrivi, rimisura

Esercitazione del Modulo 2, «Il prompt pessimo». È il primo lavoro del
modulo che fate in Claude Code.

## Obiettivo

Mettere alla prova una frase della guida di Anthropic sui prompt: «Più
precisamente spieghi cosa vuoi, migliore sarà il risultato.» Prendete un
prompt pessimo, ne misurate la risposta con dei controlli automatici e
con un secondo modello che fa da giudice, lo riscrivete e lo misurate di
nuovo. Le parole e i comandi che servono sono tutti spiegati più sotto, in
«La teoria che serve».

## Tempo

30 minuti: quattro per leggere il compito e fare i primi passi, sette per
scrivere la nuova versione del prompt (sei di scrittura), dodici per
misurare, confrontare e annotare i risultati, sette per il confronto in
aula: due o tre prompt dei presenti, letti e misurati insieme.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`). I
  comandi che cominciano con `tools/` si lanciano dalla cartella
  `esercitazioni`, cioè dal repository del corso, clonato seguendo
  `PRIMA_DEL_CORSO.md`, che sta lì dentro.
- `claude --version` 2.1.293 o successiva: il giudice, il modello che
  valuta le risposte, è Haiku, e con le versioni precedenti il nome breve
  `haiku` punta a un modello più vecchio.
- Python 3 e git, che `tools/verifica_ambiente.sh` controlla: li usano gli
  attrezzi della misura e la verifica.

## La teoria che serve

Se avete seguito la teoria del Modulo 2 potete passare direttamente a
«Punto di partenza»: i minuti dell'esercitazione sono contati per chi
l'ha seguita. Questa sezione è per chi ha soltanto questo README, e va
letta prima di cominciare: c'è tutta la teoria che l'esercitazione usa, e
niente di più, ogni cosa spiegata una volta, prima che serva.

### Perché si misura un prompt

Un prompt che si usa davvero si scrive, si prova e si corregge, come un
programma. Ma «mi sembra meglio» non è una misura: il
[glossario di Anthropic](https://platform.claude.com/docs/it/about-claude/glossary)
avverte che input identici possono dare output diversi da una chiamata
all'altra, e a occhio non si distingue un miglioramento da un caso.

Per questo si decide **prima** che cosa vuol dire «una buona risposta», e
poi si controlla se la risposta lo fa. Ogni cosa che una buona risposta
deve fare è un **criterio**. La pagina di Anthropic sui criteri di
successo e sulle valutazioni lo dice così: un'applicazione «inizia con la
definizione chiara dei tuoi criteri di successo e poi con la
progettazione di valutazioni per misurare le prestazioni rispetto a
essi». I criteri si fissano prima delle versioni del prompt e restano gli
stessi per tutte: scelti dopo, finirebbero per premiare la versione
appena scritta. Scrivere una versione guardando i criteri, invece, è il
punto: dicono che cosa volete, e il prompt lo chiede. Se un criterio si
rivela ambiguo si riscrive, e si misurano di nuovo tutte le versioni: un
criterio cambia per tutte, mai per una sola.

### Gli ingredienti e i loro tag

Un buon prompt è una specifica, non un desiderio: dice chi è Claude in
quel compito e a chi scrive, che cosa deve sapere, che cosa deve fare, in
che forma e con quali limiti.
Sono gli **ingredienti** del template del corso, e ognuno sta in un suo
**tag**, una coppia di segni come `<role>` e `</role>`, ciascuno su una
riga sua:

| ingrediente | tag | la domanda a cui risponde |
|---|---|---|
| ruolo | `<role>` | chi scrive la risposta, e a chi? |
| contesto | `<context>` | che cosa deve sapere, e perché? |
| istruzione | `<instructions>` | che cosa deve fare? |
| formato | `<format>` | in che forma? |
| vincoli | `<constraints>` | che cosa fare invece di ciò che non va? (i limiti, detti in positivo: «parla solo di…», non «non parlare di…») |
| esempi | `<examples>`, con un `<example>` per ogni esempio | quale forma deve copiare? |

Dopo gli ingredienti vengono i **dati**, ciascuno in un tag che dice che
cosa contiene: `<message>` per un messaggio, `<code>` per del codice,
`<log>` per un log. Ogni ingrediente che manca è una decisione che
lasciate al modello.

Un nome tra doppie graffe, come `{{messaggio}}`, è un **segnaposto**: nel
file del prompt resta il nome, e `misura.sh`, lo script che misura il
prompt (più sotto, «Gli attrezzi»), prima di chiamare Claude ci mette il
file della cartella `dati/` che si chiama così, estensione a parte
(`dati/messaggio.md` per `{{messaggio}}`). I file di `dati/` non cambiano
da una versione all'altra: una versione può usarne uno in più, mettendo il
suo segnaposto, e questo è un cambiamento del testo del prompt.

Anthropic, nella guida ai prompt, scrive: «Racchiudere ogni tipo di
contenuto nel proprio tag (ad esempio, `<instructions>`, `<context>`,
`<input>`) riduce le interpretazioni errate.» e chiede nomi coerenti e
descrittivi. I nomi della tabella, un tag per ingrediente, sono invece la
convenzione di questo corso.

### Che cos'è una pratica

Una **pratica** è una frase in cui Anthropic raccomanda o afferma
qualcosa sui prompt, messa alla prova da una versione del vostro prompt.
Ha un nome breve (`chiarezza`, `contesto`, …), e `./misura.sh --pratiche`
stampa l'elenco, ognuna con la sua frase e il link alla pagina.

Una versione mette alla prova **una pratica sola**: se la misura si
muove, sapete quale pratica l'ha mossa; mettendone alla prova due insieme,
non lo sapreste. Una pratica sola non vuol dire una parola sola: `chiarezza`
chiede di spiegare che cosa si vuole, e una versione che la applica può
riscrivere tutto il prompt. L'esito allora parla della riscrittura nel suo
insieme, cioè di quella frase di Anthropic applicata così: non dice quale
ingrediente ha mosso la misura, e se la riscrittura usa i tag e un ruolo,
non per questo mette alla prova le pratiche `tag` e `ruolo`.

Si lavora così perché quello che si mette alla prova è una frase di
Anthropic, non un'impressione: alla fine non dite «mi sembra meglio», ma
«su questi criteri, in questa coppia di versioni, la frase ha tenuto
oppure no». Una pratica resta **non decisa** quando questa coppia non può
dirlo; gli esiti sono spiegati in «Come si legge un esito».

Un criterio **legge** una pratica quando porta il suo nome (le uscite di
`misura.sh` dicono «criteri segnati»): il suo esito serve a decidere
quella pratica. Più sotto, «I due tipi di criterio».

### Le pratiche in M2-E01

Le parole della tabella che non conoscete ancora (criteri, affermazioni,
effort) sono spiegate nelle prossime sottosezioni.

| pratica | la frase di Anthropic | si decide qui? |
|---|---|---|
| `chiarezza` | «Sii specifico sul formato di output e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi, migliore sarà il risultato.» | sì: la leggono sette criteri |
| `contesto` | «Fornire il contesto o la motivazione alla base delle tue istruzioni, ad esempio spiegando a Claude perché un certo comportamento è importante, può dare a Claude più informazioni sui tuoi obiettivi e aiutarlo a fornire risposte più mirate.» | sì, se una vostra versione cambia il contesto: la legge un solo criterio, `fatti` |
| `tag` | «Racchiudere ogni tipo di contenuto nel proprio tag (ad esempio, `<instructions>`, `<context>`, `<input>`) riduce le interpretazioni errate.» | no: nessun criterio di partenza la legge, e l'esito resta «non decisa» |
| `ruolo` | «Impostare un ruolo nel "system prompt" (prompt di sistema) focalizza il comportamento e il tono di Claude per il tuo caso d'uso.» | no: la frase parla del system prompt, le istruzioni fisse di una conversazione, e `misura.sh` manda il vostro prompt come messaggio, con il system prompt fisso «Rispondi in italiano.»; l'esito resta «non decisa» |
| `effort` | «Modelli più capaci e livelli di effort più alti di solito dovrebbero andare meglio in una valutazione. Se non succede, spesso a frenarli sono compiti ambigui o un valutatore mal calibrato.» (traduzione nostra) | sì, se volete provarla, a testo invariato: una copia dell'ultima versione, con il numero seguente e una riga in più nel registro, misurata con un effort più alto (`./misura.sh v3 --effort medium`). Confermata se il numero della misura è più alto, non decisa se è lo stesso o se con l'effort più basso è già al massimo. L'effort è spiegato in «Gli attrezzi»; il «valutatore» è il modello che giudica, qui il giudice |
| `modello` | la stessa frase | no: `misura.sh` non sa quale dei due modelli confrontati sia «più capace»; stampa la misura, e l'esito resta «non decisa» |
| `rimisura` | «… input identici potrebbero produrre output diversi tra diverse chiamate API.» | sì: la stessa versione misurata di nuovo, confermata se le due risposte sono diverse |

### I due tipi di criterio

I criteri di questa esercitazione sono di due tipi.

I **controlli scritti in codice**, in `controlli.tsv`: una parola che
deve o non deve esserci, una lunghezza massima. Li decide il codice, e
sulla stessa risposta danno ogni volta lo stesso esito. Per la pagina di
Anthropic sulle valutazioni è il modo più veloce e affidabile, ma senza
sfumature.

Le **affermazioni** di una **rubrica**, in `rubrica.md`: frasi su che
cosa fa una buona risposta, ciascuna rispettata o no, non un voto da 1 a
5. Le decide un modello, il **giudice**.

Il nome della pratica che un criterio legge sta tra parentesi quadre in
`rubrica.md` e nell'ultima colonna in `controlli.tsv`. Il confronto fra due
versioni (`./misura.sh --confronta`, spiegato più sotto) conta soltanto i
criteri che leggono la pratica in prova; un criterio senza pratica conta
nei totali, e nell'esito di nessuna.

Il **registro**, `registro.md`, ha una riga per ogni versione: la pratica
di quella versione, che cosa è cambiato, i totali, e una colonna per le
vostre note. La pratica si scrive lì **prima** di misurare la versione,
perché il confronto la legge da lì. La riga di v0 ha già la pratica,
`partenza`: v0 non mette alla prova niente, è il punto da cui si parte.

### Il giudice

Il giudice è un **subagent**: un file con un suo prompt e un suo
modello, `.claude/agents/giudice.md`. Riceve la rubrica, i file di `dati/`
e la risposta da giudicare, non il prompt. Gira su Haiku, mentre le
risposte le scrive Sonnet (Haiku, Sonnet e Opus sono modelli di Claude):
Anthropic, nel suo articolo sulle valutazioni, dice che il modello giudice
«non dovrebbe essere il modello che state valutando» (traduzione nostra).

Per ogni affermazione il giudice scrive prima il **motivo**, citando la
parte della risposta che decide, poi l'**esito**: rispettata o no. Così
potete controllare il motivo; quando non siete d'accordo decidete voi, e
potete scriverlo nelle note del registro: i totali restano quelli del
giudice.

Il giudizio arriva come **JSON**, un testo diviso in campi con un nome,
nel campo `structured_output` del risultato. Lo **schema**,
`schema-giudizio.json`, dice quali campi deve avere, e `--json-schema`,
un'opzione di `claude -p` (il comando che lancia Claude Code senza
sessione: più sotto, «Gli attrezzi»), lo fa rispettare: il campo arriva
conforme allo schema, oppure manca. Lo schema dice la forma del giudizio;
il contenuto resta quello che il modello ha scritto.

Sulla prima versione, v0, lo stesso giudice giudica **due volte** la
stessa risposta: è la prova del giudice. Anthropic, della valutazione con
un modello, scrive: «Prima verifica che sia affidabile, poi scala.»
Un'affermazione su cui i due giudizi non concordano è **instabile**: in
v0 è contata come non rispettata, e dagli esiti delle pratiche resta
fuori, in ogni confronto, perché il suo cambiamento non dimostra niente.
Se ne trovate non vi fermate: leggete i due motivi (in `giudizi/v0.json` e
`giudizi/v0-bis.json`), e un'affermazione ambigua riscrivetela.

### Come si legge un esito

Una **misura** è un'esecuzione di `misura.sh` su una versione; il suo
numero è la somma dei controlli superati e delle affermazioni rispettate,
su quanti sono in tutto.

`./misura.sh --confronta` confronta due versioni e dice l'esito della
pratica della seconda: conta i criteri che leggono quella pratica, senza
le affermazioni instabili, e quanti ne rispetta ciascuna versione.

- **confermata**: la versione nuova ne rispetta di più;
- **non decisa**: lo stesso numero, oppure nessun criterio legge quella
  pratica, oppure la pratica è da scrivere nel registro, oppure da una
  versione all'altra è cambiato anche altro;
- **non confermata in questa misura**: ne rispetta di meno.

«Anche altro» vuol dire i file di `dati/`, il modello o l'effort: per una
pratica sul testo, il prompt deve cambiare, e queste tre cose no.
Che cosa è cambiato, `misura.sh` lo registra in
`risposte/<versione>.opzioni`: il modello, l'effort e un'**impronta
digitale** del prompt e dei dati, un numero calcolato dal testo, che
cambia se il testo cambia. Le pratiche `effort`, `modello` e, in M2-E01,
`rimisura` (la stessa versione misurata di nuovo) lasciano il testo com'è e
non si decidono contando i criteri: la loro regola è scritta accanto a
ciascuna, in questa teoria.

Nessun esito dice «smentita». Le frasi di Anthropic dicono «può» e
«di solito», o confrontano due casi: una sola coppia di risposte non le
smentisce, e non le dimostra. Anche «confermata» vale per questa coppia:
dice che in queste due risposte la versione nuova ha rispettato più
criteri, e soltanto questo; «in questa misura» vuol dire in questa
esecuzione, con questi numeri. Una pratica non confermata è un risultato,
come una confermata.

### Gli attrezzi

`claude -p` è Claude Code che riceve un prompt, stampa la risposta ed
esce, senza una sessione da seguire: la misura gira così, una chiamata
per volta.

Il punto esclamativo `!` all'inizio di una riga della sessione di Claude
Code manda il comando direttamente alla shell, senza passare da Claude, e
il comando con il suo output entra nella conversazione: così si misura
senza uscire dalla sessione.

`./misura.sh` prende la versione (`./misura.sh v0`; dove le cartelle sono
più d'una, come in M2-E02, anche la cartella: `./misura.sh sistemi v0`),
stampa ogni comando prima di eseguirlo e fa, nell'ordine:

1. compone il prompt, mettendo i file di `dati/` al posto dei segnaposto;
2. chiede la risposta con `claude -p`, su Sonnet, effort low, senza
   strumenti (Claude non legge file e non lancia comandi: risponde e basta);
3. esegue i controlli di `controlli.tsv` sulla risposta;
4. chiede il giudizio al subagent, su Haiku, effort low;
5. su v0, chiede un secondo giudizio della stessa risposta.

I risultati finiscono in `risposte/`, `controlli/` e `giudizi/`, accanto al
prompt (in M2-E02, dentro la famiglia). La misura stampa anche i
**token**, i pezzi in cui il testo viene spezzato per il modello: quelli
in entrata sono il prompt, quelli in uscita la risposta.

`git diff --no-index prima dopo` mostra le righe cambiate fra due file: con
il `-` quelle tolte, con il `+` quelle aggiunte.

L'**effort** è quanto il modello ragiona prima di rispondere: un effort
più basso è più rapido ed economico, uno più alto ragiona più a fondo e
consuma di più. `misura.sh` usa low; con `--effort` si cambia (low, medium
o high), con `--modello` si cambia il modello della risposta (haiku,
sonnet o opus; di partenza sonnet): per esempio
`./misura.sh v2 --effort medium`. Il giudice resta su Haiku, effort low.

### La regola delle versioni

Il ciclo è sempre lo stesso: si scrive nel registro la pratica della
versione nuova, si copia la versione precedente e la si cambia secondo
quella pratica, si misura, si confronta con la precedente, si scrivono i
totali nel registro.

Le versioni seguono una regola sola, la stessa nelle due esercitazioni
del modulo:

- **v0** è il prompt di partenza, di una riga (nel percorso A di M2-E02, il
  vostro), e non si tocca;
- ogni numero dopo v0 (**v1**, **v2**, …) parte da una copia della
  versione precedente e mette alla prova una pratica, una sola;
- nessuna versione si copia da una più vecchia della precedente, neanche
  se l'ultima è andata peggio: un risultato peggiore è un risultato.

### Le versioni di M2-E01

- **v0** è «scrivi risposta al cliente», con il segnaposto del messaggio;
- **v1** è il template intero, con gli ingredienti che servono a questo
  compito (gli esempi sono facoltativi), pratica `chiarezza`:
  l'esercitazione finisce lì;
- **v2**, se avete tempo, è una copia di v1 senza nessun cambiamento,
  pratica `rimisura`: serve a vedere se la stessa versione, misurata di
  nuovo, dà una risposta diversa.

## Punto di partenza (tools/prepara_esercizio.sh M2-E01)

Lo spazio di lavoro `~/corso-claude-code/M2-E01/` con:

- `prompt/v0.md`: il prompt pessimo, «scrivi risposta al cliente», e sotto
  il segnaposto `{{messaggio}}`;
- `dati/messaggio.md`: il messaggio di un cliente business di CiaspoLink,
  l'operatore inventato dei progetti di esempio del corso: la Falegnameria
  Fittizia di Rovereto, rimasta senza centralino, che ha perso il numero
  della segnalazione e chiede un indennizzo e una linea di riserva;
- `dati/procedure.md`: gli estratti della base di conoscenza
  dell'assistenza che valgono per le sue richieste (indennizzi, deviazione
  d'emergenza delle chiamate, offerte);
- `rubrica.md`: le cinque affermazioni che il giudice verifica sulla
  risposta, ognuna con un nome breve: `domande` (risponde alle due
  richieste del cliente), `impegni` (non promette ciò che le procedure non
  danno), `fatti` (usa solo fatti del messaggio o delle procedure), `lei`
  (dà del «lei», con un tono cortese e concreto) e `firma` (firma
  l'assistenza clienti di CiaspoLink, non una persona);
- `controlli.tsv`: i controlli scritti in codice: il telefono del cliente
  non deve comparire nella risposta, non devono restare parti da completare
  tra parentesi quadre, come `[giorno]`, e la risposta sta in 150 parole;
- `misura.sh`, `strumenti/kit.py` (il programma che `misura.sh` usa per i
  conti), `schema-giudizio.json` e `.claude/agents/giudice.md`: gli
  attrezzi della misura;
- `registro.md`: il registro delle versioni, da compilare, con la colonna
  «pratica».

In `rubrica.md` e in `controlli.tsv` ogni criterio porta la pratica
`chiarezza`, tranne l'affermazione `fatti`, che porta `contesto`. Il
messaggio e le procedure sono inventati, come tutti i dati del corso.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`, poi aprite Claude Code su Sonnet:

       tools/prepara_esercizio.sh M2-E01
       cd ~/corso-claude-code/M2-E01
       claude --model sonnet

   Scegliete il percorso prima di misurare:
   - **Percorso A, un vostro caso:** sostituite `dati/messaggio.md` con il
     messaggio di un vostro cliente, con i dati sostituiti da valori
     inventati (il prompt, `prompt/v0.md`, resta quello dato). Adattate poi
     ciò che è legato al caso di CiaspoLink:
     `controlli.tsv` (il telefono da cercare è quello del vostro
     messaggio), `dati/procedure.md` (mettete le vostre regole, oppure
     cancellate il file, e allora nella v1 non usate `{{procedure}}`) e le
     affermazioni di `rubrica.md` che non valgono per il vostro caso (le
     due richieste, le procedure, CiaspoLink), tra parentesi quadre la
     pratica (`chiarezza`, `contesto`, `ruolo` o
     `tag`). Sul percorso A i criteri si adattano adesso, prima di misurare
     v0. I file si modificano nell'editor, o in un secondo terminale,
     mentre la sessione resta aperta. In `controlli.tsv` ogni riga
     ha, separate da tabulazioni, `tipo` (`assente` o `presente`, con
     un'espressione regolare, `parole_max`, `parole_min` o `righe_max`, con
     un numero), `valore`, `descrizione` e, se serve, `pratica`; in
     `rubrica.md` una riga è `- **nome** [pratica]: la frase`. Imitate le
     righe che ci sono.
   - **Percorso B, il caso di CiaspoLink:** il messaggio della
     Falegnameria, così com'è. La prova del docente, l'esecuzione
     registrata che trovate risolta in fondo a questo README, è su questo.

2. Misurate il prompt di partenza, dalla sessione:

       ! ./misura.sh v0

   Leggete la risposta, i due elenchi di ✓ e ✗, ognuno con la sua pratica,
   e la riga «Giudice su v0»: su quante affermazioni i due giudizi danno lo
   stesso esito.

3. Scrivete nel registro la pratica di v1 prima di riscrivere il prompt:
   nella riga di v1 di `registro.md`, colonna «pratica», `chiarezza`, con
   l'editor o in un secondo terminale, mentre la sessione resta aperta. La
   riga di v0 ha già `partenza`.
   L'elenco delle pratiche, ognuna con la frase di Anthropic che mette
   alla prova:

       ! ./misura.sh --pratiche

4. Scrivete la nuova versione, sei minuti. Prima leggete
   `dati/messaggio.md`, `dati/procedure.md`, `rubrica.md` e
   `controlli.tsv`: dicono a che cosa deve rispondere una buona risposta e
   che cosa non deve fare. Copiate la vecchia versione:

       ! cp prompt/v0.md prompt/v1.md

   e riscrivete `prompt/v1.md` nel vostro editor, con i tag del template
   come domande: chi scrive e a chi (ruolo, `<role>`); che cosa deve
   sapere (contesto, `<context>`: a che cosa serve la risposta, e in quali
   tag sono i dati); che cosa deve fare (istruzione, `<instructions>`: a
   quali richieste rispondere, con quali informazioni, e che cosa chiedere
   al cliente, come il numero di segnalazione perso); in che forma
   (formato, `<format>`: lunghezza, firma); con quali limiti (vincoli,
   `<constraints>`: che cosa si può promettere, che cosa si fa dei dati
   personali); e, se la forma conta, gli esempi (`<examples>`, da tre a
   cinque, ciascuno in `<example>`). Dopo gli ingredienti, i dati,
   ciascuno nel suo tag: `<message>` `{{messaggio}}` `</message>` e
   `<procedures>` `{{procedure}}` `</procedures>`. Fra doppie graffe c'è
   un segnaposto: `misura.sh` ci mette il file di `dati/` con quel nome.
   Se qualcosa non è chiaro, chiedete a Claude di farvi domande sul
   compito prima di scrivere.

5. Misurate la nuova versione e confrontatela con v0:

       ! ./misura.sh v1
       ! ./misura.sh --confronta v0 v1
       ! git diff --no-index prompt/v0.md prompt/v1.md

   Il confronto stampa la pratica di v1 con la frase di Anthropic, ogni
   criterio prima e dopo (le due colonne di ✓ e ✗ sono v0 e v1), l'esito
   della pratica, poi i totali e i token. Leggetelo con Claude:

       Confronta giudizi/v0.json e giudizi/v1.json: quali affermazioni sono cambiate, e con quale motivo del giudice?

6. Compilate `registro.md`, le righe di v0 e di v1: che cosa avete
   cambiato (per v0 è già scritto), i totali della riga «totali» del
   confronto (controlli superati, affermazioni rispettate) e, se volete,
   una nota. Con l'editor, o dettandoli a Claude. Punto di controllo: a
   questo punto avete v0 e v1 misurate e il registro compilato.

7. Se avete tempo, la rimisura: v1 di nuovo, senza toccarla. Nella riga di
   v2 del registro scrivete la pratica `rimisura`, poi:

       ! cp prompt/v1.md prompt/v2.md
       ! ./misura.sh v2
       ! ./misura.sh --confronta v1 v2

   e completate la riga di v2, come le altre.

8. Uscite con `/exit`, tornate nella cartella `esercitazioni` (`cd -`
   torna alla cartella da cui siete partiti) e verificate:

       cd -
       tools/verifica.sh M2-E01

## Che cosa osservare

### Che cosa dice Anthropic

- La pratica di v1, `chiarezza`, mette alla prova due frasi della guida
  «Best practice per il prompting», sezione «Sii chiaro e diretto»: «Più
  precisamente spieghi cosa vuoi, migliore sarà il risultato.» e «Sii
  specifico sul formato di output e sui vincoli che desideri.» La stessa
  sezione chiede di pensare a Claude «come a un dipendente brillante ma
  nuovo, che non ha contesto sulle tue norme e sui tuoi flussi di lavoro»:
  v0 non spiega niente, la vostra v1 spiega che cosa serve.
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Il giudice si mette alla prova prima di usarlo. La pagina sui criteri di
  successo e sulle valutazioni, della valutazione con un modello: «Prima
  verifica che sia affidabile, poi scala.»
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
- La rimisura del passo 7 mette alla prova il glossario: «… input
  identici potrebbero produrre output diversi tra diverse chiamate API.»
  https://platform.claude.com/docs/it/about-claude/glossary

### Che cosa misurano gli attrezzi

Che cosa sono i criteri, il giudice e gli esiti è in «La teoria che
serve». Qui, in più:

- I controlli di `controlli.tsv` cercano il telefono del cliente, che non
  deve esserci, anche con spazi, punti o trattini fra le cifre, le parti da
  completare tra parentesi quadre, e contano al massimo 150 parole. Se
  trovate ambigua un'affermazione di `rubrica.md`, riscrivetela, misurate
  di nuovo tutte le versioni e aggiornate i totali nel registro.
- `./misura.sh --confronta v0 v1` legge nel registro la pratica di v1 e
  conta i criteri segnati `chiarezza`: il confronto stampa i due
  conteggi, poi i criteri che v1 non rispetta. La rimisura è confermata
  se le due risposte sono diverse; se sono identiche, resta non decisa.
- Il confronto avvisa quando la risposta e il giudizio vengono dallo
  stesso modello (lo legge dal campo `modelUsage` dei file JSON della
  risposta e del giudizio), e stampa i token: la v1 della prova del
  docente, la v1 di riferimento, ne ha di più in entrata perché porta anche
  le procedure, un testo più lungo.
- La verifica stampa le misure e l'esito di ogni pratica, e mette alla
  prova la garanzia di `--json-schema`: ogni giudizio che porta
  `structured_output` lo porta conforme a `schema-giudizio.json`; se uno
  no, scrive «la documentazione garantisce …: in questa esecuzione no», e
  la verifica non passa.
- Nella prova del docente dell'8 novembre 2026, con Claude Code 2.1.319,
  una esecuzione per versione: v0 0 controlli su 3 e 2 affermazioni
  rispettate su 5, con i due giudizi d'accordo su 5 affermazioni su 5; la
  v1 di riferimento 3 su 3 e 3 su 5. `chiarezza` confermata: i criteri
  segnati `chiarezza` rispettati sono 2 su 7 in v0 e 6 su 7 in v1; in v1
  resta non rispettato «impegni» (il giudice cita «apriremo subito la
  richiesta» e il ricontatto del commerciale per una soluzione dedicata,
  che le procedure prevedono solo per offerte o preventivi; la v1 di
  riferimento lo chiede). La rimisura confermata: le due risposte sono
  diverse (101 parole contro 91), e la misura resta 6 su 8. Come dato,
  senza esito: «Il telefono del cliente nella risposta di v2: assente». I
  token in entrata 973 contro 2013; giudizi conformi allo schema 4 su 4.
  L'esercitazione risolta passo per passo è in fondo a questo README.

## Verifica (tools/verifica.sh M2-E01)

Controlla il lavoro, non il risultato delle pratiche: v0 misurata e
giudicata due volte
(`giudizi/v0.json` e `giudizi/v0-bis.json`), v1 misurata e diversa da v0,
ogni versione misurata completa (risposta e giudizio con un esito per
ogni affermazione; i controlli di `controlli.tsv` li rifà sulla risposta,
come `--confronta`: `controlli/<versione>.txt` è per voi, gli esiti non lo
usano), e in `registro.md` la riga di ogni versione
misurata, compilata e con la sua pratica (`partenza` per v0, una
dell'elenco di `./misura.sh --pratiche` per le altre). Poi stampa le
misure e l'esito di ogni pratica; stampa anche, come dato e senza esito,
se la risposta dell'ultima versione ripete il telefono del cliente
(quello del caso di CiaspoLink: sul percorso A il vostro lo cerca
`controlli.tsv`). Una pratica non confermata non vi ferma: è un
risultato. Se manca qualcosa, o se un giudizio strutturato non rispetta
lo schema, lo stampa e non passa (codice di uscita 1).

## Se qualcosa va storto

- `misura.sh` dice che il prompt usa un segnaposto che in `dati/` non c'è:
  controllate il nome tra le doppie graffe, per esempio `{{procedure}}`.
- `misura.sh` si ferma perché il prompt composto è troppo lungo: i file di
  `dati/` sono troppo lunghi per una chiamata (oltre 100 000 byte, e il
  messaggio dice quanti ne ha ciascuno); accorciateli.
- `misura.sh` si ferma perché il testo per il giudice è troppo lungo (il
  messaggio lo chiama «la consegna al giudice»): la
  rubrica, i file di `dati/` e la risposta insieme superano lo stesso
  limite; accorciate i file di `dati/` o la rubrica, o chiedete nel prompt
  una risposta più breve.
- `misura.sh` si ferma perché non riesce a leggere i controlli, o rifiuta
  una pratica: una riga di `controlli.tsv` o di `rubrica.md` non si legge,
  e il messaggio dice quale. Tra parentesi quadre si scrive `chiarezza`,
  `contesto`, `ruolo` o `tag`; correggete e rilanciate la misura.
- `--confronta` dice «non decisa» perché la pratica è da scrivere:
  scrivetela nella colonna «pratica» di `registro.md` e rilanciate il
  confronto, senza misurare di nuovo.
- La verifica chiede di misurare di nuovo una versione: un file della sua
  misura è incompleto, per v0 anche `giudizi/v0-bis.json`; lanciate, dallo
  spazio di lavoro, il comando che la verifica stampa. Una nuova misura
  cancella prima quella
  vecchia della stessa versione: se si ferma, la versione resta da
  misurare.
- Il giudizio arriva senza esito strutturato (manca il campo
  `structured_output`): rilanciate la misura della
  stessa versione. Se succede ancora, e avete toccato
  `.claude/agents/giudice.md`, ripartite da
  `tools/reset_esercizio.sh M2-E01`; altrimenti avvisate il docente.
- La verifica scrive «la documentazione garantisce …: in questa esecuzione
  no»: un giudizio strutturato non rispetta lo schema. Misurate di nuovo
  quella versione; se succede ancora, avvisate il docente o, se lavorate da
  soli, annotatelo: è una garanzia della documentazione che in questa
  esecuzione non ha tenuto, non un errore vostro.
- Una risposta porta dati vostri, come il nome o l'e-mail: toglieteli
  prima di mostrarla in aula. In una registrazione del corso fatta
  apposta, alla domanda diretta «Come mi chiamo, e qual è il mio indirizzo
  e-mail?» il modello ha riportato l'e-mail dell'account in 3 risposte su
  3, e su cinque esecuzioni di v0 di questa esercitazione una risposta si
  è rivolta per nome a chi la eseguiva: prima di mostrare una risposta,
  controllate che non porti il vostro nome o la vostra e-mail.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E01`.

## Impronta d'uso sul piano Pro

Chiamate brevi `claude -p`, senza strumenti: tre su v0 (la risposta e due
giudizi), due su v1 (la risposta e un giudizio), cinque in tutto; sette
con la rimisura. La risposta gira su Sonnet con effort low
(973 e 2013 token in entrata, v0 e v1, nella prova del docente), i
giudizi su Haiku con effort low
(da 2988 a 3585 token in entrata e da 1395 a 1868 in uscita per giudizio,
nella stessa prova). Più la
sessione interattiva su Sonnet, di quattro o cinque turni. Il giudice gira
in una sua chiamata `claude -p`, fuori dalla sessione interattiva.
Se cambiate il modello, Opus pesa sul limite d'uso più degli altri:
usatelo per una misura sola. Niente Fable, un altro modello di Claude: sul
piano Pro funziona solo con i crediti d'uso, a consumo. Alla fine, `/exit`.

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

## La soluzione, passo per passo

Provate prima l'esercitazione da soli. Qui la risolvo io, sul percorso B,
con la prova del docente dell'8 novembre 2026, Claude Code 2.1.319,
risposte su Sonnet e giudizi su Haiku, effort low: ciò che leggete è ciò
che è successo in questa prova, una esecuzione per versione, e un'altra
esecuzione darebbe altri numeri.

La prova registrata gira con gli stessi comandi, lanciati da
`_docente/live.sh`, uno script del docente, fuori da una sessione
interattiva: qui li scrivo come li lancio io dalla sessione, e quello che
stampano è quello che ha stampato la prova, salvato in
`soluzione/trascrizione.txt`. Dove leggete «(identità dell'account,
omessa)» c'era
un dato dell'account con cui ho eseguito la prova, e l'ho tolto prima di
pubblicarla: è la cautela che trovate in «Se qualcosa va storto».

1. **Preparo lo spazio di lavoro e apro la sessione.** Dalla cartella
   `esercitazioni` creo lo spazio di lavoro, ci entro e apro Claude Code
   su Sonnet:

       tools/prepara_esercizio.sh M2-E01
       cd ~/corso-claude-code/M2-E01
       claude --model sonnet

2. **Misuro il prompt di partenza.** È di una riga, con il segnaposto del
   messaggio:

   <!-- prompt v0 -->

       scrivi risposta al cliente

       {{messaggio}}

   <!-- /prompt v0 -->

   Lo misuro così com'è, perché mi serve la partenza:

       ! ./misura.sh v0

   Sonnet risponde, i controlli girano sulla risposta, il giudice giudica
   due volte:

   <!-- estratto trascrizione.txt -->

       Risposta v0 (claude-sonnet-5-5): 973 token in entrata, 1141 in uscita
         | **Oggetto:** Re: Disservizio centralino di venerdì – Falegnameria Fittizia
         |
         | Gentile Signor Fittizio,
       […]
         | La richiameremo al +39 000 000 0103 nella mattinata di [giorno], così da discutere insieme l'indennizzo e la linea di riserva.
         |
         | Cordiali saluti,
         | (identità dell'account, omessa)
         | (identità dell'account, omessa)
         | […] (la risposta intera è in ./risposte/v0.md)
       == v0: controlli
       Controlli v0: 0 superati su 3
         ✗ [chiarezza] il numero di telefono del cliente non compare (trovato «000 000 0103»)
         ✗ [chiarezza] nessun segnaposto tra parentesi quadre da completare (trovato «[giorno]»)
         ✗ [chiarezza] al massimo 150 parole (323 parole)

   <!-- /estratto -->

   Leggo i controlli: zero su tre. Il telefono del cliente è nella
   risposta, un segnaposto `[giorno]` è rimasto da riempire, e le parole
   sono 323 dove il criterio ne ammette 150. Il giudice:

   <!-- estratto trascrizione.txt -->

       Giudizio v0 (claude-haiku-5-5): 2 affermazioni rispettate su 5
       […]
         ✗ [chiarezza] impegni: La risposta promette una proposta «con tempi e costi», il far sapere «l'esito», una richiamata «nella mattinata di [giorno]» e il recupero del ticket dallo storico, che le procedure non prevedono; non dice con chiarezza che l'amministrazione decide l'indennizzo.
         ✗ [contesto] fatti: […]
       […]
         ✗ [chiarezza] firma: […]
       […]
       Giudice su v0: stesso esito due volte su 5 affermazioni di 5; instabili: nessuna.

   <!-- /estratto -->

   I due giudizi dicono la stessa cosa su tutte le affermazioni, quindi
   nessuna è instabile, e gli esiti di v0 li posso contare tutti. La
   risposta ha deciso da sola che cosa promettere e chi firma: è quello
   che un prompt di una riga lascia al modello. Decido di mettere alla
   prova la pratica `chiarezza`.

3. **Scrivo la pratica di v1 nel registro.** Prima di riscrivere il
   prompt, in `registro.md`, riga di v1, colonna «pratica», scrivo
   `chiarezza`: è il confronto a leggerla da lì. Guardo la sua frase
   nell'elenco:

       ! ./misura.sh --pratiche

   <!-- estratto trascrizione.txt -->

       chiarezza
         Anthropic: «Sii specifico sul formato di output e sui vincoli che
         desideri.» «Più precisamente spieghi cosa vuoi, migliore sarà il
         risultato.»

   <!-- /estratto -->

4. **Scrivo v1, tag per tag.** Copio la versione precedente e la riscrivo
   nell'editor:

       ! cp prompt/v0.md prompt/v1.md

   Per ogni tag mi chiedo a quale domanda risponde, e dove ne trovo il
   contenuto:

   - `<role>`, chi scrive e a chi: l'assistenza clienti di CiaspoLink, a
     un cliente business. Lo dicono il messaggio e l'affermazione `firma`
     della rubrica.
   - `<context>`, che cosa deve sapere: in quali tag sono i dati, e che la
     risposta parte così com'è, perché non deve restare niente da
     riempire.
   - `<instructions>`, che cosa deve fare: rispondere alle due richieste
     del messaggio, l'indennizzo e la linea di riserva, ciascuna con le
     informazioni di `dati/procedure.md` (l'indennizzo lo valuta
     l'amministrazione e si apre con il numero della segnalazione, che il
     cliente ha perso; per la linea di riserva, la deviazione d'emergenza
     e il ricontatto del commerciale).
   - `<format>`, in che forma: dalla rubrica il «lei», il tono e la firma;
     dai controlli la lunghezza, che tengo a 120 parole per stare sotto il
     limite di 150.
   - `<constraints>`, che cosa fare invece di ciò che non va: parlare
     soltanto delle due richieste, e lasciare fuori la durata del guasto
     e i recapiti del cliente, come chiedono i controlli sul telefono.
   - Dopo gli ingredienti, i dati nei loro tag: `<message>` con
     `{{messaggio}}`, `<procedures>` con `{{procedure}}`.

   La versione intera:

   <!-- prompt v1 -->

       <role>
       Sei un operatore dell'assistenza clienti di CiaspoLink e rispondi per e-mail a un cliente business.
       </role>

       <context>
       Il messaggio del cliente è tra i tag <message>; le procedure dell'assistenza per le sue due richieste sono tra i tag <procedures>. La risposta parte così com'è.
       </context>

       <instructions>
       Rispondi alle due richieste del cliente, con le sole informazioni delle procedure.
       1. Indennizzo: lo valuta l'amministrazione, e la richiesta si apre con il numero della segnalazione del guasto; chiedi al cliente di ritrovarlo e di rispondere a questa e-mail.
       2. Linea di riserva: in una frase, la deviazione d'emergenza delle chiamate su un cellulare dal portale del centralino; per una soluzione dedicata, il ricontatto del commerciale negli orari d'ufficio.
       </instructions>

       <format>
       Un'e-mail di al massimo 120 parole, senza oggetto, con il «lei», un tono cortese e concreto e una sola scusa, in apertura; firma «L'assistenza clienti di CiaspoLink».
       </format>

       <constraints>
       Chiama il cliente «signor Fittizio»; parla soltanto delle due richieste, e lascia fuori la durata del guasto e i recapiti del cliente.
       </constraints>

       <message>
       {{messaggio}}
       </message>

       <procedures>
       {{procedure}}
       </procedures>

   <!-- /prompt v1 -->

5. **Misuro v1 e la confronto con v0.**

       ! ./misura.sh v1
       ! ./misura.sh --confronta v0 v1
       ! git diff --no-index prompt/v0.md prompt/v1.md

   <!-- estratto trascrizione.txt -->

       Risposta v1 (claude-sonnet-5-5): 2013 token in entrata, 313 in uscita
         | Gentile signor Fittizio,
         |
         | ci scusiamo per il disservizio di venerdì.
       […]
       Controlli v1: 3 superati su 3
         ✓ [chiarezza] il numero di telefono del cliente non compare
         ✓ [chiarezza] nessun segnaposto tra parentesi quadre da completare
         ✓ [chiarezza] al massimo 150 parole (101 parole)
       […]
       Confronto v0 → v1
         pratica di v1: chiarezza — Anthropic: «Sii specifico sul formato di output
           e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi,
           migliore sarà il risultato.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✗  ✓  [chiarezza] il numero di telefono del cliente non compare
           ✗  ✓  [chiarezza] nessun segnaposto tra parentesi quadre da completare
           ✗  ✓  [chiarezza] al massimo 150 parole
         giudice:
           ✓  ✓  [chiarezza] domande
           ✗  ✗  [chiarezza] impegni
           ✗  ✗  [contesto] fatti
           ✓  ✓  [chiarezza] lei
           ✗  ✓  [chiarezza] firma
         esito della pratica: confermata (criteri segnati [chiarezza] rispettati: 2
           su 7 in v0, 6 su 7 in v1; non rispettati in v1: impegni)
         totali: controlli 0/3 → 3/3; giudice 2 → 3 su 5
         token: in entrata 973 → 2013, in uscita 1141 → 313

   <!-- /estratto -->

   Leggo l'esito: `chiarezza` è confermata, perché i criteri segnati
   rispettati passano da 2 su 7 a 6 su 7. È una coppia sola: dice che in
   questa esecuzione v1 rispetta più criteri, non che la frase di Anthropic
   sia dimostrata. Resta non rispettata `impegni` (anche `fatti`, ma quella
   legge `contesto`, e per questa pratica non conta), e voglio sapere
   perché, quindi chiedo a Claude di leggere i due giudizi:

       Confronta giudizi/v0.json e giudizi/v1.json: quali affermazioni sono cambiate, e con quale motivo del giudice?

   La risposta a questa domanda non è registrata, perché la prova non
   apre una sessione: qui leggo io che cosa dicono i due file. Cambia una
   sola affermazione, `firma`. In v0 il giudice dice:

   <!-- estratto trascrizione.txt -->

         ✗ [chiarezza] firma: La firma è «(identità dell'account, omessa) – (identità dell'account, omessa)», cioè una persona e un'altra azienda, non l'assistenza clienti di CiaspoLink.

   <!-- /estratto -->

   In v1 `firma` è rispettata, e `impegni` resta non rispettata, con questo
   motivo:

   <!-- estratto trascrizione.txt -->

         ✗ [chiarezza] impegni: La risposta dice chi decide sull'indennizzo (l'amministrazione), ma promette «apriremo subito la richiesta» e «un commerciale la ricontatterà negli orari d'ufficio» per una soluzione dedicata, che le procedure non prevedono per questo caso (KB-09 riguarda solo offerte o preventivi).
         ✗ [contesto] fatti: […]
         ✓ [chiarezza] lei: […]
         ✓ [chiarezza] firma: La risposta chiude con «L'assistenza clienti di CiaspoLink», senza nome di persona.

   <!-- /estratto -->

   Il ricontatto del commerciale l'ho chiesto io, nel tag `instructions`:
   è un difetto del mio prompt, non della risposta. Non lo correggo qui:
   la correzione sarebbe una versione nuova, con la sua pratica e la sua
   misura, e questa esercitazione finisce con v1.

6. **Compilo il registro**, le righe di v0 e di v1: che cosa ho cambiato e
   i totali del confronto.

   <!-- estratto registro.md -->

       | v0 | partenza | il prompt di partenza | 0/3 | 2/5 | (prova automatica del docente) |
       | v1 | chiarezza | il template intero: un tag per ingrediente, le procedure nel loro tag (la versione di riferimento) | 3/3 | 3/5 | (prova automatica del docente) |

   <!-- /estratto -->

7. **Ho tempo, e faccio la rimisura.** Una copia di v1 senza nessun
   cambiamento: alla riga di v2 del registro scrivo `rimisura`, poi

       ! cp prompt/v1.md prompt/v2.md
       ! ./misura.sh v2
       ! ./misura.sh --confronta v1 v2

   <!-- estratto trascrizione.txt -->

       Confronto v1 → v2
         pratica di v2: rimisura — Anthropic: «… input identici potrebbero produrre
           output diversi tra diverse chiamate API.»
       […]
         esito della pratica: confermata (le due risposte sono diverse (parole 101
           → 91, misura 6 → 6 su 8))
         totali: controlli 3/3 → 3/3; giudice 3 → 3 su 5
         token: in entrata 2013 → 2013, in uscita 313 → 284

   <!-- /estratto -->

   Lo stesso prompt ha dato un'altra risposta, 91 parole invece di 101, e
   la misura non si è mossa: 6 su 8 tutte e due le volte. In questa prova
   è così; un'altra rimisura potrebbe andare diversamente.

8. **Esco e verifico.** Con `/exit` esco dalla sessione, torno nella
   cartella `esercitazioni` e lancio la verifica:

       cd -
       tools/verifica.sh M2-E01

   <!-- estratto trascrizione.txt -->

       Lo spazio di lavoro, versioni misurate: v0, v1, v2
         v0: controlli 0/3, giudice 2/5; due giudizi, stesso esito su 5 di 5,
           instabili: nessuna
         v1: controlli 3/3, giudice 3/5
         v2: controlli 3/3, giudice 3/5
         v1 rispetto a v0, chiarezza: confermata (criteri segnati [chiarezza]
           rispettati: 2 su 7 in v0, 6 su 7 in v1; non rispettati in v1: impegni)
         v2 rispetto a v1, rimisura: confermata (le due risposte sono diverse
           (parole 101 → 91, misura 6 → 6 su 8))
       Il telefono del cliente nella risposta di v2: assente
       Ogni giudizio strutturato è conforme a schema-giudizio.json (--json-schema), 4 su 4: confermata
       Fatto: ogni affermazione è stata messa alla prova; gli esiti sono qui sopra.

   <!-- /estratto -->

   La verifica passa: controlla il lavoro, non il risultato delle pratiche.
   La pratica `chiarezza` è confermata, in questa esecuzione, e il telefono
   del cliente non compare nelle risposte di v1 e di v2.
