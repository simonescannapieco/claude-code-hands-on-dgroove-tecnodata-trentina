# M2-D05 — Ragionare, oggi

Demo del Modulo 2, nella parte «Ragionare, sui modelli di oggi». In aula
la esegue il docente;
potete rifarla da soli quando volete.

## Obiettivo

Vedere che cosa fa oggi «ragiona passo passo»: lo stesso problema chiesto
di getto e passo passo, sui tre modelli, con i token del ragionamento che
ogni risposta riporta.

## Tempo

3 minuti in aula; circa 8 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D05)

Lo spazio di lavoro `~/corso-claude-code/M2-D05/` con:

- `sportelli.md`: «In un ufficio ci sono 3 sportelli. Ogni sportello serve
  una persona ogni 4 minuti. Alle 9:00 ci sono 27 persone in fila. A che ora
  esce l'ultima persona?»;
- `squadre.md`: un problema più lungo, 26 linee ferme e tre squadre;
- `di-getto.txt`: «Rispondi solo con l'orario, senza spiegazioni.»;
- `passo-passo.txt`: «Ragiona passo passo, poi scrivi la risposta finale.»;
- `istruzione.txt`: «Rispondi in italiano.»;
- `orario.py`: legge il JSON di una risposta e ne stampa l'orario finale;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D05
       cd ~/corso-claude-code/M2-D05

2. Le chiamate, con l'orario, i token in uscita e quelli del ragionamento
   in `ragionamento.tsv`:

       chiedi() {
         r="$(claude -p "$(cat "$1.md")"$'\n'"$(cat "$3.txt")" \
           --model "$2" --effort low --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --output-format json)"
         printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" \
           "$(python3 orario.py "$4" <<< "$r")" \
           "$(python3 leggi_json.py token_uscita <<< "$r")" \
           "$(python3 leggi_json.py token_thinking <<< "$r")" \
           | tee -a ragionamento.tsv
       }
       printf 'problema\tmodello\tvariante\torario\ttoken_uscita\ttoken_thinking\n' \
         > ragionamento.tsv
       for m in haiku sonnet opus; do
         chiedi sportelli "$m" di-getto 9:00
         chiedi sportelli "$m" passo-passo 9:00
       done
       for m in haiku sonnet opus; do chiedi squadre "$m" di-getto 8:00; done

   L'ultimo argomento è l'orario di partenza del problema: `orario.py` lo
   esclude, perché le risposte passo passo spesso lo ripetono. L'orario
   finale lo cerca nella riga della «risposta finale», poi fra gli orari in
   grassetto, poi prende l'ultimo: una risposta può aggiungere un altro
   orario dopo quello finale.

## Che cosa osservare

- Nel 2022 «Let's think step by step» faceva la differenza su problemi
  come questo. Nella registrazione del corso, sui modelli di oggi, tutte le
  risposte sono giuste anche di getto: 9:36 per gli sportelli, 15:30 per le
  squadre.
- Il ragionamento c'è già: Haiku, chiesto di getto, usa un centinaio di
  token di ragionamento anche se volete solo l'orario (105 sugli sportelli,
  97 sulle squadre); Opus ne usa qualche decina; Sonnet non ne riporta
  (uno 0 nel JSON vuol dire anche «nessuna suddivisione riportata»), ma
  scrive comunque il calcolo prima dell'orario.
- Passo passo cambia ciò che vedete, non la risposta: nella registrazione,
  sugli sportelli, da 315 a 530 token in uscita, contro i 29–110 di getto.
- Su questi modelli il thinking non si spegne; la leva è l'effort. Il
  ragionamento scritto si chiede quando serve leggerlo.

## Verifica (tools/verifica.sh M2-D05)

In `ragionamento.tsv`: ogni risposta dà 9:36 per gli sportelli e 15:30 per
le squadre.

## Se qualcosa va storto

- `orario.py` dice che non c'è un orario: rilanciate solo quella chiamata e
  leggete la risposta; per esempio, per Haiku, di getto, sugli sportelli:

      claude -p "$(cat sportelli.md)"$'\n'"$(cat di-getto.txt)" \
        --model haiku --effort low --tools "" \
        --system-prompt "$(cat istruzione.txt)" --strict-mcp-config

  Se il modello ha scritto l'orario a parole, la verifica lo segna come
  diverso.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D05`.

## Impronta d'uso sul piano Pro

Nove chiamate brevi senza strumenti, con effort low: sei sugli sportelli,
tre sulle squadre. Opus pesa sul limite d'uso più degli altri: qui sono tre
chiamate brevi. Nessun subagent.

## Per approfondire

- Effort e thinking in Claude Code:
  https://code.claude.com/docs/en/model-config
- Il ragionamento nella guida «Prompting best practices»:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
