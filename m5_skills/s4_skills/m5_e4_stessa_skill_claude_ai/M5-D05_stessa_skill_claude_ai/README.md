# M5-D05 — La stessa skill in claude.ai

Demo del Modulo 5, e una prova che potete rifare sul vostro account, se volete.
La skill di esempio `risposta-assistenza`, la stessa di Claude Code, si impacchetta
in uno ZIP e si carica su claude.ai. La demo carica due ZIP: uno con un settimo
campo nel frontmatter, che deve essere rifiutato, e quello buono, che poi risponde
in una chat. In aula il docente la fa sul suo account, oppure ne mostra il percorso
su uno schema.

## Obiettivo

Mettere alla prova una garanzia di Anthropic: nel caricamento su claude.ai il
frontmatter ammette sei campi, e un campo in più non si ignora, si ferma tutto
con un errore. Il caricamento è il punto della demo, ed è per questo che qui si
lavora su claude.ai e non in Claude Code. La parte locale costruisce i due ZIP e
li passa a un controllo che applica la stessa regola; il rifiuto vero e la
risposta in chat si guardano sullo schermo.

## Tempo

3 minuti in aula, la demo del docente: due caricamenti e una chat, o il loro
percorso su uno schema. La prova sul vostro account, se la fate, è un caricamento e una chat: qualche minuto, la
pulizia compresa.

## Prerequisiti

- Un account claude.ai con il piano Pro, nel browser, con l'esecuzione di codice
  attiva: «Skills are available for users on Free, Pro, Max, Ultra, Team, and
  Enterprise plans. This feature requires code execution to be enabled.»
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
- Python 3 nel terminale (Linux o WSL 2 su Windows), per costruire gli ZIP:
  `tools/verifica_ambiente.sh` lo controlla (`PRIMA_DEL_CORSO.md`). Lo `zip` di
  sistema non serve.
- Nessuna sessione di Claude Code.
- La prova mette una skill sul vostro account, e alla fine la togliete. Chi
  preferisce non toccare il proprio account guarda la demo del docente.

## Punto di partenza (tools/prepara_esercizio.sh M5-D05)

Lo spazio di lavoro `~/corso-claude-code/M5-D05/` con:

- `impacchetta.sh` e `impacchetta.py`: costruiscono i due ZIP dalla skill di
  esempio del repository, `riferimenti/skill-di-esempio/risposta-assistenza/`,
  senza `evals/`, con Python;
- `controlla.sh`: il controllo locale sui due ZIP, una dimostrazione;
- `richiesta.txt`: la richiesta della chat, scritta come la scriverebbe
  chiunque.

La risposta di Claude, se fate la prova, la copiate voi in un file nuovo dello
spazio di lavoro: `risposta_claude_ai.md`.

## Passi in Claude Code (qui, in claude.ai)

Questa demo non usa Claude Code: il terminale serve a costruire gli ZIP e a
verificare, il resto sta su claude.ai. La demo del docente ha tutti i passi. Se
volete provare sul vostro account, saltate il passo 3 e fate gli altri.

1. **I due ZIP.** Dalla cartella `esercitazioni`:

       export PN_HANDSON_ROOT="$PWD"
       tools/prepara_esercizio.sh M5-D05
       cd ~/corso-claude-code/M5-D05
       ./impacchetta.sh pacchetti
       ./controlla.sh pacchetti

   In `pacchetti/` trovate `risposta-assistenza.zip` e
   `risposta-assistenza-settimo-campo.zip`. Il controllo dice 0 errori sul
   primo, e l'errore sul secondo.

2. **L'esecuzione di codice.** In claude.ai, in Settings > Capabilities, «Code
   execution and file creation» dev'essere acceso (nel layout aggiornato delle
   impostazioni si chiama «Create and edit files»).

3. **Il settimo campo.** In Customize > Skills, il pulsante «+», poi «+ Create
   skill», poi «Upload a skill», e scegliete
   `pacchetti/risposta-assistenza-settimo-campo.zip`. Guardate se il caricamento
   si ferma, e con quali parole.

