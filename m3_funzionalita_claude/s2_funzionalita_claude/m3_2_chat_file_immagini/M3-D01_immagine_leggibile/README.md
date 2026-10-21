# M3-D01 — Un'immagine leggibile

Demo del Modulo 3, nella parte «Chat, file e immagini». In aula il
docente mostra il risultato registrato in Claude Code, poi la provate voi
in claude.ai; la parte in Claude Code potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova tre affermazioni di Anthropic sulle immagini. La
stessa tabella di allarmi di rete, grande (1600×1000 pixel) e piccola
(160×100), con la stessa domanda: quanti allarmi sono «critico», e su
quali apparati. Le due chiamate di una coppia hanno la stessa domanda, lo
stesso modello e le stesse opzioni: cambiano soltanto l'immagine e il suo
nome, `allarmi.png` o `allarmi-piccola.png`, che il prompt nomina.

## Tempo

4 minuti in aula: il risultato del docente, poi la vostra prova in
claude.ai. Circa 6 minuti per rifare da soli la parte in Claude Code.

## Prerequisiti

- Un account claude.ai con il piano Pro.
- Per la parte in Claude Code: Claude Code collegato al piano Pro, con
  `tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`), e
  Claude Code 2.1.293 o successiva (`claude --version`), perché sei
  chiamate su dodici sono su Haiku: «Use v2.1.293 or later with Haiku
  5.5.» (https://code.claude.com/docs/en/model-config).
- Python 3, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M3-D01)

Lo spazio di lavoro `~/corso-claude-code/M3-D01/` con:

- `allarmi.png` e `allarmi-piccola.png`: la tabella degli allarmi di una
  settimana di CiaspoLink, a 1600×1000 e a 160×100 pixel. È la stessa
  pagina, con le stesse proporzioni: la piccola è la grande rimpicciolita
  dieci volte;
- `allarmi.html`: la pagina da cui nascono le due immagini;
- `prompt.txt`: la domanda, con `IMMAGINE` al posto del nome del file;
- `verita.json`: i valori giusti, che legge il controllo;
- `controlla_lettura.py`: legge il JSON di ogni chiamata, dice che cosa
  ha letto Claude e l'esito di tre affermazioni, e scrive `esiti.tsv`;
- `.claude/settings.json`: le impostazioni prudenti del repository, più
  quattro regole che negano allo strumento Read la pagina HTML, la verità,
  gli esiti e le risposte già arrivate.

Apparati, allarmi e date sono inventati, come tutti i dati del corso.

## Passi in Claude Code (e in claude.ai)

1. **In claude.ai, con il modello predefinito:** aprite una chat nuova e,
   prima del primo messaggio, spegnete la memoria per quella chat (menu
   «+», «Memory»). Caricate `allarmi-piccola.png` (nella cartella `demo/`
   di questo elemento, o nello spazio di lavoro del passo 2), come un
   qualunque file o trascinandola nella finestra della chat, e incollate
   il testo di `prompt.txt` con `allarmi-piccola.png` al posto di
   `IMMAGINE`. Poi un'altra chat nuova, sempre con la memoria spenta, con
   `allarmi.png` e lo stesso testo, con `allarmi.png` al posto di
   `IMMAGINE`. Prima la piccola: così la sua risposta non può dipendere da
   ciò che Claude ha visto nella grande. Confrontate a voce le due
   risposte con la tabella grande, che leggete anche voi.

   Su Windows con WSL 2 il repository e lo spazio di lavoro stanno nel
   file system di Linux: se dal browser non li raggiungete, copiate le due
   immagini in una cartella di Windows e caricatele da lì, per esempio,
   dalla cartella in cui stanno,
   `cp allarmi.png allarmi-piccola.png /mnt/c/Users/<utente>/Downloads/`,
   con il vostro nome utente di Windows al posto di `<utente>`.

2. **In Claude Code:** preparate lo spazio di lavoro ed entrateci, dalla
   cartella `esercitazioni`:

       tools/prepara_esercizio.sh M3-D01
       cd ~/corso-claude-code/M3-D01

