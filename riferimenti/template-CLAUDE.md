<!--
Modello di CLAUDE.md, il file di istruzioni che Claude Code carica all'inizio
di ogni sessione. Questi commenti non costano niente: Claude Code toglie i
commenti HTML a livello di blocco prima che il file entri nel contesto.
Riempite le parti fra < >, togliete le sezioni che non servono.

Le indicazioni, dalla documentazione di Claude Code
(https://code.claude.com/docs/en/memory e
https://code.claude.com/docs/en/best-practices):
- scrivete solo ciò che Claude non trova leggendo il repository, o che
  altrimenti riscoprirebbe a ogni sessione. Prima di una riga, due domande:
  la troverebbe leggendo il codice? Andrebbe davvero a cercarla? Se la
  risposta è sì a tutte e due, la riga non serve;
- righe concrete e verificabili («Esegui `tools/php.sh phpunit` prima di un
  commit», non «Prova le modifiche»), raggruppate sotto titoli ed elenchi
  puntati;
- meno di 200 righe: ogni riga si carica a ogni sessione e prende un po'
  dell'attenzione di Claude su ogni compito;
- niente informazioni sensibili: chiavi, password, credenziali;
- ciò che deve valere sempre non è una riga: è un hook o una regola deny;
- ciò che vale per una parte del codice va in una regola di .claude/rules/,
  con «paths:»; una procedura in più passi in una skill; una preferenza
  vostra in un CLAUDE.local.md, fuori da git con .gitignore;
- poi, in una sessione nuova, /context all: il file compare sotto
  «Memory files»?
-->

# <Il progetto in una riga: che cos'è e per chi>

<!--
Una o due righe al massimo. La struttura delle cartelle e l'architettura
no: Claude le legge da sé.
-->

## Comandi

<!--
I comandi esatti per verificare il lavoro, e da quale cartella si lanciano:
i test, un solo test, lo stile, gli altri controlli.
-->

- `<comando>`: <che cosa verifica>

## Convenzioni che il codice non dice

<!--
Le decisioni prese fuori dal repository: in una riunione, nella testa di una
persona. Se un'indicazione sta già in un documento del repository, una riga
che lo nomina basta.
-->

- <la decisione, con il perché in poche parole>

## Insidie

<!--
I punti in cui il codice inganna: un vecchio pattern da non copiare, una
cartella che sembra inutile e non lo è, un file generato da non toccare a
mano. Ciò che avete dovuto correggere due volte.
-->

- <che cosa evitare, e che cosa fare invece>

## Riferimenti

<!--
I documenti da leggere quando servono, con il percorso: nominato, un file non
si carica, Claude lo legge se lo apre. Con @percorso invece si importa: si
carica a ogni sessione insieme a questo file e costa gli stessi token.
-->

- `<docs/un-documento.md>`: <quando leggerlo>
