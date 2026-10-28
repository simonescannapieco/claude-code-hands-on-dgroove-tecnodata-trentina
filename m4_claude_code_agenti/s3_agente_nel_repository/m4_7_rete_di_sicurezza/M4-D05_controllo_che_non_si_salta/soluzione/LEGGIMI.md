# M4-D05 — la registrazione del corso

Qui ci sono le sei esecuzioni della registrazione del corso del 28
ottobre 2026, con Claude Code 2.1.312 e Sonnet, sull'account del
docente: la prova del docente, `_docente/live.sh --esecuzioni 3`, l'unica
fatta, tre esecuzioni per braccio. La cartella `esecuzioni/` ha
`con-hook-1/` … `con-hook-3/` e `senza-hook-1/` … `senza-hook-3/`,
ciascuna con il suo `stream.jsonl` e la sua copia `urgenze/` come Claude
l'ha lasciata (con `.claude/settings.json`; senza la cartella `.git/`
della copia e senza `__pycache__/`). Gli stream non sono scritti a mano:
sono quelli della prova, con un solo cambiamento, il percorso della
cartella personale del docente scritto `~`. Copiate sopra uno spazio di
lavoro nuovo, fanno passare `tools/verifica.sh M4-D05`.
