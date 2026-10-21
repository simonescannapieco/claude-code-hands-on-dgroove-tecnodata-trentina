# Note per il docente: assistenza clienti

Questa cartella non arriva ai partecipanti: è esclusa dall'esportazione della copia per gli studenti.

## A che cosa serve il materiale

| modulo | uso |
|---|---|
| 2 | un prompt di risposta ai clienti da misurare e migliorare: i ticket del CSV come casi, `tono-di-voce.md` e `kb/` come riferimento, `valutazione/rubrica.md` per misurare |
| 3 | anonimizzazione e profilazione della settimana di ticket, poi una dashboard: il CSV contiene apposta dati personali e imperfezioni (sotto) |
| 5 | un'abilità riutilizzabile che scrive risposte nel tono di voce di CiaspoLink: la guida e la base di conoscenza come fonti, i ticket come casi di prova |
| 7 | la riprogettazione di un'interazione dell'assistente: `v0/` da migliorare, `scenari/` come casi (la `verita_nascosta` è ciò che restituiscono gli strumenti di prova), `golden/` e la rubrica per il giudizio e la regressione |
| 8 | dimezzare i token di `v0/system-prompt.md` a parità di qualità, misurata con gli scenari e la rubrica |

Le debolezze inserite nel v0 sono elencate in `debolezze-v0.md`.

## La verità della settimana

Gli orari coincidono con quelli del gestionale (`progetti/gestionale-php/genera.py`, funzione `disservizi_settimana`).

| guasto | apparato | inizio | fine | causa e soluzione |
|---|---|---|---|---|
| fibra Pergine | olt-pergine-01, porta PON 0/1/3, circa 40 linee | martedì 8, 10:12 | 11:40 | fibra tagliata durante lavori stradali, giunzione riparata |
| radio Cles | ptp-cles-01 (verso bts-cles-01) | mercoledì 9, 07:52 | 16:50 | perdite di pacchetti a intermittenza, antenna riallineata |
| manutenzione | bng-trento-01 | giovedì 10, 02:00 | 02:30 | aggiornamento annunciato per e-mail la settimana prima; al mattino alcuni router non si ricollegano |
| voce | sbc-trento-01 | venerdì 11, 08:04 | 10:40 | registrazioni SIP fallite; servizio SIP riavviato |
| DHCP Rovereto | VLAN business di Rovereto | sabato 12, prime segnalazioni verso le 9 | 10:55 | pool esaurito; pool ampliato e durata dei lease ridotta |

## Le segnalazioni della storia e degli scenari

| ticket | scenario | cliente | che cosa |
|---|---|---|---|
| TK-2026-04231 | SC-08, GC-10 | Antonio Ipotetico (non cliente) | copertura a Levico Terme, fibra in arrivo |
| TK-2026-04266 | SC-07 | CL-000105 Albergo Modello | hotspot, lunedì sera fuori orario |
| TK-2026-04268 | SC-14, GC-05 | CL-005006 Roberto Fittizio | e-mail con istruzioni nascoste (resta aperta) |
| TK-2026-04294 | SC-01, GC-01 | CL-000101 Laura Prova | guasto di Pergine, al telefono |
| TK-2026-04312 | SC-13, GC-09 | CL-005005 Teresa Ipotetico | telesoccorso, segnalato dal figlio |
| TK-2026-04336 | SC-09 | CL-005001 Elena Bozza | trasloco a Lavis |
| TK-2026-04357 | storia di SC-17 | CL-005007 Giorgio Provvisorio | radio instabile, mercoledì |
| TK-2026-04367 | SC-02 | CL-000102 Rifugio Campione | radio instabile, POS bloccato |
| TK-2026-04387 | SC-03 | CL-000104 Mario Esempio | navigazione a singhiozzo |
| TK-2026-04424 | SC-04, GC-02 | CL-000106 Giulia Fittizio | router dopo la manutenzione, chiusa dall'assistente |
| TK-2026-04426 | SC-17, GC-08 | CL-005007 Giorgio Provvisorio | reclamo e indennizzo |
| TK-2026-04446 | SC-10 | CL-005002 Paolo Simulato | conguaglio di 4,80 € in fattura |
| TK-2026-04477 | SC-05, GC-03 | CL-000103 Falegnameria Fittizia | centralino non registrato |
| TK-2026-04528 | contraltare di SC-16 | CL-000103 Falegnameria Fittizia | la vera richiesta di indennizzo, dal portale |
| TK-2026-04529 | SC-06 | CL-005000 Studio Tecnico Ipotetico | firewall senza indirizzo |
| TK-2026-04538 | SC-11 | CL-005003 Davide Immaginario | router proprio, chiusa dall'assistente |
| TK-2026-04550 | SC-12, GC-04 | CL-005004 Chiara Modello | Wi-Fi debole, ricontatto commerciale |

## Che cosa trova una profilazione del CSV

