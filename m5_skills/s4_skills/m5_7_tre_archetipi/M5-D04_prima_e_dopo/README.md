# M5-D04 — Prima e dopo, tre archetipi

Demo del Modulo 5, nella parte «Tre archetipi». La stessa richiesta, una
volta con la skill di esempio e una senza, per ognuno dei tre archetipi: la
revisione di un pull request, la risposta a un cliente, l'audit di una
configurazione. In aula il docente ne fa girare uno con `in_classe.sh`; una
coppia potete rifarla da soli quando volete.

## Obiettivo

Mettere alla prova che cosa dice Anthropic di una skill: che porta a Claude la
competenza di dominio, cioè il modo in cui un team fa il lavoro. Per ogni
archetipo si confrontano due sessioni nuove di `claude -p`, con lo stesso comando
e la stessa richiesta, scritta come la scriverebbe chiunque, senza nominare la
skill né le regole del team. Differiscono in una cosa sola: la cartella ha la
skill, oppure non ce l'ha. Uno script legge gli stream e conta ciò che si può
contare; il testo di una risposta a un cliente lo legge una persona. Accanto alle
coppie, tre esecuzioni a parte provano un'altra cosa: che cosa succede con la
skill spenta da `skillOverrides`.

Si usa `claude -p`, e non una sessione interattiva, perché il metodo di Anthropic
vuole ogni prova in una sessione nuova, e perché uno stream si rilegge.

## Tempo

