# M5-D05 — La stessa skill in claude.ai

Demo del Modulo 5, e una prova che potete rifare sul vostro account, se volete.
La skill di esempio `risposta-assistenza`, la stessa di Claude Code, si impacchetta
in uno ZIP e si carica su claude.ai. La demo carica tre ZIP: uno con un settimo
campo nel frontmatter, uno con dei tag XML nella description e quello buono, che poi
risponde in una chat. In aula il docente la fa sul suo account, oppure ne mostra le
schermate.

## Obiettivo

Mettere alla prova due frasi di Anthropic su che cosa succede nel caricamento su
claude.ai: un campo che la specifica non ammette «fails with a hard error», e la
description «Cannot contain XML tags». Il caricamento è il punto della demo, ed è per
questo che qui si lavora su claude.ai e non in Claude Code. Nella prova del corso la
seconda frase ha retto e la prima no: per questo il controllo si fa prima di caricare.
La parte locale costruisce i tre ZIP e li passa a un controllo che applica le regole
scritte nelle pagine; il caricamento e la risposta in chat si guardano sullo schermo.

## Tempo

3 minuti in aula, la demo del docente: tre caricamenti e una chat, o le loro
schermate. La prova sul vostro account, se la fate, è un caricamento e una chat:
qualche minuto, la pulizia compresa.

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

- `impacchetta.sh` e `impacchetta.py`: costruiscono i tre ZIP dalla skill di
  esempio del repository, `riferimenti/skill-di-esempio/risposta-assistenza/`,
  senza `evals/`, con Python;
- `controlla.sh`: il controllo locale sui tre ZIP, una dimostrazione;
- `richiesta.txt`: la richiesta della chat, scritta come la scriverebbe
  chiunque.

La risposta di Claude, se fate la prova, la copiate voi in un file nuovo dello
spazio di lavoro: `risposta_claude_ai.md`.

## Passi in Claude Code (qui, in claude.ai)

Questa demo non usa Claude Code: il terminale serve a costruire gli ZIP e a
verificare, il resto sta su claude.ai. La demo del docente ha tutti i passi. Se
volete provare sul vostro account, saltate il passo 3 e fate gli altri.

1. **I tre ZIP.** Dalla cartella `esercitazioni`:

       export PN_HANDSON_ROOT="$PWD"
       tools/prepara_esercizio.sh M5-D05
       cd ~/corso-claude-code/M5-D05
       ./impacchetta.sh pacchetti
       ./controlla.sh pacchetti

   In `pacchetti/` trovate `risposta-assistenza.zip`,
   `risposta-assistenza-settimo-campo.zip` e `risposta-assistenza-tag-xml.zip`. Il
   controllo dice 0 errori sul primo, e un errore su ciascuno degli altri due.

2. **L'esecuzione di codice.** In claude.ai, in Settings > Capabilities, «Code
   execution and file creation» dev'essere acceso (nel layout aggiornato delle
   impostazioni si chiama «Create and edit files»).

3. **Due prove sul frontmatter.** In Customize > Skills, «+ Add», poi «Upload skill»:
   scegliete `pacchetti/risposta-assistenza-settimo-campo.zip` e premete «Upload».
   Guardate se il caricamento si ferma. Se non si ferma, aprite «Contents» e il
   pulsante `</>`: la riga `argument-hint` è rimasta nel file? Poi lo stesso percorso
   con `pacchetti/risposta-assistenza-tag-xml.zip`: si ferma, e con quali parole?

4. **Lo ZIP buono.** Lo stesso percorso, con `pacchetti/risposta-assistenza.zip`. Se
   una skill con quel `name` c'è già, il sito chiede se sostituirla: «Upload and
   replace» ne salva una versione nuova. Guardate se la skill compare in Customize >
   Skills, accesa, e se la riga `argument-hint` non c'è più.

