# M2-D04 — Zero-shot contro few-shot

Demo del Modulo 2, nella parte «Esempi: quando aiutano, quando
danneggiano». In aula la fate anche voi, in
claude.ai; poi il docente mostra la stessa prova in Claude Code.

## Obiettivo

Vedere che cosa insegnano gli esempi, e che cosa no: la stessa
segnalazione da classificare nel formato «categoria | priorità | team»,
senza esempi, con due esempi, e con gli esempi più l'elenco delle etichette
ammesse.

## Tempo

3 minuti in aula; circa 5 per rifarla da soli.

## Prerequisiti

Un account claude.ai con il piano Pro; per la parte in Claude Code, Claude
Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto verde
(`PRIMA_DEL_CORSO.md`).

## Punto di partenza (tools/prepara_esercizio.sh M2-D04)

Lo spazio di lavoro `~/corso-claude-code/M2-D04/` con:

- `zero-shot.md`: l'istruzione e la segnalazione (i backup notturni verso
  il cloud che non finiscono più in tempo);
- `few-shot.md`: la stessa istruzione e due segnalazioni già classificate,
  prese dalla settimana di ticket dell'assistenza di CiaspoLink;
- `con-etichette.md`: gli stessi esempi e l'elenco delle categorie, delle
  priorità e dei team ammessi;
- `istruzione.txt`: «Rispondi in italiano.»;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

Le segnalazioni sono inventate, come tutti i dati del corso.

## Passi in Claude Code

1. **In claude.ai, con il modello predefinito:** aprite una chat nuova,
   incollate il testo di `zero-shot.md` (nella cartella `demo/` di questo
   elemento, o nello spazio di lavoro del passo 2) e inviate. Poi un'altra
   chat nuova, con `few-shot.md`. Dite a voce la categoria che avete
   ottenuto.

2. **In Claude Code:** preparate lo spazio di lavoro ed entrateci, dalla
   cartella `esercitazioni`:

       tools/prepara_esercizio.sh M2-D04
       cd ~/corso-claude-code/M2-D04

3. I tre prompt su Haiku e su Sonnet, con le risposte in `etichette.tsv`:

       printf 'modello\tvariante\trisposta\n' > etichette.tsv
       for m in haiku sonnet; do
         for v in zero-shot few-shot con-etichette; do
           r="$(claude -p "$(cat "$v.md")" --model "$m" --effort low \
             --tools "" --system-prompt "$(cat istruzione.txt)" \
             --strict-mcp-config --output-format json)"
           printf '%s\t%s\t%s\n' "$m" "$v" \
             "$(python3 leggi_json.py result <<< "$r")" | tee -a etichette.tsv
         done
       done

## Che cosa osservare

- Senza esempi il modello inventa etichette e scala, a modo suo. Nella
  registrazione del corso: «Backup e Storage | Alta | Infrastruttura
  (Sistemi/SRE)» con Haiku, «Prestazioni backup/rete | Media |
  Infrastruttura / Network» con Sonnet.
- Con due esempi prende la forma degli esempi: minuscole, il trattino
  basso, la scala delle priorità. La categoria però la inventa
  («backup_lento», «prestazioni_lente»): dagli esempi non può sapere quali
  categorie esistono.
- Con l'elenco delle etichette, entrambi scrivono «lentezza | media | noc».
  La categoria è quella della settimana di ticket; il team no (nei dati,
  primo_livello): l'hanno preso da un esempio. Le etichette si scrivono,
  le scelte che dipendono dal caso vanno spiegate.

## Verifica (tools/verifica.sh M2-D04)

In `etichette.tsv`: con gli esempi la risposta ha la forma «categoria |
priorità | team»; con l'elenco usa solo etichette ammesse. La parte in
claude.ai non si verifica: la raccontate a voce.

## Se qualcosa va storto

- In claude.ai la risposta spiega a lungo invece di classificare: va bene,
  guardate solo la riga della classificazione.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D04`.

## Impronta d'uso sul piano Pro

In claude.ai, due messaggi brevi. In Claude Code, sei chiamate brevi su
Haiku e Sonnet, con effort low, nessuno strumento e nessun subagent.

## Per approfondire

- Gli esempi nella guida «Prompting best practices»:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La lezione «Effective prompting techniques» del corso AI Fluency della
  Claude Academy:
  https://academy.claude.com/courses/ai-fluency-framework-foundations/effective-prompting-techniques