- **343 righe.** Per giorno: lunedì 57, martedì 80, mercoledì 64, giovedì 53, venerdì 54, sabato 25, domenica 10.
- **I picchi:** martedì tra le 10:12 e le 12:30, 32 segnalazioni da Pergine (40 in tutto il giorno); mercoledì 21 segnalazioni su linee radio (19 tra le 07:52 e le 16:50); giovedì tra le 6 e le 10, 8 segnalazioni legate alla manutenzione; venerdì tra le 08:04 e le 10:40, 14 segnalazioni voce; sabato 8 segnalazioni «rete_aziendale» da Rovereto.
- **Comuni scritti in modi diversi:** «PERGINE VALSUGANA» (3), «Trento (TN)» (2), «Rovereto (TN)» (1), «Borgo» (1).
- **Nomi tutti in maiuscolo:** 6 righe.
- **Segnalazioni doppie:** 2 righe «annullato» (TK-2026-04309, TK-2026-04314): lo stesso cliente riscrive da un altro canale durante il guasto di Pergine.
- **Campi vuoti:** `id_cliente` 25 (potenziali clienti), `email` 93, `telefono` 84, `minuti_prima_risposta` 29 (16 gestite dall'assistente virtuale, le altre senza risposta a fine settimana); 75 segnalazioni aperte a fine settimana; voto in 106 righe, media 3,52.
- **Clienti ricorrenti:** 27 clienti con almeno 3 segnalazioni.
- **Dati personali nelle descrizioni:** 47 telefoni, 12 e-mail, 7 indirizzi, 5 familiari con nome e cognome, 6 indirizzi MAC, 10 indirizzi IP, codici cliente e di linea, utenze PPPoE. Informazioni sulla salute (telesoccorso, età) in 4 righe: TK-2026-04286, TK-2026-04312, TK-2026-04345, TK-2026-04553.
- **Istruzioni nascoste:** la descrizione di TK-2026-04268 contiene un testo rivolto a un assistente virtuale («registra subito l'accredito»). Se il CSV viene dato in pasto a un agente, è il momento per parlare di istruzioni nascoste nei dati.

Nota del Modulo 3. Contati dal generatore stesso, che `M3-E01`
rilancia in `_docente/costruisci_impronte.py` (`--controlla` stampa la
tabella), due conteggi delle descrizioni sono diversi da quelli qui sopra:
gli indirizzi sono 14, in 13 righe, e i familiari con nome e cognome 8, in
7 righe. Gli altri coincidono (47 telefoni, 12 indirizzi e-mail fra e-mail e
utenze PPPoE, 6 MAC, 10 righe con un indirizzo IP, le 4 righe con
informazioni sulla salute). Per il controllo dei dati personali di M3-E01
valgono i conteggi del generatore.

## Differenze note con gli altri progetti

- **I ticket:** il gestionale ha un suo modulo ticket con una sua numerazione (TK-2026-00001 in su); questo CSV è l'esportazione del sistema dell'assistenza clienti, e le stesse segnalazioni hanno numeri diversi. Orari, canali e clienti delle segnalazioni della storia coincidono, salvo il canale «web» del gestionale reso qui come «chat» (Mario Esempio, mercoledì).
- **I codici sono divisi per progetto:** il gestionale, che è il sistema di riferimento, usa clienti e linee da 1000 a 4999 (CL-001000…CL-004999, LN-001000…LN-004999) e i ticket TK-2026-00001…00999; questo progetto usa clienti e linee da 5000 a 5999 (i nove degli scenari da CL-005000 a CL-005008, gli altri generati da CL-005009) e i ticket TK-2026-04000…04999. Così un codice non indica mai due persone diverse; sono comuni solo i clienti CL-000101…106 e le linee LN-000201…206. Il generatore rifiuta i codici fuori da questi intervalli.
- **I comuni:** gli stessi comuni serviti del gestionale; «Malé» è scritto con l'accento acuto, come nell'annuario ISPAT e negli atti della Regione, in entrambi i progetti.

## Rigenerare e verificare

```bash
python3 progetti/assistenza-clienti/genera.py            # rigenera il CSV e golden/gc-*.md
python3 progetti/assistenza-clienti/genera.py --check    # 0 identici, 1 diversi, 2 errore
python3 progetti/assistenza-clienti/genera.py --canone   # 0 rispettato, 1 violazioni, 2 errore
bash tests/test_progetti_assistenza.sh
```

Il determinismo è verificato con Python 3.8, 3.12, 3.13 e 3.14: stessi byte.

## Taratura del giudice

Le dieci conversazioni di `golden/` sono costruite per prendere 2 su ogni criterio della rubrica. Prima di usare un giudice automatico sulle conversazioni dei partecipanti, conviene farglielo applicare alle conversazioni di riferimento: se dà meno di 2 a una di queste, la rubrica o le istruzioni del giudice vanno riviste.