4. **Lo ZIP buono.** Lo stesso percorso, con `pacchetti/risposta-assistenza.zip`.
   Guardate se la skill compare in Customize > Skills.

5. **La chat.** Aprite una chat nuova e incollate il testo di `richiesta.txt`:

       cat richiesta.txt

   Guardate se Claude usa la skill, e la risposta: è un messaggio che un operatore
   può copiare? Se state facendo la prova, salvate il testo della risposta in
   `risposta_claude_ai.md`, nello spazio di lavoro: con un editor di testo
   semplice, oppure dal terminale con

       cat > risposta_claude_ai.md

   poi incollate, premete Invio e infine Ctrl+D.

6. **La verifica.** Dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M5-D05

7. **La pulizia, da non saltare.** Togliete la skill da Customize > Skills,
   perché non torni nel vostro terminale con lo stesso account. Nella pagina delle
   skill di Claude Code, le skill dell'account arrivano anche lì: «claude.ai
   account | Skills enabled for your claude.ai account | Cowork sessions, cloud
   sessions, and terminal sessions where you sign in with that account.» E, per
   controllare dopo: «To see which skills synced, run /skills. The menu lists them
   under claude.ai sync.» https://code.claude.com/docs/en/skills

## Che cosa osservare

### Che cosa dice Anthropic

- I sei campi, nella pagina «Extend Claude with skills»: «claude.ai skill
  uploads, the Skills API, and packaging with package_skill.py from
  anthropics/skills | name, description, license, compatibility, metadata,
  allowed-tools». Un campo in più: «If you include any field the spec doesn't
  allow, packaging or upload fails with a hard error instead of ignoring the
  field». E il messaggio: «Unexpected key(s) in SKILL.md frontmatter:
  argument-hint. Allowed properties are: allowed-tools, compatibility,
  description, license, metadata, name».
  https://code.claude.com/docs/en/skills
- Lo stesso elenco nel validatore del repository `anthropics/skills`:
  «ALLOWED_PROPERTIES = {'name', 'description', 'license', 'allowed-tools',
  'metadata', 'compatibility'}».
  https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/scripts/quick_validate.py
- La forma dello ZIP, nella pagina «Create custom skills»: «The ZIP must contain
  the skill directory itself as its top level, because Claude looks for
  <skill-name>/SKILL.md inside the archive». Il nome: «Lowercase letters, numbers,
  and hyphens only, up to 64 characters. Must match the skill's directory name».
  https://claude.com/docs/skills/how-to E la description, nella pagina «Agent
  Skills»: «Must be non-empty», «Maximum 1,024 characters», «Cannot contain XML
  tags». https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- Dove si carica, nella pagina «Use skills in Claude»: «For Free, Pro, Max, and
  Ultra plans: You can enable example skills and upload your own in Customize >
  Skills.» E come: «To add custom skills, click the "+" button, then "+ Create
  skill."», e poi «Upload a ZIP file containing your skill folder.»
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
- Che cosa resta fuori dalla chat: «Claude Code-only body features, such as
  dynamic context injection, don't function in claude.ai chat or through the
  API.» https://code.claude.com/docs/en/skills Per questo `risposta-assistenza`
  ha solo campi ammessi e nessuna riga `!`.

### Sullo schermo

Il caricamento e la chat si giudicano a occhio:

- **Il rifiuto.** Il caricamento di `risposta-assistenza-settimo-campo.zip` si
  ferma? Il messaggio assomiglia a quello che la pagina riporta, con
  `argument-hint` nominato? Le due skill hanno lo stesso `name`: cambia solo
  quel campo nel frontmatter.
- **La skill.** Dopo il caricamento di `risposta-assistenza.zip`, compare in
  Customize > Skills?
- **La risposta.** In chat, Claude usa la skill? La risposta segue il modello
  della chat della skill, con le sue parole?

### Che cosa fa il controllo

