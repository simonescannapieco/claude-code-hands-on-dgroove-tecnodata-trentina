# M5-D01 — Lo stesso testo in tre posti

Demo del Modulo 5, nella parte «Quando una skill batte un system prompt lungo».
Il docente la fa girare in aula; potete rifarla da soli quando volete, con lo
stesso comando.

## Obiettivo

Misurare che cosa entra nel contesto e quando. Lo stesso testo, tre procedure
dell'assistenza clienti di CiaspoLink (187 righe, 10.859 caratteri), sta una
volta nel corpo di una skill, una volta in `CLAUDE.md`, una volta in
`--append-system-prompt-file`, una volta da nessuna parte. A tutti e quattro i
bracci si fa la stessa domanda, che del testo non ha bisogno, e si guarda quanti
token ha la prima richiesta. Poi, nel braccio della skill, la si invoca con
`/procedure-assistenza` e si guarda che cosa cambia in quella richiesta e al
turno dopo.

## Tempo

4 minuti in aula, la demo del docente: un'esecuzione, sei chiamate brevi. Per
rifarla da soli, un paio di minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M5-D01)

Lo spazio di lavoro `~/corso-claude-code/M5-D01/` con:

- `testo.md`: `kb-02`, `kb-03` e `kb-04` di `progetti/assistenza-clienti/kb/`,
  uno dopo l'altro, byte per byte;
- `domanda.txt`, `domanda_invocata.txt`, `domanda_dopo.txt`: le tre domande;
- `prepara_bracci.sh`: costruisce i quattro bracci;
- `in_classe.sh`: le chiamate, una dopo l'altra, con ogni comando a schermo;
- `controlla_costo.py`: il controllo, che legge gli stream.

## Passi in Claude Code

1. Il docente, dalla cartella `esercitazioni`, prepara lo spazio di lavoro e fa
   partire la demo:

       tools/prepara_esercizio.sh M5-D01
       m5_skills/s4_skills/m5_3_skill_o_system_prompt/M5-D01_stesso_testo_tre_posti/demo/in_classe.sh ~/corso-claude-code/M5-D01

   Lo script mostra ogni comando prima di eseguirlo. Prima costruisce i bracci
   in `bracci/`, ciascuno un repository git con un solo commit, con
   `bash prepara_bracci.sh bracci`:

   | braccio | dove sta il testo |
   |---|---|
   | `skill` | `.claude/skills/procedure-assistenza/SKILL.md`: `name`, `description`, e il testo come corpo |
   | `claude_md` | `CLAUDE.md` |
   | `append` | `testo.md`, che la chiamata passa con `--append-system-prompt-file testo.md` |
   | `niente` | da nessuna parte |

2. In ognuno dei quattro bracci, una sessione nuova di `claude -p` su Sonnet con
   effort low, senza strumenti consentiti e senza server MCP, con la stessa
   domanda. La domanda è un testo sotto prova, e resta così com'è:

   <!-- prompt 1 -->

       Rispondi solo: ok

   <!-- /prompt 1 -->

3. Nel braccio della skill, ancora una sessione nuova, che stavolta resta
   salvata: si invoca la skill, con una domanda che soltanto il testo sa.

   <!-- prompt 2 -->

       /procedure-assistenza Qual è la velocità massima in upload dell'offerta Casa Radio?

   <!-- /prompt 2 -->

   Poi, con `--resume` e l'ID di quella sessione, un'altra domanda breve:

   <!-- prompt 3 -->

       E in download?

   <!-- /prompt 3 -->

4. In sala si guarda la tabella che stampa `controlla_costo.py`, dalla copia
   degli stream in `risposte/`, e i verdetti sotto la tabella.

La prova del docente è di tre esecuzioni e diciotto chiamate: il `_docente/live.sh`
dell'elemento, che è lo stesso script con `PN_ESECUZIONI=3`.

Perché `claude -p` e non una sessione aperta a mano: conta la prima richiesta di
una sessione nuova, e lo stream la dice messaggio per messaggio. Gli stream
stanno in `~/corso-claude-code/M5-D01.prova_dal_vivo/`, fuori dallo spazio di
lavoro, finché le chiamate non sono finite.

## Che cosa osservare

### Che cosa dice Anthropic

