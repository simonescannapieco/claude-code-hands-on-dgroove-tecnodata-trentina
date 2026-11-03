# M5-E01 — La prima skill

Esercitazione del Modulo 5, dopo la parte sull'anatomia di una skill: si scrive
una skill vera, la si guarda partire nei due modi, e la si prova in una sessione
nuova. Dentro c'è ciò che serve per tutte le altre.

## Obiettivo

Una skill di progetto, `riassunto-modifiche`, che riassume le modifiche non
ancora committate e segnala ciò che è rischioso, su `progetti/urgenze`: la regola
con cui l'assistenza di CiaspoLink decide se un guasto è urgente. La fate scrivere
a Claude Code con una richiesta, o la scrivete voi dal modello. Poi la invocate
con `/riassunto-modifiche`, e guardate se Claude la sceglie da solo su una domanda
come la farebbe chiunque, in una sessione che non l'ha vista nascere.

## Tempo

12 minuti.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M5-E01)

Lo spazio di lavoro `~/corso-claude-code/M5-E01/`, un repository git con un primo
commit, con:

- `progetti/urgenze/`: `urgenza.py`, poche righe, e i suoi test;
- `prepara_modifica.sh`: fa la piccola modifica su cui lavora la skill, in
  `progetti/urgenze/urgenza.py`, senza committarla;
- `controlla_skill.py` e `lib_leggi_frontmatter.py`: il controllo del file, lo
  stesso di `tools/controlla_skill.py`: dice che cosa non va in una skill secondo
  le regole che si leggono dai file;
- `prova.sh`: la prova in una sessione nuova;
- `.gitignore`: tiene fuori da git la cartella `prova/`, dove restano gli stream;
- `.claude/skills/`: la cartella delle skill di progetto, vuota, con un `.gitkeep`
  perché git la conservi. C'è già quando aprite Claude Code: così la sessione vede
  la skill appena la scrivete;
- `.claude/settings.json`: le impostazioni prudenti del repository.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro, entrateci e
   fate la modifica. `git status --short` deve mostrare `urgenza.py`:

       tools/prepara_esercizio.sh M5-E01
       cd ~/corso-claude-code/M5-E01
       bash prepara_modifica.sh
       git status --short

2. Aprite Claude Code, su Sonnet con effort low:

       claude --model sonnet --effort low

   Alla prima apertura vi chiede se vi fidate della cartella: «In an interactive
   session, Claude Code shows the workspace trust dialog when you start it in a
   folder you haven't trusted.» (https://code.claude.com/docs/en/security).
   Rispondete sì: in Claude Code 2.1.317 il cursore parte da «No, exit», quindi
   scendete con la freccia su «Yes, I trust this folder» e date Invio.

