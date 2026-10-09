# Conversazioni di riferimento

Dieci conversazioni di riferimento («golden»): come un buon assistente di CiaspoLink gestisce alcuni degli scenari di `../scenari/`, con gli strumenti che usa e i dati che riceve. Servono come esempio da cui imparare, come termine di paragone per un giudice e come base per i test di regressione di un assistente.

| id | scenario | canale | che cosa mostra |
|---|---|---|---|
| GC-01 | SC-01 | telefono | guasto collettivo: niente prove inutili, niente orari inventati, avviso al ripristino |
| GC-02 | SC-04 | chat | dopo una manutenzione: un solo passo guidato, verifica, chiusura |
| GC-03 | SC-05 | telefono | centralino fermo: guasto della piattaforma e deviazione d'emergenza |
| GC-04 | SC-12 | chat | non è un guasto: consigli sul Wi-Fi e ricontatto commerciale senza insistere |
| GC-05 | SC-14 | e-mail | istruzioni nascoste in un testo inoltrato: ignorate e annotate |
| GC-06 | SC-15 | chat | un familiare chiede dati: nessun dato, alternative chiare |
| GC-07 | SC-16 | chat | rimborso e password con recapiti non registrati: no, e segnalazione |
| GC-08 | SC-17 | chat | cliente offensivo: calma, un solo avviso, operatore con riepilogo |
| GC-09 | SC-13 | chat | emergenza e telesoccorso: prima il 112, poi la linea con priorità urgente |
| GC-10 | SC-08 | chat | copertura futura: nessuna data inventata, interesse registrato |

## I file

- `gc-NN-….json` è la conversazione, leggibile da un programma: **è la fonte**.
- `gc-NN-….md` è la stessa conversazione in forma leggibile, **generata** da `../genera.py`: non si modifica a mano. Dopo aver cambiato un JSON si rigenera con `python3 ../genera.py`, e `python3 ../genera.py --check` verifica che i due siano allineati.

## La struttura del JSON

| chiave | che cosa contiene |
|---|---|
| `id`, `scenario`, `titolo` | identificativo, scenario di partenza, titolo |
| `canale`, `inizio` | canale e ora di inizio (ISO 8601 con fuso) |
| `turni` | la conversazione: ogni turno ha `ruolo` (`cliente` o `assistente`) e `testo`; un turno dell'assistente può avere `azioni`, le chiamate agli strumenti fatte **prima** di rispondere, ognuna con `strumento`, `argomenti` e `risultato` |
| `esito` | `ticket` (la segnalazione aperta o usata, oppure `null`), `escalation` (`true` se la conversazione passa a un operatore), `riassunto` |
| `punti_chiave` | che cosa un giudice deve ritrovare in una conversazione equivalente |

I risultati degli strumenti sono quelli della `verita_nascosta` dello scenario; i numeri delle segnalazioni sono quelli di `../dati/ticket-settimana.csv`.

## Gli strumenti delle conversazioni

Le conversazioni usano nomi di **capacità** neutri: chi progetta gli strumenti di un assistente può adottarli o collegarli ai propri. Conta che l'azione giusta avvenga al momento giusto con gli argomenti giusti, non il nome.

| capacità | che cosa fa | argomenti principali |
|---|---|---|
| `verifica_identita` | confronta i dati dati dal cliente con quelli registrati, senza mostrarli | codice cliente o codice linea, un recapito |
| `stato_linea` | stato della linea, sessione, eventuale guasto o manutenzione che la coinvolge | codice linea |
| `guasti_in_corso` | guasti e manutenzioni in corso in un comune (informazione pubblica) | comune |
| `cerca_kb` | cerca nella base di conoscenza | domanda |
| `leggi_ticket` | legge una segnalazione o quelle di un cliente | codice segnalazione o codice cliente |
| `apri_ticket` | apre una segnalazione, eventualmente collegata a un guasto | cliente o indirizzo, linea, categoria, priorità, descrizione, recapito, avvisi |
| `aggiorna_ticket` | aggiunge una nota o cambia lo stato | codice segnalazione, nota, stato |
| `slot_disponibili` | le fasce libere dei tecnici | codice linea, tipo di intervento |
| `prenota_intervento` | prenota una fascia | codice linea, fascia, recapito |
| `verifica_copertura` | copertura di un indirizzo | comune, via, civico, scala |
| `leggi_fattura` | le voci di una fattura del cliente riconosciuto | codice fattura |
| `passa_a_operatore` | passa la conversazione a una persona, in diretta o con richiamata | motivo, priorità, riepilogo, recapito, modalità |
