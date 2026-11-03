# Modulo 5 — Skills

Le demo e le esercitazioni del quinto modulo: rendere Claude costantemente
bravo nel vostro compito, non solo in uno generico. Si misura che cosa entra
nel contesto e quando, che cosa fa scattare una skill, che cosa garantisce
Claude Code intorno a lei; poi una prima skill, e un laboratorio di circa
settanta minuti in cui una skill si prova come il codice: con i casi di prova,
una baseline e un'iterazione. Ogni elemento ha la sua cartella, con un
`README.md` che spiega che cosa fare; si comincia sempre da
`tools/prepara_esercizio.sh <ID>`, come spiega il `README.md` alla radice del
repository.

| elemento | che cosa | dove |
|---|---|---|
| M5-D01 | Lo stesso testo in tre posti | demo |
| M5-D02 | La descrizione decide | demo |
| M5-E01 | La prima skill | esercitazione |
| M5-D03 | Tre garanzie | demo |
| M5-D04 | Prima e dopo, tre archetipi | demo |
| M5-E02 | Una skill di revisione contro le convenzioni del team | laboratorio, traccia (a) |
| M5-E03 | Una skill di risposta nel tono di voce dell'assistenza | laboratorio, traccia (b) |
| M5-E04 | Una skill di audit delle configurazioni | laboratorio, traccia (c) |
| M5-D05 | La stessa skill in claude.ai | demo; la potete rifare sul vostro account, se volete |

Tutto si svolge in Claude Code, sui progetti sintetici di `progetti/`, tranne
M5-D05, su claude.ai. Ciò che Claude Code legge va ad Anthropic, per questo in
aula non si lavora su file vostri.

Il laboratorio ha tre tracce, una a testa. In ogni traccia i casi di prova ci
sono già, in `.claude/skills/<skill>/evals/evals.json`: si guarda che cosa fa
Claude senza la skill, si parte dalla skill di esempio o dal modello in
`riferimenti/`, si prova, si legge, si cambia e si riprova.
`tools/prove_skill.sh` esegue ogni prova in una sessione nuova e scrive i file
nella forma della guida dello standard Agent Skills.

Prima di cominciare: `tools/verifica_ambiente.sh` tutto verde.

Le cartelle: `s4_skills/` (tutto il modulo), poi una cartella per ogni parte
che ha demo o esercitazioni, con il nome del sotto-deck delle slide.
