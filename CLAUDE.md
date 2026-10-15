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
- Script bash: `#!/bin/bash`, `set -euo pipefail`, uscita 0/1/2 dichiarata
  in testata, shellcheck pulito; le librerie `lib_*.sh` non sono eseguibili.

## Comandi

    tests/esegui_test.sh                  # tutte le suite e shellcheck
    tools/check_handson.sh                # struttura, manifest, README
    tools/run_all.sh [--live] [ID ...]    # ogni elemento, partenza e soluzione
    tools/esporta_studenti.sh <cartella>  # una copia senza soluzioni
