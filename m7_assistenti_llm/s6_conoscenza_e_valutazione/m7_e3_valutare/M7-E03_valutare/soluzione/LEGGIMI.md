# Soluzione di M7-E03

Qui c'è la registrazione del corso del 9 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: i verdetti del giudice in
`giudizi/`, la coppia di casi nuovi che il prompt del README ha fatto scrivere
in `casi-nuovi/`, le esecuzioni dei casi in `risultati/` e `regressione.txt`,
l'uscita di `confronta.py`, da cui `tools/verifica.sh M7-E03` stampa i dati e
i verdetti. È la prova del docente, `_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model` e
`claude_code_version`; dei messaggi dell'assistente il testo, le chiamate agli
strumenti e `usage`; dei messaggi utente i risultati di `Skill`, quelli con
`is_error` e il corpo di una skill, tagliati a 300 caratteri; e, interi,
quelli di ogni strumento; i `result` interi. Il percorso del repository è
scritto `HANDS-ON` e quello della cartella personale del docente `~`. Il
controllo è stato eseguito sugli stream interi e su questi: stampa le stesse
righe.

Copiati sopra uno spazio di lavoro nuovo, questi file fanno passare
`tools/verifica.sh M7-E03`.
