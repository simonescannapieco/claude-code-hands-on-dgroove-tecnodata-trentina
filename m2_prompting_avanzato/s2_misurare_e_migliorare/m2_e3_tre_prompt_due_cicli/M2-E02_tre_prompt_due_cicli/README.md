# M2-E02 — Tre prompt, due cicli

Esercitazione del Modulo 2, nella pratica «Tre prompt, due cicli»: il
laboratorio del modulo. Usa gli stessi attrezzi di M2-E01.

## Obiettivo

Migliorare tre prompt di lavoro, uno per famiglia (sviluppo, supporto,
sistemi), con due cicli ciascuno: misurare, cambiare una cosa sola,
rimisurare. La misura la danno i controlli scritti in codice e un giudice,
un subagent che verifica le affermazioni di una rubrica.

## Tempo

80 minuti: cinque per partire, poi circa 25 per prompt.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- `claude --version` 2.1.293 o successiva: il giudice gira su Haiku.
- Python 3, che lo stesso controllo verifica.
- Consigliato: M2-E01, dove gli stessi attrezzi si usano su un prompt solo.

## Punto di partenza (tools/prepara_esercizio.sh M2-E02)

Lo spazio di lavoro `~/corso-claude-code/M2-E02/` con una cartella per
famiglia, ciascuna con `prompt/v0.md` (un prompt di una riga, come se ne
scrivono tanti), `dati/` (i dati del compito), `rubrica.md` (le
affermazioni che il giudice verifica: che cosa fa una buona risposta) e
`controlli.tsv` (i controlli scritti in codice):

- `sviluppo/`: «spiega questa funzione», sul frammento di
  `legacy/listino.inc.php` del gestionale che calcola il canone di una
  linea, con la convenzione del team sul rateo;
- `supporto/`: «rispondi al cliente», sull'e-mail di un cliente privato la
  cui linea cade più volte all'ora, con un estratto della guida al tono di
  voce dell'assistenza;
- `sistemi/`: «cosa è successo?», su un estratto del syslog di una OLT.

Poi gli attrezzi, gli stessi di M2-E01: `misura.sh`, `strumenti/kit.py`,
`schema-giudizio.json`, `.claude/agents/giudice.md`; e `registro.md`, il
registro delle versioni con una riga per famiglia e versione. I dati
vengono dai progetti di esempio di CiaspoLink: sono tutti inventati.

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
     compito (almeno uno, per esempio `parole_max`: il kit rifiuta un file
     senza controlli, e quelli della famiglia cercano dati che il vostro
     prompt non ha);
   - **Percorso B, i prompt di CiaspoLink:** le tre famiglie così come
     sono. La prova del docente è su queste.

3. Il primo ciclo, sulla famiglia più vicina al vostro lavoro (qui
   `sistemi`; al suo posto la vostra):

       ! ./misura.sh sistemi v0

   Leggete la risposta e i due elenchi: che cosa manca? Copiate il prompt
   in `sistemi/prompt/v1.md` (`! cp sistemi/prompt/v0.md sistemi/prompt/v1.md`)
   e cambiate **una cosa sola**. Nel primo ciclo, il testo (un
   ingrediente del template): la verifica chiede che `v1.md` sia diverso
   da `v0.md`. Poi:

       ! ./misura.sh sistemi v1
       ! ./misura.sh --confronta sistemi v0 v1
       ! git diff --no-index sistemi/prompt/v0.md sistemi/prompt/v1.md

   e una riga in `registro.md`. Potete chiedere a Claude di leggere il
   confronto, o di farvi domande sul compito prima di riscrivere.

4. Il secondo ciclo, dalla versione migliore: copiatela in
   `sistemi/prompt/v2.md` (`! cp sistemi/prompt/v1.md sistemi/prompt/v2.md`,
   se la migliore è v1), cambiate una cosa sola, poi
   `! ./misura.sh sistemi v2` e il confronto. Qui la cosa sola può essere
   anche il modello o l'effort, a testo invariato:
   `! ./misura.sh sistemi v2 --modello opus` (o `--modello haiku`), oppure
   `--effort medium`. Checkpoint: dopo circa 25 minuti, la prima famiglia
   misurata fino a v2 e registrata.

