# Modulo 7 — Costruire e migliorare assistenti basati su LLM

Le demo e le esercitazioni del settimo modulo: come si costruisce un assistente per i clienti, come si dà accesso agli strumenti e alla conoscenza, come si difende e come si misura. L'assistente è quello di CiaspoLink, in `progetti/assistenza-clienti/`, e lo si prova con Claude Code in Claude Pro, senza API: un banco di prova locale (`progetti/assistenza-clienti/banco/`) fa girare il system prompt e le definizioni degli strumenti su dati sintetici, con un server MCP al posto dei sistemi veri. Ogni elemento ha la sua cartella, con un `README.md` che spiega che cosa fare; si comincia sempre da `tools/prepara_esercizio.sh <ID>`, come spiega il `README.md` alla radice del repository.

| elemento | che cosa | dove |
|---|---|---|
| M7-D01 | Cambia solo il system prompt | demo |
| M7-D02 | Solo una POST | demo del docente, sull'API |
| M7-D03 | Il modello chiede, il codice risponde | demo |
| M7-D04 | La descrizione è il contratto | demo |
| M7-E01 | Il banco di prova | esercitazione |
| M7-E02 | Riprogettare un'interazione | laboratorio |
| M7-D05 | Cercare per significato | demo del docente, con un modello locale |
| M7-D06 | Tre brani, una risposta con la fonte | demo |
| M7-D10 | L'assistente in un progetto di claude.ai | demo; la potete rifare sul vostro account, se volete |
| M7-D07 | Tre difese a confronto | demo |
| M7-D08 | Il brano avvelenato | demo |
| M7-D09 | La guardia nel codice | demo |
| M7-E03 | Valutare e non regredire | laboratorio |

Tutto si svolge in Claude Code, sui dati sintetici di `progetti/`, tranne M7-D10 su claude.ai; M7-D02 e M7-D05 sono del docente. Ciò che Claude Code legge va ad Anthropic, per questo in aula non si lavora su dati vostri.

Prima di cominciare: `tools/verifica_ambiente.sh` tutto verde.

Le cartelle: `s5_anatomia_e_strumenti/` e `s6_conoscenza_e_valutazione/`, poi una cartella per ogni parte che ha demo o esercitazioni, con il nome del sotto-deck delle slide.
