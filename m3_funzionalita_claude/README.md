# Modulo 3 — Funzionalità core di Claude (piano Pro)

Le demo e le esercitazioni del terzo modulo: che cosa c'è nel piano Pro
(la chat, i file e le immagini, la ricerca sul web, i progetti, la
memoria) e un laboratorio che porta una settimana di ticket da un file
con dati personali a una dashboard. Ogni elemento ha la sua cartella, con
un `README.md` che spiega che cosa fare; si comincia sempre da
`tools/prepara_esercizio.sh <ID>`, come spiega il `README.md` alla radice
del repository.

| elemento | che cosa | dove |
|---|---|---|
| M3-D01 | Un'immagine leggibile | demo in Claude Code; la provate anche voi in claude.ai |
| M3-D02 | Quando Claude cerca sul web | demo in Claude Code; la provate anche voi in claude.ai |
| M3-D03 | Che cosa vede Claude in un progetto | prova guidata in claude.ai |
| M3-D04 | Una chat senza memoria | prova guidata in claude.ai |
| M3-E01 | Anonimizzare la settimana di ticket | esercitazione in Claude Code |
| M3-E02 | La dashboard della settimana | esercitazione in claude.ai |
| M3-E03 | La stessa dashboard in Claude Code | esercitazione in Claude Code |

Le prove in claude.ai le fate sul vostro account Pro. M3-D03 e M3-D04 si
verificano dalle risposte che copiate nei file dello spazio di lavoro;
M3-D04 lascia un codice di prova nella vostra memoria, e il suo README
spiega come toglierlo.

Il laboratorio è una catena, nell'ordine:

1. **M3-E01** anonimizza in Claude Code la settimana di ticket di
   `progetti/assistenza-clienti/`: Claude scrive lo script dal
   dizionario delle colonne, senza aprire il file con i dati personali, e
   lo corregge finché il controllo dei dati personali passa;
2. **M3-E02** carica il file anonimo in claude.ai: prima i numeri, che
   uno script confronta con quelli veri, poi la dashboard;
3. **M3-E03** fa la stessa dashboard in Claude Code, come pagina HTML
   locale, con un controllo che confronta i suoi numeri con il profilo
   della settimana.

Chi non ha finito M3-E01, o la cui verifica non è uscita con 0, trova
nella cartella di M3-E02 una copia di riferimento del file anonimo, e in
quella di M3-E03 il file anonimo e il profilo. Prima di M3-E01,
`tools/verifica_ambiente.sh` tutto verde.

Le cartelle: `s2_funzionalita_claude/` (tutto il modulo), poi una
cartella per ogni parte che ha demo o esercitazioni,
con il nome del sotto-deck delle slide (`m3_2_chat_file_immagini/`,
`m3_4_ricerca_codice_file/`, `m3_5_progetti_o_chat/`,
`m3_6_memoria_e_dati/`, `m3_e2_anonimizzare/`, `m3_e3_dashboard/`,
`m3_e4_dashboard_locale/`).
