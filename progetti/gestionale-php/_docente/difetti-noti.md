# Gestionale CiaspoLink: difetti inseriti e appigli per le esercitazioni

**Solo per il docente.** La cartella `_docente/` è esclusa dalla copia dei partecipanti (`.gitattributes`, `export-ignore`). Niente di quanto segue compare nei file visibili ai partecipanti né nei commenti del codice. I numeri di riga valgono per la versione generata il 2026-10-09; se il codice cambia, ricontrollarli con `grep -n`.

## 1. Difetti inseriti apposta

| # | dove | il difetto | come si vede | correzione attesa |
|---|---|---|---|---|
| D1 | `src/Fatturazione/CalcoloTotali.php:23` | **IVA troncata**: `(int) ($imponibile * 22 / 100)` taglia i decimali invece di arrotondare. | 1.136 fatture su 1.905 dello storico hanno l'IVA più bassa di un centesimo. Esempio: FT-2025-001397 di CL-000101 (Laura Prova), imponibile 25,90 €, IVA 5,69 € invece di 5,70 €. `CalcoloTotaliTest` passa perché usa importi con IVA intera. | `(int) round(...)`, cioè metà per eccesso (convenzioni 5.2, commento di `schema.sql`), più un test con imponibile 22,90 € → IVA 5,04 €. Lo storico resta com'è: si discute come trattarlo (note di credito? nulla sotto una soglia?). |
| D2 | `legacy/fattura_stampa.php:28-34`, con `legacy/inc/funzioni.inc.php:68` | **La stampa ricalcola i totali** riga per riga, in virgola mobile, invece di mostrare quelli registrati. | FT-2026-000313 di CL-000106: stampa 67,04 €, in tabella 67,03 €. Un cliente se n'è accorto (vedi §2, TK-2026-00061). | Stampare i totali della tabella `fatture`, e correggere D1. |
| D3 | `legacy/listino.inc.php:48`, `:56`, `:63` | **Rateo su un mese fisso di 30 giorni**: in attivazione `30 − giorno + 1`, in cessazione `giorno`. | FT-2026-000313: linea attivata il 16/02/2026, fatturati «15 gg» per 15,95 € invece di 13/28 × 31,90 = 14,81 €. Casi estremi (non presenti nei dati): attivata il 31 → rateo 0; cessata il 31 → 31/30 del canone. | Giorni effettivi del mese (`Periodo::giorni()`), convenzioni 5.3 e commento di `righe_fattura` in `schema.sql`. Il generatore `genera.py` replica lo stesso calcolo per lo storico. |
| D4 | `src/Attivazioni/AttivazioneRepository.php:55` | **Giorno calcolato in UTC**: `date(a.completata_il)` di SQLite converte l'istante in UTC, quindi le attivazioni completate tra 00:00 e 02:00 (01:00 d'inverno) finiscono nel giorno precedente. Il collaudo automatico chiude le attivazioni proprio a quell'ora. | `bin/esporta-attivazioni.php --giorno=2026-09-08` non contiene AT-2026-0032 (completata 2026-09-08T00:34+02:00), che compare nel file del 07. AT-2026-0036 (10/09 alle 01:12) va nel file del 09, e quello del 10 resta vuoto. | `substr(a.completata_il, 1, 10) = :giorno` (convenzioni 5.5), più un test di integrazione con un'attivazione notturna. |
| D5 | `legacy/inc/db.inc.php:80`; `legacy/clienti_lista.php:24`, `:33`; `legacy/ticket_nuovo.php:38` | **SQL injection**. `db_escape()` è `addslashes()`, che in SQLite non protegge (l'apice si raddoppia, non si scappa con `\`). L'ordinamento arriva da `$_GET['ordina']` dritto nella query. In `ticket_nuovo.php` categoria, priorità e canale entrano senza nemmeno `db_escape()`. | Cercare `dell'Esempio` nella pagina Clienti dà «Errore nella query», con l'SQL in chiaro. | Query preparate (convenzioni 7.1) ed elenco chiuso per l'ordinamento. Meglio ancora: rifare la ricerca con `ClienteRepository::cerca()`. |
| D6 | `legacy/clienti_lista.php:41`, `:52`; `legacy/ticket_nuovo.php:41`, `:56`; `legacy/cliente_scheda.php:25`, `:56` | **XSS**: valori stampati senza `htmlspecialchars()`. Riflesso: il testo cercato. Memorizzati: le note del cliente e l'oggetto del ticket. | `index.php?pagina=clienti&q=<i>x</i>` | Escape in uscita (convenzioni 8.1, valida per il codice che esce da `legacy/`). |
| D7 | `legacy/provvigioni.inc.php:35`, `:53` contro `src/Rivenditori/CalcoloProvvigioni.php:35`, `:51` | **Regola duplicata e discordante: provvigioni.** Il legacy (che scrive la tabella `provvigioni`, lanciato da `bin/provvigioni-rivenditori.php` e dalla chiusura) conta le attivazioni **richieste** nel mese, di ogni tipo, non annullate, a 40/80 € fissi. La classe nuova (pagina Provvigioni) conta le **nuove** attivazioni **completate** nel mese, con le tariffe di ogni rivenditore (RV-003 50/90 €, RV-009 45/85 €, RV-011 35/70 €). | Pagina Provvigioni, agosto 2026: RV-003 calcolata 140 €, registrata 120 €; RV-001, RV-004, RV-006 calcolate 0 € contro 80, 40 e 80 € registrati (richieste di agosto non ancora completate). Il rivenditore ha aperto TK-2026-00202. | Vale la classe nuova (convenzione 2023, docblock della classe). Il legacy va sostituito o allineato (convenzioni 9.6); i mesi già liquidati non si toccano. |
| D8 | `legacy/inc/funzioni.inc.php:92` e `legacy/clienti_lista.php:75` contro `legacy/inc/config.inc.php:18` | **Regola duplicata e discordante: morosità.** Il badge «MOROSO» compare da una fattura scaduta, ma la chiusura sospende solo da due (`$SOGLIA_MOROSITA`). | Un cliente attivo con una sola fattura scaduta appare moroso nell'elenco e nella scheda, ma non viene mai sospeso. | Una sola definizione, in un posto solo. |
| D9 | `src/Report/ReportFatturato.php:31`, con `src/Fatturazione/FatturaRepository.php:37` | **N+1**: una query per le fatture di ogni cliente, più una per le righe di ogni fattura; circa 2.100 query per un anno di dati. Le righe neppure servono. | Pagina Fatturato: misurare le query, o fare leggere il codice. | Una query aggregata per zona (convenzioni 7.3). |

Fuori elenco ma veri, se un partecipante li trova: `NumeratoreFatture` non regge due fatturazioni in parallelo (`MAX(id) + 1` senza blocco); la chiusura sovrascrive le note del cliente quando lo sospende; il legacy usa un proprio percorso del database (`legacy/inc/config.inc.php:13`) invece di `config/config.php`.

## 2. Tracce nei dati

- **TK-2026-00061** (CL-001002, 9 marzo 2026): «il totale sulla copia della fattura FT-2026-000316 … è di un centesimo più alto dell'importo pagato». Porta a D1 e D2.
- **TK-2026-00202** (rivenditore RV-003, 4 settembre 2026, in lavorazione): «le provvigioni di agosto non corrispondono alle attivazioni completate nel mese». Porta a D7.

## 3. Appigli per le esercitazioni

**Modulo 4: una funzione da aggiungere con i test.** Lacune lasciate apposta (non sono difetti):
- l'elenco ticket non filtra per **apparato** né per **intervallo di date** (`FiltroTicket`, `TicketRepository::cerca`, `templates/ticket_elenco.php`). Nella settimana dei disservizi serve. Attenzione: i ticket dei clienti collegati a un disservizio non hanno `apparato_id`; si arriva all'apparato dal ticket padre o dalla linea.
- non c'è un elenco delle **linee coinvolte** da un guasto su un apparato o una porta, per esempio olt-pergine-01, porta 0/1/3: 40 linee attive l'8 settembre.

**Modulo 4: un modulo legacy da documentare e da rifattorizzare.** `legacy/chiusura_mese.inc.php`: `chiusura_mese()` va dalla riga 24 alla 301 (278 righe) e contiene sei responsabilità in fila, globali, numeri magici (24 ore, 1000 e 10000 centesimi, scadenza a 30 giorni), nomi misti italiano-inglese, un blocco commentato e il commento «non spezzare in più funzioni». Alternativa più breve: `legacy/listino.inc.php`, chiamato dal codice nuovo attraverso `src/Legacy/PonteListino.php`.

**Modulo 4: uno script operativo che gira davvero.** Non esiste un controllo notturno. I dati contengono anomalie da trovare:
- LN-001062 (CL-001061) e LN-001092 (CL-001090): cliente cessato con la linea ancora attiva e fatturata (la disdetta è stata registrata solo in anagrafica; fatture da giugno non pagate);
- LN-001156 (CL-001152): linea attiva senza apparato né porta;
- AT-2026-0016, AT-2026-0019, AT-2026-0022: ferme in verifica tecnica da maggio e giugno;
- TK-2026-00172, TK-2026-00180, TK-2026-00186: in attesa del cliente senza aggiornamenti da oltre tre settimane;
- 11 fatture scadute; 3 clienti sospesi per morosità (CL-001010, CL-001011, CL-001043).

Gli script esistenti di `bin/` sono i modelli da imitare (opzioni, uscite 0/1/2, messaggi su STDERR).

**Modulo 5: revisione di una pull request.** `docs/convenzioni.md` ha regole numerate e verificabili. D1, D4 e D9 violano le regole 5.2, 5.5 e 7.3 anche nel codice nuovo. `phpcs` è pulito su tutto il codice nuovo, quindi la revisione deve guardare oltre lo stile.

**Modulo 6: il CLAUDE.md del progetto.** Il progetto non ha `CLAUDE.md` né `.claude/`. Materiale da descrivere: comandi (`tools/php.sh` …), struttura, schema (`database/schema.sql`), operazioni ricorrenti (`bin/`), le convenzioni, il confine con `legacy/`, i dati generati da non modificare a mano.

## 4. Storia comune agli altri due progetti

Clienti CL-000101…106 e linee LN-000201…206 come da brief. Apparati olt-pergine-01, olt-trento-01, olt-rovereto-01, bng-trento-01, ptp-cles-01, bts-cles-01, sbc-trento-01. Ticket principali dei disservizi della settimana, con i ticket dei clienti collegati:

| disservizio | ticket | collegati |
|---|---|---|
| mar 08, fibra tagliata, olt-pergine-01 porta 0/1/3, 10:12–11:40 | TK-2026-00210 | 8, tra cui LN-000201 |
| mer 09, ponte radio ptp-cles-01 | TK-2026-00221 | 4, tra cui LN-000202 e LN-000204 |
| gio 10, manutenzione bng-trento-01, 02:00–02:30 (avviso del 03/09) | TK-2026-00201 | 2 |
| ven 11, registrazioni SIP su sbc-trento-01 | TK-2026-00232 | 3, tra cui LN-000203 (CL-000103) |
| sab 12, pool DHCP della VLAN business di Rovereto (apparato non indicato) | TK-2026-00242 | 2 |

Due disservizi passati: TK-2025-00670 (olt-trento-01, 21/11/2025) e TK-2026-00032 (neve sul ponte di Cles, 3–4/02/2026, da cui tre note di credito per indennizzo a febbraio).
