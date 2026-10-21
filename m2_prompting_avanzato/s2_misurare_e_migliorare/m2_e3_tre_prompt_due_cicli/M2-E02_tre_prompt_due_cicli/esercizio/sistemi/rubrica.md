# Rubrica: la lettura del syslog

Il compito vero: dire al collega di turno che cosa è successo, quanti
clienti sono coinvolti e che cosa si controlla per primo.

Tra parentesi quadre, la pratica che l'affermazione legge (l'elenco:
`./misura.sh --pratiche`); un'affermazione senza parentesi conta nei
totali, ma nell'esito di nessuna pratica. Il giudice riceve le
affermazioni senza la pratica. I criteri si fissano prima dei prompt.

- **un_guasto** [contesto]: La risposta dice che è un guasto solo, a monte, sulla porta PON 0/1/3 di olt-pergine-01, non tanti guasti dei singoli clienti.
- **quanti**: La risposta dice quanti clienti sono coinvolti: le 40 ONT della porta.
- **primo_controllo** [contesto]: La risposta indica come primo controllo un punto comune a tutta la porta (il modulo ottico della porta sulla OLT, la fibra o lo splitter a monte), non gli apparati dei singoli clienti.
- **cauto**: La risposta presenta le cause possibili come ipotesi da verificare, non come certezze.
