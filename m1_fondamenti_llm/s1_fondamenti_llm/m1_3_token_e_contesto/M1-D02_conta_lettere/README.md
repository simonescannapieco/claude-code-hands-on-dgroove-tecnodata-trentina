# M1-D02 — Quante n in «interconnessione»?

Demo del Modulo 1, nella parte «Token e finestra di contesto». In aula si fa
in claude.ai: ognuno pone la domanda al proprio Claude e scrive la
risposta nella chat del corso. Il docente la ripete in Claude Code sui tre
modelli.

## Obiettivo

Vedere che un modello non legge le lettere una per una: legge pezzi di
parola, i token. Contare le lettere di una parola gli riesce quasi sempre,
non sempre; se gli si chiede di scriverla lettera per lettera prima di
contare, il conteggio torna.

## Tempo

4 minuti in aula; circa 5 per rifarla in Claude Code.

## Prerequisiti

- In aula: claude.ai aperto nel browser, con il vostro account Pro.
- Per rifarla in Claude Code: Claude Code installato e collegato al piano
  Pro, con `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).

## Punto di partenza (tools/prepara_esercizio.sh M1-D02)

Lo spazio di lavoro `~/corso-claude-code/M1-D02/` con tre file:

- `conta.txt`: «Quante n ci sono nella parola interconnessione? Rispondi
  solo con il numero.»;
- `compitata.txt`: la stessa domanda, chiedendo prima di scrivere la parola
  una lettera per riga;
- `istruzione.txt`: l'istruzione di sistema, «Rispondi in italiano.».

## Passi in Claude Code (e in claude.ai)

In aula, in claude.ai:

1. Aprite una conversazione nuova. Il modello lo scegliete dal menu
   accanto al pulsante di invio: va bene quello che avete.
2. Incollate la domanda:

       Quante n ci sono nella parola interconnessione? Rispondi solo con il numero.

3. Scrivete nella chat del corso la risposta e il modello che avete usato.
4. Nella stessa conversazione di claude.ai, chiedete:

       Scrivi la parola interconnessione una lettera per riga, poi conta le n e dimmi quante sono.

Per rifarla in Claude Code, sui tre modelli, dalla cartella
`esercitazioni`:

    tools/prepara_esercizio.sh M1-D02
    cd ~/corso-claude-code/M1-D02
    printf 'modello\tdomanda\trisposta\n' > risposte.tsv
    for m in haiku sonnet opus; do
      for d in conta compitata; do
        risposta="$(claude -p "$(cat "$d.txt")" --model "$m" \
          --effort low --tools "" \
          --system-prompt "$(cat istruzione.txt)" \
          --strict-mcp-config --no-session-persistence)" || continue
        risposta="$(printf '%s' "$risposta" | tr '\n\t' '  ')"
        printf '%s\t%s\t%s\n' "$m" "$d" "$risposta" | tee -a risposte.tsv
      done
    done

Una chiamata che fallisce non finisce nel file (`|| continue`): se a un
modello mancano risposte, la verifica ve lo dice.

Le opzioni sono quelle di M1-D01: un modello per chiamata, effort low,
nessuno strumento, l'istruzione di sistema, nessun server MCP né
connettore, nessuna sessione salvata.

## Che cosa osservare

- Le n di «interconnessione» sono 4 (i-n-t-e-r-c-o-n-n-e-s-s-i-o-n-e).
- Nelle registrazioni del corso, Haiku con effort low ha risposto 4, 4 e 5:
  una volta su tre, un 5 detto con la stessa sicurezza del 4. Sonnet e Opus
  hanno risposto sempre 4, e con la parola scritta lettera per lettera
  tutti e tre hanno risposto 4.
- Il caso famoso, le r di «strawberry», oggi non fa più cadere i modelli:
  nelle stesse registrazioni, 3 su ogni modello, ogni volta.
- In aula: quante risposte diverse sono arrivate in chat? Su quali
  modelli?
- Per chi scrive codice: un conteggio di lettere si fa senza modello, e
  senza sbagliare, con `grep -o n <<< interconnessione | wc -l`.

## Verifica (tools/verifica.sh M1-D02)

`risposte.tsv` contiene, per ciascuno dei tre modelli, almeno una risposta
alla domanda `conta` e una alla domanda `compitata`. La verifica mostra
l'inizio di ogni risposta, e il conteggio lo leggete voi: un conteggio
sbagliato non la fa fallire, perché è proprio ciò che la demo vi fa
osservare.

## Se qualcosa va storto

- In claude.ai la risposta dipende anche dal vostro account, per esempio
  dalla memoria: è normale che in aula arrivino risposte diverse.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-D02`.

## Impronta d'uso sul piano Pro

In aula: due messaggi in claude.ai, con il modello che avete. Per rifarla in
Claude Code: sei chiamate brevi, due per modello, con effort low, nessuno
strumento e nessun subagent. Niente Fable: sul piano Pro funziona solo con
i crediti d'uso (usage credits), a pagamento.

## Per approfondire

- Il tutorial dell'Academy «Tokens: why some inputs cost more than
  others»: https://academy.claude.com/tutorials/tokens-and-embeddings
- Il corso dell'Academy «AI capabilities and limitations»:
  https://academy.claude.com/courses/ai-capabilities-and-limitations
