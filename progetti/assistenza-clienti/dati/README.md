# La settimana di ticket

`ticket-settimana.csv` è l'esportazione del sistema di ticketing dell'assistenza clienti di CiaspoLink per la settimana da lunedì 7 a domenica 13 settembre 2026: 343 segnalazioni, una per riga. Il file è generato da `../genera.py` con un seme fisso: non si modifica a mano.

I dati sono come escono da un sistema vero: possono esserci campi vuoti, scritture diverse dello stesso valore e segnalazioni doppie.

## Il formato

- CSV con separatore virgola; un campo sta tra virgolette doppie quando contiene virgole o virgolette.
- Codifica UTF-8 senza BOM, fine riga LF, una riga di intestazione.
- Date e ore in ISO 8601 con il fuso (ora legale italiana, +02:00), per esempio `2026-09-08T10:21:00+02:00`.
- Un campo vuoto vuol dire «nessun valore»: una segnalazione ancora aperta, per esempio, non ha `chiuso_il`.
- L'estrazione è di domenica 13 settembre 2026 alle 23:59: ciò che si chiude dopo risulta ancora aperto.

## Le colonne

| colonna | che cosa contiene | valori |
|---|---|---|
| `id_ticket` | il codice della segnalazione, in ordine di apertura | da TK-2026-04213 in su |
| `aperto_il` | quando è stata aperta | ISO 8601 |
| `chiuso_il` | quando è stata chiusa; vuoto se è aperta | ISO 8601 |
| `canale` | da dove è arrivata | `telefono`, `e-mail`, `chat`, `portale` |
| `id_cliente` | il codice cliente; vuoto per chi non è ancora cliente | CL-000123 |
| `tipo_cliente` | il tipo di cliente | `privato`, `azienda`, `associazione` |
| `nome_cliente` | nome e cognome, o ragione sociale, come scritti nella segnalazione | testo |
| `telefono` | il telefono registrato nella segnalazione; può mancare | +39 00x xxx xxxx |
| `email` | l'e-mail registrata nella segnalazione; può mancare | …@example.org |
| `comune` | il comune del cliente, come scritto nella segnalazione | testo |
| `id_linea` | il codice della linea; vuoto se la segnalazione non riguarda una linea | LN-000456 |
| `tecnologia` | il servizio coinvolto | `FTTH` (fibra), `FWA` (radio), `VoIP` (voce e centralino), `altro` |
| `categoria` | il tipo di problema | `assenza_connessione`, `lentezza`, `connessione_instabile`, `wifi`, `router_configurazione`, `telefonia_voip`, `hotspot`, `fatturazione`, `attivazione`, `copertura`, `trasloco`, `rete_aziendale`, `informazioni`, `reclamo` |
| `priorita` | la priorità | `bassa`, `media`, `alta`, `urgente` |
| `stato` | lo stato alla fine della settimana | `aperto`, `in_lavorazione`, `in_attesa_cliente`, `chiuso`, `annullato` |
| `oggetto` | l'oggetto | testo breve |
| `descrizione` | il testo della segnalazione: il messaggio del cliente, la nota dell'operatore o il riepilogo dell'assistente virtuale | testo libero |
| `team` | chi se ne occupa | `primo_livello`, `noc` (tecnici di rete), `tecnici_campo`, `voce`, `servizi_it`, `amministrazione`, `commerciale`, `assistente_virtuale` |
| `minuti_prima_risposta` | minuti fino alla prima risposta di una persona; vuoto se nessuno ha ancora risposto o se la segnalazione l'ha gestita tutta l'assistente virtuale | intero |
| `minuti_risoluzione` | minuti dall'apertura alla chiusura; vuoto se la segnalazione è aperta | intero |
| `soddisfazione` | il voto del cliente, se l'ha dato | da 1 a 5 |

## Dati personali

I dati sono inventati, ma vanno trattati come se fossero veri: nomi, telefoni, e-mail, indirizzi e i dettagli che i clienti scrivono nelle descrizioni (familiari, recapiti, codici, informazioni sulla salute) sono dati personali. Prima di analizzarli con strumenti esterni o di condividerli, si anonimizzano.

## Rigenerare e verificare

```bash
python3 ../genera.py           # rigenera il file
python3 ../genera.py --check   # 0 se il file è identico a quello rigenerato
```
