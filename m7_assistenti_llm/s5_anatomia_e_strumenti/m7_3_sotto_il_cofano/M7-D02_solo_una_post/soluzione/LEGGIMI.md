# Soluzione di M7-D02

Qui c'è la registrazione del corso del 9 novembre 2026, sul modello
`claude-haiku-5-5` con la chiave del docente: il corpo della risposta,
`risposte/risposta.json`, e lo stato HTTP, `risposte/stato.txt`, della
richiesta `demo/corpo.json` alla Messages API (`anthropic-version: 2026-10-21`,
`max_tokens` 100), fatta con `curl` e con la chiave sullo STDIN: la chiave non
compare in nessun file. Stato 200, `stop_reason` `max_tokens`, `usage` 37 token
in ingresso e 100 in uscita: il tetto di 100 token è quello fissato nel corpo.
È la prova del docente, `_docente/live.sh`, da cui `tools/verifica.sh M7-D02`
stampa i dati.

Copiata sopra uno spazio di lavoro nuovo, `risposte/` fa passare
`tools/verifica.sh M7-D02`.