`controlla.sh` è una dimostrazione: lo ZIP con il settimo campo lo costruisce la
demo, e `tools/controlla_skill.py --caricamento` applica la regola scritta nella
pagina: 0 errori sul primo ZIP, sul secondo l'errore nella forma del messaggio
del caricamento. L'avviso su `evals/` è atteso, perché le prove restano fuori
dallo ZIP. Non è il caricamento vero, e non dice che cosa farà claude.ai.

Nella prova del corso (3 novembre 2026, `_docente/live.sh`, la sola parte locale,
senza chiamate al modello), i due ZIP di 18 file ciascuno sotto
`risposta-assistenza/`, senza `evals/`: «controlla_skill: risposta-assistenza: 0
errori, 1 avviso» sul primo; sul secondo «controlla_skill: risposta-assistenza: 1
errore, 1 avviso», con la riga `ERRORE caricamento` nella forma del messaggio.

`verifica.sh` non chiama nessun modello. Guarda i due ZIP: la forma, i campi. Di
`risposta_claude_ai.md`, se c'è, stampa i criteri che si contano, come dati: le
parole da evitare della guida del tono e della skill, con le forme della stessa
parola, le frasi, le parole, la forma del canale, la premessa; e il testo, che
legge una persona. Nessuno di questi dati decide l'uscita.

## Verifica (tools/verifica.sh M5-D05)

È fatta quando i due ZIP di `pacchetti/` ci sono, si aprono, hanno la cartella
`risposta-assistenza/` al primo livello e niente `evals/`, e il settimo campo sta
in uno solo dei due. Se avete fatto la prova, `risposta_claude_ai.md` non dev'essere
vuoto. Quando tutto è in ordine, le ultime due righe sono «Fatto: i due ZIP sono
pronti; il rifiuto e la risposta si guardano su claude.ai.» e
«VERIFICA OK   M5-D05: fatto.»

## Se qualcosa va storto

- `impacchetta.sh` o `controlla.sh` dicono che manca `PN_HANDSON_ROOT`: rifate
  l'`export` del passo 1, nello stesso terminale, dalla cartella `esercitazioni`.
- Claude.ai rifiuta anche lo ZIP buono. Fra le cause che la pagina elenca: «ZIP
  file exceeds size limits», «Skill folder name doesn't match the skill name»,
  «Missing required skill.md file», «Invalid characters in skill name or
  description». https://support.claude.com/en/articles/12512180-use-skills-in-claude
  Controllate di aver scelto `risposta-assistenza.zip`, e rilanciate
  `./controlla.sh pacchetti`.
- La funzione richiede l'esecuzione di codice: se la skill non si carica o non
  parte, controllate anche il passo 2.
- Volete passarla a un collega: «On Team and Enterprise plans, you can share
  skills you've created with specific colleagues, groups.» Sul piano Pro, invece:
  «On all other plans, each person uploads skills to their own account.»
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
- La verifica dice che `risposta_claude_ai.md` è vuoto: incollateci la risposta,
  o toglietelo se non fate la prova.
- Per ricominciare da capo: `tools/reset_esercizio.sh M5-D05`. La skill su
  claude.ai non se ne va da sola: togliete anche quella (passo 7).

## Impronta d'uso sul piano Pro

Niente Claude Code e nessun subagent. La demo sono due caricamenti e una chat di un
solo messaggio. La prova facoltativa è un caricamento e una chat di un solo
messaggio, con Sonnet, che si sceglie dal menu del modello accanto al pulsante di
invio. La parte locale non consuma il piano: nella prova del corso, un secondo.

## Per approfondire

- «Use skills in Claude», caricare e attivare le skill su claude.ai:
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
- «Create custom skills», la forma dello ZIP:
  https://claude.com/docs/skills/how-to
- «What are skills?», nel centro assistenza:
  https://support.claude.com/en/articles/12512176-what-are-skills
- «Extend Claude with skills», i campi e la sincronizzazione nel terminale:
  https://code.claude.com/docs/en/skills
- «Specification», il formato dello standard Agent Skills:
  https://agentskills.io/specification
