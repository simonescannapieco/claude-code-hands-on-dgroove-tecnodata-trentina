# M2-E02 — Tre prompt, due cicli

Esercitazione del Modulo 2, «Tre prompt, due cicli»: il laboratorio del
modulo. Usa gli stessi attrezzi di M2-E01.

## Obiettivo

Migliorare tre prompt di lavoro, per lo sviluppo, il supporto e i
sistemi, con due giri di misura e correzione ciascuno: a ogni giro
mettete alla prova una frase di Anthropic, una sola,
misurando il prompt prima e dopo con dei controlli automatici e con un
secondo modello che fa da giudice. Le parole e i comandi che servono sono
tutti spiegati più sotto, in «La teoria che serve».

## Tempo

80 minuti: cinque per partire, poi circa 25 per prompt.

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
- Consigliato: M2-E01, dove gli stessi attrezzi si usano su un prompt solo.

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

### Le famiglie e i due cicli

Una **famiglia** è una cartella di questa esercitazione, sviluppo,
supporto o sistemi: un prompt con i suoi dati e i suoi criteri. Su ogni
famiglia si fanno due giri di misura e correzione, due **cicli**,
descritti più sotto.

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

### Le pratiche in M2-E02

Le parole della tabella che non conoscete ancora (criteri, affermazioni,
effort) sono spiegate nelle prossime sottosezioni.

| pratica | la frase di Anthropic | si decide qui? |
|---|---|---|
| `chiarezza` | «Sii specifico sul formato di output e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi, migliore sarà il risultato.» | sì: la leggono i criteri di formato e di lunghezza di ogni famiglia |
| `contesto` | «Fornire il contesto o la motivazione alla base delle tue istruzioni, ad esempio spiegando a Claude perché un certo comportamento è importante, può dare a Claude più informazioni sui tuoi obiettivi e aiutarlo a fornire risposte più mirate.» | sì: la leggono i criteri che dipendono dal contesto del compito |
| `tag` | «Racchiudere ogni tipo di contenuto nel proprio tag (ad esempio, `<instructions>`, `<context>`, `<input>`) riduce le interpretazioni errate.» | no: nessun criterio di partenza la legge, e l'esito resta «non decisa» |
| `ruolo` | «Impostare un ruolo nel "system prompt" (prompt di sistema) focalizza il comportamento e il tono di Claude per il tuo caso d'uso.» | no: la frase parla del system prompt, le istruzioni fisse di una conversazione, e `misura.sh` manda il vostro prompt come messaggio, con il system prompt fisso «Rispondi in italiano.»; l'esito resta «non decisa» |
| `effort` | «Modelli più capaci e livelli di effort più alti di solito dovrebbero andare meglio in una valutazione. Se non succede, spesso a frenarli sono compiti ambigui o un valutatore mal calibrato.» (traduzione nostra) | sì, a testo invariato: una copia della versione precedente, misurata con un effort più alto; l'effort è spiegato in «Gli attrezzi», la regola è in «Effort e modello, come pratiche», e il «valutatore» è il modello che giudica, qui il giudice |
| `modello` | la stessa frase | no: `misura.sh` non sa quale dei due modelli confrontati sia «più capace»; stampa la misura, e l'esito resta «non decisa» |

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

### Le versioni di M2-E02

In ogni famiglia:

- **v0** è il prompt di una riga, con il segnaposto dei suoi dati;
- **v1** è il template intero, con gli ingredienti che servono al compito
  (gli esempi sono facoltativi), pratica `chiarezza`: ogni ingrediente nel
  suo tag, e `<context>` dice soltanto in quale tag sono i dati;
- **v2** è una copia di v1 in cui cambia soltanto `<context>`, che ora
  dice anche perché si chiedono quelle cose e chi usa il risultato. Dove
  la famiglia ha un documento di riferimento (la convenzione del team, la
  guida al tono), v2 lo aggiunge dopo i dati, nel suo tag (`<convention>`,
  `<tone_guide>`), e `<context>` dice in quale tag sta: pratica `contesto`.

### Il contesto, come pratica

Nel template `<context>` risponde a «che cosa deve sapere, e perché?».
La pratica `contesto` mette alla prova quel «perché»: la frase di
Anthropic è nella tabella qui sopra. Per questo v1 ha un `<context>`
minimo, e v2 lo riempie: tra le due versioni cambia soltanto il contesto,
con il documento che il contesto nomina, dove c'è.

### Effort e modello, come pratiche

`effort` e `modello` si mettono alla prova a testo invariato: la versione
nuova è una copia della precedente, e si misura con `--effort medium` o
con `--modello opus`. La misura è la somma dei controlli superati e delle
affermazioni rispettate, senza le instabili. Con `effort` è confermata se
la misura è più alta con l'effort più alto; è non decisa se è la stessa o
se con l'effort più basso è già al massimo; è non confermata in questa
misura se è più bassa, e allora il confronto ricorda i due sospetti della
frase, il compito o il valutatore. Con `modello` resta non decisa: non si
può dire quale modello sia il più capace.

## Punto di partenza (tools/prepara_esercizio.sh M2-E02)

Lo spazio di lavoro `~/corso-claude-code/M2-E02/` con una cartella per
famiglia, ciascuna con `prompt/v0.md` (un prompt di una riga, come se ne
scrivono tanti), `dati/` (i dati del compito), `rubrica.md` (le
affermazioni che il giudice verifica: che cosa fa una buona risposta) e
`controlli.tsv` (i controlli scritti in codice):

- `sviluppo/`: «spiega questa funzione», sul frammento di
  `legacy/listino.inc.php` del gestionale, il programma di amministrazione
  dell'azienda inventata, che calcola il canone di una linea, con la
  convenzione del team sul rateo, la quota del canone per i giorni di un
  mese non intero;
- `supporto/`: «rispondi al cliente», sull'e-mail di un cliente privato la
  cui linea cade più volte all'ora, con un estratto della guida al tono di
  voce dell'assistenza;
- `sistemi/`: «cosa è successo?», su un estratto del syslog di una OLT,
  l'apparato di centrale da cui partono le fibre verso i clienti: ogni sua
  porta in fibra, detta PON, serve molte ONT, gli apparati a casa dei
  clienti.

Poi gli attrezzi, gli stessi di M2-E01: `misura.sh`, `strumenti/kit.py`
(il programma che `misura.sh` usa per i conti), `schema-giudizio.json`,
`.claude/agents/giudice.md`; e `registro.md`, il registro delle versioni
con una riga per famiglia e versione e la colonna «pratica». I dati vengono
dai progetti di esempio di CiaspoLink, l'operatore inventato del corso:
sono tutti inventati.

I criteri portano il nome della pratica che leggono, dove ne leggono una,
tra parentesi quadre in `rubrica.md` e nell'ultima colonna di
`controlli.tsv`. I controlli di formato e di lunghezza portano `chiarezza`
(in supporto c'è anche la firma, «L'assistenza clienti di CiaspoLink»); le
affermazioni che dipendono dal contesto del compito portano `contesto`.
Gli altri criteri non portano una pratica: contano nei totali, ma
nell'esito di nessuna.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`, poi aprite Claude Code su Sonnet:

       tools/prepara_esercizio.sh M2-E02
       cd ~/corso-claude-code/M2-E02
       claude --model sonnet

