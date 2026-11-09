# Soluzione di M7-E01

Qui c'è la registrazione del corso del 9 novembre 2026, con Claude Code 2.1.319,
sull'account del docente: la conversazione del v0 sullo scenario `sc-16` e le note,
come un partecipante le lascerebbe nello spazio di lavoro.

- `conversazione/`: la trascrizione (`trascrizione.md`), il registro delle chiamate
  agli strumenti (`registro.jsonl`), la conversazione in JSON (`conversazione.json`),
  il system prompt che ha girato (`system-prompt.usato.md`). Sono quelli
  dell'esecuzione del docente con `_docente/live.sh`, con il percorso del
  repository scritto `HANDS-ON` e la cartella personale del docente `~`; lo
  `stream.jsonl` non c'è: la verifica non lo legge.
- `note.md`: quattro voci scritte da chi ha letto quella trascrizione, ciascuna con
  il turno o lo strumento. Le note sono il lavoro del partecipante: quelle di un
  altro partecipante, sulla stessa trascrizione, possono essere altre.

La prova del docente, `_docente/live.sh`: Sonnet con effort low per l'assistente,
Haiku per il cliente, poi la lettura e le note in `claude -p` al posto della sessione
interattiva. Le righe della verifica, su quella esecuzione, con le note del file qui
accanto:

    La conversazione: scenario SC-16, versione v0, 8 messaggi, 4 giri.
    (dato) le chiamate agli strumenti nel registro: 2: cercaCliente, operatore

Copiata sopra uno spazio di lavoro nuovo, questa cartella fa passare
`tools/verifica.sh M7-E01`: «Fatto: la conversazione c'è e le note citano ciò che si
vede nella trascrizione.». I secondi e i token della conversazione e della lettura
stanno nel README, sezione «Impronta d'uso sul piano Pro».