5. Le altre due famiglie, allo stesso modo. Se il tempo stringe, sulla
   terza basta un ciclo.

6. Uscite con `/exit`, tornate nella cartella `esercitazioni` e
   verificate:

       cd -
       tools/verifica.sh M2-E02

## Che cosa osservare

- Le risposte a v0 sono già plausibili: lunghe, generiche, con qualcosa di
  inventato. La rubrica dice che cosa serve davvero a chi le legge: è lì
  che il prompt v0 non dice niente.
- Una variabile per volta: se cambiate testo e modello insieme, non sapete
  quale dei due ha fatto la differenza.
- Il giudice è anch'esso un modello. Nello schema il motivo viene prima
  dell'esito: il giudice scrive la ragione, poi decide. Leggete i motivi, e
  quando non siete d'accordo decidete voi: se serve, riscrivete
  l'affermazione della rubrica perché sia verificabile senza ambiguità.
- Il giudice gira su Haiku. Se misurate le risposte di Haiku, il giudice
  valuta il suo stesso modello: un giudice diverso dal modello valutato è
  la scelta più prudente.
- Nelle registrazioni del corso le lunghezze chieste nel prompt sono state
  rispettate solo all'incirca (una risposta di 131 parole contro le 120
  chieste): per questo le conta il codice, in `controlli.tsv`.
- Una risposta può riportare il vostro nome: nella prova del docente, la
  v0 di supporto si è firmata con il nome del titolare dell'account, che
  nessun prompt né dato conteneva (nei file di `soluzione/` è sostituito
  da «(identità dell'account, omessa)»). Controllate le risposte prima di
  mostrarle in aula.
- Nelle registrazioni del corso, con le versioni di riferimento, ogni
  famiglia migliora su v0, ma non ogni affermazione a ogni ciclo.
  Rilanciando la stessa versione, risposta e giudizio possono cambiare.

## Verifica (tools/verifica.sh M2-E02)

Per ogni famiglia controlla che v0 e v1 siano misurate (risposta,
controlli e giudizio con un esito per ogni affermazione) e che
`prompt/v1.md` sia diverso da `prompt/v0.md`; poi, sulla somma di controlli
superati e affermazioni rispettate dell'ultima versione contro v0, che
nessuna famiglia peggiori e che almeno due migliorino; che almeno due
famiglie abbiano due cicli (v2); che in `registro.md` le righe di v0 e v1
di ogni famiglia siano compilate.

## Se qualcosa va storto

- `misura.sh` dice che il prompt usa un segnaposto che in `dati/` non c'è:
  controllate il nome tra le doppie graffe, per esempio `{{log}}`.
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
  stessa versione.
- Una famiglia peggiora: guardate il confronto e tornate alla versione
  migliore per il ciclo successivo.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-E02`.

## Impronta d'uso sul piano Pro

Ogni misura sono due chiamate brevi senza strumenti: la risposta su Sonnet
con effort low e il giudizio su Haiku con effort low. Tre famiglie per tre
versioni fanno nove misure, diciotto chiamate; più la sessione interattiva
su Sonnet, di dieci o quindici turni. Il giudice gira in una sua chiamata
`claude -p`, non come subagent dentro la sessione. Se cambiate il modello,
Opus pesa sul limite d'uso più degli altri: usatelo per una misura sola.
Niente Fable. Alla fine, `/exit`.

## Per approfondire

- La pagina sui criteri di successo e sulle valutazioni:
  https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- L'articolo «Automating eval design and hillclimbing with Claude», sul
  blog per gli sviluppatori di Anthropic:
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- La guida «Prompting best practices» della documentazione:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Il talk «Prompting 101 | Code w/ Claude», sul canale YouTube di
  Anthropic: https://www.youtube.com/watch?v=ysPbXH0LpIE
