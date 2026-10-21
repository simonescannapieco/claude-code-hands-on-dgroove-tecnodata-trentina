# M1-D05 — La circolare che non esiste

Demo del Modulo 1, nella parte «Punti di forza, limiti, allucinazioni». In
aula si fa in claude.ai: ognuno incolla nel proprio Claude una circolare
inventata, con tre regole, e chiede il riassunto di un'altra circolare,
che non c'è. Il docente la ripete in Claude Code sui tre modelli, con le
regole e senza, e uno script controlla le risposte.

## Obiettivo

Mettere alla prova tre tecniche che Anthropic consiglia contro le
allucinazioni: il permesso di dire «non lo so», le sole informazioni del
documento, una citazione per ogni affermazione. Il documento sta accanto
alla domanda: alla domanda A risponde, alla domanda B no. Così è il
codice, e non chi legge, a dire se le frasi citate stanno davvero nel
documento e se nella risposta compaiono numeri che il documento non ha.

## Tempo

3 minuti in aula; per rifarla in Claude Code, dodici chiamate brevi, una
dopo l'altra.

## Prerequisiti

- In aula: claude.ai aperto nel browser, con il vostro account Pro.
- Per rifarla in Claude Code: Claude Code installato e collegato al piano
  Pro, con `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`);
  Python 3, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D05)

Lo spazio di lavoro `~/corso-claude-code/M1-D05/` con questi file:

- `circolare-6-2025.md`: la circolare interna n. 6/2025 di CiaspoLink,
  «attivazione delle linee FWA nelle valli», in cinque punti;
- `domanda-documento.txt`, la domanda A, a cui la circolare risponde:
  «Entro quanti giorni lavorativi va chiusa un'attivazione FWA, secondo la
  circolare?»;
- `richiesta.txt`, la domanda B, a cui la circolare non risponde:
  «Riassumi la circolare n. 7/2025 sulle nuove regole di attivazione delle
  linee FWA.»;
- `regole.txt`: l'istruzione di sistema con le tre regole, qui sotto;
- `istruzione.txt`: l'istruzione di sistema senza regole, «Rispondi in
  italiano.»;
- `prova-claude-ai.md`: il messaggio da incollare in claude.ai, con le
  regole, la circolare e la domanda B;
- `controlla_citazioni.py`: il controllo delle dodici risposte;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato;
- `insisto.txt`: un testo d'ingresso della registrazione del modello
  aperto che la slide mostra (gemma3:4b in locale con Ollama); non fa
  parte dei passi di questa demo.

Le tre regole di `regole.txt`:

> Rispondi in italiano. Usa solo le informazioni del documento, non le tue
> conoscenze generali né il web. Riporta tra «» la frase del documento su
> cui si basa ogni tua affermazione. Se l'informazione non è nel
> documento, scrivi soltanto: NON NEL DOCUMENTO.

CiaspoLink è un operatore inventato, e la circolare n. 6/2025 l'ha scritta
il corso; la n. 7/2025 non esiste.

## Passi in Claude Code (e in claude.ai)

In aula, in claude.ai:

1. Aprite una conversazione nuova, con il modello che avete.
2. Incollate tutto il testo di `demo/prova-claude-ai.md`, così com'è: le
   regole, la circolare n. 6/2025 fra i tag `<documento>` e la richiesta
   di riassumere la n. 7/2025. Copiate il testo del file, non una sua
   vista formattata: apritelo in un editor, o su GitHub nella vista «Raw»,
   e copiate tutto.
3. A voce, due delle regole del messaggio, controllate da voi: è arrivata
   la frase «NON NEL DOCUMENTO»? E le frasi tra «», se ce ne sono: le
   ritrovate, parola per parola, nella circolare (Ctrl+F nel file)?

Per rifarla in Claude Code, sui tre modelli e con le due istruzioni di
sistema, dalla cartella `esercitazioni`:

    tools/prepara_esercizio.sh M1-D05
    cd ~/corso-claude-code/M1-D05
    mkdir -p risposte
    chiedi() {  # modello, domanda, istruzione di sistema, file del JSON
      claude -p "$(printf '<documento>\n%s\n</documento>\n\n%s' \
          "$(cat circolare-6-2025.md)" "$(cat "$2")")" \
        --model "$1" --effort low --tools "" \
        --system-prompt "$(cat "$3")" --strict-mcp-config \
        --output-format json --no-session-persistence > "$4"
    }
    for m in haiku sonnet opus; do
      chiedi "$m" domanda-documento.txt istruzione.txt "risposte/A-senza-$m.json"
      chiedi "$m" domanda-documento.txt regole.txt "risposte/A-regole-$m.json"
      chiedi "$m" richiesta.txt istruzione.txt "risposte/B-senza-$m.json"
      chiedi "$m" richiesta.txt regole.txt "risposte/B-regole-$m.json"
    done
    python3 controlla_citazioni.py

