# Soluzione di M6-E01

Qui c'è la registrazione del corso del 7 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: `prima.md` e `dopo.md`, le due
uscite di `/context all`, `risposta.txt`, il `/export` della sessione, e
`.claude/caricamenti.jsonl`, il registro dell'hook, da cui `tools/verifica.sh
M6-E01` stampa i dati e i verdetti. Sono i passi del README eseguiti così come
sono, la domanda in una sessione interattiva su un terminale.

Nell'intestazione di `risposta.txt`, il `/export` della sessione, il nome del
piano dell'account del docente, che non è un Pro, è scritto «(piano
dell'account, omesso)» e la cartella della sessione «(cartella della sessione,
omessa)». Il controllo è stato eseguito sui file interi e su questi: stampa le
stesse righe.

In `dopo.md` il percorso di CLAUDE.md è quello dello spazio di lavoro della
registrazione: la verifica riconosce il file dal nome della cartella,
`M6-E01/CLAUDE.md`, e per questo vale anche dove la soluzione si applica.
`applica.sh` scrive `CLAUDE.md` con lo stesso `printf` del README, poi copia
questi file nello spazio di lavoro: con questi `tools/verifica.sh M6-E01`
passa. `CLAUDE.md` non sta qui: un `CLAUDE.md` in una sottocartella di questo
repository si caricherebbe nelle sessioni di Claude Code che vi leggono un
file.