2. Scegliete il percorso:
   - **Percorso A, i vostri prompt:** in una o più famiglie mettete un
     prompt che usate davvero, con i dati sostituiti da valori inventati
     (niente nomi di clienti, password, indirizzi o configurazioni reali):
     il prompt in `prompt/v0.md`, i dati in `dati/`, in `rubrica.md`
     quattro o cinque affermazioni che una buona risposta rispetta, e in
     `controlli.tsv` i controlli scritti in codice adatti al vostro
     compito (almeno uno: `misura.sh` rifiuta un file senza controlli, e
     quelli della famiglia cercano dati che il vostro prompt non ha). In
     `controlli.tsv` ogni riga ha, separate da tabulazioni, `tipo` (`assente`
     o `presente`, con un'espressione regolare, `parole_max`, `parole_min` o
     `righe_max`, con un numero), `valore`, `descrizione` e, se serve,
     `pratica`; in `rubrica.md` una riga è `- **nome** [pratica]: la frase`;
     imitate le righe che ci sono; tra parentesi quadre la pratica è
     `chiarezza`, `contesto`, `ruolo` o `tag`. Il file di `dati/` si chiama
     come il segnaposto, estensione a parte; quelli che non userete mai
     potete toglierli, ma un documento che vorrete aggiungere in v2 deve
     stare in `dati/` fin da v0. Scegliete la pratica di ogni criterio
     prima di misurare v0, nell'editor o in un secondo terminale, mentre
     la sessione resta aperta;
   - **Percorso B, i prompt di CiaspoLink:** le tre famiglie così come
     sono. La prova del docente, l'esecuzione registrata che trovate risolta
     in fondo a questo README, è su queste.

3. Il primo ciclo, sulla famiglia più vicina al vostro lavoro (qui
   `sistemi`; al suo posto la vostra):

       ! ./misura.sh sistemi v0

   Leggete la risposta, i due elenchi di ✓ e ✗ con le loro pratiche e la
   riga «Giudice su v0»: su quante affermazioni i due giudizi danno lo
   stesso esito. Poi l'elenco delle pratiche, ognuna con la frase
   di Anthropic che mette alla prova:

       ! ./misura.sh --pratiche

   Scrivete la pratica del ciclo nel registro, alla riga di sistemi e v1,
   colonna «pratica», prima di riscrivere: `chiarezza`, come la prova del
   docente sul percorso B, e anche sul percorso A: la v1 è la riscrittura
   del prompt nel template (`effort` e `modello` lasciano il testo com'è, e
   la verifica vuole v1 diversa da v0). La riga di v0 ha già `partenza`. Il
   registro e i file
   si modificano nell'editor, o in un secondo terminale, mentre la sessione
   resta aperta. Prima di riscrivere leggete i dati della famiglia,
   `rubrica.md` e `controlli.tsv`: dicono che cosa deve fare una buona
   risposta. La v1 la scrivete voi: è l'esercitazione. Poi copiate v0:

       ! cp sistemi/prompt/v0.md sistemi/prompt/v1.md

   e riscrivete `sistemi/prompt/v1.md` nel vostro editor, con i tag del
   template come domande: chi scrive e a chi (ruolo, `<role>`); che cosa
   deve sapere (contesto, `<context>`: per ora, soltanto in quale tag
   sono i dati); che cosa deve fare (istruzione, `<instructions>`: che
   cosa chiedete alla risposta, passo per passo, guardando che cosa si
   aspettano `rubrica.md` e `controlli.tsv`, senza copiarli; il perché e
   chi usa il risultato li lasciate al secondo ciclo); in che forma (formato,
   `<format>`: la forma e la lunghezza); con quali limiti (vincoli,
   `<constraints>`, detti in positivo). Dopo gli ingredienti, i dati,
   ciascuno nel suo tag: per sistemi `<log>` `{{log}}` `</log>`, per
   sviluppo `<code>` `{{codice}}` `</code>`, per supporto `<message>`
   `{{messaggio}}` `</message>`. Fra doppie graffe c'è un segnaposto:
   `misura.sh` ci mette il file di `dati/` con quel nome. Sul percorso A
   riscrivete il vostro prompt nello stesso modo. Poi:

       ! ./misura.sh sistemi v1
       ! ./misura.sh --confronta sistemi v0 v1
       ! git diff --no-index sistemi/prompt/v0.md sistemi/prompt/v1.md

   e completate in `registro.md` le righe di v0 e di v1: che cosa avete
   cambiato (per v0 è già scritto), i totali della riga «totali» del
   confronto (controlli superati, affermazioni rispettate) e, se volete,
   una nota. Nel confronto, le due colonne di ✓ e ✗ sono le due versioni.
   Potete chiedere a Claude di leggere il confronto, o di farvi domande sul
   compito prima di riscrivere.

4. Il secondo ciclo parte da una copia della versione appena misurata,
   v1 (la regola è in «La regola delle versioni»):

       ! cp sistemi/prompt/v1.md sistemi/prompt/v2.md

   Scrivete nel registro la pratica di v2 e cambiate il prompt secondo
   quella pratica soltanto: sul percorso A `contesto`, come qui sotto, o
   una di quelle a testo invariato. Sul percorso B la prova del docente usa
   `contesto`: cambia soltanto
   `<context>`, che ora dice anche perché si chiedono quelle cose e chi
   usa il risultato; dove la famiglia ha un documento di riferimento,
   aggiunge anche quello, dopo i dati, nel suo tag (in sviluppo la
   convenzione del team, `<convention>` `{{convenzione}}`
   `</convention>`; in supporto la
   guida al tono, `<tone_guide>` `{{tono}}` `</tone_guide>`). Poi misurate
   v2 e confrontatela con v1:

       ! ./misura.sh sistemi v2
       ! ./misura.sh --confronta sistemi v1 v2
       ! git diff --no-index sistemi/prompt/v1.md sistemi/prompt/v2.md

   e completate la riga di v2 in `registro.md`, come quella di v1.

   In questo secondo ciclo, al posto del contesto, potete mettere alla
   prova l'effort, a testo invariato: v2 resta la copia di v1 che avete
   fatto, senza toccarla, scrivete `effort` nel registro e la misurate con
   `! ./misura.sh sistemi v2 --effort medium`. Il modello si cambia allo
   stesso modo, con `--modello opus` (pratica `modello`): il confronto
   stampa la misura, e l'esito resta non decisa.

   Punto di controllo: dopo circa 25 minuti, la prima famiglia misurata
   fino a v2 e registrata.

5. Le altre due famiglie, allo stesso modo. Se il tempo stringe, sulla
   terza basta un ciclo.

6. Uscite con `/exit`, tornate nella cartella `esercitazioni` (`cd -`
   torna alla cartella da cui siete partiti) e verificate:

       cd -
       tools/verifica.sh M2-E02

