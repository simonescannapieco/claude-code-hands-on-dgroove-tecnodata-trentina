# Soluzione di M4-D06

Qui c'è la registrazione del corso del 31 ottobre 2026, con Claude Code
2.1.316 e Sonnet, sull'account del docente: gli stream delle tre coppie,
in `risposte/` (`delega-<n>.jsonl` e `senza-<n>.jsonl`), da cui
`tools/verifica.sh M4-D06` stampa i dati e i verdetti. È la prova del
docente con i due prompt di allora, scritti a etichette prima che ogni
ingrediente avesse il suo tag: le stesse parole, senza la frase che ora
sta nel tag `<constraints>`. Le sessioni avevano
`--tools Agent,Read,Grep,Glob`, senza Bash (nel README, «Perché le
sessioni non hanno Bash»); le prove di prima non valgono. I prompt di
adesso, un tag per ingrediente, aspettano una prova nuova del docente.
Gli stream non sono scritti a mano: sono quelli della prova, con un solo
cambiamento, il percorso della cartella personale del docente scritto
`~`. Copiata sopra uno spazio di lavoro nuovo, `risposte/` fa passare
`tools/verifica.sh M4-D06`.
