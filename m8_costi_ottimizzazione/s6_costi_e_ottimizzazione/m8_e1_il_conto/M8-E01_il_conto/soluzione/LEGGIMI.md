# Soluzione di M8-E01

Qui c'è il riferimento del docente per l'esercitazione.

- `conto.py`: uno script che fa il conto, scritto per il corso, non l'uscita
  della richiesta del passo 3 del README: legge `risposte/prima.json`, `listino.json` e `volume.txt` nella cartella in
  cui lo si lancia e stampa i cinque conteggi di `usage` ciascuno al suo prezzo,
  il costo della chiamata, `total_cost_usd` per confronto e il costo del mese.
  È una versione, non la versione: quella che Claude scrive con la richiesta del
  README può essere più lunga o stampare altre righe, e la verifica la accetta
  se i due numeri ci sono.
- `risposte/prima.json`: la registrazione del corso del 10 novembre 2026, con
  Claude Code 2.1.322 e Haiku con effort low, sull'account del docente: il JSON
  della chiamata del passo 2 del README, così come l'ha scritto
  `_docente/live.sh` in uno spazio di lavoro nuovo, da cui `tools/verifica.sh
  M8-E01` stampa la tabella e i dati. Il docente lo importa dalla prova. Le
  cifre: 2 token in `input_tokens`, 767
  scritti nella cache a un'ora, 3.133 letti dalla cache, 1.950 in uscita;
  `total_cost_usd` 0,001160 $, uguale al ricalcolo (differenza 0,000000 $); il
  mese, a 10.000 ticket da 1.000 token in entrata e 150 in uscita, 1,75 $.

Copiati sopra uno spazio di lavoro nuovo (tutta la cartella, con
`cp -R soluzione/. ~/corso-claude-code/M8-E01/`), `conto.py` e
`risposte/prima.json` fanno passare `tools/verifica.sh M8-E01`.

<!-- registrazione del corso -->
## La registrazione del corso

Qui c'è la registrazione del corso del 10 novembre 2026, con Claude Code
2.1.322 e `claude-haiku-5-5`, sull'account del docente: il JSON
della chiamata del passo 2 del README, `risposte/prima.json`, da cui
`tools/verifica.sh M8-E01` stampa i dati e i verdetti. È la prova del docente,
`_docente/live.sh`.

Copiato sopra uno spazio di lavoro nuovo, insieme a `conto.py` di questa
cartella, `risposte/prima.json` fa passare `tools/verifica.sh M8-E01`.
<!-- /registrazione del corso -->
