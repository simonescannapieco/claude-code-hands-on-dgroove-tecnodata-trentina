# Soluzione di M8-E02

Qui c'è la versione di riferimento del prompt, `prompt/v1.md`: scritta per il
corso nel template del corso, con ogni ingrediente nel suo tag e la guida al
tono e le procedure ridotte alle regole che le risposte richiedono. È il punto
d'arrivo di un esempio, non l'unico possibile: i partecipanti scrivono la loro
versione con Claude Code, partendo da `prompt/v0.md`.

`_docente/live.sh` misura `v0` e poi questa `v1` sui tre casi del laboratorio
(dodici chiamate di `claude -p`, Sonnet con effort low per le risposte, Haiku
per il giudice), e poi fa girare la verifica. La registrazione del corso è
importata dalla prova del docente del 10 novembre 2026, con Claude Code
2.1.322: `risposte/` e `giudizi/` contengono, per ogni versione e per ogni
caso, il JSON di `claude -p` (il testo della risposta, `usage`,
`total_cost_usd`, il giudizio strutturato), con i percorsi personali
sostituiti, e `risposte/<versione>/opzioni.tsv` il modello, l'effort e le
impronte della misura. Copiata sopra uno spazio di lavoro nuovo con
`prompt/v1.md`, la registrazione fa passare `tools/verifica.sh M8-E02`. I dati
della prova, il confronto e gli esiti sono nel README, in «Nella prova del
corso».

<!-- registrazione del corso -->
## La registrazione del corso

Qui c'è la registrazione del corso del 10 novembre 2026, con Claude Code
2.1.322, `claude-sonnet-5-5` per le risposte e Haiku per il giudice,
sull'account del docente: le
risposte, i giudizi e i controlli delle due misure, in `risposte/`, `giudizi/`
e `controlli/`, una cartella per versione, da cui `tools/verifica.sh M8-E02`
stampa i dati e i verdetti. È la prova del docente, `_docente/live.sh`.

Copiati sopra uno spazio di lavoro nuovo, insieme a `prompt/v1.md` di questa
cartella, fanno passare `tools/verifica.sh M8-E02`.
<!-- /registrazione del corso -->
