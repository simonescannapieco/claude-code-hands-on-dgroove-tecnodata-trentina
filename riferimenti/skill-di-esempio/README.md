# Skill di esempio

Tre skill complete del Modulo 5, una per archetipo, da leggere e da adattare.
Seguono lo standard Agent Skills e le best practice di Anthropic: uno
`SKILL.md` con il frontmatter e il corpo in Markdown, i file di supporto
nelle loro cartelle, e le prove in `evals/`. `audit-configurazione` ha in più un
campo proprio di Claude Code, `disallowed-tools`.

| skill | che cosa fa | dove va bene |
|---|---|---|
| [`revisione-pr`](revisione-pr/SKILL.md) | rivede un pull request del gestionale contro le convenzioni numerate del team | una regola scritta, che Claude non può indovinare |
| [`risposta-assistenza`](risposta-assistenza/SKILL.md) | scrive la risposta a un cliente nel tono di voce e nel formato del canale | un modo di scrivere: ciò che si conta lo conta un controllo, il tono lo legge una persona |
| [`audit-configurazione`](audit-configurazione/SKILL.md) | controlla un apparato contro la checklist di audit, senza modificare nulla | una checklist, con uno script per ciò che si trova senza ragionare |

Si adattano nel laboratorio, con `tools/prove_skill.sh <ID> copia esempio`;
chi preferisce parte da [`template-SKILL.md`](../template-SKILL.md), con
`tools/prove_skill.sh <ID> copia modello`.

## Com'è fatta ciascuna

- **`SKILL.md`.** `name` uguale alla cartella; `description` in terza persona,
  con che cosa fa e quando usarla; il corpo con la procedura a passi, il
  modello della risposta, gli esempi, i casi limite, i gotcha.
- **`references/`.** Le copie dei documenti del progetto che servono alla
  skill: le convenzioni, il tono di voce e le procedure, la checklist. La
  skill dice quando leggerli, così entrano nel contesto solo se servono, e la
  cartella può uscire dal progetto.
- **`scripts/`.** Solo in `audit-configurazione`: `controlli_ovvi.py`, con
  `--help`, un'uscita in TSV su stdout e i messaggi su stderr.
- **`evals/`.** `evals.json`, i tre casi di prova del laboratorio, con le loro
  asserzioni; `eval_queries.json`, una richiesta che non deve attivare la
  skill.

`risposta-assistenza` usa solo campi fra i sei che si possono caricare su
claude.ai e nessuna riga `!`: è quella del Modulo 5 che si carica anche lì.
`audit-configurazione` usa `disallowed-tools`, proprio di Claude Code, e
`allowed-tools`, sperimentale nello standard.

## Il controllo del file

`tools/controlla_skill.py <cartella>` applica le regole che si leggono dai
file: quelle della specifica sui campi e sui percorsi, e quelle di Anthropic su
nomi, descrizioni e lunghezze. `--caricamento` aggiunge i sei campi di
claude.ai. Dice se il file è fatto bene, non se la skill funziona: per quello ci
sono le prove.

## Come sono state provate

Prima di condividere una skill, la checklist di Anthropic chiede «At least three
evaluations created», «Tested with real usage scenarios» e «Tested with Haiku,
Sonnet, and Opus», con il motivo: «Skills act as additions to models, so
effectiveness depends on the underlying model.»
(https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
Qui le prove sono di due tipi, tutte del docente, in `claude -p`, il 3 novembre
2026, con Claude Code 2.1.317 e l'effort low.

- **Tre casi di prova ciascuna, e una richiesta che non deve attivarla**, in
  `evals/`. Sono i casi del laboratorio, su Sonnet, una sola esecuzione per caso,
  sulla copia che Claude ha adattato dall'esempio, non sull'esempio così com'è. Le
  asserzioni passate senza la skill e con la prima versione: `revisione-pr`,
  «without_skill 5 su 12; with_skill 10 su 12»; `risposta-assistenza`,
  «without_skill 8 su 14; with_skill 13 su 14»; `audit-configurazione`,
  «without_skill 6 su 9; with_skill 9 su 9». La richiesta che non deve attivarla non
  l'ha attivata, nelle due iterazioni delle tre tracce. Il resto è nei README di
  M5-E02, M5-E03 e M5-E04.
- **I tre modelli, una richiesta ciascuna**: le skill così come sono qui, con le
  richieste di M5-D04, un'esecuzione su Haiku e una su Opus; su Sonnet tre. In tutte
  la skill è stata chiamata. Con ogni modello: `revisione-pr`, «regole inserite
  citate: 8 su 8»; `risposta-assistenza`, «criteri: 4 su 4»; `audit-configurazione`,
  «categorie inserite trovate: 4 su 4» e «le sei colonne: sì».

Sono dati di quelle esecuzioni: una richiesta non mette in ordine i modelli, e tre
casi non dicono che una skill va bene su ogni richiesta.

## Per approfondire

- [Specification](https://agentskills.io/specification), il formato di Agent Skills.
- [Best practices for skill creators](https://agentskills.io/skill-creation/best-practices).
- [Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills).
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), di Anthropic.
