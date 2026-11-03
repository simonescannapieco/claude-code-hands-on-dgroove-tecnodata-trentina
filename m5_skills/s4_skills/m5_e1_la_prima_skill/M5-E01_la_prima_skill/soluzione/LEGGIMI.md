# Soluzione di M5-E01

`.claude/skills/riassunto-modifiche/SKILL.md` è la skill di riferimento, con il
modello della risposta e un esempio; passa `tools/controlla_skill.py`. La skill
che la prova ha scritto sta nella registrazione del corso, non qui.

Qui c'è la registrazione del corso del 3 novembre 2026, con Claude Code
2.1.317 e Sonnet, sull'account del docente: gli stream della prova del
docente, in `prova/` (`richiesta.jsonl`, `stream.jsonl`, `stream-<k>.jsonl`,
`nome.jsonl`, `skill-doctor.jsonl`), da cui `tools/verifica.sh M5-E01` stampa
i dati e i verdetti. È la prova del docente, `_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model` e
`claude_code_version`; dei messaggi dell'assistente il testo, le chiamate agli
strumenti e `usage`; dei messaggi utente i risultati di `Skill` e quelli con
`is_error`, tagliati a 300 caratteri, e il corpo della skill intero; i
`result` interi. Il percorso del repository è scritto `HANDS-ON` e quello
della cartella personale del docente `~`. Il controllo è stato eseguito sugli
stream interi e su questi: stampa le stesse righe.

`applica.sh` fa la modifica non committata e copia la skill di riferimento e
`prova/`: con questi `tools/verifica.sh M5-E01` passa.
