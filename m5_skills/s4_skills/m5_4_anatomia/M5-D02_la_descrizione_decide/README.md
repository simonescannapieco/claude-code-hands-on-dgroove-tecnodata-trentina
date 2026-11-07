# M5-D02 — La descrizione decide

Demo del Modulo 5, nella parte «Anatomia di uno SKILL.md». Il docente la fa girare
in aula; potete rifarla da soli quando volete, con lo stesso comando.

## Obiettivo

Mettere alla prova che cosa fa scattare una skill. Lo stesso corpo, lo stesso nome
neutro, `prova-d02`, la stessa richiesta: cambia soltanto la `description`. Poi la
description specifica con una richiesta vicina che chiede altro, una near-miss; poi
la stessa con `disable-model-invocation: true`, che Claude non può usare da solo e
voi potete invocare con `/prova-d02`.

## Tempo

3 minuti in aula, la demo del docente: un'esecuzione, cinque chiamate. Per rifarla
da soli, qualche minuto.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto verde
  (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M5-D02)

Lo spazio di lavoro `~/corso-claude-code/M5-D02/` con:

- `configurazione.txt`: due righe di configurazione di un apparato, sintetiche;
- `richiesta.txt`, `richiesta_near_miss.txt`: le due richieste;
- `descrizione_vaga.txt`, `descrizione_specifica.txt`, `corpo.md`: le due
  description e il corpo della skill, uguale in ogni braccio;
- `prepara_braccio.sh`: costruisce la cartella di un'esecuzione;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_descrizione.py`: il controllo, che legge gli stream.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M5-D02
       m5_skills/s4_skills/m5_4_anatomia/M5-D02_la_descrizione_decide/demo/in_classe.sh ~/corso-claude-code/M5-D02

   Lo script mostra ogni comando prima di eseguirlo. Ogni chiamata ha una cartella
   nuova, `prove/<lettera>-<n>`, fatta da `bash prepara_braccio.sh`: un repository
   git con `configurazione.txt` e `.claude/skills/prova-d02/SKILL.md`, in una
   sessione nuova di `claude -p` su Sonnet con effort low, con i soli strumenti Read
   e Skill (`--tools Read,Skill`), Read consentito e senza server MCP. I bracci
   differiscono soltanto nella parte che cambia:

   | braccio | cartella | `description` | richiesta |
   |---|---|---|---|
   | `vaga` | `a` | vaga | la richiesta |
   | `specifica` | `b` | specifica | la richiesta |
   | `near_miss` | `c` | specifica | la near-miss |
   | `manuale` | `d` | specifica, con `disable-model-invocation: true` | la richiesta |
   | `manuale_nome` | `e` | come `manuale` | `/prova-d02` e la richiesta |

   La description vaga, sul modello di ciò che Anthropic dice di evitare:

       description: Aiuta con i file

   Quella specifica, in terza persona, che dice che cosa fa e quando usarla:

       description: Controlla la configurazione di un apparato di rete contro la checklist di audit del team. Da usare quando si chiede di controllare o rivedere la configurazione di un apparato.

   Il corpo, con un marcatore che il controllo può vedere nella risposta:

       Audit della configurazione: per ogni riga con `snmp-server community` scrivi «AUD-01 riga N». Se non ne trovi, scrivi «nessun problema».

2. La richiesta, che resta com'è, come la direbbe chiunque:

   <!-- prompt 1 -->

       Controlla la configurazione di sw-prova-01 (configurazione.txt): ci sono problemi?

   <!-- /prompt 1 -->

   La near-miss, che condivide la configurazione ma chiede altro:

   <!-- prompt 2 -->

       Quante righe ha il file configurazione.txt?

   <!-- /prompt 2 -->

   La richiesta con il nome della skill, nel braccio con il flag:

   <!-- prompt 3 -->

       /prova-d02 Controlla la configurazione di sw-prova-01 (configurazione.txt): ci sono problemi?

   <!-- /prompt 3 -->

3. In sala si guardano i conteggi che stampa `controlla_descrizione.py`, dalla copia
   degli stream in `risposte/`, e i verdetti.

