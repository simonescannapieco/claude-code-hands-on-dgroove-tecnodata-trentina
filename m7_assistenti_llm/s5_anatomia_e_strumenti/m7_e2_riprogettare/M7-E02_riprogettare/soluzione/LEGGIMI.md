# Soluzione di M7-E02

Qui c'è il riferimento del docente per il laboratorio.

- `v1/`: una riprogettazione dell'assistente nel modello del corso:
  `system-prompt.md` con i tag del template, `strumenti.json` con una capacità per
  ogni strumento e descrizioni di almeno tre frasi, `regole-escalation.md` con i
  criteri di passaggio, un esempio per criterio, tutto nel tag `procedures`. È
  una versione, non la versione: la vostra può essere diversa e fare meglio o
  peggio su un caso.
- La registrazione del corso (9 novembre 2026, Claude Code 2.1.319, sull'account del
  docente, `_docente/live.sh`): i tre prompt del README in `claude -p`, Sonnet con
  effort medium, e poi i cinque casi di `progetti/assistenza-clienti/banco/casi/` su
  v0 e sulla v1 che Claude ha scritto con quei prompt, ogni caso una chiamata di
  `claude -p` su Sonnet con effort low e il server MCP del banco. La registrazione
  (`risultati/v0/` e `risultati/v1/`, con la v1 scritta da Claude, non questa) la
  copia il docente qui dopo l'esecuzione. Le righe della verifica su quella
  registrazione:

      (dato) escalation v0 5/5  ->  v1 5/5  non distinguibile
      (dato) strumenti  v0 10/15  ->  v1 15/15  confermata in questa misura
      (dato) prima_di   v0 1/3  ->  v1 3/3  confermata in questa misura
      (dato) risposta   v0 7/7  ->  v1 7/7  non distinguibile
      (dato) totale     v0 23/30  ->  v1 30/30  confermata in questa misura

Prova della `v1/` di riferimento di questa cartella (9 novembre 2026, Claude Code
2.1.319, Sonnet con effort low, una esecuzione per caso, sul banco): 30 asserzioni
soddisfatte su 30, CASO-01 10/10, CASO-02 6/6, CASO-03 5/5, CASO-04 5/5, CASO-05
4/4. Sono i risultati di una sola esecuzione: un'esecuzione non è una garanzia. I
token e i secondi della registrazione stanno nel README, sezione «Impronta d'uso sul
piano Pro».

Per copiarla sopra uno spazio di lavoro: `cp -R soluzione/v1 ~/corso-claude-code/M7-E02/`
(dalla cartella dell'elemento), poi le prove del README. Quando la registrazione è
in questa cartella, copiata sopra uno spazio di lavoro nuovo fa passare
`tools/verifica.sh M7-E02`.

<!-- registrazione del corso -->
## La registrazione del corso

Qui c'è la registrazione del corso del 9 novembre 2026, con Claude Code
2.1.319 e Sonnet, sull'account del docente: le esecuzioni dei cinque casi su
v0 e sulla v1 che Claude ha scritto con i prompt del README, in
`risultati/v0/` e `risultati/v1/`, da cui `tools/verifica.sh M7-E02` stampa i
dati e i verdetti. È la prova del docente, `_docente/live.sh`.

Gli stream non sono scritti a mano: sono quelli della prova, ridotti a ciò che
il controllo legge. Di `system/init` restano `skills`, `model` e
`claude_code_version`; dei messaggi dell'assistente il testo, le chiamate agli
strumenti e `usage`; dei messaggi utente i risultati di `Skill`, quelli con
`is_error` e il corpo di una skill, tagliati a 300 caratteri; e, interi,
quelli di ogni strumento; i `result` interi. Il percorso del repository è
scritto `HANDS-ON` e quello della cartella personale del docente `~`. Il
controllo è stato eseguito sugli stream interi e su questi: stampa le stesse
righe.

Copiata sopra uno spazio di lavoro nuovo, insieme a `v1/`, `risultati/` fa
passare `tools/verifica.sh M7-E02`.
<!-- /registrazione del corso -->
