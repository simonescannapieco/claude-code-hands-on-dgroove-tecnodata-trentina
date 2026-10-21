# M2-D05 — Ragionare, oggi

Demo del Modulo 2, nella parte «Ragionare, sui modelli di oggi». In aula
la esegue il docente; potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova, sullo stesso problema, quattro affermazioni di
Anthropic sul ragionamento dei modelli 5.5: i token di ragionamento stanno
dentro quelli in uscita; dire a Haiku di rispondere direttamente non gli
impedisce di ragionare; in Claude Code `MAX_THINKING_TOKENS=0` non spegne
il thinking di questi modelli; un effort più alto porta più ragionamento.
Le chiamate confrontate differiscono in una cosa sola: R2 da R1 per
`MAX_THINKING_TOKENS=0`, la chiamata a `high` da quella a `low` dello
stesso modello per l'effort. Il controllo legge i token dal JSON di ogni
risposta e dice, per ogni affermazione, se questa esecuzione la conferma.

## Tempo

3 minuti in aula; circa 10 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D05)

Lo spazio di lavoro `~/corso-claude-code/M2-D05/` con:

- `sportelli.md`: «In un ufficio ci sono 3 sportelli. Ogni sportello serve
  una persona ogni 4 minuti. Alle 9:00 ci sono 27 persone in fila. A che ora
  esce l'ultima persona?»;
- `direttamente.txt`: «Rispondi direttamente, senza ragionare: scrivi solo
  l'orario.», che va in coda al problema;
- `istruzione.txt`: «Rispondi in italiano.», il system prompt di ogni
  chiamata;
- `leggi_json.py`: legge il JSON di una risposta e ne stampa un dato;
- `orario.py`: legge il JSON di una risposta e ne stampa l'orario finale;
- `controlla_ragionamento.py`: il controllo che `tools/verifica.sh M2-D05`
  esegue su `ragionamento.tsv`.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D05
       cd ~/corso-claude-code/M2-D05

2. Togliete dall'ambiente due variabili che cambierebbero le chiamate alle
   spalle delle loro opzioni. `CLAUDE_CODE_EFFORT_LEVEL` vale più di
   `--effort` («Ha la precedenza su `--effort`, `/effort` e sulle
   impostazioni `modelSettings` ed `effortLevel`»,
   https://code.claude.com/docs/it/env-vars#variables), mentre la colonna
   `effort` della tabella scrive quello chiesto con `--effort`;
   `MAX_THINKING_TOKENS` deve arrivare a una chiamata sola, R2:

       unset CLAUDE_CODE_EFFORT_LEVEL MAX_THINKING_TOKENS

3. Le sette chiamate, con il modello che ha risposto, l'orario, i token in
   uscita e quelli di ragionamento in `ragionamento.tsv`:

       chiedi() {
         r="$(claude -p "$(cat sportelli.md)"$'\n'"$(cat direttamente.txt)" \
           --model "$1" --effort "$2" --tools "" \
           --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
           --setting-sources project,local --output-format json \
           --no-session-persistence)"
         printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" \
           "$(env | grep '^MAX_THINKING_TOKENS=' || echo no)" \
           "$(python3 leggi_json.py modello <<< "$r")" \
           "$(python3 orario.py 9:00 <<< "$r")" \
           "$(python3 leggi_json.py token_uscita <<< "$r")" \
           "$(python3 leggi_json.py token_thinking <<< "$r")" \
           | tee -a ragionamento.tsv
       }
       printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' modello effort thinking_off \
         modello_id orario token_uscita token_thinking > ragionamento.tsv
       chiedi haiku low                         # R1
       MAX_THINKING_TOKENS=0 chiedi haiku low   # R2
       chiedi haiku high                        # R3
       chiedi sonnet low                        # R4
       chiedi sonnet high                       # R5
       chiedi opus low                          # R6
       chiedi opus high                         # R7

   R2 è R1 con `MAX_THINKING_TOKENS=0`: scritta davanti al comando, la
   variabile vale per quella sola chiamata. La terza colonna,
   `thinking_off`, dice se la chiamata l'aveva nel suo ambiente: `no`,
   oppure `MAX_THINKING_TOKENS=0`. `--setting-sources project,local` lascia
   fuori le vostre impostazioni utente (`~/.claude/settings.json`);
   `orario.py 9:00` esclude l'orario di partenza del problema. L'orario è
   un dato: nessuna affermazione lo riguarda, e il controllo lo stampa
   senza giudicarlo. Le etichette R1…R7, nei commenti, sono quelle che usa
   il controllo.

