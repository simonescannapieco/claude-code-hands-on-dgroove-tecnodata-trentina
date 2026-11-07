# Modulo 6 — Projects e Context Engineering

Le demo e le esercitazioni del sesto modulo: che cosa c'è nel contesto di
Claude, e come lo si decide. Si guarda che cosa entra all'avvio e che cosa
quando serve, quanto pesa una riga, che cosa succede a una modifica fatta a
sessione avviata; poi si controlla che un CLAUDE.md sia caricato, e in un
laboratorio di circa un'ora un CLAUDE.md si prova come il codice: le stesse
richieste senza, con una prima versione e con una seconda. Ogni elemento ha la
sua cartella, con un `README.md` che spiega che cosa fare; si comincia sempre
da `tools/prepara_esercizio.sh <ID>`, come spiega il `README.md` alla radice
del repository.

| elemento | che cosa | dove |
|---|---|---|
| M6-D01 | Il documento che nessun modello ha letto | demo |
| M6-D02 | Che cosa entra all'avvio, e che cosa quando serve | demo |
| M6-E01 | Che cosa vede Claude | esercitazione |
| M6-D03 | Il comando dei test: Claude andrebbe a cercarlo? | demo |
| M6-D04 | Una modifica a sessione avviata, e dopo `/compact` | demo |
| M6-E02 | Un CLAUDE.md per il gestionale | laboratorio, traccia del gestionale |
| M6-E03 | Un CLAUDE.md per la rete | laboratorio, traccia della rete |
| M6-D05 | La stessa domanda, in un progetto di claude.ai | demo; la potete rifare sul vostro account, se volete |

Tutto si svolge in Claude Code, sui progetti sintetici di `progetti/`, tranne
M6-D05, su claude.ai. Ciò che Claude Code legge va ad Anthropic, per questo in
aula non si lavora su file vostri.

Il laboratorio ha due tracce, una a testa: il gestionale (M6-E02) o la rete
(M6-E03). In tutte e due si comincia senza CLAUDE.md, come consiglia Anthropic,
e si guarda che cosa fa Claude con tre richieste; poi si scrive una prima
versione con `/init` e con gli appunti del team, si rifanno le stesse
richieste, si corregge e si riprova. `tools/prova_contesto.sh` esegue ogni
richiesta in una sessione nuova, in una copia pulita dello spazio di lavoro, e
l'hook `InstructionsLoaded` dice che cosa si è caricato e perché.

Prima di cominciare: `tools/verifica_ambiente.sh` tutto verde.

Le cartelle: `s5_projects_context/` (tutto il modulo), poi una cartella per
ogni parte che ha demo o esercitazioni, con il nome del sotto-deck delle
slide.

Le cartelle `demo/` delle demo contengono dei `CLAUDE.md` e un
`CLAUDE.local.md`, i file che le demo mettono alla prova: una sessione di
Claude Code aperta alla radice del repository li carica appena legge, scrive o
modifica un file nella loro cartella («Files in subdirectories load on
demand.», https://code.claude.com/docs/en/memory).
