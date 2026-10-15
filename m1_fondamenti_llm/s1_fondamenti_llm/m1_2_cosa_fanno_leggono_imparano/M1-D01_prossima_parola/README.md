# M1-D01 — La prossima parola

Demo del Modulo 1, nella parte «Cosa fanno, cosa leggono, come imparano».
In aula la esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Vedere da vicino il mestiere di un modello linguistico: continuare il
testo con la parola che ritiene più adatta. La stessa frase va più volte a
ciascuno dei tre modelli Claude del piano Pro, e si confrontano le parole.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).

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
   daranno tre parole diverse? E tre modelli diversi?

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

- Ogni chiamata restituisce una parola sola.
- Lo stesso modello tende a dare la stessa parola. Nelle registrazioni del
  corso, venti chiamate per modello: Haiku ha risposto «maltempo» 20 volte
  su 20, Sonnet e Opus «sciopero» 20 volte su 20.
- Tende, ma non è garantito: a parità di richiesta un modello può
  rispondere in modo diverso. Se una parola cambia, è proprio questo.
- Modelli diversi non sono d'accordo: la parola più probabile dipende dal
  modello.
- Confrontate con le parole dette in aula.

## Verifica (tools/verifica.sh M1-D01)

`risultati.tsv` contiene almeno una risposta per ciascuno dei tre modelli.
La verifica riassume le parole di ogni modello: che coincidano o no non è
un requisito, è ciò che la demo vi fa osservare.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Una parola vuota in `risultati.tsv`: rilanciate solo quella chiamata, poi
  sistemate la riga a mano.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D01`.

## Impronta d'uso sul piano Pro

Nove chiamate brevi, tre per modello, con effort low, nessuno strumento e
nessun subagent: ciascuna manda al modello meno di 700 token. Opus pesa
sul limite d'uso più di Sonnet e di Haiku. Per risparmiare, nel ciclo del
passo 3 scrivete `for m in haiku sonnet; do`, poi fate una sola chiamata
con `opus` (la verifica chiede almeno una risposta per modello):

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
