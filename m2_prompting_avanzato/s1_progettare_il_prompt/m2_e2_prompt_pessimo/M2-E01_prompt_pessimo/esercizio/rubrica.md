# Rubrica: la risposta al cliente

Le affermazioni che il giudice verifica sulla risposta, una per riga. Per
ciascuna dice se la risposta la rispetta, con il motivo in una riga.
Quello che si controlla meglio con il codice (il telefono, i segnaposto, la
lunghezza) sta in `controlli.tsv`.

Tra parentesi quadre, la pratica che l'affermazione legge (l'elenco:
`./misura.sh --pratiche`): `./misura.sh --confronta` decide l'esito di una
pratica dai criteri segnati con il suo nome. Il giudice riceve le
affermazioni senza la pratica. I criteri si fissano prima dei prompt.

- **domande** [chiarezza]: La risposta risponde a entrambe le richieste del cliente: l'indennizzo per l'interruzione di venerdì e la linea di riserva per il centralino.
- **impegni** [chiarezza]: La risposta non promette importi, esiti, date od orari che le procedure non danno: dice chi decide e che cosa succede dopo.
- **fatti** [contesto]: La risposta usa solo fatti presenti nel messaggio del cliente o nelle procedure, senza aggiungerne altri.
- **lei** [chiarezza]: La risposta dà del «lei» al cliente, con un tono cortese e concreto.
- **firma** [chiarezza]: La risposta è firmata dall'assistenza clienti di CiaspoLink, non con il nome di una persona.