5. **La chat.** Aprite una chat nuova e incollate il testo di `richiesta.txt`:

       cat richiesta.txt

   Guardate se Claude usa la skill: sopra la risposta c'è una riga che si apre, e
   dentro «Loaded skill». E la risposta: è un messaggio che un operatore può copiare?
   Se state facendo la prova, salvate il testo della risposta in
   `risposta_claude_ai.md`, nello spazio di lavoro: con un editor di testo semplice,
   oppure dal terminale con

       cat > risposta_claude_ai.md

   poi incollate, premete Invio e infine Ctrl+D.

6. **La verifica.** Dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M5-D05

7. **La pulizia, da non saltare.** Togliete la skill: nella sua pagina, il menu «…» e
   «Remove». Così non torna nel vostro terminale. Nella pagina delle skill di Claude
   Code, le skill dell'account arrivano anche lì: «claude.ai account | Skills enabled
   for your claude.ai account | Cowork sessions, cloud sessions, and terminal sessions
   where you sign in with that account.» E, per controllare dopo: «To see which skills
   synced, run /skills. The menu lists them under claude.ai sync.»
   https://code.claude.com/docs/en/skills La togliete perché non torni nel vostro
   terminale con lo stesso account; spenta soltanto, non sparisce subito (vedete «Nella
   prova del corso»).

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
- Il controllo prima di caricare, nella pagina «Create custom skills»: «Before you
  upload the ZIP, check the skill's files». Per il frontmatter: «Check the frontmatter
  against the Agent Skills specification with the skills-ref reference tool». «A skill
  that passes prints Valid skill: ./my-skill. Otherwise the command lists each
  problem, such as a name that doesn't match the directory or a frontmatter field the
  specification doesn't define.» https://claude.com/docs/skills/how-to In questo corso
  il controllo è `tools/controlla_skill.py`.
- Dove si carica, nella pagina «Use skills in Claude»: «For Free, Pro, Max, and
  Ultra plans: You can enable example skills and upload your own in Customize >
  Skills.» E come: «To add custom skills, click the "+" button, then "+ Create
  skill."», e poi «Upload a ZIP file containing your skill folder.»
  https://support.claude.com/en/articles/12512180-use-skills-in-claude Nella prova
  del corso i pulsanti si chiamavano «+ Add» e «Upload skill».
- Che cosa resta fuori dalla chat: «Claude Code-only body features, such as
  dynamic context injection, don't function in claude.ai chat or through the
  API.» https://code.claude.com/docs/en/skills Per questo `risposta-assistenza`
  ha solo campi ammessi e nessuna riga `!`.

### Nella prova del corso