3. Scrivete la skill. Incollate:

   <!-- prompt 1 -->

       <instructions>
       Scrivi la skill di progetto in
       .claude/skills/riassunto-modifiche/SKILL.md: riassume le modifiche
       non committate e segnala i rischi. Poi esegui da solo questo comando:
       python3 -B -I controlla_skill.py .claude/skills/riassunto-modifiche
       </instructions>

       <format>
       Description in terza persona, con «Da usare quando …». Nel corpo
       !`git status --short` e !`git diff HEAD`, passi numerati, un modello
       della risposta, un esempio.
       </format>

   <!-- /prompt 1 -->

   `.claude/` è una cartella protetta: Claude Code vi chiede di approvare la
   scrittura, e può offrirvi «Yes, and allow Claude to edit files in this
   project's .claude folder for this session»
   (https://code.claude.com/docs/en/permission-modes). Leggete il file prima di
   approvarlo: è la prima skill che vedete nascere. Poi vi chiede di approvare il
   comando del controllo, quello del prompt, con «This command requires approval»:
   rispondete «Yes».

   Oppure scrivetela voi. Dalla cartella `esercitazioni`, in un altro terminale,
   copiate il modello:

       mkdir -p ~/corso-claude-code/M5-E01/.claude/skills/riassunto-modifiche
       cp riferimenti/template-SKILL.md ~/corso-claude-code/M5-E01/.claude/skills/riassunto-modifiche/SKILL.md

   Poi riempitelo, con `name: riassunto-modifiche`, e dallo spazio di lavoro
   controllatelo con
   `python3 -B -I controlla_skill.py .claude/skills/riassunto-modifiche`.

4. Provatela, nella stessa sessione, un comando alla volta:

       /skills
       /riassunto-modifiche
       /skill-doctor

   `/skills` la elenca, in un pannello che si chiude con Esc. `/riassunto-modifiche`
   la invoca. `/skill-doctor` dice quanto costa ogni skill e quanto viene usata: in
   Claude Code 2.1.317 apre il pannello dei plugin sulla scheda Stats, «/skill-doctor
   moved — skill usage and context costs now live in this Stats tab.», e anche quel
   pannello si chiude con Esc. Poi uscite con `/exit`.

5. Nel terminale, nello spazio di lavoro, il controllo di Claude Code:

       claude plugin validate .claude/skills

6. La prova in una sessione nuova. Chiede «Che cosa ho cambiato?» e mostra il
   comando prima di eseguirlo:

       bash prova.sh

7. Dalla cartella `esercitazioni`, la verifica:

       cd -
       tools/verifica.sh M5-E01

## Che cosa osservare

### Che cosa dice Anthropic

- **I due modi.** «Claude uses skills when relevant, or you can invoke one
  directly with /skill-name.» (https://code.claude.com/docs/en/skills) È il
  comportamento che la prova mette sotto gli occhi: Claude può chiamare la skill
  da solo, e la verifica lo stampa come un dato, non come un esito.
- **Il `!`.** «The command output replaces the placeholder, so Claude receives
  actual data, not the command itself.» (stessa pagina) Quindi Claude ha la
  differenza già nel corpo della skill, senza chiamare uno strumento: la verifica
  stampa gli strumenti che ha chiamato prima di rispondere, e il corpo che gli è
  arrivato.
- **La sessione nuova.** «A fresh session matters because leftover context from
  authoring the skill will mask gaps in the written instructions.» (stessa
  pagina) Per questo c'è `prova.sh`.
- **`/skills`.** «/skills | List available skills.»
  (https://code.claude.com/docs/en/commands) Le skill del vostro account hanno una
  voce a sé: «To see which skills synced, run /skills. The menu lists them under
  claude.ai sync.» (https://code.claude.com/docs/en/skills) Se la vostra non
  compare: «Skill
  doesn't appear in /skills | Skill file is at .claude/skills/name.md instead of
  in a folder» (https://code.claude.com/docs/en/debug-your-config).
- **`/skill-doctor`.** «Run /skill-doctor to see what each of your skills costs
  and how often it gets used, so you can decide which ones to turn off.»
  (https://code.claude.com/docs/en/skills) La sua nota, in Claude Code 2.1.317:
  «context = this skill's one-line listing in the system prompt, included every
  turn».
- **`claude plugin validate`.** «To find SKILL.md files whose frontmatter doesn't
  parse, run claude plugin validate on the skills directory … Requires Claude Code
  v2.1.233 or later.» (https://code.claude.com/docs/en/skills) Nelle prove del
  corso, con Claude Code 2.1.317: su un frontmatter che non si analizza esce con 1,
  «YAML frontmatter failed to parse»; senza `description` esce con 0 e un avviso,
  «No description in frontmatter.»; e ha lasciato passare, con 0,
  `description: [non chiusa` e `description: Controlla: tutto: bene`. Non è una
  garanzia, e per questo non decide la verifica. `controlla_skill.py` applica le
  regole scritte nella specifica, con la sola libreria standard.
- **I campi.** Dalla specifica, per `name`: «Max 64 characters. Lowercase letters,
  numbers, and hyphens only. Must not start or end with a hyphen.» e «Must match
  the parent directory name»; per `description`: «Max 1024 characters. Non-empty.
  Describes what the skill does and when to use it.»
  (https://agentskills.io/specification). E dalle best practice di Anthropic:
  «Always write in third person. The description is injected into the system
  prompt»
  (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

### Due cose trovate nelle prove del corso

Con Claude Code 2.1.317, in `claude -p` e `dontAsk`. In una sessione interattiva è
stata provata soltanto la prima: `/riassunto-modifiche` è partito senza chiedere
niente.

- Le righe `` !`git diff HEAD` `` passano senza `allowed-tools`: sono comandi di
  sola lettura, e il corpo arriva con il loro output. Per questo la skill di
  riferimento non ha il campo.
- Una skill con `allowed-tools` o `disallowed-tools` nel frontmatter, che Claude
  invoca da sé, è negata finché le regole non ammettono `Skill(<nome>)`: la
  chiamata finisce in `permission_denials`. Per questo `prova.sh` consente
  `Skill(riassunto-modifiche)`: se Claude vi ha messo `allowed-tools`, la prova
  gira lo stesso.

### Che cosa misura la verifica

`tools/verifica.sh M5-E01` decide tre cose, e solo queste: `tools/controlla_skill.py`
del repository non trova errori nella skill; il corpo ha una riga `` !`comando` ``,
fuori dai blocchi di codice; la prova, `prova/stream.jsonl`, c'è ed è completa.
Dice che il lavoro è fatto, non che la skill è buona.

Tutto il resto lo stampa come dati, nelle righe `(dato)`, mai come uscita, perché
dipende da ciò che Claude sceglie di fare:

- la chiamata `Skill` sulla domanda naturale: nello stream è un `tool_use` di nome
  `Skill`, con `input.skill`;
- il file cambiato, `urgenza.py`, nella risposta;
- gli strumenti chiamati prima della risposta, oltre a `Skill`;
- il corpo arrivato a Claude, quando è Claude a chiamare la skill: nello stream è
  il messaggio che comincia «Base directory for this skill:». Si guarda se ci
  resta un `` !`comando` `` e se c'è il file cambiato;
- la chiamata riuscita, «n su N», su tutte le prove di `prova/`: ogni nuova prova
  conserva le precedenti in `prova/stream-<k>.jsonl`.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, tre prove con `bash
prova.sh`): «(dato) tutte le prove di prova/: la chiamata Skill riuscita in 3 su 3».
Le righe dell'ultima prova:

    (dato) la chiamata Skill sulla domanda naturale: sì
    (dato) il file cambiato nella risposta: urgenza.py: sì
    (dato) gli strumenti, oltre a Skill, prima della risposta: nessuno
    (dato) il corpo arrivato a Claude: nessun !`comando` rimasto: sì; urgenza.py: sì

Con `/riassunto-modifiche`, in una sessione nuova: «chiamate Skill: 0; strumenti:
nessuno; il file nella risposta: urgenza.py: sì; turni 1; token 19192; 9,5 s». Da
`/skill-doctor`, lanciato prima delle prove:

    riassunto-modifiche  projectSettings      ~80          -     0×  never

`claude plugin validate .claude/skills` è uscito con 0, un dato. Dal controllo del
file: «controlla_skill: riassunto-modifiche: 0 errori, 1 avviso», l'avviso che
mancano i casi di prova in `evals/`, che in questa prima skill non ci sono. Sono le
righe di queste esecuzioni: dicono che cosa è successo lì, non che cosa succederà
nella vostra.

È una prova in `claude -p`, senza nessuno davanti, con una differenza dalla vostra
sessione. Lì la skill Claude l'ha scritta in `bozza/riassunto-modifiche/`, con il
percorso del prompt cambiato, e `_docente/live.sh` l'ha spostata in `.claude/skills/`.
Nelle prove del corso, in `claude -p`, le scritture sotto `.claude/skills/` sono
negate anche con le regole: «permissions.allow rules in settings files do not
pre-approve protected-path writes»
(https://code.claude.com/docs/en/permission-modes). A voi, nel passo 3, Claude Code
lo chiede. `/skills` e la domanda di fiducia nella cartella, in quella prova, non ci
sono.

Il percorso interattivo è stato provato a parte, su un terminale, con Claude Code
2.1.317, Sonnet ed effort low, dal prompt alla verifica: le domande e i pannelli dei
passi 2, 3 e 4 sono quelli visti lì, con `.claude/skills/` già presente all'avvio.
Con la cartella creata dopo l'avvio, `/skills` non ha trovato la skill finché non si
è lanciato `/reload-skills`.

## Verifica (tools/verifica.sh M5-E01)

Dalla cartella `esercitazioni`:

    tools/verifica.sh M5-E01

Esce con 0 se la skill passa il controllo, ha una riga `` !`comando` `` e la prova è
completa; con 1 se qualcosa manca, e dice che cosa; con 2 se non può partire, per
esempio se lo spazio di lavoro non c'è. Quando tutto è in ordine, le ultime due
righe sono «Fatto: …» e «VERIFICA OK   M5-E01: fatto.»

## Se qualcosa va storto

- La sessione si chiude appena aperta: alla domanda di fiducia il cursore parte da
  «No, exit». Riaprite e scegliete «Yes, I trust this folder».
- Claude Code sembra fermo: sta aspettando una risposta, sulla scrittura in `.claude/`
  o sul comando `python3` del controllo (passo 3).
- `/skills` o `/skill-doctor` restano aperti e non potete scrivere: il pannello si
  chiude con Esc.
- `/skills` non la elenca: il file è `.claude/skills/riassunto-modifiche/SKILL.md`,
  in una cartella con quel nome. Se è lì e non compare, forse `.claude/skills/` non
  c'era quando avete aperto la sessione: «If you create a top-level skills directory
  that didn't exist when the session started, run /reload-skills to pick up the
  skills you put there.» (https://code.claude.com/docs/en/skills) Lanciate
  `/reload-skills`, e di nuovo dopo ogni modifica.
- La verifica dice che `name` non va: è uguale alla cartella,
  `riassunto-modifiche`. Dice che manca la `description`: forse è un campo scritto
  male; `claude plugin validate` non basta a trovarlo, `controlla_skill.py` sì.
- La prova risponde senza chiamare la skill: la verifica lo stampa come un dato e
  non vi boccia. Riscrivete la `description` con le parole di chi chiede, e
  rilanciate `bash prova.sh`.
- Il dato dice che la chiamata è negata dal permesso: controllate che la skill si
  chiami `riassunto-modifiche`, il nome che `prova.sh` consente.
- Il dato dice che la chiamata è respinta dallo strumento: il motivo è nel
  `tool_result`, in `prova/stream.jsonl`. Controllate che il frontmatter non abbia
  `disable-model-invocation: true`, con cui Claude non può chiamarla da solo.
- `/riassunto-modifiche` si ferma con «Shell command permission check failed»: un
  `` !`comando` `` non è di sola lettura. Tenete `git status --short` e
  `git diff HEAD`.
- `prova.sh` dice che manca la skill: non l'avete ancora scritta, o sta in un'altra
  cartella.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M5-E01`. Cancella anche la
  skill.

## Impronta d'uso sul piano Pro

Sonnet, effort low, pochi turni brevi nella sessione interattiva, nessun subagent,
una chiamata di prova, `bash prova.sh`. `controlla_skill.py` e la verifica girano sul
vostro computer, e `claude plugin validate` non chiama il modello.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, `_docente/live.sh` in `claude -p` sull'account del docente, un piano
Max), dalle righe `(dato)`: la richiesta di scrivere la skill, «turni 4; token 58870;
16,2 s»; l'ultima delle tre prove, «turni 3; token 36620; 9,4 s», e dal `result` delle
altre due, 3 turni, 36.583 e 36.548 token, 11,0 e 9,5 secondi; `/riassunto-modifiche`,
«turni 1; token 19192; 9,5 s»; `/skill-doctor`, zero turni. I token sono quelli di
`modelUsage`, entrata, cache e uscita di ogni chiamata, compreso il contesto letto
dalla cache: dicono quanto lavoro è stato, non un prezzo, e non quanta parte del
vostro piano occupa. La sessione interattiva non è stata misurata.

## Per approfondire

- «Extend Claude with skills», la pagina di Claude Code:
  https://code.claude.com/docs/en/skills
- La specifica di Agent Skills, i campi e il corpo:
  https://agentskills.io/specification. Per validare una skill indica la sua
  libreria: «Use the skills-ref reference library to validate your skills»; in questo
  corso non la eseguiamo, e il controllo è `tools/controlla_skill.py`.
- «Skill authoring best practices», di Anthropic:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Il corso dell'Academy «Introduction to agent skills»:
  https://academy.claude.com/courses/introduction-to-agent-skills
