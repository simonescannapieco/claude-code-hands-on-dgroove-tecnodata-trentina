# SPECIFICA — l'elenco dei ticket per apparato e per date

La pagina Ticket del gestionale di CiaspoLink, l'operatore inventato del
corso (un progetto sintetico), filtra per stato, priorità, categoria e
cliente. Nella settimana dei disservizi serve anche filtrare per
**apparato** e per **intervallo di date**. Questa specifica dice che cosa
deve fare il filtro nuovo: i test si scrivono da qui. I numeri degli esempi
sono quelli dei dati di esempio del gestionale (`database/dati/`), che i
test di integrazione caricano con `DatabaseDiProva::conDati()`.

## Dove

- `src/Ticket/FiltroTicket.php`: tre criteri nuovi, dopo quelli che ci
  sono, tutti con il valore predefinito `null`:
  `?string $apparatoId`, `?DateTimeImmutable $dal`, `?DateTimeImmutable $al`.
  Si passano per nome, come gli altri:
  `new FiltroTicket(apparatoId: 'olt-pergine-01', dal: new DateTimeImmutable('2026-09-08'))`.
- `src/Ticket/TicketRepository.php`: `cerca()` applica i criteri nuovi;
  l'ordine (dal più recente) e il limite restano quelli che ci sono.
- `FiltroTicket::daParametri()`: legge i parametri `apparato`, `dal` e `al`
  della pagina.
- `templates/ticket_elenco.php`: tre campi nel modulo dei filtri (R7,
  facoltativo).

## Requisiti

R1. Filtro per apparato. Con `apparatoId`, `cerca()` restituisce i ticket
che riguardano quell'apparato: quelli per cui vale almeno una di queste
condizioni.
  (a) Il ticket ha quell'apparato (`apparato_id`).
  (b) Il suo ticket padre (`padre_id`, il disservizio a cui è collegato) ha
  quell'apparato.
  (c) La sua linea (`linea_id`) è attestata su quell'apparato
  (`linee.apparato_id`).
I ticket dei clienti collegati a un disservizio non hanno `apparato_id`:
all'apparato si arriva dal ticket padre o dalla linea.
Esempio: con `olt-pergine-01` e martedì 8 settembre 2026 escono il
disservizio TK-2026-00210, per (a), e gli otto ticket dei clienti
collegati, da TK-2026-00211 a TK-2026-00218, per (b) e (c); fra questi
TK-2026-00212, della linea LN-000201.

R2. Le tre condizioni di R1 si sommano: un ticket esce se ne vale anche una
sola, pure se il suo ticket padre ha un altro apparato.
Esempio: TK-2026-00228 (linea LN-001112, attestata su `olt-pergine-01`,
collegato alla manutenzione TK-2026-00201 di `bng-trento-01`) esce sia con
`olt-pergine-01` sia con `bng-trento-01`.

R3. Intervallo di date. `dal` e `al` limitano i ticket al giorno di
apertura, estremi compresi. Il giorno è quello locale di `aperto_il`, i
suoi primi dieci caratteri (regola 5.5 di `docs/convenzioni.md`). Si può
dare uno solo dei due estremi; dell'orario di `dal` e `al` conta solo la
data.
Esempio: con `dal` e `al` uguali a 2026-09-08 escono gli 11 ticket aperti
martedì 8 settembre; con il solo `dal` 2026-09-12 escono i 10 ticket
aperti dal 12 settembre in poi.

R4. I criteri si combinano fra loro e con quelli che ci sono già: devono
valere tutti.
Esempio: `olt-pergine-01`, dal 2026-09-07 al 2026-09-13, categoria
`disservizio`: esce solo TK-2026-00210.

R5. Un intervallo rovesciato è un errore: se `dal` viene dopo `al`, il
costruttore lancia `InvalidArgumentException` (regola 6.1).
Esempio: `new FiltroTicket(dal: new DateTimeImmutable('2026-09-13'), al: new DateTimeImmutable('2026-09-07'))`.

R6. La pagina. `daParametri()` legge `apparato` togliendo gli spazi in testa
e in coda e passando alle minuscole, e lo accetta solo nella forma
`<ruolo>-<comune>-<nn>` (lettere minuscole, due cifre); legge `dal` e `al`
solo come date AAAA-MM-GG che esistono. Come per gli altri filtri della
pagina, un valore non valido si ignora; un intervallo rovesciato si ignora
tutto, tutti e due gli estremi.
Esempio: `['apparato' => ' OLT-Pergine-01 ', 'dal' => '2026-09-08', 'al' => '2026-02-30']`
dà `apparatoId` `olt-pergine-01`, `dal` il 2026-09-08 e `al` null.

R7. Facoltativo, e fuori dalla verifica: nel modulo dei filtri di
`templates/ticket_elenco.php`, tre campi, apparato (un testo, come il
cliente), dal e al (date); i valori scelti restano nel modulo dopo
«Filtra».

## Casi di accettazione

I casi 1–8 chiedono a `cerca()` l'elenco con i criteri dati (la settimana
è da lunedì 2026-09-07 a domenica 2026-09-13); il caso 9 costruisce il
filtro.

| # | criteri | ticket attesi |
|---|---|---|
| 1 | apparato olt-pergine-01, dal 2026-09-08 al 2026-09-08 | 9: da TK-2026-00210 a TK-2026-00218 |
| 2 | apparato olt-pergine-01, la settimana | 14: i 9 del caso 1, TK-2026-00228, TK-2026-00245, TK-2026-00246, TK-2026-00247, TK-2026-00248 |
| 3 | apparato ptp-cles-01, la settimana | 5: da TK-2026-00221 a TK-2026-00225 |
| 4 | apparato bts-cles-01, la settimana | 8: da TK-2026-00222 a TK-2026-00225, TK-2026-00235, TK-2026-00236, TK-2026-00240, TK-2026-00243 |
| 5 | apparato bng-trento-01, senza date | 3: TK-2026-00201, TK-2026-00227, TK-2026-00228 |
| 6 | dal 2026-09-08 al 2026-09-08, senza apparato | 11 ticket, tutti aperti il 2026-09-08 |
| 7 | apparato olt-pergine-01, la settimana, categoria disservizio | 1: TK-2026-00210 |
| 8 | apparato olt-inesistente-01 | nessuno |
| 9 | dal 2026-09-13, al 2026-09-07 | InvalidArgumentException dal costruttore |
