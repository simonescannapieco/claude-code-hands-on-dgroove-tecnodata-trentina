# Progetti di esempio — il materiale condiviso delle esercitazioni

Le esercitazioni del corso lavorano su tre progetti **sintetici**, inventati da cima a fondo: un piccolo operatore di connettività immaginario, **CiaspoLink S.r.l.**, con il suo gestionale in PHP, la sua rete e la sua assistenza clienti. Nessun file descrive persone, aziende o sistemi reali: ogni somiglianza con un operatore esistente è casuale.

| cartella | che cosa contiene | dove serve |
|---|---|---|
| `gestionale-php/` | il gestionale dell'operatore, scritto in PHP negli anni e mai riscritto: clienti, offerte «Casa» e «Business», linee FTTH e FWA, copertura per indirizzo, attivazioni, rivenditori, ticket, fatture; parti pulite accanto a moduli legacy volutamente oscuri; test PHPUnit parziali; le convenzioni del team in `docs/convenzioni.md` | Moduli 2, 4, 5, 6 |
| `rete/` | configurazioni di apparati nei dialetti che un operatore radio e fibra usa davvero, ciascuna con l'elenco dei problemi inseriti apposta; log syslog, RADIUS/PPPoE, DHCP e di registrazione SIP; l'inventario in CSV; gli allarmi del monitoraggio | Moduli 2, 4, 5 |
| `assistenza-clienti/` | un assistente virtuale «versione 0», volutamente mediocre (system prompt, strumenti, regole di passaggio all'operatore); la base di conoscenza delle procedure di assistenza guidata; gli scenari di prova, anche ostili; le conversazioni di riferimento; il tono di voce; una settimana di ticket in CSV | Moduli 2, 3, 5, 7, 8 |

## L'operatore immaginario

- **Ragione sociale:** CiaspoLink S.r.l. — un nome inventato (le ciaspole sono le racchette da neve). Sede: Via dell'Esempio 1, 38051 Borgo Valsugana (TN).
- **Che cosa fa:** connettività internet in fibra fino a casa (FTTH, fino a 2,5 Gbit/s in download) e via radio (FWA) nelle valli del Trentino, con la tecnologia migliore disponibile a ciascun indirizzo; due famiglie di offerte, «Casa» e «Business»; reti Wi-Fi e sistemi hotspot; telefonia fissa e centralino in cloud (VoIP); servizi IT per le aziende; verifica della copertura e attivazione per indirizzo; assistenza tecnica guidata oppure con operatore; una rete di rivenditori nelle valli.
- **Rete:** OLT GPON/XGS-PON nei centri più grandi, collegamenti radio punto-punto verso le valli, stazioni radio base punto-multipunto per l'FWA, PPPoE con autenticazione RADIUS, DHCP per le linee business, SIP per la voce.

## Regole dei dati sintetici

Valgono per ogni file di `progetti/` e per ogni esercizio che ne deriva. Ogni generatore le controlla sul proprio output.

| dato | regola | esempio |
|---|---|---|
| persone | nome di battesimo comune + un cognome della lista fissa, palesemente inventato: Esempio, Prova, Fittizio, Campione, Modello, Bozza, Simulato, Inventato, Ipotetico, Immaginario, Provvisorio, Fantasia | Laura Prova |
| aziende clienti | nomi inventati con lo stesso criterio | Falegnameria Fittizia S.n.c., Rifugio Campione |
| indirizzi | comuni del Trentino (geografia pubblica), vie inventate e riconoscibili come tali | Via dell'Esempio 12, 38057 Pergine Valsugana (TN) |
| e-mail | solo su `example.org`, dominio riservato agli esempi (RFC 2606), o su un suo sottodominio | laura.prova@example.org |
| nomi di host | solo sotto `example.org` | radius1.ciaspolink.example.org |
| telefoni | `+39` seguito da `00`: un prefisso che nessun numero italiano può avere (00 è il prefisso per le chiamate internazionali), dunque non assegnabile | +39 000 000 0123 |
| IPv4 | solo gli intervalli di documentazione dell'RFC 5737: 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 (maschere e wildcard a parte) | 203.0.113.17 |
| IPv6 | solo 2001:db8::/32 (RFC 3849) | 2001:db8:c1a5::1 |
| MAC | solo 00:00:5e:00:53:00 – 00:00:5e:00:53:ff (RFC 7042) | 00:00:5e:00:53:2a |
| numeri AS | solo 64496–64511 (RFC 5398) | AS64500 |
| partite IVA | 11 cifre con la cifra di controllo volutamente sbagliata; mai un codice fiscale | 00000000001 |
| date e ore | gli eventi della settimana (ticket, log, allarmi) cadono nella settimana sintetica, da lunedì 2026-09-07 a domenica 2026-09-13; la storia che serve a un progetto (contratti, attivazioni, fatture) può andare indietro quanto serve, ma nessun dato va oltre domenica 2026-09-13; ISO 8601, ora italiana con offset (`2026-09-07T08:15:00+02:00`) salvo dove un formato di log ne impone un altro | 2026-09-08T14:32:10+02:00 |
| identificativi | cliente `CL-000123` · linea `LN-000456` · attivazione `AT-2026-0012` · ticket `TK-2026-00123` · fattura `FT-2026-000123` · rivenditore `RV-012` · apparato `<ruolo>-<comune>-<nn>`. I sei clienti e le sei linee con nome (CL-000101…106, LN-000201…206) e i sette apparati sono comuni ai tre progetti; i numeri generati sono divisi per progetto: `gestionale-php` CL-/LN-001000…004999 e ticket fino a TK-2026-00999, `assistenza-clienti` CL-/LN-005000…005999 e ticket TK-2026-04000…04999, `rete` LN-006000…006999 | `olt-pergine-01` |
| utenze PPPoE | l'identificativo della linea in minuscolo, sul dominio `ciaspolink.example.org` | ln000456@ciaspolink.example.org |

## Generatori deterministici

Ogni progetto ha il suo generatore, `genera.py` (Python 3.8 o successivo, solo libreria standard, seme fisso): i file che produce sono nel repository, e rigenerarli deve dare file identici byte per byte. `python3 <progetto>/genera.py --check` rigenera in una cartella temporanea e confronta (uscita 0 identici, 1 diversi, 2 errore); i test in `tests/` lo verificano.
