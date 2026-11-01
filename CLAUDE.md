# CLAUDE.md

Repository delle esercitazioni del corso «Claude e Claude Code in pratica —
Corso base»: le demo e gli esercizi dei nove moduli, i progetti di esempio
condivisi, le dispense di riferimento e gli strumenti che preparano e
verificano ogni elemento.

## Com'è fatto

- `m<N>_<nome>/`: un modulo; `README.md`, `manifest.tsv` (un elemento per
  riga: id, kind, env, section_dir, subdeck_dir, deck_path, minutes,
  title_it, separati da tabulazioni) e le cartelle degli elementi in
  `<section_dir>/<subdeck_dir>/<ID>_<nome>/`.
- Un elemento: `README.md` con dieci sezioni fisse; `esercizio/` o `demo/`
  (il punto di partenza); `soluzione/` (i file che, copiati sullo spazio di
  lavoro, risolvono l'elemento, oppure `soluzione/applica.sh <spazio>`);
  `_docente/` (solo per il docente, con `live.sh <spazio>` per la prova dal
  vivo); `verifica.sh <spazio>` (0 fatto · 1 non ancora · 2 precondizione);
  `progetti.txt` facoltativo (righe `progetti/<nome>` da copiare).
- `progetti/` i progetti sintetici condivisi, `riferimenti/` le dispense,
  `tools/` gli strumenti (libreria comune `lib_handson.sh`), `tests/` le prove.

## Regole

- Gli esercizi si svolgono nello spazio di lavoro creato da
  `tools/prepara_esercizio.sh <ID>`, fuori da questo repository, non qui.
- Mentre si aiuta un partecipante non si aprono e non si modificano
  `soluzione/` e `_docente/`: sono il riferimento del docente; stanno
  anche nel repository che i partecipanti clonano, ma un esercizio si fa
  senza guardarle.
- Solo dati sintetici, con le regole di `progetti/README.md`: mai persone,
  aziende o sistemi reali.
- Ogni demo o esercitazione in cui risponde Claude mette alla prova
  un'affermazione che Anthropic fa nella sua documentazione. Il README la
  cita con il link, in «Che cosa osservare». Le esecuzioni confrontate
  differiscono in una cosa sola, e uno script legge il JSON di ogni
  esecuzione e dice se l'affermazione è confermata. Del comportamento del
  modello si scrive solo ciò che Anthropic afferma e ciò che il controllo
  ha trovato nella registrazione del corso: quante volte su quante, e la
  data. Una garanzia del prodotto deve valere a ogni esecuzione.
- Il controllo decide ciò che l'affermazione dice, non di più.
  - Un'affermazione comparativa («più precisamente … migliore», «invece di
    … prova …») si decide confrontando le due esecuzioni che differiscono
    in quella cosa.
  - Una sola esecuzione non smentisce un «può» o un «di solito», e nessun
    esito dice «smentita».
  - Una soglia che l'affermazione non contiene (ogni criterio, zero
    elementi, un token per lettera) si stampa come dato, mai come esito né
    come codice d'uscita.
  - Il controllo legge le esecuzioni, mai un file di esiti scritto prima.
  - Un oggetto che il controllo costruisce da sé è una dimostrazione.
- I prompt delle demo e degli esercizi seguono il template di
  `riferimenti/pattern-di-prompt.md` quando sono lunghi o portano dati, un
  documento o esempi: ogni ingrediente nel suo tag, su una riga sua, con i
  nomi in inglese. Nel Modulo 2 lo seguono il prompt B e la versione di
  riferimento della prima esercitazione; i prompt che il modulo mette alla
  prova restano come sono.
  - `<role>` in una frase, «Sei …»: chi è Claude e per chi lavora, o a
    chi scrive; poi `<context>` (lo scopo, e chi legge se il ruolo non
    lo dice; con i dati, in quali tag stanno),
    `<instructions>` (passi numerati, il controllo che Claude esegue per
    ultimo), `<format>` (la forma della risposta, lunghezza e tono
    compresi; un contratto che un controllo legge, alla lettera),
    `<constraints>` detti in positivo, `<examples>` con da tre a cinque
    `<example>`.
  - I dati vanno ciascuno in un tag che dice che cosa contengono
    (`<message>`, `<procedures>`, `<data>`…), dopo gli ingredienti; un
    documento lungo va in cima, e allora `<instructions>` va per ultimo.
  - Un seguito nella stessa sessione tiene i tag e non ripete `<role>`.
    Una richiesta breve resta semplice; se le sue frasi portano
    ingredienti diversi, ogni frase va nel tag del suo ingrediente.
  - I nomi dei tag sono la convenzione del corso, non una raccomandazione
    di Anthropic.
  - Le due esecuzioni di una coppia differiscono solo nella parte che
    cambia, e le slide mostrano il prompt così com'è.
- Script bash: `#!/bin/bash`, `set -euo pipefail`, uscita 0/1/2 dichiarata
  in testata, shellcheck pulito; le librerie `lib_*.sh` non sono eseguibili.

## Comandi

    tests/esegui_test.sh                  # tutte le suite e shellcheck
    tools/check_handson.sh                # struttura, manifest, README
    tools/run_all.sh [--live] [ID ...]    # ogni elemento, partenza e soluzione
    tools/esporta_studenti.sh <cartella>  # una copia senza soluzioni
