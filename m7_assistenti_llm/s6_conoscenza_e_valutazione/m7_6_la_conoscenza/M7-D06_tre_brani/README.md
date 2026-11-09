# M7-D06 — Tre brani, una risposta con la fonte

Demo del Modulo 7, nella parte sulla conoscenza dell'assistente. Il docente la
fa girare in aula; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Mettere alla prova una tecnica che Anthropic indica contro le informazioni false:
«Allow Claude to say "I don't know": Explicitly give Claude permission to admit
uncertainty.» L'assistente di CiaspoLink, il fornitore di connettività inventato dei
progetti del corso (dati sintetici), risponde a due domande cercando in tre brani
delle procedure: una domanda che un brano copre, e una che nessun brano copre. Le
stesse domande vanno in due versioni del system prompt, che differiscono in una sola
frase, il permesso di dire «non lo so». Uno strumento di ricerca, lo stesso nelle
due versioni, restituisce i brani; lo structured output (l'uscita strutturata delle
righe del controllo) dice se la risposta è coperta e da quale procedura viene. Uno
script decide dai campi strutturati e dal registro del server che cosa è successo.

## Tempo

3 minuti in aula, la demo del docente: quattro chiamate brevi. Per rifarla da
soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- `uv`, per il server MCP del banco di prova: la prima volta prepara l'ambiente
  del server e serve la rete; le volte dopo no.
- Python 3 e git, che lo script verifica.

## Punto di partenza (tools/prepara_esercizio.sh M7-D06)

Lo spazio di lavoro `~/corso-claude-code/M7-D06/` con:

- `kb/`: tre brani delle procedure di CiaspoLink, `kb-90`, `kb-91` e `kb-92`, nel
  formato della base di conoscenza del corso; il primo risponde alla domanda
  coperta, nessuno dei tre risponde all'altra;
- `casi/`: le due domande, una per file;
- `con-permesso/` e `senza-permesso/`: le due versioni dell'assistente, ognuna con
  `system-prompt.md` e lo stesso `strumenti.json`, l'unico strumento di ricerca
  `cerca_kb`;