Ogni chiamata manda al modello la circolare fra i tag `<documento>` e,
sotto, una domanda. Fra le due varianti cambia una cosa sola,
l'istruzione di sistema: le regole (`regole.txt`) o la sola riga
«Rispondi in italiano.» (`istruzione.txt`). L'ultima riga lancia il
controllo: stampa i numeri e i verdetti e scrive `esiti.tsv`. Per leggere
una risposta intera:

    python3 leggi_json.py result < risposte/B-regole-haiku.json

## Che cosa osservare

### Che cosa dice Anthropic

Dalla guida «Ridurre le allucinazioni» della documentazione
(https://platform.claude.com/docs/it/test-and-evaluate/strengthen-guardrails/reduce-hallucinations):

- «Anche i modelli linguistici più avanzati, come Claude, possono talvolta
  generare testo fattualmente errato o incoerente con il contesto
  fornito.»
- «Dai esplicitamente a Claude il permesso di ammettere l'incertezza.
  Questa semplice tecnica può ridurre drasticamente le informazioni
  false.» Nell'esempio della guida, il prompt chiede una frase fissa per
  quando l'informazione manca: «If you're unsure about any aspect or if the
  report lacks necessary information, say "I don't have enough information
  to confidently assess this."» (l'esempio è in inglese anche nella pagina
  italiana; in italiano: «Se non sei sicuro di qualche aspetto o se il
  report non ha le informazioni necessarie, di' "Non ho abbastanza
  informazioni per valutarlo con sicurezza."», traduzione nostra). Qui la
  frase fissa è «NON NEL DOCUMENTO».
- «Istruisci esplicitamente Claude a usare solo le informazioni dei
  documenti forniti e non la sua conoscenza generale.»
- «Rendi verificabile la risposta di Claude facendogli citare passaggi e
  fonti per ciascuna delle sue affermazioni.»
- «Ricorda che, sebbene queste tecniche riducano significativamente le
  allucinazioni, non le eliminano del tutto. Convalida sempre le
  informazioni critiche, soprattutto per decisioni ad alto rischio.»

Dal tutorial dell'Academy «Why do AI models hallucinate?»
(https://academy.claude.com/tutorials/why-do-ai-models-hallucinate):
«Siate scettici e ricontrollate i numeri, le date e le citazioni
specifiche» (traduzione nostra; l'originale: «Be skeptical and
double-check specific numbers, dates, and citations.»).

Dalla pagina «Citazioni» della documentazione
(https://platform.claude.com/docs/it/build-with-claude/citations), una
garanzia della API che qui non c'è: con la sua funzionalità delle
citazioni «è garantito che le citazioni contengano puntatori validi ai
documenti forniti». Con `claude -p` le frasi tra «» le scrive il modello,
seguendo le regole: per questo le confronta uno script.

### Che cosa misura il controllo

`controlla_citazioni.py` legge il JSON di ciascuna delle dodici chiamate
e, per ogni risposta, stampa (e scrive in `esiti.tsv`):

- le citazioni: le frasi tra «», “” o "" di almeno tre parole, e quante se
  ne ritrovano nella circolare o nella domanda della chiamata. Nel
  confronto non contano le virgolette, gli apostrofi e i trattini
  tipografici, gli asterischi, i trattini bassi e gli apici inversi del
  markdown, gli spazi in più, la punteggiatura all'inizio e in fondo, la
  maiuscola della prima lettera. Un'omissione («…», «...», «[…]», «(…)»)
  divide la frase in pezzi, e ogni pezzo di almeno tre parole va
  ritrovato. La frase «NON NEL DOCUMENTO» tra «» non è una citazione;
- per la domanda A, se fra i numeri della risposta c'è 10, i giorni
  lavorativi della circolare;
- i numeri estranei: le sequenze di cifre della risposta che non stanno né
  nella circolare né nella domanda, con il punto delle migliaia tolto
  (1.200 vale 1200);
- se c'è la frase «NON NEL DOCUMENTO» (in maiuscolo o no), e se c'è solo
  lei.

Poi, per ogni modello, una riga per affermazione, con «confermata», «non
confermata in questa esecuzione» o «non distinguibile»:

- citazioni verificabili (domanda A, con le regole): almeno una
  citazione, e tutte ritrovate;
- la frase concordata e nessun numero estraneo (domanda B, con le
  regole);
- meno numeri estranei con le regole (domanda B): un confronto fra le due
  risposte alla domanda B, senza e con le regole. Confermata se quella con
  le regole ha meno numeri estranei di quella senza; non distinguibile se
  quella senza non ne ha, perché non c'è niente da ridurre; altrimenti non
  confermata. I due conteggi si stampano come dato.

Sono raccomandazioni di Anthropic, non garanzie: il verdetto si stampa e
non fa fallire la verifica. Nessuna risposta si giudica a occhio, ma il
controllo non vede i numeri scritti in lettere, i nomi inventati, né un
numero inventato che compare anche nella circolare. Una risposta senza
frasi tra «» il codice non la può ricondurre al documento: ne conta solo
i numeri.

Nella registrazione del corso del 20 ottobre 2026 (Claude Code 2.1.305,
tre chiamate per domanda, variante e modello):

| affermazione | Haiku | Sonnet | Opus |
|---|---|---|---|
| citazioni verificabili (A, con le regole) | 3 su 3 | 3 su 3 | 3 su 3 |
| la frase concordata e nessun numero estraneo (B, con le regole) | 3 su 3 | 3 su 3 | 3 su 3 |
| meno numeri estranei con le regole (B, chiamata per chiamata) | non distinguibile 3 su 3 | non distinguibile 3 su 3 | non distinguibile 3 su 3 |
| «10» nella risposta alla domanda A (senza e con le regole) | 6 su 6 | 6 su 6 | 6 su 6 |

La seconda riga controlla soltanto due cose: che la frase concordata ci
sia e che non compaia nessun numero estraneo. `regole.txt` chiede di più,
«scrivi soltanto: NON NEL DOCUMENTO»; se la frase è da sola il controllo
lo stampa («sì, da sola»), come dato, senza verdetto. Nella registrazione
le risposte alla domanda B con le regole fatte della sola frase sono 1 su
9: Haiku 0 su 3, Sonnet 0 su 3, Opus 1 su 3.

La terza riga è «non distinguibile» in tutti e nove i confronti, tre per
modello, perché nemmeno senza le regole le risposte alla domanda B hanno
numeri estranei: 0 senza le regole e 0 con le regole, ogni volta. Non
c'è niente da ridurre.

## Verifica (tools/verifica.sh M1-D05)

`tools/verifica.sh M1-D05` lancia lo stesso controllo sulle dodici
risposte di `risposte/`, con la circolare e le domande dell'elemento (non
le copie dello spazio di lavoro), e non scrive niente. Esce con 0 quando
le dodici risposte ci sono, e l'ultima riga è «Fatto: ogni affermazione è
stata messa alla prova; gli esiti sono qui sopra.»; con 1 quando una
manca o è incompleta (un file vuoto, un errore di claude, una risposta di
un altro modello), e dice quale. I verdetti non cambiano l'uscita.

## Se qualcosa va storto

- In claude.ai la risposta dipende anche dal vostro account, dalla memoria
  e dalla ricerca sul web (con la nuova esperienza di claude.ai non c'è un
  interruttore: Claude cerca sul web quando serve): in aula è normale che
  arrivino risposte diverse.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Una risposta manca o è incompleta: rilanciate solo quella chiamata, che
  il controllo nomina, nella cartella `~/corso-claude-code/M1-D05` e nella
  shell in cui avete definito `chiedi`; per esempio, per
  `risposte/B-regole-opus.json`:

      chiedi opus richiesta.txt regole.txt risposte/B-regole-opus.json

- Una frase tra «» che a voi sembra nella circolare, e che il controllo dà
  per non ritrovata: confrontatela con `circolare-6-2025.md`; il controllo
  la stampa com'è, e una parafrasi non è una citazione.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D05`.

## Impronta d'uso sul piano Pro

In aula: un messaggio in claude.ai, con il modello che avete; se Claude
cerca sul web, anche la ricerca consuma i limiti d'uso. Per rifarla in
Claude Code: dodici chiamate, quattro per modello, con effort low, nessuno
strumento e nessun subagent; ciascuna manda al modello la circolare e una
domanda (nella registrazione del corso, da 894 a 1012 token in entrata
per chiamata). Opus pesa sul limite d'uso più degli
altri due. Niente Fable: sul piano Pro funziona solo con i crediti d'uso
(usage credits), a pagamento.

## Per approfondire

- La guida «Ridurre le allucinazioni» della documentazione:
  https://platform.claude.com/docs/it/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- Il tutorial dell'Academy «Why do AI models hallucinate?»:
  https://academy.claude.com/tutorials/why-do-ai-models-hallucinate
- La pagina «Citazioni» della documentazione, sulle citazioni che la API
  garantisce: https://platform.claude.com/docs/it/build-with-claude/citations
