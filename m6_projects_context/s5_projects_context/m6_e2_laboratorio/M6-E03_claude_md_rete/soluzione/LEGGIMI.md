# Soluzione di M6-E03

Un esempio di riferimento della seconda versione, scritto per il corso dagli
appunti del team e da ciò che il controllo ha letto nella prova del docente, nel
formato che Anthropic indica per questi file: titoli Markdown ed elenchi
puntati, righe concrete e verificabili, sotto le 200 righe.

- `CLAUDE.md`, 16 righe, nelle sezioni del prompt 1 del README: che cosa vuol
  dire «a posto», con i due controlli e la cartella da cui si lanciano, perché
  senza il file Claude li ha trovati con un turno in più e più di tre volte i
  token; la
  forma dei commit e la riga `Rif:`, che il team ha deciso in una riunione e il
  repository non contiene; i file generati, con il rimando al generatore.
- `.claude/rules/generatore.md`: che cosa fare dopo una modifica al
  generatore, con `paths:`. Si carica soltanto quando Claude legge o modifica un
  file di `progetti/rete/generatore/`.
- `.claude/settings.json`: le regole prudenti e l'hook del punto di partenza,
  con quattro regole `deny` in più, per `configurazioni/`, `log/`,
  `inventario.csv` e `allarmi.csv`. Il generatore li riscrive con un comando, e
  le regole non lo fermano.

Che cosa degli appunti non c'è, e perché: il fuso orario dei log lo dice il
README del progetto; l'apparato nuovo è una procedura in più passi, da una
skill; la preferenza di Marco Prova è personale, e va in un `CLAUDE.local.md`,
fuori da git.

Non è l'unica versione buona: quelle che Claude ha scritto con i prompt del
README sono diverse, e il controllo dice che cosa cambia da una versione
all'altra, richiesta per richiesta.

<!-- registrazione del corso -->
## La registrazione del corso

Qui c'è la registrazione del corso del 7 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: le prove di
`tools/prova_contesto.sh` nelle tre versioni, `base`, `v1` e `v2`, una
esecuzione per richiesta, in `prove-contesto/`: gli stream, `prompt.txt`,
`strumenti.txt`, `file-cambiati.txt`, `commit.txt`, `file-committati.txt`,
`diff.txt`, `stderr.txt`, il registro dell'hook `caricamenti.jsonl` e la
`fotografia/` di ogni versione, da cui `tools/verifica.sh M6-E03` stampa i
dati e i verdetti. È la prova del docente, `_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model` e
`claude_code_version`; dei messaggi dell'assistente il testo, le chiamate agli
strumenti e `usage`; dei messaggi utente i risultati di `Skill` e il corpo di
una skill, tagliati a 300 caratteri; e, interi, quelli dei comandi Bash con
«genera.py»; i `result` interi. Il percorso del repository è scritto
`HANDS-ON` e quello della cartella personale del docente `~`. Il controllo è
stato eseguito sugli stream interi e su questi: stampa le stesse righe.

Copiata sopra uno spazio di lavoro nuovo con il resto di questa cartella,
`prove-contesto/` fa passare `tools/verifica.sh M6-E03`.
<!-- /registrazione del corso -->
