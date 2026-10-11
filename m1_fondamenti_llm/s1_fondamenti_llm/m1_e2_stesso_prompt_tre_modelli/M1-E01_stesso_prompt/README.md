# M1-E01 — Lo stesso prompt su tre modelli

Esercitazione del Modulo 1, nella pratica «Lo stesso prompt su più modelli
Claude». È il primo elemento del corso che fate in Claude Code.

## Obiettivo

Scegliere un modello sul vostro compito, misurando: lo stesso prompt su
Haiku, Sonnet e Opus, poi il confronto delle risposte, dei tempi e dei
token.

## Tempo

15 minuti.

## Prerequisiti

- Claude Code installato e collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`).
- `claude --version` 2.1.293 o successiva: con le versioni precedenti
  l'alias `haiku` punta a un modello più vecchio.
- Python 3, che lo stesso controllo verifica: lo usa la verifica.

## Punto di partenza (tools/prepara_esercizio.sh M1-E01)

Lo spazio di lavoro `~/corso-claude-code/M1-E01/` con:

- `prompt/sviluppo.md`: una funzione PHP del gestionale; in quali casi il
  calcolo del rateo sbaglia?
- `prompt/sistemi.md`: un estratto del syslog della rete; che cosa è
  successo, e che cosa si controlla per primo?
- `prompt/supporto.md`: l'e-mail di un cliente e un estratto della guida al
  tono di voce; da scrivere, la risposta al cliente;
- `confronto.md`: la tabella da compilare;
- `consegna_confronto.txt`: la richiesta da fare a Claude per i numeri
  della tabella.

I dati vengono dai progetti di esempio di CiaspoLink: sono tutti
inventati.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M1-E01
       cd ~/corso-claude-code/M1-E01

2. Scegliete il percorso, e leggete il prompt:
   - **percorso A, un vostro compito:** scrivete in `prompt/mio.md` un
     compito vero del vostro lavoro, con i dati sostituiti da valori
     inventati (niente nomi di clienti, password, indirizzi o configurazioni
     reali), e usate quello;
   - **percorso B, i progetti di esempio:** il prompt di CiaspoLink più
     vicino al vostro lavoro, `sviluppo`, `sistemi` o `supporto`. La prova
     del docente è su `prompt/sistemi.md`.

3. Mandatelo ai tre modelli, uno dopo l'altro (al posto di `sistemi`, il
   vostro):

       p=prompt/sistemi.md
       mkdir -p risposte
       for m in haiku sonnet opus; do
         claude -p "$(cat "$p")" --model "$m" --effort low --tools "" \
           --system-prompt "Rispondi in italiano." --strict-mcp-config \
           --output-format json > "risposte/$m.json"
       done

   Ogni file è il JSON del risultato: la risposta (`result`), la durata in
   millisecondi (`duration_ms`), i token (`usage`) e il modello che ha
   risposto (`modelUsage`). Le opzioni sono quelle delle demo: un modello
   per chiamata, effort low, nessuno strumento, l'istruzione di sistema,
   nessun server MCP né connettore. Checkpoint, a metà tempo: i tre file in
   `risposte/`.

4. Aprite una sessione interattiva su Sonnet, nello spazio di lavoro:

       claude --model sonnet

   e chiedete:

       Mostrami, uno dopo l'altro, il campo result di risposte/haiku.json, risposte/sonnet.json e risposte/opus.json, senza commentarli.

   Leggete voi le tre risposte: dove differiscono?

5. Nella stessa sessione incollate il testo di `consegna_confronto.txt` (lo
   copiate aprendo il file nel vostro editor): Claude scrive in
   `confronto.md` i secondi e i token di ogni modello. Se Claude Code vi
   chiede il permesso di modificare il file, concedetelo.

6. Scrivete voi, in `confronto.md`, il prompt usato (il nome del file, per
   esempio `prompt/sistemi.md`), la colonna «che cosa cambia nella
   risposta», il modello che scegliereste e il perché: con il vostro
   editor, o dettandoli a Claude.

7. Uscite con `/exit`, tornate nella cartella `esercitazioni` (`cd -`, se
   dallo spazio di lavoro non vi siete spostati, oppure il suo percorso) e
   verificate:

       cd -
       tools/verifica.sh M1-E01

   Checkpoint finale: la verifica esce con 0.

## Che cosa osservare

- Dove le risposte differiscono, non quanto sono lunghe: hanno colto il
  punto? Che cosa manca? Che cosa è sbagliato?
- Che cosa cercare nei tre compiti del percorso B:
  - sviluppo: un'attivazione il 31 del mese conta zero giorni; una
    cessazione il 31 fa pagare 31/30 del canone; se la linea è attivata e
    cessata nello stesso mese, conta solo la cessazione;
  - sistemi: tutte le ONT della stessa porta PON sono cadute nel giro di un
    secondo per perdita di segnale: il guasto è uno solo, a monte (la fibra
    o lo splitter della porta), non quaranta guasti dei clienti;
  - supporto: il «lei», una scusa sola e specifica, che cosa facciamo e che
    cosa deve fare il cliente, nessun orario inventato.
- Il tempo e i token: chi ha scritto di più? Chi ha risposto prima?
- I numeri che Claude ha scritto in `confronto.md` sono giusti? La verifica
  li confronta con i JSON e, se non tornano, ve lo dice.
- Una sola esecuzione non è una misura: rilanciate un modello salvando la
  risposta in un file nuovo, per esempio `risposte/haiku-2.json` (i tre
  file del passo 3 restano quelli della verifica), e confrontate le due
  risposte.
- Il modello non è l'unica leva: anche l'effort cambia tempi e risposte.

## Verifica (tools/verifica.sh M1-E01)

Controlla i tre JSON (senza errori, con una risposta, ciascuno dal suo
modello) e `confronto.md`: tutto compilato, uno dei tre modelli scelto, e i
numeri della tabella uguali a quelli dei JSON, i secondi con un secondo di
tolleranza.

## Se qualcosa va storto

- Un JSON vuoto o con un errore: rilanciate solo quella chiamata, nella
  stessa cartella e con `p` impostato come al passo 3 (qui per opus):

      m=opus
      claude -p "$(cat "$p")" --model "$m" --effort low --tools "" \
        --system-prompt "Rispondi in italiano." --strict-mcp-config \
        --output-format json > "risposte/$m.json"
- La verifica dice che i numeri non tornano: correggeteli voi, oppure
  chiedete a Claude di ricontrollarli. È uno dei punti dell'esercizio:
  quello che scrive un modello si verifica.
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M1-E01`.

## Impronta d'uso sul piano Pro

Tre chiamate, una per modello, con effort low e nessuno strumento; poi una
sessione interattiva su Sonnet di tre o quattro turni, senza subagent. Opus
pesa sul limite d'uso più degli altri due: qui è una chiamata sola. Niente
Fable: sul piano Pro funziona solo con i crediti d'uso (usage credits), a
pagamento. Alla fine, `/exit`.

## Per approfondire

- Il tutorial dell'Academy «Choosing the right Claude model: Haiku, Sonnet,
  Opus, or Fable»:
  https://academy.claude.com/tutorials/choosing-the-right-claude-model
- La pagina «Choosing the right model» della documentazione:
  https://platform.claude.com/docs/en/about-claude/models/choosing-a-model
