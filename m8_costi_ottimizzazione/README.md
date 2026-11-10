# Modulo 8 — Costi, piano Pro e ottimizzazione

Le demo e le esercitazioni dell'ottavo modulo: quanto costa una risposta, chi la paga e come si fa pagare meno. Sul piano Pro nessuno vi manda una fattura: i consumi li leggete da voi, dal campo `usage` del JSON di `claude -p` e con `/usage` e `/context`. Sull'API, invece, ogni token si paga, e per i conti del docente c'è il conteggio dei token.

| elemento | che cosa | dove |
|---|---|---|
| M8-D01 | Quanti token pesa una frase | demo del docente, sull'API |
| M8-D02 | Il conto dal campo usage | demo |
| M8-D04 | Il modello giusto per il lavoro | demo |
| M8-D03 | La cache, vista nel contatore | demo |
| M8-E01 | Quanto costa una risposta | esercitazione |
| M8-E02 | Metà dei token, a parità di qualità | laboratorio |

Tutto si svolge in Claude Code, sui dati sintetici di `progetti/assistenza-clienti`; M8-D01 è del docente, sulla sua chiave. Ciò che Claude Code legge va ad Anthropic, per questo in aula non si lavora su dati vostri.

Prima di cominciare: `tools/verifica_ambiente.sh` tutto verde.

La cartella è `s6_costi_e_ottimizzazione/`, poi una cartella per ogni parte che ha demo o esercitazioni, con il nome del sotto-deck delle slide.
