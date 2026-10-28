# Modulo 4 — Claude Code e agenti

Le demo e le esercitazioni del quarto modulo: Claude Code come agente
nel repository. Si installa e si configura, gli si dà un server MCP, lo
si guarda lavorare una richiesta alla volta, gli si concede fiducia per
gradini, lo si fa delegare a un subagent e lavorare in parallelo; poi un
file mai visto e un laboratorio di circa due ore, in due parti. Ogni
elemento ha la sua cartella, con un `README.md` che spiega che cosa fare;
si comincia sempre da `tools/prepara_esercizio.sh <ID>`, come spiega il
`README.md` alla radice del repository.

| elemento | che cosa | dove |
|---|---|---|
| M4-D01 | La chiave che scavalca il Pro | demo; la provate anche voi, senza chiamate al modello |
| M4-D02 | Un server MCP per la copertura | demo; poi aggiungete il server e lo interrogate |
| M4-D03 | Un giro del ciclo, registrato | demo |
| M4-D04 | Tre gradini, tre garanzie | demo; poi provate la regola deny |
| M4-D05 | Il controllo che non si salta | demo |
| M4-D06 | Delegare la lettura | demo |
| M4-D07 | Due filoni, due worktree | demo |
| M4-D08 | Il log in una pipe | demo |
| M4-E01 | Un file mai visto | esercitazione, il riscaldamento del laboratorio |
| M4-E02 | Una funzione nuova, con i test | laboratorio, traccia (a) |
| M4-E03 | Un modulo opaco: documentarlo e proporre il refactoring | laboratorio, traccia (b) |
| M4-E04 | Uno script operativo che gira davvero | laboratorio, traccia (c), nel gestionale |
| M4-E05 | Il rapporto quotidiano dei log | laboratorio, traccia (c), sulla rete |

Tutto si svolge in Claude Code, sui progetti sintetici di `progetti/`:
il gestionale e la rete di CiaspoLink, e il piccolo `progetti/urgenze/`.
Ciò che Claude Code legge va ad Anthropic, per questo in aula non si
lavora su codice vostro.

Il laboratorio ha tre tracce, una a testa, e la terza ha due varianti:
il controllo notturno del gestionale (PHP) o il rapporto quotidiano dei
log della rete (Bash o Python). In ogni traccia almeno un subagent, un
controllo che Claude può eseguire, prima il piano, piccoli passi con un
commit ciascuno. Alla fine della prima parte un commit e una nota,
`NOTA.md`, da cui riparte la seconda.

Prima di cominciare: `tools/verifica_ambiente.sh` tutto verde. M4-D02
usa `uv` (il server MCP del corso è in Python, con FastMCP), le tracce
del gestionale usano PHP attraverso `tools/php.sh`.

Le cartelle: `s3_agente_nel_repository/` (tutto il modulo), poi una
cartella per ogni parte che ha demo o esercitazioni, con il nome del
sotto-deck delle slide.
