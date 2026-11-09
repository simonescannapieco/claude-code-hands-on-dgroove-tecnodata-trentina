# Soluzione di M7-D06

Qui c'è la registrazione del corso del 9 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: i file delle esecuzioni, tre per
cella, in `risposte/` (`<braccio>-<n>/<domanda>/`), da cui `tools/verifica.sh
M7-D06` stampa i dati e i verdetti. È la prova del docente,
`_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model` e
`claude_code_version`; dei messaggi dell'assistente il testo, le chiamate agli
strumenti e `usage`; dei messaggi utente i risultati di `Skill`, quelli con
`is_error` e il corpo di una skill, tagliati a 300 caratteri; e, interi,
quelli di ogni strumento; i `result` interi. Il percorso del repository è
scritto `HANDS-ON` e quello della cartella personale del docente `~`. Il
controllo è stato eseguito sugli stream interi e su questi: stampa le stesse
righe.

Copiata sopra uno spazio di lavoro nuovo, `risposte/` fa passare
`tools/verifica.sh M7-D06`.
