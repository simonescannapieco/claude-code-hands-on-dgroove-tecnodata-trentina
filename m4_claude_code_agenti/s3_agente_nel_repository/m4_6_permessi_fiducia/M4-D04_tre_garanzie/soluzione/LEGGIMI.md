# Soluzione di M4-D04

- `.claude/settings.json`: le impostazioni dello spazio di lavoro con la
  regola deny della prova dei partecipanti, uguali a
  `demo/impostazioni/deny.json`. Copiate sullo spazio di lavoro,
  `tools/verifica.sh M4-D04` passa: è la soluzione della prova, scritta a
  mano, non una risposta di Claude.
- La registrazione del corso del 28 ottobre 2026, con Claude Code 2.1.312
  e Sonnet, sull'account del docente: la seconda prova del docente,
  quella con la regola ancorata (la prima non vale). In `risposte/` gli
  stream-json delle sei esecuzioni delle tre coppie (`piano-con.jsonl` …
  `hook-senza.jsonl`) e quello della prova dei partecipanti, rifatta dal
  docente con `claude -p` invece che in una sessione (`prova.jsonl`); in
  `esito_del_controllo.txt` le righe che `live.sh` ha stampato, con
  quelle del controllo che `controlla_gradini.py` di questo elemento
  stampa sulle stesse esecuzioni, rifatto dopo la prova sulla sua
  cartella. Non sono scritti a mano: sono quelli della prova, con un solo
  cambiamento, il percorso della cartella personale del docente scritto
  `~`. Le sei copie del progetto su cui ha lavorato Claude (`gradini/`,
  ognuna con il suo `.git/`) qui non ci sono: senza di loro
  `controlla_gradini.py` non si rifà da questa cartella.
