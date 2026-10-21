# Modulo 2 — Prompting avanzato

Le demo e le esercitazioni del secondo modulo: come si progetta un prompt
(gli ingredienti, dove va che cosa, i tag, gli esempi, il ragionamento sui
modelli di oggi) e come lo si misura e lo si migliora. Ogni elemento ha la
sua cartella, con un `README.md` che spiega che cosa fare; si comincia
sempre da `tools/prepara_esercizio.sh <ID>`, come spiega il `README.md`
alla radice del repository.

| elemento | che cosa | dove |
|---|---|---|
| M2-D01 | Prompt A contro prompt B: lo stesso messaggio, due prompt | demo in Claude Code |
| M2-D02 | Il system prompt che non vedete | demo in Claude Code |
| M2-D03 | Solo JSON, o uno schema | demo in Claude Code |
| M2-D04 | Zero-shot contro few-shot | demo in claude.ai, poi in Claude Code |
| M2-D05 | Ragionare, oggi | demo in Claude Code |
| M2-E01 | Il prompt pessimo: misura, riscrivi, rimisura | esercitazione in Claude Code |
| M2-D06 | La galleria degli orrori | demo in Claude Code |
| M2-E02 | Tre prompt, due cicli | esercitazione in Claude Code |

In aula le demo le esegue il docente; quella degli esempi la fate anche
voi, in claude.ai. Le due esercitazioni usano gli stessi attrezzi di
misura: `misura.sh` (la risposta, i controlli scritti in codice e il
giudizio di un subagent con una rubrica, due volte su v0) e
`misura.sh --confronta`, che mette due versioni fianco a fianco e dice
l'esito della pratica della guida di Anthropic che la nuova versione
applica. M2-E01 li introduce su un prompt solo, M2-E02 li usa su tre.
Prima di M2-E01,
`tools/verifica_ambiente.sh` tutto verde.

Il riassunto del modulo, da tenere a portata di mano, è
[`riferimenti/pattern-di-prompt.md`](../riferimenti/pattern-di-prompt.md).

Le cartelle: `s1_progettare_il_prompt/` (la prima parte del modulo) e
`s2_misurare_e_migliorare/` (la seconda), poi una cartella per ogni parte
che ha demo o esercitazioni, con il nome del sotto-deck delle slide
(`m2_1_cambiato_solo_il_prompt/`, `m2_3_ruoli_dei_messaggi/`,
`m2_4_tag_e_struttura/`, `m2_5_esempi/`, `m2_6_ragionamento/`,
`m2_e2_prompt_pessimo/`, `m2_7_galleria_degli_orrori/`,
`m2_e3_tre_prompt_due_cicli/`).
