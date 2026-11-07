# CLAUDE.md

Configurazioni, log, inventario e checklist di audit sintetici della rete di CiaspoLink, in `progetti/rete/`, prodotti da un generatore Python.

## Comandi

- Quando ti chiedono se i file della rete sono «a posto», lancia tutti e due i controlli, dalla radice del repository, e riporta l'esito di ciascuno:
  - `python3 progetti/rete/genera.py --check`
  - `python3 progetti/rete/genera.py --canone`

## Convenzioni che il codice non dice

- Soggetto del commit: `rete(<ambito>): <descrizione>`, all'indicativo presente; ambito `audit`, `generatore`, `inventario` o `doc`.
- Ogni commit ha nel messaggio una riga `Rif: NOC-<n>` con il numero della segnalazione del NOC; senza segnalazione (un refuso) `Rif: NOC-0`.