4. Il controllo dei file, dalla cartella `esercitazioni`, sulle due cartelle della
   prima esecuzione:

       python3 -B -I tools/controlla_skill.py ~/corso-claude-code/M5-D02/prove/a-1/.claude/skills/prova-d02
       python3 -B -I tools/controlla_skill.py ~/corso-claude-code/M5-D02/prove/b-1/.claude/skills/prova-d02

   Sulla specifica passa senza avvisi sulla description. Sulla vaga passa anche, con
   la riga `AVVISO description: non dice quando usarla`: è il punto della demo, e
   un controllo dei file lo vede senza far girare nessuna prova. Tutte e due le volte
   `AVVISO evals` ricorda che qui, per una demo, i casi di prova non ci sono.

La prova del docente è di tre esecuzioni e quindici chiamate: il `_docente/live.sh`
dell'elemento, che è lo stesso script con `PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: ogni prova deve partire da una
sessione nuova, e lo stream dice se e come la skill è stata chiamata. Gli stream
stanno in `~/corso-claude-code/M5-D02.prova_dal_vivo/`, fuori dallo spazio di
lavoro, finché le chiamate non sono finite.

## Che cosa osservare

### Che cosa dice Anthropic

- In «How to create Skills for Claude: steps and examples»: «Claude evaluates skill
  descriptions against your request to determine relevance. This isn't keyword
  matching—Claude understands semantic relationships. However, vague descriptions
  reduce triggering accuracy.» E perché il nome qui è neutro: «the name and
  description are the only parts of the SKILL.md file that influence triggering».
  https://claude.com/resources/articles/how-to-create-skills-key-steps-limitations-and-examples
- In «Skill authoring best practices», gli esempi da evitare: «Avoid vague
  descriptions such as these», fra cui «description: Does stuff with files».
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- In «Extend Claude with skills», se la skill non scatta: «Check the description
  includes keywords users would naturally say». Se scatta troppo: «Make the
  description more specific» e «Add disable-model-invocation: true if you only want
  manual invocation». Il flag: «disable-model-invocation: true: Claude can't invoke
  the skill on its own. Use this for workflows with side effects or that you want to
  control timing». Nella tabella di chi invoca che cosa: «disable-model-invocation:
  true | Yes | Not on its own | Description not in context, full skill loads when
  invoked». https://code.claude.com/docs/en/skills
- In «Extend Claude Code»: «Set disable-model-invocation: true in a skill's
  frontmatter to keep its description out of Claude's context.»
  https://code.claude.com/docs/en/features-overview
- In «Run Claude Code programmatically», su `/nome` in `claude -p`: «User-invoked
  skills and custom commands work. Include /skill-name in the prompt string and
  Claude Code expands it before running.»
  https://code.claude.com/docs/en/headless
- In «Optimizing skill descriptions», dello standard Agent Skills: «The most
  valuable negative test cases are near-misses — queries that share keywords or
  concepts with your skill but actually need something different.»
  https://agentskills.io/skill-creation/optimizing-descriptions

### Che cosa misura il controllo

Una chiamata, nello stream di una skill che Claude invoca da sé: un `tool_use` di
nome `Skill` con `input.skill`, il suo risultato che dice `Launching skill`, poi un
messaggio utente che comincia con `Base directory for this skill:` e porta il
corpo. Con `/nome` in testa al prompt il `tool_use` non c'è, e il corpo entra subito.

`controlla_descrizione.py` legge gli stream, cinque per esecuzione. Stampa:

- `Skill` sì o no, esecuzione per esecuzione, e per ogni braccio `Skill` e il
  marcatore `AUD-01` nella risposta, «n su N»: il marcatore è un dato;
- il confronto, sui conteggi: la specifica scatta più volte della vaga,
  «confermata»; tante volte, «non distinguibile»; meno volte, «non confermata in
  questa esecuzione». Si stampa e non decide l'uscita;
- la near-miss, un dato, «n su N»: una near-miss non dovrebbe far scattare la skill;
- la garanzia del flag, su ogni esecuzione: con `disable-model-invocation: true`,
  una chiamata a `prova-d02` che non sia stata rifiutata è una segnalazione, e fa
  uscire con 1. Una chiamata tentata e rifiutata non invoca niente, e una a un'altra
  skill non riguarda questa: si stampano come dati;
- `/prova-d02` con il flag, su ogni esecuzione: il marcatore nella risposta o il
  corpo nello stream; se non c'è né l'uno né l'altro è una segnalazione;
- la prima richiesta in token di ogni braccio, un dato: con il flag la description
  resta fuori dal contesto.