## Che cosa osservare

### Che cosa dice Anthropic

- Ogni ciclo che cambia il testo mette alla prova una frase della guida
  «Best practice per il prompting», sui criteri che la frase nomina:
  - `chiarezza`, sezione «Sii chiaro e diretto»: «Sii specifico sul
    formato di output e sui vincoli che desideri.» e «Più precisamente
    spieghi cosa vuoi, migliore sarà il risultato.»;
  - `contesto`, sezione «Aggiungi contesto per migliorare le prestazioni»:
    «Fornire il contesto o la motivazione alla base delle tue istruzioni,
    ad esempio spiegando a Claude perché un certo comportamento è
    importante, può dare a Claude più informazioni sui tuoi obiettivi e
    aiutarlo a fornire risposte più mirate.»;
  - `tag`, sezione «Struttura i prompt con tag XML»: «Racchiudere ogni
    tipo di contenuto nel proprio tag (ad esempio, `<instructions>`,
    `<context>`, `<input>`) riduce le interpretazioni errate.» Nelle
    rubriche di partenza nessun criterio la legge;
  - `ruolo`, sezione «Assegna un ruolo a Claude»: «Impostare un ruolo nel
    "system prompt" (prompt di sistema) focalizza il comportamento e il
    tono di Claude per il tuo caso d'uso.» Qui non si mette alla prova:
    `misura.sh` manda il vostro prompt come messaggio, con il system
    prompt fisso «Rispondi in italiano.».

  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- `effort` e `modello`, a testo invariato, mettono alla prova l'articolo
  di Anthropic sulle valutazioni: «Modelli più capaci e livelli di effort
  più alti di solito dovrebbero andare meglio in una valutazione. Se non
  succede, spesso a frenarli sono compiti ambigui o un valutatore mal
  calibrato.» (traduzione nostra). Lo stesso articolo descrive, fra i
  controlli delle prime esecuzioni, la prova che `misura.sh` fa su v0:
  «Claude esegue il valutatore due volte sullo stesso output e riferisce
  se il verdetto è cambiato» (traduzione nostra); e del modello giudice
  dice: «non dovrebbe essere il modello che state valutando» (traduzione
  nostra).
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- La pagina sui criteri di successo e sulle valutazioni, della valutazione
  con un modello: «Prima verifica che sia affidabile, poi scala.»
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- Il giudizio arriva con `--json-schema`. Il riferimento della CLI:
  «Ottieni output JSON convalidato corrispondente a uno JSON Schema dopo
  che l'agente completa il suo flusso di lavoro (solo modalità print).» La
  pagina sull'esecuzione programmatica: «Se un'esecuzione termina senza un
  output strutturato valido, ad esempio perché Claude ha rifiutato la
  richiesta, la risposta non contiene il campo `structured_output`.»
  https://code.claude.com/docs/it/cli-reference ·
  https://code.claude.com/docs/it/headless

### Che cosa misurano gli attrezzi

Che cosa sono i criteri, il giudice e gli esiti è in «La teoria che
serve». Qui, in più:

- Se trovate ambigua un'affermazione di `rubrica.md`, riscrivetela,
  misurate di nuovo tutte le versioni di quella famiglia, v0 compresa (una
  nuova misura rifà anche la risposta) e aggiornate i totali nel registro.
- `./misura.sh --confronta <famiglia> vA vB` legge nel registro la
  pratica di vB: il confronto stampa i conteggi dei criteri segnati, poi
  i criteri che vB non rispetta. Se da vA a vB è cambiato anche altro,
  oltre alla pratica, l'esito è non decisa, con il motivo.
- Il confronto avvisa quando la risposta e il giudizio vengono dallo
  stesso modello (lo legge dal campo `modelUsage` dei file JSON della
  risposta e del giudizio): per esempio se
  misurate le risposte di Haiku, `--modello haiku`, con il giudice su
  Haiku.
- La verifica stampa le misure e l'esito di ogni pratica, e mette alla
  prova la garanzia di `--json-schema`: ogni giudizio che porta
  `structured_output` lo porta conforme a `schema-giudizio.json`; se uno
  no, scrive «la documentazione garantisce …: in questa esecuzione no», e
  la verifica non passa.
- Nella prova del docente dell'8 novembre 2026, con Claude Code 2.1.319,
  una esecuzione per versione, per famiglia (controlli superati, poi
  affermazioni rispettate):
  - sviluppo: v0 1 su 2 e 3 su 5, v1 1 su 2 e 3 su 5, v2 1 su 2 e 4 su 5;
  - supporto: v0 2 su 4 e 3 su 5, v1 4 su 4 e 4 su 5, v2 4 su 4 e 5 su 5;
  - sistemi: v0 2 su 3 e 3 su 4, v1 2 su 3 e 3 su 4, v2 3 su 3 e 4 su 4.

  I due giudizi di v0 d'accordo su ogni affermazione (5 su 5 in sviluppo
  e in supporto, 4 su 4 in sistemi). Gli esiti, con i criteri segnati
  rispettati nelle due versioni:
  - `chiarezza`, da v0 a v1: confermata in supporto (1 su 3, poi 3 su 3)
    e in sistemi (0 su 1, poi 1 su 1); non decisa in sviluppo (1 su 2 e 1
    su 2: in v1 resta non rispettato «al massimo 300 parole», 321 parole);
  - `contesto`, da v1 a v2: confermata in sviluppo (1 su 3, poi 3 su 3),
    in supporto (1 su 2, poi 2 su 2) e in sistemi (1 su 2, poi 2 su 2).

  Giudizi conformi allo schema 12 su 12. L'esercitazione risolta passo
  per passo è in fondo a questo README.

## Verifica (tools/verifica.sh M2-E02)

Per ogni famiglia controlla il lavoro, non il risultato delle pratiche: v0
misurata e
giudicata due volte (`giudizi/v0.json` e `giudizi/v0-bis.json`), v1
misurata e diversa da v0, ogni versione misurata completa (risposta e
giudizio con un esito per ogni affermazione; i controlli di
`controlli.tsv` li rifà sulla risposta, come `--confronta`:
`controlli/<versione>.txt` è per voi, gli esiti non lo usano), e in
`registro.md` la riga di ogni versione misurata, compilata e con la sua
pratica (`partenza` per v0, una dell'elenco di `./misura.sh --pratiche`
per le altre); poi che almeno due famiglie abbiano due cicli (v2). Stampa
le misure e l'esito di ogni pratica, ogni versione confrontata con la
precedente. Una pratica non confermata non vi ferma, è un risultato. Se
manca qualcosa, o se un giudizio strutturato non rispetta lo schema, lo
stampa e non passa (codice di uscita 1).

## Se qualcosa va storto

