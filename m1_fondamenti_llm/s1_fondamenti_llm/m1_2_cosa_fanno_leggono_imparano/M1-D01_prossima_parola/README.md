# M1-D01 — La prossima parola

Demo del Modulo 1, nella parte «Cosa fanno, cosa leggono, come imparano».
In aula la esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Vedere da vicino il mestiere di un modello linguistico: continuare il
testo con la parola che ritiene più adatta. La stessa frase va più volte a
ciascuno dei tre modelli Claude del piano Pro, e si confrontano le parole:
la documentazione di Anthropic dice che input identici possono produrre
output diversi, e la demo lo mette alla prova.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica: lo usa la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-D01)

Lo spazio di lavoro `~/corso-claude-code/M1-D01/` con due file:

- `frase.txt`: la frase da completare, «La riunione è stata rinviata a
  causa dello»;
- `istruzione.txt`: l'istruzione di sistema, che chiede una parola sola,
  senza punteggiatura.

## Passi in Claude Code

Si lavora dal terminale con `claude -p`, la modalità non interattiva di
Claude Code: stampa la risposta ed esce.

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M1-D01
       cd ~/corso-claude-code/M1-D01

2. Prima di eseguire, una previsione: tre chiamate allo stesso modello
   daranno tre parole diverse? E tre modelli diversi? Alla fine
   confrontate le parole con le vostre previsioni.

3. Date la frase tre volte a ciascun modello e raccogliete le parole in
   `risultati.tsv`:

       printf 'modello\tparola\n' > risultati.tsv
       for m in haiku sonnet opus; do
         for i in 1 2 3; do
           parola="$(claude -p "$(cat frase.txt)" --model "$m" \
             --effort low --tools "" \
             --system-prompt "$(cat istruzione.txt)" \
             --strict-mcp-config --no-session-persistence)" || continue
           printf '%s\t%s\n' "$m" "$parola" | tee -a risultati.tsv
         done
       done

   Una chiamata che fallisce non finisce nel file (`|| continue`): se a
   un modello mancano risposte, la verifica ve lo dice.

   Che cosa fanno le opzioni:
   - `--model` sceglie il modello per questa chiamata;
   - `--effort low` chiede poco ragionamento: basta per una parola;
   - `--tools ""` toglie a Claude tutti gli strumenti integrati: qui deve solo
     rispondere;
   - `--system-prompt` dà a Claude l'istruzione di sistema di questa
     chiamata;
   - `--strict-mcp-config` usa solo i server MCP passati con
     `--mcp-config`, cioè nessuno: restano fuori anche i connettori del
     vostro account claude.ai;
   - `--no-session-persistence` non salva la sessione.

## Che cosa osservare

### Che cosa dice Anthropic

- Il glossario della documentazione, alla voce «Temperature»: «Anche con
  la temperatura impostata a 0, i risultati non saranno completamente
  deterministici e input identici possono produrre output diversi tra le
  chiamate API.»
  (https://platform.claude.com/docs/it/about-claude/glossary). Nella demo,
  per ogni modello, ogni chiamata manda la stessa frase, con la stessa
  istruzione di sistema e le stesse opzioni.
- La guida al prompting, alla voce «Sii chiaro e diretto»: «Claude
  risponde bene a istruzioni chiare ed esplicite. Essere specifici
  sull'output desiderato può aiutare a migliorare i risultati.»
  (https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices).
  L'istruzione di sistema della demo è esplicita: una parola sola, senza
  punteggiatura.

### Che cosa misura il controllo

`verifica.sh` legge `risultati.tsv` e, per ogni modello, stampa quante
risposte ci sono, ogni parola con il numero di volte, quante parole sono
diverse e quante risposte sono una parola sola, senza punteggiatura; le
risposte si confrontano senza gli spazi in testa e in coda. Una riga senza
tabulazione continua la risposta della riga di sopra: così il `printf`
del passo 3 scrive una risposta di più righe. Prima di ogni controllo le
righe si uniscono con uno spazio, e la verifica stampa quante ne ha
unite. Poi, per ogni modello, un verdetto per ciascuna affermazione:

- input identici, output diversi: «confermata» se il modello ha dato
  almeno due parole diverse, altrimenti «non dimostrata in questa
  esecuzione». La documentazione dice «possono»: risposte tutte uguali non
  la smentiscono, una parola diversa la dimostra; con una risposta sola
  non si può vedere;
- l'istruzione esplicita: «confermata» se tutte le risposte del modello
  sono una parola sola, senza punteggiatura, altrimenti «non confermata in
  questa esecuzione», con il conto. È una raccomandazione: la verifica la
  stampa e non fallisce per questa.

La verifica esce con 0 quando ognuno dei tre modelli ha almeno una
risposta.

Nella registrazione del corso dell'11 ottobre 2026 (Claude Code 2.1.296),
venti chiamate per modello: Haiku ha risposto «maltempo» 20 volte su 20,
Sonnet e Opus «sciopero» 20 volte su 20. Input identici, output diversi:
non dimostrata su nessuno dei tre modelli. L'istruzione esplicita: una
parola sola, senza punteggiatura, 20 risposte su 20 per ciascun modello,
confermata.

## Verifica (tools/verifica.sh M1-D01)

Le regole dei verdetti sono quelle di «Che cosa misura il controllo».
Quando `risultati.tsv` contiene almeno una risposta per ciascuno dei tre
modelli la verifica esce con 0, e la sua ultima riga è: «Fatto: ogni
affermazione è stata messa alla prova; gli esiti sono qui sopra.»

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Una parola vuota in `risultati.tsv`: rilanciate solo quella chiamata, poi
  sistemate la riga a mano, con la tabulazione fra il modello e la parola:
  una riga senza tabulazione si unisce alla risposta di sopra.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D01`.

## Impronta d'uso sul piano Pro

Nove chiamate brevi, tre per modello, con effort low, nessuno strumento e
nessun subagent: ciascuna manda al modello meno di 700 token. Opus pesa
sul limite d'uso più di Sonnet e di Haiku. Per risparmiare, nel ciclo del
passo 3 scrivete `for m in haiku sonnet; do`, poi fate una sola chiamata
con `opus` (la verifica chiede almeno una risposta per modello; con una
sola, per Opus il primo verdetto resta «non dimostrata»):

    m=opus
    parola="$(claude -p "$(cat frase.txt)" --model "$m" \
      --effort low --tools "" \
      --system-prompt "$(cat istruzione.txt)" \
      --strict-mcp-config --no-session-persistence)" &&
      printf '%s\t%s\n' "$m" "$parola" | tee -a risultati.tsv

Niente Fable: sul piano Pro funziona solo con i crediti d'uso (usage
credits), a pagamento.

## Per approfondire

- Il video «What happens when you talk to AI?» del canale YouTube Claude:
  https://www.youtube.com/watch?v=j1Vk6Y-23CY
- Il corso dell'Academy «AI capabilities and limitations»:
  https://academy.claude.com/courses/ai-capabilities-and-limitations
- Tutte le opzioni di `claude -p`: `claude --help`.
