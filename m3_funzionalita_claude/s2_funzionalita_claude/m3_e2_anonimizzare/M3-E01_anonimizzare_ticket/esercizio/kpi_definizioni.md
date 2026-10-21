# Gli indicatori della settimana

Gli indicatori (KPI) della settimana di ticket, calcolati dal file anonimo
`ticket-anonimi.csv`, una riga per segnalazione. In M3-E01 li scrive
`profilo.py` nella chiave `kpi` di `anonimo/profilo.json`; M3-E02 e M3-E03
usano le stesse chiavi, con le stesse regole.

## Le dieci chiavi

`kpi` è un oggetto JSON con esattamente queste dieci chiavi, né una di più
né una di meno.

| chiave | che cosa conta | tipo e arrotondamento |
|---|---|---|
| `segnalazioni` | le righe del file | intero |
| `per_giorno` | le righe per giorno della settimana di `aperto_il`, così come la data è scritta (ora locale): le chiavi `lun`, `mar`, `mer`, `gio`, `ven`, `sab`, `dom`, tutte e sette, anche con 0 | oggetto di interi |
| `aperte_fine_settimana` | le righe con `chiuso_il` vuoto | intero |
| `annullate` | le righe con `stato` uguale a `annullato` | intero |
| `per_categoria` | le righe per `categoria`, solo le categorie presenti | oggetto di interi |
| `mediana_minuti_prima_risposta` | la mediana dei valori non vuoti di `minuti_prima_risposta`; con un numero pari di valori, la media dei due centrali | numero, 1 decimale |
| `media_minuti_risoluzione_per_tecnologia` | la media dei valori non vuoti di `minuti_risoluzione` per `tecnologia`, solo le tecnologie con almeno un valore | oggetto di numeri, 1 decimale |
| `voti` | le righe con `soddisfazione` non vuota | intero |
| `soddisfazione_media` | la media dei valori non vuoti di `soddisfazione` | numero, 2 decimali |
| `clienti_ricorrenti` | gli pseudonimi distinti, non vuoti, di `cliente` che compaiono in almeno 3 righe | intero |

## Le regole

- Un campo vuoto è un campo senza valore: non vale zero e non entra nelle
  medie né nella mediana.
- Le chiavi di `per_categoria` e di
  `media_minuti_risoluzione_per_tecnologia` sono i valori come sono scritti
  nel file, senza correggerli.
- Si arrotonda all'ultimo decimale indicato, con la metà per eccesso: 0,05
  diventa 0,1.
- I numeri sono numeri JSON, con il punto: `8.5`, non `"8,5"` né `"8.5"`.

## La forma, con valori segnaposto

I valori qui sotto sono zeri e nomi di comodo, non quelli della settimana:

```json
{
  "kpi": {
    "segnalazioni": 0,
    "per_giorno": {"lun": 0, "mar": 0, "mer": 0, "gio": 0, "ven": 0, "sab": 0, "dom": 0},
    "aperte_fine_settimana": 0,
    "annullate": 0,
    "per_categoria": {"<categoria>": 0},
    "mediana_minuti_prima_risposta": 0.0,
    "media_minuti_risoluzione_per_tecnologia": {"<tecnologia>": 0.0},
    "voti": 0,
    "soddisfazione_media": 0.0,
    "clienti_ricorrenti": 0
  }
}
```

Accanto a `kpi`, il profilo può avere altre chiavi, a scelta: per esempio
i campi vuoti per colonna, i comuni scritti in modi diversi, le
segnalazioni doppie.

## Come li confronta la verifica

La verifica calcola gli stessi indicatori dal file e li confronta chiave per
chiave. Un intero è giusto se è uguale. Un decimale è giusto se dista dal
valore vero, non arrotondato, al più mezza unità del suo ultimo decimale:
0,05 con un decimale, 0,005 con due. Così un valore arrotondato bene è
sempre giusto, anche se ha più decimali. Un oggetto è giusto se ha le stesse
chiavi e ogni valore è giusto.