3 minuti in aula, la demo del docente: un archetipo, due sessioni. Per rifare
una coppia da soli, qualche minuto.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh` tutto
  verde (`PRIMA_DEL_CORSO.md`).
- Python 3 e git, che lo stesso controllo verifica.
- Niente PHP né Docker: il gestionale qui si legge, non si esegue.

## Punto di partenza (tools/prepara_esercizio.sh M5-D04)

Lo spazio di lavoro `~/corso-claude-code/M5-D04/` con:

- `in_classe.sh`: una coppia di esecuzioni per un archetipo, e
  `lib_archetipi.sh`, le sue funzioni;
- `richieste.tsv`: le tre richieste;
- `pr-demo.patch`: il pull request della demo, una classe nuova del gestionale,
  `ReportMorosita`;
- `controlla_archetipi.py`: il controllo, che legge gli stream.

Le skill non ci sono ancora. La prima volta, `in_classe.sh` crea le due cartelle
dell'archetipo, due repository git con il progetto che serve. Una ha anche la
skill di esempio, copiata da `riferimenti/skill-di-esempio/` senza `evals/`: per
questo vuole `PN_HANDSON_ROOT`. L'altra, che finisce in `-senza`, è uguale, ma il
suo commit è nato senza la cartella della skill. Ogni archetipo sta nelle sue
cartelle, così le letture di una sessione non incontrano gli altri progetti.

| archetipo | le cartelle | skill | progetto | la richiesta |
|---|---|---|---|---|
| revisione | `revisione/`, `revisione-senza/` | `revisione-pr` | `progetti/gestionale-php`, sul ramo `pr-demo` | «Rivedi il pull request di questo branch rispetto a main.» |
| risposta | `risposta/`, `risposta-senza/` | `risposta-assistenza` | `progetti/assistenza-clienti` | «Rispondi a questo cliente, nella chat del sito: «Sono il gestore del Rifugio Campione: da stamattina la connessione va e viene, il POS non riesce a collegarsi e le prenotazioni online si bloccano. Ho la sala piena.»» |
| audit | `audit/`, `audit-senza/` | `audit-configurazione` | `progetti/rete` | «Controlla la configurazione di core-trento-01: che problemi ha?» |

Che cosa cercare, cioè le regole violate dal pull request e i problemi inseriti
nell'apparato, sta in `verita.json`, nella cartella di questo elemento: fuori
dallo spazio di lavoro, e come impronte.

## Passi in Claude Code

1. Dalla cartella `esercitazioni`, preparate lo spazio di lavoro ed entrateci:

       export PN_HANDSON_ROOT="$PWD"
       tools/prepara_esercizio.sh M5-D04
       cd ~/corso-claude-code/M5-D04

2. Una coppia, per l'archetipo che volete: `revisione`, `risposta` o `audit`.

       ./in_classe.sh revisione

   Lo script mostra ogni comando prima di eseguirlo. Sono due sessioni nuove con
   lo stesso comando, la prima dalla cartella `revisione/`, la seconda da
   `revisione-senza/`:

       claude -p --allowedTools 'Read,Skill(revisione-pr)' --model sonnet \
         --permission-mode dontAsk --permission-prompts none \
         --output-format stream-json --verbose \
         --setting-sources project,local --effort low \
         --strict-mcp-config --no-session-persistence \
         -- 'Rivedi il pull request di questo branch rispetto a main.'

   Gli stream restano in una cartella temporanea finché le due sessioni non sono
   finite, poi vanno in `risposte/`. Se rilanciate lo stesso archetipo, la coppia
   nuova prende il numero dopo.

3. Dalla cartella `esercitazioni`, la verifica:

       cd -
       tools/verifica.sh M5-D04

Per vedere la skill spenta, dopo una coppia della revisione: dalla cartella
`revisione/`, lo stesso comando con, in più, `--settings`, prima di `--`, e lo stream
in `risposte/`, dove la verifica lo legge:

    cd ~/corso-claude-code/M5-D04/revisione
    claude -p --allowedTools 'Read,Skill(revisione-pr)' --model sonnet \
      --permission-mode dontAsk --permission-prompts none \
      --output-format stream-json --verbose \
      --setting-sources project,local --effort low \
      --strict-mcp-config --no-session-persistence \
      --settings '{"skillOverrides":{"revisione-pr":"off"}}' \
      -- 'Rivedi il pull request di questo branch rispetto a main.' \
      > ../risposte/revisione-off-1.jsonl
    cd -

Il docente registra tre coppie per ognuno dei tre archetipi e un'esecuzione per
archetipo con la skill spenta, ventuno esecuzioni, con
`_docente/live.sh <spazio di lavoro>`; poi le stesse richieste su Haiku e su Opus,
sei esecuzioni con la skill accesa, con `_docente/live.sh <spazio di lavoro>
modelli`; ogni set in uno spazio di lavoro nuovo.

## Che cosa osservare

### Che cosa dice Anthropic

- Nella pagina «Agent Skills»: «Skills are reusable, filesystem-based resources
  that give Claude domain-specific expertise: workflows, context, and best
  practices that turn a general-purpose agent into a specialist.» È un
  confronto: un agente generico e uno specialista.
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- In un articolo di Anthropic su come si costruiscono gli agenti: «Skills are
  the right fit when the agent needs to know how a team does work».
  https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop
- Nella pagina «Extend Claude with skills», il metodo: «measure separately
  whether Claude invokes it on the prompts it should, and whether the output
  matches what you expect when it does.» https://code.claude.com/docs/en/skills
- Il confronto, nella guida dello standard Agent Skills: «run each test case
  twice: once with the skill and once without it (or with a previous version)».
  https://agentskills.io/skill-creation/evaluating-skills E nelle best practice di
  Anthropic: «Run Claude on representative tasks without a Skill. … Measure
  Claude's performance without the Skill.»
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
  Le coppie di questa demo fanno così: la seconda cartella non ha la skill.
- La pagina «Extend Claude with skills» propone anche di spegnerla: «Collect a few
  realistic prompts, run each one in a fresh session with the skill available and
  again with it turned off», e «Personal or project skill: set it to "off" in
  skillOverrides.» Un'esecuzione sola la si spegne con `--settings`; in
  `claude --help`: «--settings <file-or-json> Path to a settings JSON file or a
  JSON string to load additional settings from».
- Che cosa vuol dire `off`, nel riferimento delle impostazioni: «"off": Claude
  doesn't see the skill and /name is hidden from autocomplete».
  https://code.claude.com/docs/en/settings-reference E nella pagina delle skill:
  «Invoking a hidden skill by its full name returns the skillOverrides error
  instead of running it.» È una garanzia: deve valere a ogni esecuzione, e ha le
  sue tre esecuzioni.

### Perché le coppie non usano `off`

`off` toglie la skill da ciò che Claude vede come disponibile, e i suoi file
restano sul disco, dove Claude li può trovare. Nella registrazione del corso (3
novembre 2026, Claude Code 2.1.317, Sonnet con effort low), tre esecuzioni con la
skill spenta, una per archetipo: «garanzia di off, in tutto: tiene 3 su 3»; «come
dati: tentativi respinti: 0 su 3; file sotto .claude/skills/ nominati da Claude: 1
su 3». Quell'una è l'audit: `Read` di `SKILL.md` e di
`references/checklist-audit.md`, nella cartella
`.claude/skills/audit-configurazione/`, e un comando Bash su
`scripts/controlli_ovvi.py`, che in `dontAsk` è stato negato. In una prova
precedente Claude ha anche tentato la chiamata, e lo strumento l'ha respinta con
«Skill audit-configurazione is disabled for model invocation in skillOverrides
settings». Un braccio così non è un braccio senza la skill. Nessuna frase di
Anthropic dice il contrario: qui c'è soltanto ciò che le esecuzioni hanno mostrato.
Per questo le coppie confrontano due cartelle, e `off` ha il suo set, che nel
confronto non entra.

### Che cosa misura il controllo

`controlla_archetipi.py` legge gli stream di `risposte/`: una coppia per numero,
`<archetipo>-on-<n>.jsonl` e `<archetipo>-senza-<n>.jsonl`, e il set della skill
spenta, `<archetipo>-off-1.jsonl`. Per ogni esecuzione stampa se c'è la chiamata a
`Skill`, a parte, come chiede il metodo: nello stream, provato il 3 novembre 2026
con Claude Code 2.1.317, una skill che Claude invoca da sé è un `tool_use` di nome
`Skill` con `input.skill`. Stampa anche, come dati, un tentativo respinto, con il
testo dell'errore, e i file che gli strumenti nominano sotto `.claude/skills/`; poi
i turni, i token e i secondi, sommati su ogni risultato della chiamata. In on e in
senza, i criteri dell'archetipo:

- **revisione**: quante regole violate dal pull request cita con il numero, a
  numero intero, e gli altri numeri citati, come dati. Quando senza la skill
  Claude sceglie da sé la skill integrata `code-review`, il controllo la nomina,
  come dato. Nella pagina «Review locally with /code-review»:
  «/code-review is a bundled skill: its instructions are built into Claude Code,
  so there is no SKILL.md file on disk to open or edit.»
  https://code.claude.com/docs/en/code-review-local
- **risposta**: quattro criteri che si contano, dalla guida del tono di voce:
  nessuna parola da evitare, con le parole della guida del tono e dello `SKILL.md`,
  con le forme della stessa parola, a parola intera, e i nomi degli apparati; al
  massimo tre frasi, la forma della chat nella guida; la forma del canale, cioè
  niente titoli, grassetti, emoji, punti esclamativi in serie, né un elenco di
  più passi; nessuna premessa. La lunghezza in parole è un dato. Il testo si
  stampa per intero, perché il tono lo legge una persona: «Subjective skills
  (writing style, design quality) are better evaluated qualitatively — don't
  force assertions onto things that need human judgment.»
  https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md
- **audit**: quante categorie di problemi inserite nell'apparato riporta come
  problemi, con il codice `AUD-nn`, e se il report ha le sei colonne della skill:
  apparato, file, riga, categoria, gravità, descrizione, con almeno una riga. Una
  riga del report conta sempre; non conta un codice in una riga che dice che la
  categoria è a posto, o sotto un titolo come «Categorie senza problemi»: nominarla
  non vuol dire averla trovata. Si stampano, come dati, le altre categorie e quelle
  senza un rilievo.

I token sono quelli di `modelUsage` nell'ultimo risultato, tutti i modelli: «Use
modelUsage, or model_usage in Python, for whole-tree token accounting; the usage
field undercounts as soon as nesting occurs.»
https://code.claude.com/docs/en/agent-sdk/cost-tracking Sono entrata, cache e
uscita; per l'entrata, nella pagina sul prompt caching: «total_input_tokens =
cache_read_input_tokens + cache_creation_input_tokens + input_tokens».
https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Poi i verdetti, per archetipo:

- le garanzie: senza la skill e con la skill spenta, la skill non è nell'elenco
  `skills` di `system/init` e nessuna chiamata `Skill` a quella skill riesce; se
  Claude ne chiama un'altra, come `code-review`, è un dato. Se non regge, il
  controllo stampa `REPERTO` e la verifica esce con 1. Un tentativo respinto dallo
  strumento non è un reperto: il corpo non è arrivato, e si stampa come dato. Con
  la skill nella cartella deve esserci davvero: nell'elenco, e, se Claude la
  chiama, senza che la chiamata sia negata o respinta;
- il confronto, fra on e senza: più criteri con la skill che senza,
  **confermata**; tanti quanti, **non distinguibile**; meno, **non confermata in
  questa esecuzione**. Si stampa coppia per coppia, con «confermata n su N», e sul
  totale dei criteri. Il confronto non decide l'uscita, e una coppia sola dice poco: «One
  run of a non-deterministic agent tells you little» (stessa pagina di
  «Come si legge», qui sotto). Per questo il docente ne registra tre.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, tre coppie per archetipo, `_docente/live.sh` sull'account del docente):

- **revisione.** «revisione: Skill revisione-pr: on 3 su 3, senza 0 su 3»; regole
  inserite citate, 8 su 8 in ogni esecuzione con la skill e 0 su 8 in ogni
  esecuzione senza; «revisione: altre skill, senza: code-review 3 su 3»; «revisione:
  criteri in tutto: on 24, senza 0 su 24: confermata»; «revisione: coppia per coppia:
  confermata 3 su 3».
- **risposta.** «risposta: Skill risposta-assistenza: on 3 su 3, senza 0 su 3»; con
  la skill 4 criteri su 4 in ogni esecuzione, e 55, 53 e 71 parole; senza, 2, 1 e 1
  criteri su 4, e 283, 243 e 248 parole; «risposta: criteri in tutto: on 12, senza 4
  su 12: confermata»; «risposta: coppia per coppia: confermata 3 su 3». Il tono non è
  fra i criteri: il controllo stampa i testi, per chi li legge.
- **audit.** «audit: Skill audit-configurazione: on 3 su 3, senza 0 su 3»; categorie
  inserite trovate, 4 su 4 in tutte e sei le esecuzioni; le sei colonne, sì con la
  skill e no senza; «audit: criteri in tutto: on 15, senza 12 su 15: confermata»;
  «audit: coppia per coppia: confermata 3 su 3». Le categorie le trovano tutti e due
  i bracci: «dove i due bracci fanno lo stesso, non è la skill». La differenza fra i
  due bracci è tutta nella forma del report, le sei colonne: quel «confermata» dice
  questo, non che con la skill si trovino più categorie.

La garanzia di senza tiene 3 su 3 per ogni archetipo. Gli stream sono nella cartella
`soluzione/risposte/` di questo elemento.

### Come si legge

Il punteggio da solo non dice niente. Nella pagina «Test plugins with evals»:
«A high score on its own doesn't tell you the plugin helped, because Claude
might do as well without it.» E «If a case scores 1.0 both with and without the
plugin, the plugin isn't what made it pass.»
https://code.claude.com/docs/en/plugin-evals La pagina parla dei plugin: il
corso usa la stessa regola per leggere questo confronto.

### Perché `Skill(<nome>)` fra gli strumenti

Tutte le esecuzioni hanno `--allowedTools 'Read,Skill(<skill>)'`, anche quelle
senza la skill, perché le due di una coppia differiscano solo nella cartella.
Provato il 3 novembre 2026 con Claude Code 2.1.317, in `claude -p` con dontAsk:
una skill che ha `allowed-tools` o `disallowed-tools` nel frontmatter, come
`audit-configurazione`, e che Claude invoca da sé, è negata finché le regole non
ammettono `Skill(<nome>)`.

### I modelli

Prima di condividere una skill, la checklist di «Skill authoring best practices»
chiede «At least three evaluations created» e «Tested with real usage scenarios»
(le tre skill di esempio hanno le loro prove in `evals/`), e poi «Tested with
Haiku, Sonnet, and Opus», con il motivo: «Skills act as additions to models, so
effectiveness depends on the underlying model.»
https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
Per questo il docente fa girare anche il set `modelli`: `controlla_archetipi.py
--modelli risposte-modelli` stampa gli stessi criteri per modello, come dati.
Nessun verdetto confronta i modelli.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, effort low,
un'esecuzione per archetipo con la skill accesa, modelli riportati
`claude-haiku-5-5` e `claude-opus-5-5`), con tutti e due: la skill chiamata in ognuna delle sei
esecuzioni; nella revisione «regole inserite citate: 8 su 8»; nella risposta
«criteri: 4 su 4»; nell'audit «categorie inserite trovate: 4 su 4» e «le sei colonne:
sì». Sonnet sono le esecuzioni delle coppie. «Questa tabella non confronta i
modelli.»

## Verifica (tools/verifica.sh M5-D04)

La verifica fa girare `controlla_archetipi.py` dell'elemento, con `verita.json`
dell'elemento, sulle risposte dello spazio di lavoro. È fatta quando c'è almeno
una coppia completa, ogni stream si legge e le garanzie tengono, anche quella
della skill spenta, se il suo set c'è. Il confronto, i token, i secondi, i
tentativi respinti e i file sotto `.claude/skills/` si stampano e non la fanno
fallire. Quando tutto è in ordine, le ultime due righe sono «Fatto: ogni
affermazione è stata messa alla prova; gli esiti sono qui sopra.» e
«VERIFICA OK   M5-D04: fatto.»

## Se qualcosa va storto

- `in_classe.sh` dice che manca `PN_HANDSON_ROOT`: rifate l'`export` del passo
  1, nello stesso terminale, dalla cartella `esercitazioni`.
- La verifica dice che manca la cartella `risposte/`: eseguite il passo 2.
- Il controllo stampa `MANCA` su uno stream o su una coppia: togliete quella
  coppia, per esempio `rm risposte/revisione-*-2.jsonl`, e rilanciate
  `./in_classe.sh revisione`.
- `REPERTO`, senza la skill o con la skill spenta: una garanzia non ha retto, ed è
  un esito da segnalare al docente, con lo stream. Non dovrebbe dipendere da una skill
  caricata su claude.ai: questi comandi hanno `--setting-sources project,local`, con
  cui, per la pagina di Anthropic, le skill dell'account non arrivano, e nella prova del
  corso di M5-D05 una sessione così non le elencava.
- `REPERTO`, «negata dal permesso»: la chiamata a `Skill` non ha trovato la sua
  regola; controllate che il comando abbia `Skill(<skill>)` fra gli strumenti.
- Con la skill spenta, il controllo stampa «tentata e respinta» o dei file sotto
  `.claude/skills/`: è un dato, non un errore (qui sopra, «Perché le coppie non
  usano `off`»).
- `in_classe.sh` dice che una cartella non è al punto di partenza: qualcuno vi
  ha cambiato dei file. Per ricominciare da capo:
  `tools/reset_esercizio.sh M5-D04`.
- `claude: command not found`, oppure un errore di accesso: rifate i passi di
  `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.