Nella prova del corso (4 novembre 2026, claude.ai nella nuova esperienza,
sull'account del docente, che non è un Pro; le schermate sono nelle dispense):

- **Il settimo campo è passato.** `risposta-assistenza-settimo-campo.zip`, come primo
  caricamento: nessun errore, e nel file salvato la riga `argument-hint: "[canale]"`
  è rimasta. La frase di Anthropic dice altro, e su questa corsa non ha retto: è un
  fatto con la sua data, non una regola. Sul vostro account guardate che cosa succede.
- **I tag XML si sono fermati.** `risposta-assistenza-tag-xml.zip`: «SKILL.md
  description cannot contain XML tags», e nessuna versione nuova.
- **Lo ZIP buono ha sostituito la skill.** «Replace "risposta-assistenza" skill?»,
  «Upload and replace», una versione nuova, e la riga `argument-hint` non c'era più.
- **La chat.** Con Sonnet, un messaggio, due chat: in tutte e due, sopra la risposta,
  «Loaded skill» e «Read kb-03-wifi-di-casa-e-mesh.md»; due risposte con il «tu» della
  chat e senza premesse, con parole diverse: quattro frasi la prima, che è oltre le tre
  del modello della skill, e tre la seconda.
- **Il terminale.** Una sessione da terminale con lo stesso account la elencava come
  `anthropic-skills:risposta-assistenza`; una con `--setting-sources project,local`
  no. Spenta la skill con il suo interruttore, 15 secondi dopo una sessione nuova la
  elencava ancora; 13 minuti dopo, un'altra sessione nuova non la elencava più.

Nella stessa corsa, altri ZIP, ciascuno diverso da quello buono per una cosa sola: un
campo inventato è passato, ed è rimasto nel file; uno ZIP senza `description` è
passato, con «No description found in SKILL.md» nell'anteprima; una cartella con un
altro nome è passata; il `name` `Risposta_Assistenza` è passato, e nel file è diventato
`risposta-assistenza`. Uno ZIP senza `SKILL.md` si è fermato: «Zip must contain a
SKILL.md file».

### Sullo schermo

Il caricamento e la chat si giudicano a occhio:

- **Il settimo campo.** Il caricamento di `risposta-assistenza-settimo-campo.zip` si
  ferma? Se si ferma, il messaggio assomiglia a quello che la pagina riporta, con
  `argument-hint` nominato? Le due skill hanno lo stesso `name`: cambia solo quel
  campo nel frontmatter.
- **I tag XML.** Il caricamento di `risposta-assistenza-tag-xml.zip` si ferma, e con
  quali parole?
- **La skill.** Dopo il caricamento di `risposta-assistenza.zip`, compare in
  Customize > Skills?
- **La risposta.** In chat, Claude usa la skill? La risposta segue il modello
  della chat della skill, con le sue parole?

### Che cosa fa il controllo

`controlla.sh` è una dimostrazione: i due ZIP che sbagliano li costruisce la demo, e
`tools/controlla_skill.py --caricamento` applica le regole scritte nelle pagine: 0
errori sul primo; sul secondo l'errore con il messaggio che la pagina riporta; sul
terzo l'errore sui tag XML. L'avviso su `evals/` è atteso, perché le prove restano
fuori dallo ZIP. Non è il caricamento, e non dice che cosa farà claude.ai.

Nella stessa prova del corso, la sola parte locale, senza chiamate al modello, i tre
ZIP di 18 file ciascuno sotto `risposta-assistenza/`, senza `evals/`: «controlla_skill:
risposta-assistenza: 0 errori, 1 avviso» sul primo; sugli altri due «controlla_skill:
risposta-assistenza: 1 errore, 1 avviso», con la riga `ERRORE caricamento` sul secondo
e `ERRORE description` sul terzo.

`verifica.sh` non chiama nessun modello. Guarda i tre ZIP: la forma, i campi. Di
`risposta_claude_ai.md`, se c'è, stampa i criteri che si contano, come dati: le
parole da evitare della guida del tono e della skill, con le forme della stessa
parola, le frasi, le parole, la forma del canale, la premessa; e il testo, che
legge una persona. Nessuno di questi dati decide l'uscita.

## Verifica (tools/verifica.sh M5-D05)

È fatta quando i tre ZIP di `pacchetti/` ci sono, si aprono, hanno la cartella
`risposta-assistenza/` al primo livello e niente `evals/`, il settimo campo sta in
uno solo dei tre, e i tag XML in un altro. Se avete fatto la prova,
`risposta_claude_ai.md` non dev'essere vuoto. Quando tutto è in ordine, le ultime due
righe sono «Fatto: i tre ZIP sono pronti; il caricamento e la risposta si guardano su
claude.ai.» e «VERIFICA OK   M5-D05: fatto.»

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

Niente Claude Code e nessun subagent. La demo sono tre caricamenti e una chat di un
solo messaggio. La prova facoltativa è un caricamento e una chat di un solo
messaggio, con Sonnet, che si sceglie dal menu del modello accanto al pulsante di
invio. La parte locale non consuma il piano: nella prova del corso, un secondo.

## Per approfondire

- «Use skills in Claude», caricare e attivare le skill su claude.ai:
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
- «Create custom skills», la forma dello ZIP e il controllo prima di caricare:
  https://claude.com/docs/skills/how-to
- «What are skills?», nel centro assistenza:
  https://support.claude.com/en/articles/12512176-what-are-skills
- «Extend Claude with skills», i campi e la sincronizzazione nel terminale:
  https://code.claude.com/docs/en/skills
- «Specification», il formato dello standard Agent Skills:
  https://agentskills.io/specification
