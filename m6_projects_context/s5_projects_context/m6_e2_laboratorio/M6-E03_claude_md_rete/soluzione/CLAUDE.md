# Rete CiaspoLink

Configurazioni, log, inventario e allarmi sintetici in `progetti/rete/`, scritti da `genera.py` con il pacchetto `generatore/`.

## Comandi

- «A posto» vuol dire i due controlli, dalla radice: `python3 progetti/rete/genera.py --check` e `python3 progetti/rete/genera.py --canone`; si riporta l'esito di ciascuno.

## Convenzioni che il codice non dice

- Il soggetto dei commit nella forma `rete(<ambito>): <descrizione>`, all'indicativo presente; l'ambito è la parte toccata: `audit`, `generatore`, `inventario`, `doc`.
- Ogni messaggio ha una riga `Rif: NOC-<n>`, il numero della segnalazione del NOC; `Rif: NOC-0` per la manutenzione, come un refuso.

## Insidie

- `configurazioni/`, `log/`, `inventario.csv` e `allarmi.csv` non si modificano a mano: si cambia `generatore/` e si rigenera.