4. Il controllo, dalla cartella `esercitazioni`: `tools/verifica.sh M2-D05`
   (sezione «Verifica»).

## Che cosa osservare

### Che cosa dice Anthropic

- I token di ragionamento si contano dentro quelli in uscita, ed è una
  garanzia (V1): «Per vedere quanti token di output fatturati sono stati
  spesi per il ragionamento interno, leggi
  `usage.output_tokens_details.thinking_tokens` nella risposta. Questo
  valore riflette il ragionamento grezzo generato dal modello (non il testo
  riassunto restituito nel corpo) ed è sempre minore o uguale a
  `output_tokens`. Sottrailo da `output_tokens` per approssimare la
  porzione dell'output non dedicata al ragionamento.»
  (Orientare il ragionamento, «Prezzi»:
  https://platform.claude.com/docs/it/build-with-claude/thinking-steering-and-cost)
- Dire a Haiku di rispondere direttamente (V2): «Per ottenere meno
  ragionamento, abbassa il livello di effort. Nei test di Anthropic, dire
  al modello nel prompt di rispondere direttamente non gli ha impedito di
  ragionare.»
  (Prompting per Claude Haiku 5.5:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5#use-effort-to-control-thinking)
- In Claude Code il thinking dei modelli 5.5 non si spegne (V3): «Non puoi
  disattivare il ragionamento su Opus 5.5, Sonnet 5.5, Haiku 5.5 o sui
  modelli Fable.»
  (Configurazione del modello:
  https://code.claude.com/docs/it/model-config#extended-thinking); e di
  `MAX_THINKING_TOKENS`: «Imposta a `0` per disabilitare il ragionamento
  sull'API Anthropic, tranne su Opus 5.5, Sonnet 5.5, Haiku 5.5 e i modelli
  Fable, per i quali il ragionamento non può essere disattivato.»
  (Variabili d'ambiente:
  https://code.claude.com/docs/it/env-vars#variables). Il controllo non la
  tratta come una garanzia che fa fallire la verifica: con R2 che ragiona
  la dice «confermata»; con uno 0 la lascia «non dimostrata in questa
  esecuzione», perché uno 0 può voler dire che Claude ha deciso di non
  ragionare (il punto che segue).
- Ragionare resta però una scelta del modello, richiesta per richiesta:
  «Il ragionamento è facoltativo per il modello. A ogni richiesta, Claude
  valuta la complessità dell'input e determina se un ragionamento più
  approfondito migliorerebbe la risposta.» e «Nessun livello garantisce un
  blocco di ragionamento a ogni richiesta.» (Orientare il ragionamento,
  «Come Claude determina quando ragionare» e «Livelli di effort»). E nel
  JSON uno 0 ha due significati: «Nel messaggio di risultato,
  `thinking_tokens` vale `0` quando il modello o il provider non riporta
  alcuna suddivisione.»
  (Riferimento Agent SDK - TypeScript, «Usage»:
  https://code.claude.com/docs/it/agent-sdk/typescript#usage)
- Più effort, più ragionamento (V4): «Un effort più elevato induce più
  ragionamento, e lo stesso vale per le richieste più complesse.»
  (Best practice per il prompting:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices#leverage-thinking-and-interleaved-thinking-capabilities).
  Con `low`: «Claude riduce al minimo il ragionamento. Salta il
  ragionamento per le attività semplici in cui la velocità conta di più.»
  (Orientare il ragionamento:
  https://platform.claude.com/docs/it/build-with-claude/thinking-steering-and-cost#effort-levels).
  Su Sonnet 5.5: «Con `low`, salta il ragionamento nella maggior parte
  delle richieste semplici.»
  (https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5#calibrate-effort);
  su Opus 5.5: «Con `low` il modello mantiene breve il suo ragionamento. La
  frequenza con cui salta del tutto il ragionamento dipende dai tuoi
  prompt»
  (https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/prompting-claude-opus-5-5#prompts-written-for-thinking-disabled).
  È un orientamento, non una garanzia: «`effort` è un'indicazione non
  vincolante su quanta parte di quell'output Claude alloca al
  ragionamento. Modella il comportamento ma non garantisce un conteggio di
  token.» (Orientare il ragionamento, «Controllo dei costi»)

### Che cosa misura il controllo

`tools/verifica.sh M2-D05` passa `ragionamento.tsv` a
`controlla_ragionamento.py`. Prima stampa i numeri, chiamata per chiamata:
l'orario, i token in uscita, quelli di ragionamento e la loro differenza.
Poi una riga per affermazione:

- V1, la garanzia: in ogni chiamata `token_thinking` sta fra 0 e
  `token_uscita`. Se una chiamata la viola, il controllo scrive «la
  documentazione garantisce …: in questa esecuzione no» ed esce con 1.
- V2: R1 ha più di 0 token di ragionamento: «confermata»; con 0, «non
  confermata in questa esecuzione».
- V3: R2 ha più di 0 token di ragionamento: «confermata». Con 0 scrive «non
  dimostrata in questa esecuzione»: Claude può aver deciso di non
  ragionare, quindi uno 0 non dice che il thinking si è spento.
- V4, modello per modello: più token di ragionamento a `high` che a `low`
  (R3 contro R1, R5 contro R4, R7 contro R6): «confermata»; altrimenti
  «non confermata in questa esecuzione»; 0 a tutti e due i livelli: «non
  distinguibile», perché uno 0 compare anche quando la suddivisione non è
  riportata. Accanto stampa i token in uscita, come dato: nessun verdetto
  li usa.

V2, V3 e V4 dipendono da scelte del modello: il loro esito si legge, ma
non fa mai fallire il controllo. Con una sola esecuzione per chiamata, come
la vostra, una di loro può non confermarsi.

Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.305), con
ogni chiamata eseguita tre volte: V1 confermata in 21 chiamate su 21; V2
confermata 3 volte su 3; V3 3 su 3; V4 su Haiku 2 su 3, su Sonnet 3 su 3,
su Opus 3 su 3 (l'altra, su Haiku, «non confermata»: 160 token di
ragionamento a low e 116 a high; nessuna «non distinguibile»).

## Verifica (tools/verifica.sh M2-D05)

In `ragionamento.tsv` ci sono le sette chiamate, ognuna con il modello che
ha risposto (quello della riga: `claude-haiku-5-5`, `claude-sonnet-5-5`,
`claude-opus-5-5`) e i suoi token, e in ognuna i token di ragionamento non
superano quelli in uscita (V1). Allora l'ultima riga è «Fatto: ogni
affermazione è stata messa alla prova; gli esiti sono qui sopra.»,
qualunque sia l'esito di V2, V3 e V4. Se in una riga ha risposto un altro
modello, la verifica si ferma (uscita 2): le affermazioni riguardano i
modelli 5.5.

## Se qualcosa va storto

- La verifica dice che manca una riga, o che un campo non è un numero: una
  chiamata non ha dato una risposta. Rifate solo quella, nello stesso
  terminale (la funzione `chiedi` c'è ancora): per esempio
  `chiedi sonnet high`, oppure `MAX_THINKING_TOKENS=0 chiedi haiku low` per
  R2. Di ogni chiamata conta l'ultima riga.
- Una riga «ignorata» con `MAX_THINKING_TOKENS` nella terza colonna: la
  variabile era nel vostro ambiente. Rifate il passo 2 e poi il passo 3.
- La verifica si ferma perché ha risposto un altro modello: nella vostra
  versione di Claude Code l'alias (`haiku`, `sonnet`, `opus`) indica un
  modello diverso da quelli 5.5, di cui parlano le affermazioni.
- `orario.py` dice che non c'è un orario: l'orario è un dato, e la verifica
  non lo giudica. Per leggere la risposta, rilanciate la chiamata senza
  `--output-format json`; per esempio R1:

      claude -p "$(cat sportelli.md)"$'\n'"$(cat direttamente.txt)" \
        --model haiku --effort low --tools "" \
        --system-prompt "$(cat istruzione.txt)" --strict-mcp-config \
        --setting-sources project,local --no-session-persistence

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D05`.

## Impronta d'uso sul piano Pro

Sette chiamate brevi, senza strumenti né subagent: tre a Haiku, due a
Sonnet, due a Opus; quattro con effort `low` e tre con `high`. Un effort
più basso è più rapido ed economico, e Opus consuma più quota degli altri
modelli. Nella registrazione del corso la chiamata con più token in uscita
ne ha usati 168: Haiku con effort high (R3).

## Per approfondire

- Orientare il ragionamento: quando Claude ragiona, i livelli di effort, i
  prezzi:
  https://platform.claude.com/docs/it/build-with-claude/thinking-steering-and-cost
- Prompting per Claude Haiku 5.5, l'effort e il ragionamento:
  https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5#use-effort-to-control-thinking
- Effort e ragionamento in Claude Code:
  https://code.claude.com/docs/it/model-config
- Le variabili d'ambiente di Claude Code (`CLAUDE_CODE_EFFORT_LEVEL`,
  `MAX_THINKING_TOKENS`):
  https://code.claude.com/docs/it/env-vars