- In «Best practices for Claude Code»: «A long release procedure sitting in a
  skill doesn't weigh on your unrelated bug fix the way it would in CLAUDE.md.»
  https://code.claude.com/docs/en/best-practices
- In «Steering Claude Code: when to use CLAUDE.md, skills, hooks, and
  subagents»: «Appending the system prompt can have a higher context cost
  compared to other methods of passing instructions.» E subito dopo: «It
  increases input tokens, though prompt caching reduces this cost after the
  first request in a session.»
  https://claude.com/resources/articles/steering-claude-code-skills-hooks-rules-subagents-and-more
- In «Extend Claude with skills», sul corpo: «Unlike CLAUDE.md content, a
  skill’s body loads only when it’s used, so long reference material costs
  almost nothing until you need it.» Nella tabella di chi invoca che cosa:
  «(default) | Yes | Yes | Description always in context, full skill loads when
  invoked». E dopo l'invocazione: «When you or Claude invoke a skill, the
  rendered SKILL.md content enters the conversation as a single message and
  stays there across later turns.» https://code.claude.com/docs/en/skills
- In «Extend Claude Code», la tabella di che cosa si carica e quando:
  «CLAUDE.md | Session start | Full content of each file that loads at session
  start | Every request» e «Skills | Session start + when used | Descriptions at
  start, full content when used | Low (descriptions every request)».
  https://code.claude.com/docs/en/features-overview
- In «Run Claude Code programmatically», su `/nome` in `claude -p`: «User-invoked
  skills and custom commands work. Include /skill-name in the prompt string and
  Claude Code expands it before running.»
  https://code.claude.com/docs/en/headless
- In «Prompt caching», come si conta l'input di una richiesta: «total_input_tokens
  = cache_read_input_tokens + cache_creation_input_tokens + input_tokens».
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Il testo sta dentro i limiti che lo standard Agent Skills dà per il corpo di una
skill, nella «Specification»: «Keep your main SKILL.md under 500 lines. Move
detailed reference material to separate files.» e «Instructions (< 5000 tokens
recommended): The full SKILL.md body is loaded when the skill is activated».
https://agentskills.io/specification `tools/controlla_skill.py` passa sulla skill
del braccio.

### Che cosa misura il controllo

`controlla_costo.py` legge gli stream, sei per esecuzione: `niente-<n>`,
`skill-<n>`, `claude_md-<n>`, `append-<n>`, `skill_invocata-<n>`, `skill_dopo-<n>`.
Di ognuno conta la prima richiesta: i tre campi di `usage` sommati del primo
messaggio dell'assistente della conversazione principale. Stampa:

- righe e caratteri di `testo.md`, e la tabella dei quattro bracci;
- i due confronti, esecuzione per esecuzione e poi «confermata n su N»: la skill
  contro `CLAUDE.md`, la skill contro l'append. Se la skill costa meno,
  «confermata»; se costa uguale, «non distinguibile»; se costa di più, «non
  confermata in questa esecuzione». Un confronto si stampa e non decide l'uscita;
- come dati, ogni braccio sopra il braccio `niente`, e l'append contro
  `CLAUDE.md`: nessuna delle due frasi li mette in ordine fra loro;
- come dati, la skill invocata meno quella non invocata, il turno dopo, le due
  risposte. Nello stream `/nome` non ha nessun `tool_use`: il corpo si vede dai
  token della richiesta.

Una chiamata a `Skill` nei bracci `claude_md`, `append` o `niente` è una
segnalazione, e fa uscire con 1: la domanda non ha bisogno di nessun testo. Lo
stesso se `procedure-assistenza` manca dall'elenco `skills` di `system/init` dove
deve esserci, o se c'è dove non deve: il braccio non è quello che dovrebbe, e il
confronto non varrebbe. Una chiamata a `Skill` sulla domanda nel braccio della
skill è un dato: la prima richiesta viene prima della chiamata.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, tre esecuzioni e diciotto chiamate, `_docente/live.sh` sull'account
del docente), la prima richiesta è la stessa in tutte e tre le esecuzioni: 17.271
token nel braccio `niente`, 17.395 in `skill`, 22.251 in `claude_md` e 22.113 in
`append`. Sopra il braccio `niente`, «skill +124, claude_md +4.980, append +4.842;
append meno claude_md -138». Skill contro `CLAUDE.md`, «confermata 3 su 3»; skill
contro append, «confermata 3 su 3». Come dati: «non invocata 17.395; invocata
22.388 (+4.993)» in tutte e tre, e il turno dopo 22.532 (+5.137), 22.540 (+5.145)
e 22.551 (+5.156). «Chiamate a Skill sulla domanda, nel braccio della skill: 0 su
3.» Gli stream sono nella cartella `soluzione/risposte/` di questo elemento.