3. Le dodici chiamate: tre coppie per Haiku e tre per Sonnet, ogni coppia
   prima la grande e poi la piccola, con il JSON della risposta in
   `risposte/`. Ogni chiamata parte da una sottocartella, `grande/` o
   `piccola/`, che contiene soltanto la sua immagine e una copia di
   `.claude/`: nella cartella da cui Claude lavora c'è soltanto l'immagine
   che il prompt nomina, e le impostazioni del passo 2 valgono anche lì,
   perché valgono per «Everyone working in the folder that contains it»
   (https://code.claude.com/docs/en/settings). `--tools Read` lascia a
   Claude un solo strumento, Read, per leggere il file che il prompt
   nomina:

       mkdir -p risposte grande piccola
       cp allarmi.png grande/ && cp -R .claude grande/
       cp allarmi-piccola.png piccola/ && cp -R .claude piccola/
       p="$(cat prompt.txt)"
       for m in haiku sonnet; do
         for n in 1 2 3; do
           for g in grande piccola; do
             f=allarmi.png
             if [ "$g" = piccola ]; then f=allarmi-piccola.png; fi
             (cd "$g" && claude -p "${p//IMMAGINE/$f}" --model "$m" \
               --effort low --tools Read --allowedTools Read \
               --strict-mcp-config --no-session-persistence \
               --output-format json) > "risposte/$g-$m-$n.json"
           done
         done
       done

4. Che cosa ha letto Claude, e l'esito delle tre affermazioni:

       python3 controlla_lettura.py

`_docente/live.sh`, la prova del docente, manda gli stessi testi con le
stesse opzioni, dalle stesse sottocartelle, più
`--setting-sources project,local` e
`--permission-mode dontAsk --permission-prompts none`; la registrazione
del corso fa lo stesso, con ogni chiamata in una cartella nuova che
contiene soltanto la sua immagine.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina sulla vision della documentazione per sviluppatori, fra i
  consigli sulle immagini: «If the image contains important text, make
  sure it's legible and not too small.» Se l'immagine contiene testo
  importante, deve essere leggibile e non troppo piccolo.
  https://platform.claude.com/docs/en/build-with-claude/vision
- Nel centro assistenza, sul caricamento dei file: «Use images that are
  1000x1000 pixels or larger. Avoid small or low-resolution images where
  possible.» Immagini da 1000×1000 pixel in su; evitare quelle piccole o a
  bassa risoluzione.
  https://support.claude.com/en/articles/8241126-upload-files-to-claude
- Nella pagina sulla vision, fra i limiti: «Claude might hallucinate or
  make mistakes when interpreting low-quality, rotated, or very small
  images under 200 pixels.» Con immagini molto piccole, sotto i 200 pixel,
  Claude può avere allucinazioni o sbagliare.
  https://platform.claude.com/docs/en/build-with-claude/vision
- E la conseguenza pratica, nella stessa pagina: «Always carefully review
  and verify Claude's image interpretations, especially for high-stakes
  use cases.»

Le due immagini stanno ai due lati delle soglie che queste frasi nominano:
la grande è di 1600×1000 pixel, la piccola di 160×100, sotto i 200.

Come arriva l'immagine in Claude Code: «Provide an image path to Claude,
for example "Analyze this image: /path/to/your/image.png"»
(https://code.claude.com/docs/en/common-workflows). Lo strumento Read,
nel riferimento degli strumenti: «PNG, JPEG, GIF, and WebP files are
returned as visual content that Claude can see, not as raw bytes.» E:
«Claude Code resizes and recompresses large images to fit the model's
image size limits before sending them»
(https://code.claude.com/docs/en/tools-reference). Se la grande supera
quei limiti, Claude Code la riduce prima di mandarla: la prova confronta
le due immagini così come le date voi. In claude.ai:
«Upload an image like you would a file, or drag and drop an image
directly into the chat window.»
(https://platform.claude.com/docs/en/build-with-claude/vision)

### Che cosa misura il controllo

`controlla_lettura.py` legge il JSON di ogni chiamata, il testo della
risposta nel campo `result`, e cerca le due righe che il prompt chiede,
«critici: …» e «apparati: …», senza badare alle maiuscole, agli spazi,
agli elenchi puntati e al grassetto; i nomi in qualunque ordine. Per ogni
risposta stampa che cosa ha letto e se è giusto. Una risposta che dice
«non leggibile» è un rifiuto: nessun valore letto, e nessun errore. Una
risposta senza le due righe e senza «non leggibile» si stampa così com'è.
Scrive `esiti.tsv`, una riga per file: la lettura, i valori letti, e se
sono giusti.

Poi, per Haiku e per Sonnet:

- «Testo leggibile, immagine grande», le prime due affermazioni messe alla
  prova insieme, coppia per coppia (la chiamata n sulla grande con la n
  sulla piccola): confermata se la grande dà giusti tutti e due i valori e
  la piccola no; non distinguibile se li danno giusti tutte e due, o
  nessuna delle due; non confermata in questa esecuzione se li dà giusti
  la piccola e non la grande. Poi «confermata n su 3».
- «Sotto i 200 pixel, Claude può sbagliare», la terza, su ogni chiamata
  sulla piccola: confermata se la risposta dà un valore sbagliato; un
  rifiuto, una risposta giusta o una senza le due righe danno «non
  confermata in questa esecuzione». Anthropic dice che può succedere, e
  una prova in cui non succede non dice il contrario. Poi «confermata n su
  3».

Sono due raccomandazioni e un «può»: gli esiti si stampano e non fanno
fallire la verifica. In claude.ai la stessa prova la guardate a occhio.
`tools/verifica.sh M3-D01` fa girare lo stesso controllo, quello della
cartella dell'elemento, sulle risposte dello spazio di lavoro: decide
dalle risposte, non legge `esiti.tsv` e non scrive niente.

Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,
Haiku e Sonnet, tre coppie per modello): l'immagine grande è stata letta
giusta in tutte e sei le chiamate, «critici: 3» e i tre apparati;
quella piccola ha avuto sei volte su sei la risposta «non leggibile».
Per ciascuno dei due modelli: «Testo leggibile, immagine grande»
confermata 3 su 3; «Sotto i 200 pixel, Claude può sbagliare» confermata
0 su 3, perché un rifiuto non è un errore: la frase di Anthropic dice
che può sbagliare, e in questa registrazione Claude non ha sbagliato, ha
detto che non riusciva a leggere. Le dodici risposte sono nella cartella
`soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M3-D01)

La verifica fa girare `controlla_lettura.py` dell'elemento sulle risposte
di `risposte/`, senza scrivere niente (non legge `esiti.tsv`). È fatta
quando le dodici risposte ci sono e sono il JSON riuscito di `claude -p`.
Che cosa ha letto Claude e gli esiti delle tre affermazioni si stampano e
non fanno fallire la verifica. La parte in claude.ai non si verifica: la
raccontate a voce.

## Se qualcosa va storto

- In claude.ai l'immagine non si carica: le immagini PNG sono ammesse;
  provate a trascinarla nella finestra della chat invece di sceglierla
  dal menu.
- `controlla_lettura.py` dice che una risposta manca, o che non è il JSON
  di `claude -p`: rifate quella chiamata dallo spazio di lavoro, con il
  modello, la grandezza, l'immagine e il numero del suo nome, e il prompt
  (per `risposte/piccola-haiku-2.json`: `m=haiku`, `n=2`, `g=piccola`,
  `f=allarmi-piccola.png` e `p="$(cat prompt.txt)"`), poi le quattro righe
  del passo 3 da `(cd "$g" && claude -p` a `> "risposte/$g-$m-$n.json"`, e
  di nuovo `python3 controlla_lettura.py`. Se mancano le cartelle
  `grande/` e `piccola/`, rifate prima le prime tre righe del passo 3.
- Una risposta «senza le due righe»: è un esito, non un errore; il
  controllo la stampa così com'è.
- `controlla_lettura.py` dice che `verita.json` non va: il file è
  cambiato; `tools/reset_esercizio.sh M3-D01` riporta lo spazio di lavoro
  all'inizio (le risposte si perdono).
- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M3-D01`.

## Impronta d'uso sul piano Pro

In claude.ai, due messaggi brevi con un'immagine ciascuno. In Claude
Code, dodici chiamate brevi, sei su Haiku e sei su Sonnet, con effort
low, il solo strumento Read e nessun subagent; ogni chiamata manda
un'immagine. claude.ai e Claude Code consumano gli stessi limiti: se il
limite della sessione è vicino, guardate il risultato del docente invece
di rifare le dodici chiamate.

## Per approfondire

- Le immagini nella documentazione per sviluppatori: formati, dimensioni,
  consigli e limiti:
  https://platform.claude.com/docs/en/build-with-claude/vision
- Caricare file e immagini in claude.ai:
  https://support.claude.com/en/articles/8241126-upload-files-to-claude
- Le immagini in Claude Code (percorso, trascinamento, incolla):
  https://code.claude.com/docs/en/common-workflows
- Lo strumento Read e le immagini grandi:
  https://code.claude.com/docs/en/tools-reference
- I limiti d'uso, condivisi fra claude.ai e Claude Code:
  https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work