## Impronta d'uso sul piano Pro

Ogni esecuzione è una sessione nuova di `claude -p` su Sonnet con effort low; la
demo non chiede subagent. Una coppia sono due esecuzioni, e in aula il docente ne
fa una. Per rifarla da soli basta una coppia, su un archetipo. Le diciotto
esecuzioni delle coppie, le tre con la skill spenta e le sei del set `modelli` sono
del docente.

Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con
effort low, `_docente/live.sh` sull'account del docente, un piano Max), come le
stampa il controllo:

- «revisione: in media, come dato: on 61093 token, 18,4 s; senza 60925 token, 17,5
  s», con 4 turni del modello con la skill e 2 senza;
- «risposta: in media, come dato: on 60109 token, 13,0 s; senza 18017 token, 8,8 s»,
  con 4 turni e 1;
- «audit: in media, come dato: on 154922 token, 34,1 s; senza 154386 token, 47,2 s»,
  con 11, 10 e 9 turni, e 6, 7 e 7.

Con la skill spenta: 3 turni, 82.290 token e 18,4 s nella revisione; 1 turno, 18.080
token e 10,2 s nella risposta; 10 turni, 154.469 token e 49,2 s nell'audit. Il set
`modelli`, su Haiku: 6, 5 e 12 turni, 86.964, 65.542 e 163.693 token, 19,6, 10,4 e
35,9 s; su Opus: 8, 6 e 11 turni, 119.000, 91.508 e 162.704 token, 38,3, 12,2 e
60,5 s. I token sono quelli di `modelUsage`, qui sopra: contano entrata, cache e uscita, e
nelle coppie sono per la maggior parte letti dalla cache. Dicono quanto lavoro è
stato, non un prezzo, e non quanta parte del vostro piano occupa. Nella revisione
senza la skill conta anche il subagent che lavora dopo la chiamata a `code-review`.

## Per approfondire

- «Extend Claude with skills», le skill in Claude Code e come si provano:
  https://code.claude.com/docs/en/skills
- «Agent Skills», nella documentazione della piattaforma:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- «Skill authoring best practices», con la checklist:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- «Test plugins with evals», il confronto con e senza:
  https://code.claude.com/docs/en/plugin-evals
- «Review locally with /code-review», la revisione integrata:
  https://code.claude.com/docs/en/code-review-local
- «Evaluating skill output quality», la guida dello standard Agent Skills:
  https://agentskills.io/skill-creation/evaluating-skills