## Verifica (tools/verifica.sh M5-D01)

La verifica fa girare `controlla_costo.py` dell'elemento sugli stream di
`risposte/` dello spazio di lavoro, quelli che lo script vi ha copiato. È fatta
quando ogni stream è lo stream-json riuscito di `claude -p` e non c'è nessuna
segnalazione. I confronti si stampano e non la fanno fallire. Quando tutto è in
ordine, le ultime due righe sono «Fatto: ogni affermazione è stata messa alla prova;
gli esiti sono qui sopra.» e «VERIFICA OK   M5-D01: fatto.»

## Se qualcosa va storto

- La verifica dice che manca `risposte/`: eseguite il passo 1 fino in fondo.
- La verifica esce con 2 e dice che manca uno stream o che uno stream non si
  legge: una chiamata si è fermata a metà. Ripartite da capo, come qui sotto.
- Lo script dice «c'è già una prova» o «non è al punto di partenza»: per
  ricominciare, `tools/reset_esercizio.sh M5-D01` e
  `rm -r ~/corso-claude-code/M5-D01.prova_dal_vivo`.
- Una riga `SEGNALAZIONE`: il controllo dice quale stream. Se è una chiamata a
  `Skill`, guardate che cosa ha chiamato; se è l'elenco `skills`, il braccio non è
  stato costruito da `prepara_bracci.sh`, o Claude Code non ha caricato la skill.
- «non confermata in questa esecuzione» è un esito, non un errore: quel confronto,
  in quell'esecuzione, è andato così, e la verifica lo stampa.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Sonnet con effort low, nessun subagent, nessuno strumento consentito.
Un'esecuzione sono sei chiamate di `claude -p`, una domanda breve ciascuna; la
prova del docente ne fa tre, diciotto chiamate. Rifarla da soli costa
un'esecuzione.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, un piano Max), dal
`result` di ogni stream: un turno del modello a chiamata; da 1,3 a 18,3 secondi a
chiamata, 61,8 in tutto; 17.275 token nel braccio `niente`, 17.399 in `skill`,
22.255 in `claude_md`, 22.117 in `append`, da 22.525 a 22.544 con la skill
invocata e da 22.629 a 22.652 il turno dopo, 372.657 in tutto. Sono i token di
`usage`, entrata, cache e uscita di ogni chiamata, compreso il contesto letto dalla
cache: dicono quanto lavoro è stato, non un prezzo, e non quanta parte del vostro
piano occupa. Del turno dopo conta `usage` perché, in una sessione ripresa con
`--resume`, `modelUsage` conta anche la chiamata di prima: 45.154, 45.169 e 45.196.

La chiamata con `/procedure-assistenza` e quella dopo restano salvate, per poterla
riprendere con `--resume`. Tutte le altre hanno `--no-session-persistence`: in
`claude --help`, «Disable session persistence - sessions will not be saved to disk
and cannot be resumed (only works with --print)».

## Per approfondire

- «Extend Claude with skills», le skill in Claude Code:
  https://code.claude.com/docs/en/skills
- «Extend Claude Code», che cosa si carica e quando:
  https://code.claude.com/docs/en/features-overview
- «Best practices for Claude Code»:
  https://code.claude.com/docs/en/best-practices
- «Steering Claude Code: when to use CLAUDE.md, skills, hooks, and subagents»:
  https://claude.com/resources/articles/steering-claude-code-skills-hooks-rules-subagents-and-more
- «Run Claude Code programmatically», `claude -p` e lo stream-json:
  https://code.claude.com/docs/en/headless
- «Prompt caching», i campi di `usage`:
  https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- «Specification», lo standard Agent Skills:
  https://agentskills.io/specification
