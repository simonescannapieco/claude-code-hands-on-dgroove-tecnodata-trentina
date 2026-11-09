# M7-D05 — Cercare per significato

Demo del Modulo 7, nella parte sulla conoscenza dell'assistente. La fa il
docente sul suo computer; la sua registrazione è il ripiego.

## Obiettivo

Vedere la differenza fra una ricerca per parole e una ricerca per significato, sulle
stesse tre domande e sugli stessi dodici articoli dell'assistenza di CiaspoLink, il
fornitore di connettività inventato dei progetti del corso (dati sintetici). Le
domande sono scritte apposta: la prima usa le parole dell'articolo che risponde; la
seconda dice la stessa cosa con altre parole, e nessuna è in comune con l'articolo;
la terza usa parole che stanno in articoli che non c'entrano.

La ricerca per significato si fa con un modello di embedding, e Claude qui non
c'entra: «Anthropic does not offer its own embedding model.»
(https://platform.claude.com/docs/en/build-with-claude/embeddings) Per questo
gira un modello locale, su Ollama, sul computer del docente: nessuna chiamata a
Claude, nessun token del piano Pro, e il controllo non dice niente su Claude.

## Tempo

2 minuti in aula, sullo schermo del docente.

## Prerequisiti

- Il computer del docente con Ollama già in ascolto (porta 11434) e il modello
  `embeddinggemma:300m` scaricato. Lo script non avvia nessun servizio: se Ollama
  non risponde, lo dice ed esce.
- Python 3.
- Claude Code qui non serve; chi vuole rifarla sul proprio computer ha bisogno
  soltanto di Ollama con quel modello.

## Punto di partenza (tools/prepara_esercizio.sh M7-D05)

Lo spazio di lavoro `~/corso-claude-code/M7-D05/` con:

- `articoli/`: dodici articoli brevi dell'assistenza, uno per file;
- `domande.txt`: le tre domande, una per riga;
- `cerca.py`: le due ricerche;
- `controlla_risultati.py`: legge il risultato.

Le tre domande e come sono fatte:

| domanda | com'è fatta |
|---|---|
| «Come si cambia la password del Wi-Fi?» | le stesse parole di `art-03-password-wifi` |
| «Vado ad abitare in un'altra casa: che fine fa il mio abbonamento?» | altre parole: `art-07-cambio-indirizzo` dice «nuovo indirizzo» e «spostare la linea», e nessuna parola della domanda è in un articolo |
| «Mi hanno fatto pagare due volte lo stesso mese» | altre parole: `art-06-addebito-ripetuto` dice «addebito ripetuto», e «due», «volte» e «mese» stanno in articoli che parlano d'altro |

## Passi in Claude Code (qui, sul computer del docente)

Questa demo non usa Claude Code e non chiama Claude: Anthropic non ha un modello
di embedding suo, e la ricerca per significato ne ha bisogno. Dal terminale,
nella cartella delle esercitazioni:

1. Si prepara lo spazio di lavoro:

       tools/prepara_esercizio.sh M7-D05

2. Il docente fa girare la demo, con il comando sullo schermo (`_docente/live.sh`
   fa girare `cerca.py` e poi la verifica; lo stesso comando si lancia a mano
   dallo spazio di lavoro, `python3 -B -I cerca.py`):

       m7_assistenti_llm/s6_conoscenza_e_valutazione/m7_6_la_conoscenza/M7-D05_cercare_per_significato/_docente/live.sh ~/corso-claude-code/M7-D05

3. In sala si guardano le due classifiche affiancate, domanda per domanda.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina sugli embedding: «Anthropic does not offer its own embedding
  model.» (https://platform.claude.com/docs/en/build-with-claude/embeddings);
  e, sempre lì, «One embeddings provider with a wide variety of models and
  capabilities is Voyage AI by MongoDB.»
- Che cosa fa il RAG, secondo Anthropic: «RAG is a method that retrieves relevant
  information from a knowledge base and appends it to the user's prompt»
  (https://www.anthropic.com/research/contextual-retrieval). Recuperare il pezzo
  giusto è il passo che questa demo mette sullo schermo; il modulo lo riprende
  con l'assistente vero, in M7-D06.

### Che cosa stampa lo script

Per ogni domanda, due classifiche affiancate: a sinistra gli articoli per numero
di volte in cui compaiono le parole della domanda (le parole vuote non contano:
articoli, preposizioni, pronomi); a destra i primi cinque articoli per similarità
del coseno fra il vettore della domanda e quello dell'articolo. Sopra, il modello
e il digest usati.

- Sulla prima domanda la ricerca per parole mette in cima `art-03`.
- Sulla seconda la ricerca per parole non trova niente: nessun articolo contiene
  «abitare», «altra», «casa», «fine» o «abbonamento».
- Sulla terza la ricerca per parole mette in cima gli articoli che dicono «due» e
  «volte», cioè quelli che non rispondono.

Che cosa fa la ricerca per significato sulle stesse domande lo dice la colonna di
destra della registrazione (`soluzione/risposte/risultati.json`, nel repository del
corso; la copia senza soluzioni non l'ha).

### Che cosa fa il controllo

`controlla_risultati.py` legge `risposte/risultati.json`, quello che `cerca.py`
ha scritto: per ogni domanda, per ogni articolo, il conteggio delle parole, il
coseno e i due ranghi, con il modello e il digest. Controlla che ci siano tutte
le domande di `domande.txt` e stampa le classifiche. Non decide quale ricerca sia
migliore e non dice niente su Claude: è un'indicazione di che cosa succede con
questi dodici articoli, questo modello locale e queste tre domande, una
dimostrazione.

### Nella registrazione del corso

La prova del docente del 9 novembre 2026, con il modello `embeddinggemma:300m` in
locale su Ollama 0.15.1 (digest `85462619ee72…`), è in
`soluzione/risposte/risultati.json` (nel repository del corso; la copia senza
soluzioni non l'ha), e dal file vengono le classifiche sulla slide. Sulla
domanda 1 tutte e due le ricerche mettono in testa la procedura giusta,
`art-03`. Sulla domanda 2 («Vado ad abitare in un'altra casa…») la ricerca per
parole non trova nessun articolo, e il coseno mette in testa `art-07`, il cambio
di indirizzo, con 0,586. Sulla domanda 3 («Mi hanno fatto pagare due volte…») la
ricerca per parole mette in testa `art-01` e `art-08`, che parlano d'altro, e il
coseno mette in testa `art-06`, l'addebito ripetuto, con 0,548. Sono i numeri di
questa prova, di questi dodici articoli e di questo modello.

## Verifica (tools/verifica.sh M7-D05)

La verifica fa girare `controlla_risultati.py` dell'elemento, non la copia dello
spazio di lavoro. È fatta quando `risposte/risultati.json` c'è, con tutte e tre
le domande e le loro classifiche: l'ultima riga è «Fatto: le due ricerche sono in
risposte/risultati.json.» Il risultato della ricerca non decide l'uscita.

## Se qualcosa va storto

- `cerca.py` dice «Ollama non risponde»: sul computer del docente il servizio
  non è avviato. Lo script non lo avvia: va fatto a mano, poi si rilancia.
- «il modello embeddinggemma:300m non è fra quelli di Ollama»: va scaricato con
  Ollama, poi si rilancia.
- `PN_OLLAMA_URL` con un indirizzo che non è di questo computer: lo script lo
  rifiuta, esce con 2 e non apre nessuna connessione.
- La verifica dice che manca `risposte/risultati.json`: lanciate `cerca.py` fino
  in fondo; il file si scrive soltanto quando tutte le domande sono finite.
- Per ricominciare da capo: `tools/reset_esercizio.sh M7-D05`.
- Il ripiego in aula è la registrazione: `tools/verifica.sh M7-D05` sopra una
  copia di `soluzione/risposte/` (nel repository del corso; la copia senza
  soluzioni non l'ha).

## Impronta d'uso sul piano Pro

Nessuna: non si chiama Claude e nessun token passa dal piano Pro. Gira tutto sul
computer del docente, con Ollama in locale.

## Per approfondire

- La pagina sugli embedding:
  https://platform.claude.com/docs/en/build-with-claude/embeddings
- «Contextual Retrieval», sul recupero in un RAG:
  https://www.anthropic.com/research/contextual-retrieval
