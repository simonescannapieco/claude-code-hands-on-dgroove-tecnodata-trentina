# M4-D01 — la soluzione è la registrazione del corso

Qui ci sono i due file della registrazione del corso del 28 ottobre 2026,
con Claude Code 2.1.312, sull'account del docente: `stato/senza.json` e
`stato/con.json`, le due esecuzioni di `claude auth status --json` del
passo 3 del README, salvate da `controlla_accesso.py --salva` con i soli
tre campi `loggedIn`, `authMethod` e `apiKeySource`. Vengono dalla prova
del docente, `_docente/live.sh`, l'unica fatta, senza nessuna chiamata al
modello; non sono scritti a mano.

Senza la chiave il metodo è `claude.ai`; con la chiave finta, impostata
per quel solo comando, `api_key`, con la chiave da `ANTHROPIC_API_KEY`.
Copiati sopra uno spazio di lavoro nuovo, fanno passare
`tools/verifica.sh M4-D01`.