Se `prova-d02` manca dall'elenco `skills` di `system/init` è una segnalazione: senza
la skill, un «no» non vorrebbe dire niente.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, tre esecuzioni e quindici chiamate, `--tools Read,Skill`,
`_docente/live.sh` sull'account del docente): «vaga: Skill 0 su 3, marcatore 0 su
3», «specifica: Skill 3 su 3, marcatore 3 su 3», «near-miss: Skill 0 su 3,
marcatore 0 su 3», «con il flag: Skill 0 su 3, marcatore 0 su 3». «Specifica contro
vaga, «vague descriptions reduce triggering accuracy»: confermata (3 su 3 contro 0
su 3)». «Con il flag, «Claude can't invoke the skill on its own»: confermata 3 su
3». «/prova-d02 con il flag, «Include /skill-name in the prompt string»: confermata
3 su 3», con «marcatore 3 su 3, corpo nello stream 0 su 3». «Near-miss, come dato:
Skill 0 su 3». Come dati, la prima richiesta della prima esecuzione, in token: «vaga
7.141, specifica 7.192, near-miss 7.174, con il flag 7.128». Sono i conteggi di
queste tre esecuzioni, con questo nome e questa richiesta, non una regola. Gli
stream sono nella cartella `soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M5-D02)

La verifica fa girare `controlla_descrizione.py` dell'elemento sugli stream di
`risposte/` dello spazio di lavoro, quelli che lo script vi ha copiato. È fatta
quando ogni stream è lo stream-json riuscito di `claude -p` e non c'è nessuna
segnalazione. Il confronto e la near-miss si stampano e non la fanno fallire. Quando
tutto è in ordine, le ultime due righe sono «Fatto: ogni affermazione è stata messa
alla prova; gli esiti sono qui sopra.» e «VERIFICA OK   M5-D02: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica esce con 2 e dice che manca uno stream o che uno stream non si legge:
  una chiamata si è fermata a metà. Ripartite da capo, come qui sotto.
- Lo script dice «c'è già una prova» o «non è al punto di partenza»: per
  ricominciare, `tools/reset_esercizio.sh M5-D02` e
  `rm -r ~/corso-claude-code/M5-D02.prova_dal_vivo`.
- Una riga `SEGNALAZIONE`: il controllo dice quale stream e perché. Con il flag è un
  esito da segnalare: Claude non dovrebbe poter invocare quella skill da solo.
- «non confermata in questa esecuzione» o «non distinguibile» sono esiti, non errori:
  la near-miss e il confronto si stampano così come sono andati.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent, i soli strumenti Read e Skill, Read
consentito. `--tools Read,Skill` lascia alla sessione soltanto quei due, fra gli
strumenti integrati: in `claude --help`, «Specify the list of available tools from
the built-in set.». Senza Bash nessuna sessione può stampare il proprietario di un
file, e uno stream registrato non deve portare il nome dell'utente della macchina.
Un'esecuzione sono cinque chiamate di `claude -p`, con due righe da leggere; la
prova del docente ne fa tre, quindici chiamate. Rifarla da soli costa un'esecuzione.
Nessuna sessione resta salvata: tutte hanno `--no-session-persistence`.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, un piano Max), dal `result`
di ogni stream: nel braccio `specifica` 4 turni del modello e da 22.214 a 22.217
token a chiamata; negli altri 2 turni e da 14.604 a 15.087 token; da 3,2 a 16,2
secondi a chiamata. In tutto 36 turni, 245.268 token e 120,5 secondi. I token sono
entrata, cache e uscita di ogni chiamata, compreso il contesto letto dalla cache:
dicono quanto lavoro è stato, non un prezzo, e non quanta parte del vostro piano
occupa.

## Per approfondire

- «Extend Claude with skills», la `description` e chi invoca che cosa:
  https://code.claude.com/docs/en/skills
- «Skill authoring best practices»:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- «How to create Skills for Claude: steps and examples»:
  https://claude.com/resources/articles/how-to-create-skills-key-steps-limitations-and-examples
- «Extend Claude Code», che cosa si carica e quando:
  https://code.claude.com/docs/en/features-overview
- «Run Claude Code programmatically», `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- «Optimizing skill descriptions», lo standard Agent Skills:
  https://agentskills.io/skill-creation/optimizing-descriptions