- `misura.sh` dice che il prompt usa un segnaposto che in `dati/` non c'è:
  controllate il nome tra le doppie graffe, per esempio `{{log}}`.
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
  confronto, senza misurare di nuovo. Se dice che è cambiato anche
  altro (i file di `dati/`, il modello o l'effort), rifate il ciclo
  lasciando fermo quello.
- La verifica chiede di misurare di nuovo una versione: un file della sua
  misura è incompleto, per v0 anche `giudizi/v0-bis.json`; lanciate, dallo
  spazio di lavoro, il comando che la verifica stampa. Una nuova misura
  cancella prima quella
  vecchia della stessa versione: se si ferma, la versione resta da
  misurare.
- Il giudizio arriva senza esito strutturato (manca il campo
  `structured_output`): rilanciate la misura della
  stessa versione. Se succede ancora, avvisate il docente.
- La verifica scrive «la documentazione garantisce …: in questa esecuzione
  no»: un giudizio strutturato non rispetta lo schema. Misurate di nuovo
  quella versione; se succede ancora, avvisate il docente o, se lavorate da
  soli, annotatelo: è una garanzia della documentazione che in questa
  esecuzione non ha tenuto, non un errore vostro.
- Una famiglia peggiora: è un risultato, e il ciclo successivo parte
  comunque da una copia della versione appena misurata.
- Una risposta porta dati vostri, come il nome o l'e-mail: toglieteli
  prima di mostrarla in aula. In una registrazione del corso fatta
  apposta, alla domanda diretta «Come mi chiamo, e qual è il mio indirizzo
  e-mail?» il modello ha riportato l'e-mail dell'account in 3 risposte su
  3, e su cinque esecuzioni di v0 del supporto 4 risposte hanno portato
  dati dell'account nella firma: prima di mostrare una risposta,
  controllate che non porti il vostro nome o la vostra e-mail.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E02`.

## Impronta d'uso sul piano Pro

Chiamate brevi `claude -p`, senza strumenti: sette per famiglia, tre su v0
(la risposta e due giudizi) e due su v1 e su v2, ventuno in tutto. La
risposta gira su Sonnet con effort low
(nella prova del docente da 673 a 1725 token in entrata e da 306 a 1206
in uscita per risposta),
i giudizi su Haiku con effort low
(da 2567 a 15199 token in entrata e da 470 a 2806 in uscita per giudizio).
Più la sessione
interattiva su Sonnet, di dieci o quindici turni. Il giudice gira in una
sua chiamata `claude -p`, fuori dalla sessione interattiva. Se
cambiate il modello, Opus pesa sul limite d'uso più degli altri: usatelo
per una misura sola. Niente Fable, un altro modello di Claude: sul piano
Pro funziona solo con i crediti d'uso, a consumo. Alla fine, `/exit`.

## Per approfondire

- La pagina sui criteri di successo e sulle valutazioni:
  https://platform.claude.com/docs/it/test-and-evaluate/develop-tests
- L'articolo «Automating eval design and hillclimbing with Claude», sul
  blog degli sviluppatori di Anthropic:
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- La guida «Best practice per il prompting» della documentazione:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Il talk «Prompting 101 | Code w/ Claude», sul canale YouTube di
  Anthropic: https://www.youtube.com/watch?v=ysPbXH0LpIE

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
`soluzione/trascrizione.txt`. Il README fa l'esempio su `sistemi`; la
prova misura le
famiglie nell'ordine sviluppo, supporto, sistemi, e le seguo in
quest'ordine.

Comincio creando lo spazio di lavoro, dalla cartella `esercitazioni`,
entrandoci e aprendo Claude Code su Sonnet; sul percorso B le famiglie
restano così come sono:

    tools/prepara_esercizio.sh M2-E02
    cd ~/corso-claude-code/M2-E02
    claude --model sonnet

### Sviluppo

1. **Misuro il prompt di partenza.**

   <!-- prompt sviluppo/v0 -->

       spiega questa funzione

       {{codice}}

   <!-- /prompt sviluppo/v0 -->

       ! ./misura.sh sviluppo v0

   <!-- estratto trascrizione.txt -->

       Risposta v0 (claude-sonnet-5-5): 1097 token in entrata, 1068 in uscita
         | # Cosa fa il codice
         |
         | Calcola l'**importo di una riga di fattura mensile** per una linea/offerta in abbonamento, applicando il **rateo** (pro-rata) quando la linea è stata attivata o cessata nel mese di fatturazione.
       […]
       Controlli v0: 1 superato su 2
         ✓ [chiarezza] contiene un blocco di codice
         ✗ [chiarezza] al massimo 300 parole (361 parole)
       […]
       Giudizio v0 (claude-haiku-5-5): 3 affermazioni rispettate su 5
         ✗ [contesto] mese_fisso: La risposta descrive il 'mese commerciale' di 30 giorni e, nel punto su febbraio, lo giudica 'coerente con la convenzione', senza segnalare che la convenzione 5.3 chiede i giorni effettivi del mese: il contrasto non viene riconosciuto.
       […]
         ✗ [contesto] correzione: Le correzioni proposte sono min($gg, $gg_mese), arrotondamento con intdiv/round e cessazione − attivazione + 1, ma nessuna usa i giorni effettivi del mese: resta il divisore 30 fisso.
       […]
       Giudice su v0: stesso esito due volte su 5 affermazioni di 5; instabili: nessuna.

   <!-- /estratto -->

   Leggo: la risposta spiega il frammento, ma non lo mette a confronto
   con la convenzione del team, perché v0 non gliela dà. È anche lunga: 361
   parole dove il criterio ne ammette 300. I due giudizi dicono la stessa
   cosa su tutte le affermazioni, quindi conto tutti gli esiti.

2. **La pratica di v1, poi v1, tag per tag.** Nel registro, alla riga di
   sviluppo e v1, scrivo `chiarezza`. La sua frase, nell'elenco:

       ! ./misura.sh --pratiche

   <!-- estratto trascrizione.txt -->

       chiarezza
         Anthropic: «Sii specifico sul formato di output e sui vincoli che
         desideri.» «Più precisamente spieghi cosa vuoi, migliore sarà il
         risultato.»

   <!-- /estratto -->

   Copio v0 e riscrivo la copia:

       ! cp sviluppo/prompt/v0.md sviluppo/prompt/v1.md

   - `<role>`, chi scrive e a chi: un programmatore PHP che scrive a un
     collega, perché il frammento è codice e la spiegazione non va a un
     cliente.
   - `<context>`: per ora soltanto dove sono i dati, nel tag `<code>`.
   - `<instructions>`: la riga di v0, «spiega questa funzione», e quello
     che chiede la rubrica: i casi in cui il frammento sbaglia l'importo,
     con un esempio numerico, e la correzione.
   - `<format>`: dai controlli, un blocco di codice PHP e al massimo 300
     parole; dalla rubrica, un elenco dei difetti.
   - `<constraints>`: dall'affermazione `niente_invenzioni`, citare
     soltanto ciò che ha davanti.
   - I dati: `<code>` con `{{codice}}`.

   <!-- prompt sviluppo/v1 -->

       <role>
       Sei un programmatore PHP e scrivi a un collega.
       </role>

       <context>
       Il frammento di codice è tra i tag <code>.
       </context>

       <instructions>
       Spiega questa funzione.
       1. Trova i casi in cui il frammento sbaglia l'importo, ciascuno con un esempio numerico.
       2. Proponi la correzione.
       </instructions>

       <format>
       Un elenco puntato dei difetti, poi la correzione in un blocco di codice PHP; al massimo 300 parole in tutto.
       </format>

       <constraints>
       Cita soltanto le funzioni, i campi e i file che hai davanti.
       </constraints>

       <code>
       {{codice}}
       </code>

   <!-- /prompt sviluppo/v1 -->

3. **Misuro v1 e la confronto con v0.**

       ! ./misura.sh sviluppo v1
       ! ./misura.sh --confronta sviluppo v0 v1

   Le due colonne di ✓ e ✗ sono v0 e v1:

   <!-- estratto trascrizione.txt -->

       Confronto v0 → v1 (sviluppo)
         pratica di v1: chiarezza — Anthropic: «Sii specifico sul formato di output
           e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi,
           migliore sarà il risultato.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✓  ✓  [chiarezza] contiene un blocco di codice
           ✗  ✗  [chiarezza] al massimo 300 parole
         giudice:
           ✗  ✗  [contesto] mese_fisso
           ✓  ✓  casi
           ✓  ✓  [contesto] stesso_mese
           ✗  ✗  [contesto] correzione
           ✓  ✓  niente_invenzioni
         esito della pratica: non decisa (criteri segnati [chiarezza] rispettati: 1
           su 2 in v0, 1 su 2 in v1; lo stesso numero: questa coppia non lo dice;
           non rispettati in v1: al massimo 300 parole)
         totali: controlli 1/2 → 1/2; giudice 3 → 3 su 5
         token: in entrata 1097 → 1322, in uscita 1068 → 951

   <!-- /estratto -->

   Leggo: `chiarezza` qui è non decisa. I due criteri segnati sono uno
   rispettato prima e dopo e uno mancato prima e dopo, perché la risposta
   di v1 arriva a 321 parole. Lo stesso numero non mi dice se la frase
   regge. Scrivo la riga nel registro, e passo al secondo ciclo.

4. **v2: cambio soltanto il contesto.** Nel registro, alla riga di
   sviluppo e v2, scrivo `contesto`. Copio v1 e tocco soltanto `<context>`:
   da dove viene il frammento e che cosa calcola, che l'importo giusto è
   quello della convenzione del team, perché dal calcolo nascono le
   fatture, e chi usa il risultato. La convenzione entra dopo i dati, nel
   suo tag `<convention>`, con il segnaposto del file:

       ! cp sviluppo/prompt/v1.md sviluppo/prompt/v2.md

   Modifico `sviluppo/prompt/v2.md` nell'editor, poi guardo che cosa è
   cambiato:

       ! git diff --no-index sviluppo/prompt/v1.md sviluppo/prompt/v2.md

   <!-- estratto trascrizione.txt -->

       diff --git a/sviluppo/prompt/v1.md b/sviluppo/prompt/v2.md
       index bb70236..8c48ed7 100644
       --- a/sviluppo/prompt/v1.md
       +++ b/sviluppo/prompt/v2.md
       @@ -3,7 +3,7 @@ Sei un programmatore PHP e scrivi a un collega.
        </role>

        <context>
       -Il frammento di codice è tra i tag <code>.
       +Il frammento di codice è tra i tag <code> e viene da legacy/listino.inc.php, il gestionale di CiaspoLink: calcola in centesimi il canone mensile di una linea, anche quando la linea è attivata o cessata nel mese. L'importo giusto è quello della convenzione del team, tra i tag <convention>: dal calcolo nascono le righe delle fatture dei clienti. La revisione serve a chi mantiene il gestionale.
        </context>

        <instructions>
       @@ -23,3 +23,7 @@ Cita soltanto le funzioni, i campi e i file che hai davanti.
        <code>
        {{codice}}
        </code>
       +
       +<convention>
       +{{convenzione}}
       +</convention>

   <!-- /estratto -->

   <!-- prompt sviluppo/v2 -->

       <role>
       Sei un programmatore PHP e scrivi a un collega.
       </role>

       <context>
       Il frammento di codice è tra i tag <code> e viene da legacy/listino.inc.php, il gestionale di CiaspoLink: calcola in centesimi il canone mensile di una linea, anche quando la linea è attivata o cessata nel mese. L'importo giusto è quello della convenzione del team, tra i tag <convention>: dal calcolo nascono le righe delle fatture dei clienti. La revisione serve a chi mantiene il gestionale.
       </context>

       <instructions>
       Spiega questa funzione.
       1. Trova i casi in cui il frammento sbaglia l'importo, ciascuno con un esempio numerico.
       2. Proponi la correzione.
       </instructions>

       <format>
       Un elenco puntato dei difetti, poi la correzione in un blocco di codice PHP; al massimo 300 parole in tutto.
       </format>

       <constraints>
       Cita soltanto le funzioni, i campi e i file che hai davanti.
       </constraints>

       <code>
       {{codice}}
       </code>

       <convention>
       {{convenzione}}
       </convention>

   <!-- /prompt sviluppo/v2 -->

5. **Misuro v2 e la confronto con v1.**

       ! ./misura.sh sviluppo v2
       ! ./misura.sh --confronta sviluppo v1 v2

   <!-- estratto trascrizione.txt -->

       Confronto v1 → v2 (sviluppo)
         pratica di v2: contesto — Anthropic: «Fornire il contesto o la motivazione
           alla base delle tue istruzioni, ad esempio spiegando a Claude perché un
           certo comportamento è importante, può dare a Claude più informazioni sui
           tuoi obiettivi e aiutarlo a fornire risposte più mirate.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✓  ✓  [chiarezza] contiene un blocco di codice
           ✗  ✗  [chiarezza] al massimo 300 parole
         giudice:
           ✗  ✓  [contesto] mese_fisso
           ✓  ✓  casi
           ✓  ✓  [contesto] stesso_mese
           ✗  ✓  [contesto] correzione
           ✓  ✗  niente_invenzioni
         esito della pratica: confermata (criteri segnati [contesto] rispettati: 1
           su 3 in v1, 3 su 3 in v2)
         totali: controlli 1/2 → 1/2; giudice 3 → 4 su 5
         token: in entrata 1322 → 1570, in uscita 951 → 1206

   <!-- /estratto -->

   Leggo: `contesto` è confermata, da 1 su 3 a 3 su 3. Con la convenzione
   davanti, la risposta segnala i 30 giorni fissi e corregge il calcolo
   con i giorni effettivi del mese. Cade `niente_invenzioni`, che non
   porta nessuna pratica, e conta solo nel totale; il motivo del giudice
   lo leggo:

   <!-- estratto trascrizione.txt -->

         ✗ niente_invenzioni: Il blocco di correzione usa funzioni PHP (date, mktime, max, round) che non compaiono nel codice né nella convenzione; sono funzioni reali ma citate fuori dal perimetro dei soli elementi presenti nei dati, quindi l'affermazione non è rispettata nel senso letterale.

   <!-- /estratto -->

   Le funzioni di una correzione in PHP non sono un'invenzione: qui il
   giudice ha letto l'affermazione alla lettera, e su questo punto decido
   io; il totale del registro resta quello del giudice. Scrivo la riga nel
   registro:

   <!-- estratto registro.md -->

       | sviluppo | v0 | partenza | il prompt di partenza | 1/2 | 3/5 | (prova automatica del docente) |
       | sviluppo | v1 | chiarezza | il template intero: un tag per ingrediente, il dato nel suo tag | 1/2 | 3/5 | (prova automatica del docente) |
       | sviluppo | v2 | contesto | solo il contesto: il perché e chi usa il risultato, e la convenzione del team nel suo tag | 1/2 | 4/5 | (prova automatica del docente) |

   <!-- /estratto -->

### Supporto

1. **Misuro il prompt di partenza.**

   <!-- prompt supporto/v0 -->

       rispondi al cliente

       {{messaggio}}

   <!-- /prompt supporto/v0 -->

       ! ./misura.sh supporto v0

   <!-- estratto trascrizione.txt -->

       Risposta v0 (claude-sonnet-5-5): 673 token in entrata, 644 in uscita
         | **Oggetto: R: La linea cade spesso**
         |
         | Buongiorno Sig. Fabio,
       […]
         | Cordiali saluti,
         | Il Servizio Assistenza Clienti
       == v0: controlli
       Controlli v0: 2 superati su 4
         ✗ [chiarezza] al massimo 130 parole (240 parole)
         ✓ [chiarezza] nessun segnaposto tra parentesi quadre da completare
         ✓ nessun punto esclamativo
         ✗ [chiarezza] firmata dall'assistenza clienti di CiaspoLink (non trovato)
       […]
       Giudizio v0 (claude-haiku-5-5): 3 affermazioni rispettate su 5
       […]
         ✗ una_scusa: La risposta contiene due scuse, «ci scusiamo per il disagio» all'inizio e «ci scusiamo ancora per l'inconveniente» alla fine, quindi supera il massimo di una; non attribuisce colpa esplicita al cliente.
         ✗ [contesto] tono: […]
       […]
       Giudice su v0: stesso esito due volte su 5 affermazioni di 5; instabili: nessuna.

   <!-- /estratto -->

   Leggo: la firma non è quella che vuole il criterio, la risposta è lunga
   il doppio del dovuto e le scuse sono due.

2. **La pratica di v1, poi v1, tag per tag.** Nel registro, alla riga di
   supporto e v1, `chiarezza`.

       ! cp supporto/prompt/v0.md supporto/prompt/v1.md

   - `<role>`, chi scrive e a chi: l'assistenza clienti di CiaspoLink, a un
     cliente privato: lo dicono la cartella e il messaggio.
   - `<context>`: soltanto dove sono i dati, nel tag `<message>`.
   - `<instructions>`: dalla rubrica, una scusa sola e i passi che il
     cliente può fare; dal messaggio, come ci aggiorna.
   - `<format>`: dai controlli la lunghezza e la firma, dalla rubrica il
     «lei» e nessun oggetto.
   - `<constraints>`: dai controlli, una risposta senza parti da
     completare e senza punti esclamativi, detto in positivo.
   - I dati: `<message>` con `{{messaggio}}`.

   <!-- prompt supporto/v1 -->

       <role>
       Sei un operatore dell'assistenza clienti di CiaspoLink e rispondi per e-mail a un cliente privato.
       </role>

       <context>
       Il messaggio del cliente è tra i tag <message>.
       </context>

       <instructions>
       Rispondi al cliente.
       1. Scusati una volta sola.
       2. Indica due o tre passi semplici che può fare lui.
       3. Digli come ci aggiorna.
       </instructions>

       <format>
       Un'e-mail di al massimo 120 parole, senza oggetto, con il «lei»; firma «L'assistenza clienti di CiaspoLink».
       </format>

       <constraints>
       Consegna una risposta completa, pronta da inviare; chiudi le frasi con il punto.
       </constraints>

       <message>
       {{messaggio}}
       </message>

   <!-- /prompt supporto/v1 -->

3. **Misuro v1 e la confronto con v0.**

       ! ./misura.sh supporto v1
       ! ./misura.sh --confronta supporto v0 v1

   <!-- estratto trascrizione.txt -->

       Confronto v0 → v1 (supporto)
         pratica di v1: chiarezza — Anthropic: «Sii specifico sul formato di output
           e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi,
           migliore sarà il risultato.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✗  ✓  [chiarezza] al massimo 130 parole
           ✓  ✓  [chiarezza] nessun segnaposto tra parentesi quadre da completare
           ✓  ✓  nessun punto esclamativo
           ✗  ✓  [chiarezza] firmata dall'assistenza clienti di CiaspoLink
         giudice:
           ✓  ✓  lei
           ✓  ✓  passi
           ✓  ✗  [contesto] orari
           ✗  ✓  una_scusa
           ✗  ✓  [contesto] tono
         esito della pratica: confermata (criteri segnati [chiarezza] rispettati: 1
           su 3 in v0, 3 su 3 in v1)
         totali: controlli 2/4 → 4/4; giudice 3 → 4 su 5
         token: in entrata 673 → 933, in uscita 644 → 317

   <!-- /estratto -->

   Leggo: `chiarezza` è confermata, da 1 su 3 a 3 su 3. In v1 però cade
   `orari`:

   <!-- estratto trascrizione.txt -->

         ✗ [contesto] orari: La risposta promette «entro due giorni lavorativi» per l'esito, ma né il messaggio né la guida danno questo tempo; la guida chiede di non inventare orari.

   <!-- /estratto -->

   Il modello ha promesso un tempo che nessuno gli ha dato: è proprio ciò
   che il contesto dovrà governare nel ciclo seguente.

4. **v2: cambio soltanto il contesto.** Nel registro, alla riga di
   supporto e v2, `contesto`. Copio v1, e in `<context>` dico chi scrive e
   che cosa sappiamo, che la risposta segue la guida al tono di voce, e
   perché, e chi la legge. La guida entra dopo i dati, nel suo tag:

       ! cp supporto/prompt/v1.md supporto/prompt/v2.md

   Modifico `supporto/prompt/v2.md` nell'editor, poi guardo che cosa è
   cambiato:

       ! git diff --no-index supporto/prompt/v1.md supporto/prompt/v2.md

   <!-- estratto trascrizione.txt -->

       diff --git a/supporto/prompt/v1.md b/supporto/prompt/v2.md
       index 9c620e9..c1c0895 100644
       --- a/supporto/prompt/v1.md
       +++ b/supporto/prompt/v2.md
       @@ -3,7 +3,7 @@ Sei un operatore dell'assistenza clienti di CiaspoLink e rispondi per e-mail a u
        </role>

        <context>
       -Il messaggio del cliente è tra i tag <message>.
       +Il messaggio del cliente è tra i tag <message>: scrive un cliente privato di CiaspoLink, e della sua linea sappiamo solo quello che scrive. La risposta segue la guida al tono di voce dell'assistenza, tra i tag <tone_guide>, perché il cliente ritrovi lo stesso modo di parlare in ogni risposta; la legge il cliente da solo, senza un operatore accanto.
        </context>

        <instructions>
       @@ -24,3 +24,7 @@ Consegna una risposta completa, pronta da inviare; chiudi le frasi con il punto.
        <message>
        {{messaggio}}
        </message>
       +
       +<tone_guide>
       +{{tono}}
       +</tone_guide>

   <!-- /estratto -->

   <!-- prompt supporto/v2 -->

       <role>
       Sei un operatore dell'assistenza clienti di CiaspoLink e rispondi per e-mail a un cliente privato.
       </role>

       <context>
       Il messaggio del cliente è tra i tag <message>: scrive un cliente privato di CiaspoLink, e della sua linea sappiamo solo quello che scrive. La risposta segue la guida al tono di voce dell'assistenza, tra i tag <tone_guide>, perché il cliente ritrovi lo stesso modo di parlare in ogni risposta; la legge il cliente da solo, senza un operatore accanto.
       </context>

       <instructions>
       Rispondi al cliente.
       1. Scusati una volta sola.
       2. Indica due o tre passi semplici che può fare lui.
       3. Digli come ci aggiorna.
       </instructions>

       <format>
       Un'e-mail di al massimo 120 parole, senza oggetto, con il «lei»; firma «L'assistenza clienti di CiaspoLink».
       </format>

       <constraints>
       Consegna una risposta completa, pronta da inviare; chiudi le frasi con il punto.
       </constraints>

       <message>
       {{messaggio}}
       </message>

       <tone_guide>
       {{tono}}
       </tone_guide>

   <!-- /prompt supporto/v2 -->

5. **Misuro v2 e la confronto con v1.**

       ! ./misura.sh supporto v2
       ! ./misura.sh --confronta supporto v1 v2

   <!-- estratto trascrizione.txt -->

       Confronto v1 → v2 (supporto)
         pratica di v2: contesto — Anthropic: «Fornire il contesto o la motivazione
           alla base delle tue istruzioni, ad esempio spiegando a Claude perché un
           certo comportamento è importante, può dare a Claude più informazioni sui
           tuoi obiettivi e aiutarlo a fornire risposte più mirate.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✓  ✓  [chiarezza] al massimo 130 parole
           ✓  ✓  [chiarezza] nessun segnaposto tra parentesi quadre da completare
           ✓  ✓  nessun punto esclamativo
           ✓  ✓  [chiarezza] firmata dall'assistenza clienti di CiaspoLink
         giudice:
           ✓  ✓  lei
           ✓  ✓  passi
           ✗  ✓  [contesto] orari
           ✓  ✓  una_scusa
           ✓  ✓  [contesto] tono
         esito della pratica: confermata (criteri segnati [contesto] rispettati: 1
           su 2 in v1, 2 su 2 in v2)
         totali: controlli 4/4 → 4/4; giudice 4 → 5 su 5
         token: in entrata 933 → 1523, in uscita 317 → 306

   <!-- /estratto -->

   Leggo: `contesto` è confermata, da 1 su 2 a 2 su 2:
   nella risposta di v2 non c'è più un tempo promesso. Scrivo la riga nel
   registro:

   <!-- estratto registro.md -->

       | supporto | v0 | partenza | il prompt di partenza | 2/4 | 3/5 | (prova automatica del docente) |
       | supporto | v1 | chiarezza | il template intero: un tag per ingrediente, il dato nel suo tag | 4/4 | 4/5 | (prova automatica del docente) |
       | supporto | v2 | contesto | solo il contesto: il perché e chi usa il risultato, e la guida al tono nel suo tag | 4/4 | 5/5 | (prova automatica del docente) |

   <!-- /estratto -->

### Sistemi

1. **Misuro il prompt di partenza.**

   <!-- prompt sistemi/v0 -->

       cosa è successo?

       {{log}}

   <!-- /prompt sistemi/v0 -->

       ! ./misura.sh sistemi v0

   <!-- estratto trascrizione.txt -->

       Risposta v0 (claude-sonnet-5-5): 1451 token in entrata, 935 in uscita
         | **Sintesi:** alle 10:12:31 del 2026-09-08 l'OLT `olt-pergine-01` ha perso completamente il segnale ottico (LOS, *Loss of Signal*) sulla porta PON 0/1/3. Tutte le 40 ONT collegate a quella porta sono andate offline contemporaneamente, con causa LOS.
       […]
       Controlli v0: 2 superati su 3
         ✗ [chiarezza] al massimo 8 righe (17 righe)
         ✓ nomina la porta della OLT
         ✓ dice il numero di ONT coinvolte
       […]
       Giudizio v0 (claude-haiku-5-5): 3 affermazioni rispettate su 4
       […]
         ✗ [contesto] primo_controllo: Il primo elemento della sezione "Cosa verificare" è controllare se la porta è tornata su (cercare PON_LOS_RECOVER); il controllo del modulo ottico della porta compare solo al secondo posto e nessun punto comune a monte è indicato come primo controllo.
       […]
       Giudice su v0: stesso esito due volte su 4 affermazioni di 4; instabili: nessuna.

   <!-- /estratto -->

   Leggo: la diagnosi c'è, ma la risposta è un rapporto di 17 righe, dove
   il criterio ne ammette 8, e per il giudice non dice da dove partire.

2. **La pratica di v1, poi v1, tag per tag.** Nel registro, alla riga di
   sistemi e v1, `chiarezza`.

       ! cp sistemi/prompt/v0.md sistemi/prompt/v1.md

   - `<role>`, chi scrive e a chi: un tecnico di rete che scrive una nota
     a un collega.
   - `<context>`: soltanto dove sono i dati, nel tag `<log>`.
   - `<instructions>`: la riga di v0, «che cosa è successo», e le domande
     della rubrica: un guasto solo o tanti, quanti clienti, che cosa
     controllare per primo, e perché.
   - `<format>`: dai controlli, una nota breve; chiedo cinque righe per
     stare sotto il limite di otto.
   - `<constraints>`: dall'affermazione `cauto`, le cause come ipotesi.
   - I dati: `<log>` con `{{log}}`.

   <!-- prompt sistemi/v1 -->

       <role>
       Sei un tecnico di rete e scrivi una nota a un collega.
       </role>

       <context>
       Le righe del syslog sono tra i tag <log>.
       </context>

       <instructions>
       Di' che cosa è successo.
       1. Un guasto solo o tanti?
       2. Quanti clienti sono coinvolti?
       3. Che cosa controlli per primo, e perché?
       </instructions>

       <format>
       Una nota di al massimo cinque righe.
       </format>

       <constraints>
       Presenta le cause come ipotesi da verificare.
       </constraints>

       <log>
       {{log}}
       </log>

   <!-- /prompt sistemi/v1 -->

3. **Misuro v1 e la confronto con v0.**

       ! ./misura.sh sistemi v1
       ! ./misura.sh --confronta sistemi v0 v1

   <!-- estratto trascrizione.txt -->

       Confronto v0 → v1 (sistemi)
         pratica di v1: chiarezza — Anthropic: «Sii specifico sul formato di output
           e sui vincoli che desideri.» «Più precisamente spieghi cosa vuoi,
           migliore sarà il risultato.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✗  ✓  [chiarezza] al massimo 8 righe
           ✓  ✗  nomina la porta della OLT
           ✓  ✓  dice il numero di ONT coinvolte
         giudice:
           ✓  ✗  [contesto] un_guasto
           ✓  ✓  quanti
           ✗  ✓  [contesto] primo_controllo
           ✓  ✓  cauto
         esito della pratica: confermata (criteri segnati [chiarezza] rispettati: 0
           su 1 in v0, 1 su 1 in v1)
         totali: controlli 2/3 → 2/3; giudice 3 → 3 su 4
         token: in entrata 1451 → 1643, in uscita 935 → 414

   <!-- /estratto -->

   Leggo: `chiarezza` è confermata, ed è un solo criterio, la lunghezza. Il
   resto si muove nei due sensi: la nota cita la porta come «1/3», e il
   controllo che cerca «0/1/3» non la trova; lo dice anche il motivo del
   giudice su `un_guasto`:

   <!-- estratto trascrizione.txt -->

         ✗ [contesto] un_guasto: La risposta dice «è un guasto solo, a livello di porta/fibra, non 40 guasti separati», ma non dice esplicitamente «a monte» e indica la porta come «1/3», senza il frame 0 (PON 0/1/3).

   <!-- /estratto -->

4. **v2: cambio soltanto il contesto.** Nel registro, alla riga di
   sistemi e v2, `contesto`. Copio v1, e in `<context>` dico che cosa sono
   le righe del log e a chi serve la nota. Questa famiglia non ha un
   documento di riferimento, quindi non aggiungo tag:

       ! cp sistemi/prompt/v1.md sistemi/prompt/v2.md

   Modifico `sistemi/prompt/v2.md` nell'editor, poi guardo che cosa è
   cambiato:

       ! git diff --no-index sistemi/prompt/v1.md sistemi/prompt/v2.md

   <!-- estratto trascrizione.txt -->

       diff --git a/sistemi/prompt/v1.md b/sistemi/prompt/v2.md
       index a092cd0..81552d9 100644
       --- a/sistemi/prompt/v1.md
       +++ b/sistemi/prompt/v2.md
       @@ -3,7 +3,7 @@ Sei un tecnico di rete e scrivi una nota a un collega.
        </role>

        <context>
       -Le righe del syslog sono tra i tag <log>.
       +Le righe del syslog sono tra i tag <log>: un estratto del syslog di una OLT di CiaspoLink, dove la prima riga è l'allarme della porta e le altre sono le ONT dei clienti che vanno offline. La nota serve al collega di turno, per decidere da dove partire.
        </context>

        <instructions>

   <!-- /estratto -->

   <!-- prompt sistemi/v2 -->

       <role>
       Sei un tecnico di rete e scrivi una nota a un collega.
       </role>

       <context>
       Le righe del syslog sono tra i tag <log>: un estratto del syslog di una OLT di CiaspoLink, dove la prima riga è l'allarme della porta e le altre sono le ONT dei clienti che vanno offline. La nota serve al collega di turno, per decidere da dove partire.
       </context>

       <instructions>
       Di' che cosa è successo.
       1. Un guasto solo o tanti?
       2. Quanti clienti sono coinvolti?
       3. Che cosa controlli per primo, e perché?
       </instructions>

       <format>
       Una nota di al massimo cinque righe.
       </format>

       <constraints>
       Presenta le cause come ipotesi da verificare.
       </constraints>

       <log>
       {{log}}
       </log>

   <!-- /prompt sistemi/v2 -->

5. **Misuro v2 e la confronto con v1.**

       ! ./misura.sh sistemi v2
       ! ./misura.sh --confronta sistemi v1 v2

   <!-- estratto trascrizione.txt -->

       Confronto v1 → v2 (sistemi)
         pratica di v2: contesto — Anthropic: «Fornire il contesto o la motivazione
           alla base delle tue istruzioni, ad esempio spiegando a Claude perché un
           certo comportamento è importante, può dare a Claude più informazioni sui
           tuoi obiettivi e aiutarlo a fornire risposte più mirate.»
           https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
         controlli:
           ✓  ✓  [chiarezza] al massimo 8 righe
           ✗  ✓  nomina la porta della OLT
           ✓  ✓  dice il numero di ONT coinvolte
         giudice:
           ✗  ✓  [contesto] un_guasto
           ✓  ✓  quanti
           ✓  ✓  [contesto] primo_controllo
           ✓  ✓  cauto
         esito della pratica: confermata (criteri segnati [contesto] rispettati: 1
           su 2 in v1, 2 su 2 in v2)
         totali: controlli 2/3 → 3/3; giudice 3 → 4 su 4
         token: in entrata 1643 → 1725, in uscita 414 → 366

   <!-- /estratto -->

   Leggo: `contesto` è confermata, da 1 su 2 a 2 su 2, e
   la nota di v2 nomina la porta per intero. Scrivo la riga nel registro:

   <!-- estratto registro.md -->

       | sistemi | v0 | partenza | il prompt di partenza | 2/3 | 3/4 | (prova automatica del docente) |
       | sistemi | v1 | chiarezza | il template intero: un tag per ingrediente, il dato nel suo tag | 2/3 | 3/4 | (prova automatica del docente) |
       | sistemi | v2 | contesto | solo il contesto: il perché e chi usa il risultato | 3/3 | 4/4 | (prova automatica del docente) |

   <!-- /estratto -->

### La verifica

Esco dalla sessione con `/exit`, torno nella cartella `esercitazioni` e
lancio la verifica:

    cd -
    tools/verifica.sh M2-E02

<!-- estratto trascrizione.txt -->

    Sviluppo, versioni misurate: v0, v1, v2
    […]
      v1 rispetto a v0, chiarezza: non decisa (criteri segnati [chiarezza]
        rispettati: 1 su 2 in v0, 1 su 2 in v1; lo stesso numero: questa coppia
        non lo dice; non rispettati in v1: al massimo 300 parole)
      v2 rispetto a v1, contesto: confermata (criteri segnati [contesto]
        rispettati: 1 su 3 in v1, 3 su 3 in v2)
    […]
    Famiglie con due cicli (v2): 3 su tre.
    Ogni giudizio strutturato è conforme a schema-giudizio.json (--json-schema), 12 su 12: confermata
    Fatto: ogni affermazione è stata messa alla prova; gli esiti sono qui sopra.

<!-- /estratto -->

La verifica passa: controlla il lavoro, non il risultato delle pratiche.
In questa prova
`contesto` è confermata in tutte e tre le famiglie, e `chiarezza` in due:
in sviluppo resta non decisa. È ciò che è successo in questa prova, una
esecuzione per versione.
