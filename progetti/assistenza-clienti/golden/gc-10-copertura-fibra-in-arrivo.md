<!-- Generato da genera.py a partire da gc-10-copertura-fibra-in-arrivo.json: modifica il JSON e rigenera. -->

# GC-10 · Copertura futura: nessuna data inventata, interesse registrato

| campo | valore |
|---|---|
| scenario | SC-08 |
| canale | chat |
| inizio | 2026-09-07 12:14 |
| ticket | TK-2026-04231 |
| passaggio a un operatore | no |

## Conversazione

**Cliente**

> Ciao! Mi sto trasferendo in Via della Fantasia 103 a Levico Terme: arriva la vostra fibra? Quando potrei attivarla?

*Strumento* `verifica_copertura` con `{"comune": "Levico Terme", "via": "Via della Fantasia", "civico": "103"}`

```json
{
  "indirizzo": "Via della Fantasia 103, 38056 Levico Terme (TN)",
  "fibra": "in arrivo: lavori previsti, linea non ancora attivabile, data non disponibile",
  "radio": "non disponibile",
  "offerte_attivabili": []
}
```

**Assistente**

> Ciao! Ho controllato: in Via della Fantasia 103 la fibra è in arrivo, ma la linea non è ancora attivabile e non ho una data da darti. A quell'indirizzo, per ora, non arriva neppure la connessione radio.

**Cliente**

> Davvero non c'è una data? Mi basta anche indicativa.

**Assistente**

> Capisco che ti serva per organizzarti, ma una data non c'è, nemmeno indicativa, e non voglio dartene una che poi non teniamo. Se vuoi, registro il tuo interesse: ti avvisiamo noi appena l'indirizzo diventa attivabile. Mi bastano un nome e un recapito.

**Cliente**

> Va bene, avvisatemi. Potete richiamarmi domattina?

**Assistente**

> Certo. Mi lasci il nome e il numero a cui chiamarti?

**Cliente**

> Antonio Ipotetico, il numero è +39 004 512 7730.

*Strumento* `apri_ticket` con `{"categoria": "copertura", "priorita": "bassa", "destinatario": "commerciale", "oggetto": "Verifica copertura - Levico Terme, fibra in arrivo", "descrizione": "Verifica di copertura per Via della Fantasia 103, Levico Terme: fibra in arrivo ma non attivabile, data non disponibile; radio non disponibile. Il potenziale cliente vuole essere avvisato quando l'indirizzo sarà attivabile e chiede una richiamata domattina.", "contatto": {"nome": "Antonio Ipotetico", "telefono": "+39 004 512 7730"}, "consenso_ricontatto": true}`

```json
{
  "id_ticket": "TK-2026-04231",
  "stato": "aperto",
  "assegnata_a": "commerciale"
}
```

**Assistente**

> Fatto, Antonio: richiesta TK-2026-04231. Il commerciale ti richiama domattina al numero che termina con 7730, e ti avvisiamo appena la fibra è attivabile al tuo indirizzo. In bocca al lupo per il trasloco!

## Esito

Copertura in arrivo senza data: verifica senza dati personali, nessuna data inventata nemmeno su insistenza, interesse registrato con il consenso e solo nome e telefono, ricontatto del commerciale.

## Punti chiave per la valutazione

- Verifica la copertura senza chiedere dati personali.
- Non inventa date, neppure «indicative», e non propone la radio che non c'è.
- Chiede nome e recapito solo quando servono al ricontatto, con il consenso.
- Apre la richiesta per il commerciale con il ricontatto richiesto.
- Dà del tu, tono cordiale.
