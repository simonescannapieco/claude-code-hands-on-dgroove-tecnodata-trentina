# Soluzione di M8-D01

Qui c'è la registrazione del corso del 10 novembre 2026, sul modello
`claude-haiku-5-5` con la chiave del docente: per ognuna delle due frasi della
demo, in `risposte/`, il corpo della richiesta (`<nome>.richiesta.json`), il
corpo della risposta di `POST /v1/messages/count_tokens` (`<nome>.json`) e lo
stato HTTP (`<nome>.stato`), fatte con `curl`
(`anthropic-version: 2026-10-21`) e con la chiave sullo STDIN: la chiave non
compare in nessun file. Stato 200 per le due richieste; `input_tokens` 34 per la
frase italiana, su 73 caratteri, e 26 per quella inglese, su 71. È la prova del
docente, `_docente/live.sh`, da cui `tools/verifica.sh M8-D01` stampa i dati.

Copiata sopra uno spazio di lavoro nuovo, `risposte/` fa passare
`tools/verifica.sh M8-D01`.