- `schema.json`: i campi dello structured output: `coperta` (se i brani
  contengono la risposta), `codice_procedura` (il codice del brano da cui viene
  la risposta, oppure null) e `risposta` (il testo per il cliente);
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_fonti.py`: il controllo, che legge le esecuzioni;
- `progetti/assistenza-clienti/banco/`: il banco di prova del modulo, con il suo
  server MCP.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M7-D06
       m7_assistenti_llm/s6_conoscenza_e_valutazione/m7_6_la_conoscenza/M7-D06_tre_brani/demo/in_classe.sh ~/corso-claude-code/M7-D06

   Lo script mostra ogni comando prima di eseguirlo. Per ogni variante (il “braccio”
   del controllo) lancia `prova.py casi`, il banco di prova: una chiamata di `claude
   -p` per domanda, su Sonnet con effort low, sessione nuova, nessuno strumento
   integrato, il solo server MCP del banco con la ricerca sui tre brani; le due
   domande di una variante girano insieme. Nessuna chiave API: il banco ripulisce
   l'ambiente, e Claude Code usa l'abbonamento.

2. Le due domande sono i testi sotto prova, e restano così come sono. La prima è
   coperta, la seconda no:

   <!-- prompt 1 -->

       Il mio router in comodato si è guastato: tra quanto arriva quello nuovo?

   <!-- /prompt 1 -->

   <!-- prompt 2 -->

       Se mi cade il router e si rompe, quanto devo pagare per averne uno nuovo?

   <!-- /prompt 2 -->

3. Le due versioni differiscono in una frase sola, che è in
   `con-permesso/system-prompt.md` e non in `senza-permesso/system-prompt.md`:

   Se non sei sicuro o se i brani non contengono le informazioni necessarie,
   scrivi al cliente che non lo sai.

   È una frase sul modello dell'esempio della guida di Anthropic. Il resto del
   system prompt è uguale nelle due varianti, parola per parola; il prompt del banco è
   nel template del corso, un tag per ingrediente.

4. In sala si guarda ciò che stampa `controlla_fonti.py`: per ogni esecuzione e
   domanda, le ricerche, i brani restituiti, i tre campi, il codice e i numeri
   fuori dai brani; poi il confronto.

La prova del docente è di tre esecuzioni per variante, dodici chiamate: il
`_docente/live.sh` dell'elemento, lo stesso script con `PN_ESECUZIONI=3`.

Perché il banco e `claude -p`, e non una sessione aperta a mano: ogni esecuzione
deve partire da una sessione nuova, con i soli strumenti del server, e ci
servono le righe del registro del server e lo structured output: uno script legge
quelle, non un testo a vista. Il banco è il `prova.py` del progetto, documentato
in `progetti/assistenza-clienti/banco/README.md`.

## Che cosa osservare

### Che cosa dice Anthropic

In «Reduce hallucinations»
(https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations):

- «Allow Claude to say "I don't know": Explicitly give Claude permission to admit
  uncertainty. This technique can drastically reduce false information.» È la
  frase che il confronto mette alla prova: la variante con la frase contro la
  variante senza;
- l'esempio della stessa pagina: «If you're unsure about any aspect or if the
  report lacks necessary information, say "I don't have enough information to
  confidently assess this."», a cui è ispirata la frase della variante con il
  permesso;
- sulle fonti: «Make Claude's response auditable by having it cite quotes and
  sources for each of its claims.» Qui il codice della procedura è un campo
  dello structured output, che lo script legge;
- sui limiti: «Remember, although these techniques significantly reduce
  hallucinations, they don't eliminate them entirely. Always validate critical
  information». «Can reduce» non è una garanzia: una tecnica che riduce può non
  cambiare niente su una domanda data, e niente esclude che un numero inventato
  esca lo stesso.

Per lo structured output: `--json-schema` «Get validated JSON output matching a
JSON Schema after the agent completes its workflow (print mode only).»
(https://code.claude.com/docs/en/cli-reference); e se manca il campo: «A result
can also end with subtype success but no structured_output value … Treat that
case as a failure as well.»
(https://code.claude.com/docs/en/agent-sdk/structured-outputs). Il system prompt
sta in un file: «--system-prompt-file | Replaces with file contents»
(https://code.claude.com/docs/en/cli-reference).

### Che cosa misura il controllo

`controlla_fonti.py` legge, per ogni esecuzione e domanda, `stream.jsonl` (lo
structured output; turni, secondi, token) e `registro.jsonl` (il registro del
server: quali brani ha restituito lo strumento), e stampa:

- le ricerche fatte e i brani restituiti;
- i tre campi dello structured output: `coperta`, `codice_procedura`, se il
  codice è fra i brani restituiti, e la risposta;
- i numeri della risposta che non stanno nei brani restituiti, fuori dai codici
  KB-NN: un dato, stampato così com'è. Un numero fuori dai brani non dice che la
  risposta è sbagliata, né un numero dentro dice che è giusta: per questo non
  decide niente;
- turni, secondi e token della chiamata.

Poi il confronto, che decide ciò che l'affermazione dice e niente di più. Sulla
domanda non coperta, in quante esecuzioni di ciascuna variante il campo `coperta`
è false, cioè la risposta dice che i brani non la contengono: con il permesso più
che senza, «confermata»; tante quante, «non distinguibile»; meno con il permesso
che senza, «non confermata in questa misura». Sulla domanda coperta il confronto
è il codice giusto, un dato per ciascuna variante. Nessun esito decide il codice
d'uscita del controllo: la prova è finita quando ogni esecuzione c'è ed è finita
bene.

### Nella registrazione del corso

Nella registrazione del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, tre esecuzioni per variante, `_docente/live.sh` sull'account del
docente), le sei esecuzioni per domanda dicono:

- la domanda coperta: il codice giusto, KB-90, in 3 su 3 con il permesso e in 3
  su 3 senza. La ricerca ha restituito KB-90 e KB-91, e la risposta è quella del
  brano: il nuovo router parte entro 2 giorni lavorativi, il vecchio si rispedisce
  entro 10 giorni, con la busta prepagata;
- la domanda non coperta: `coperta` false in 3 su 3 con il permesso e in 3 su 3
  senza. In tutte e sei le esecuzioni la risposta dice che le procedure non
  trattano il caso, per esempio «Non so dirle quanto costerebbe un nuovo router se
  si rompe per una caduta. So solo che la sostituzione è gratuita quando il router
  in comodato si guasta, ma non ho informazioni sui danni accidentali.» nella
  variante con il permesso, e «Non ho l'importo da pagare per un router rotto a causa di
  una caduta.» senza. Nessun numero fuori dai brani, in nessuna delle dodici
  chiamate;
- il confronto: «non distinguibile (3 contro 3: la stessa cosa con e senza il
  permesso)».

Su questa domanda, in tre esecuzioni per variante, la frase del permesso non ha
cambiato il campo. Anthropic scrive «can», non «will»: una tecnica che può ridurre
le informazioni false non promette un effetto su ogni domanda, e nella stessa
pagina dice che non le elimina del tutto. Qui si legge soltanto ciò che queste
esecuzioni dicono.

Gli `esito.json`, i registri e gli stream sono in `soluzione/risposte/` (nel
repository del corso; la copia senza soluzioni non li ha).

## Verifica (tools/verifica.sh M7-D06)

La verifica fa girare `controlla_fonti.py` dell'elemento, non la copia dello
spazio di lavoro, sulle esecuzioni di `risposte/`. È fatta quando ogni esecuzione
di ogni coppia c'è ed è finita bene, con il suo `stream.jsonl` e lo structured
output richiesto: le ultime due righe sono «Fatto: ogni esecuzione è stata
messa alla prova; gli esiti sono qui sopra.» e «VERIFICA OK M7-D06: fatto.» Gli
esiti del confronto si stampano e non la fanno fallire.

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- Il controllo dice che manca un'esecuzione, o che una domanda non è finita bene:
  una chiamata si è fermata a metà, per un limite di utilizzo o un errore di
  rete. Ricominciate da capo, come qui sotto.
- Lo script dice «non è al punto di partenza»: per ricominciare,
  `tools/reset_esercizio.sh M7-D06`.
- `in_classe.sh` dice che non trova `tools/lib_handson.sh`: lanciatelo dalla
  cartella `esercitazioni`, come al passo 1, oppure date `PN_HANDSON_ROOT`.
- `prova: il server non si prepara`: controllate `uv` e, la prima volta, la rete
  (`tools/verifica_ambiente.sh`).
- «non distinguibile» o «non confermata in questa misura»: sono esiti, non errori.
  L'affermazione dice «can»: in questa esecuzione, con queste domande, il permesso
  non ha cambiato il campo. Leggete le risposte che il controllo stampa.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent, solo il server MCP del banco. La prova in
aula, una per variante, fa quattro chiamate; la prova del docente ne fa dodici.
Rifarla da soli costa un'esecuzione per variante. Il modello predefinito di Claude
Code sul Pro è un altro: «Pro, Max, Ultra, Team, Enterprise, and Anthropic API:
defaults to Opus 5.5» (https://code.claude.com/docs/en/model-config). Il corso
fissa Sonnet perché la registrazione e le vostre prove girino sullo stesso
modello.

Nella registrazione del corso (9 novembre 2026, Claude Code 2.1.319, Sonnet con
effort low, `_docente/live.sh` sull'account del docente), dal `result` di ogni
stream, sommato su ogni segmento: ogni chiamata 3 turni, da 2,9 a 5,1 secondi, da
4.807 a 5.023 token; «Come dati,
tutte le 12 chiamate: turni 36; token 58.800; 44,1 s.». I token sono quelli di
`modelUsage`: «Use modelUsage, or model_usage in Python, for whole-tree token
accounting; the usage field undercounts as soon as nesting occurs.»
(https://code.claude.com/docs/en/agent-sdk/cost-tracking). Sono entrata, cache e
uscita di ogni chiamata, compreso il contesto letto dalla cache: dicono quanto
lavoro è stato, non un prezzo, e non quanta parte del vostro piano occupa. La
prima richiesta della variante con il permesso pesa circa 44 token in più (da 2.071 a
2.075 contro da 2.028 a 2.030): sono la frase del permesso.

Nessuna sessione resta salvata: ogni chiamata ha `--no-session-persistence`, che
in `claude --help` è «Disable session persistence - sessions will not be saved
to disk and cannot be resumed (only works with --print)».

## Per approfondire

- «Reduce hallucinations»:
  https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- Lo structured output con `claude -p`: https://code.claude.com/docs/en/headless
  e https://code.claude.com/docs/en/agent-sdk/structured-outputs
- Il banco di prova del modulo: `progetti/assistenza-clienti/banco/README.md`
- `--system-prompt-file` e `--tools`:
  https://code.claude.com/docs/en/cli-reference
