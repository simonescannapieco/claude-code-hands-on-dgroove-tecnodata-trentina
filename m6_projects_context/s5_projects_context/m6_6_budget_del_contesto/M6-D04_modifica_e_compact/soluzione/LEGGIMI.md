# Soluzione di M6-D04

Qui c'è la registrazione del corso del 7 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: gli stream, i registri dell'hook
InstructionsLoaded e i passi delle nove sessioni, in `risposte/`
(`compact-<n>.jsonl`, `compact-<n>.caricamenti.jsonl`,
`compact-<n>.sessione.json`, `clear-<n>…`, `regola-<n>…`), da cui
`tools/verifica.sh M6-D04` stampa i dati e i verdetti. È la prova del docente,
`_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model`,
`claude_code_version` e `cwd`; dei messaggi dell'assistente il testo, le
chiamate agli strumenti e `usage`; dei messaggi utente i risultati di ogni
strumento, quelli con `is_error` e il corpo di una skill, tagliati a 300
caratteri; e intero il messaggio che comincia con «This session is being
continued»; i `result` interi; interi gli eventi `compact_boundary` e
`conversation_reset`. Il percorso del repository è scritto `HANDS-ON` e quello
della cartella personale del docente `~`. Il controllo è stato eseguito sugli
stream interi e su questi: stampa le stesse righe.

Copiata sopra uno spazio di lavoro nuovo, `risposte/` fa passare
`tools/verifica.sh M6-D04`.
