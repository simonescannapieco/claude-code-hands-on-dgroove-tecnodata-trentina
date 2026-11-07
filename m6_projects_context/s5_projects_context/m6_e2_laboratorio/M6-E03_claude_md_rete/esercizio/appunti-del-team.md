# Appunti del team di rete

Gli appunti del NOC sul progetto della rete: un po' di tutto, scritto da
persone diverse in momenti diversi. Stanno qui, accanto al progetto, e non
nel suo repository.

## Dalla riunione di martedì 8 settembre 2026

- I commit del progetto rete hanno il soggetto nella forma
  `rete(<ambito>): <descrizione>`, all'indicativo presente. L'ambito è la
  parte che si tocca: `audit` per la checklist, `generatore`, `inventario`,
  `doc` per il README. Per esempio:
  `rete(doc): aggiorna la tabella dei dialetti del README`.
- Ogni commit ha nel messaggio una riga `Rif: NOC-<n>`, con il numero della
  segnalazione del NOC. La manutenzione che non ha una segnalazione, come un
  refuso, porta `Rif: NOC-0`.

## Come lavoriamo

- Quando qualcuno chiede se i file della rete sono «a posto», si intendono
  i due controlli del README, tutti e due, dalla radice:
  `python3 progetti/rete/genera.py --check` e
  `python3 progetti/rete/genera.py --canone`. Si riporta l'esito di
  ciascuno.
- Gli orari dei log sono in ora italiana: in quella settimana l'ora legale,
  UTC+2.
- `configurazioni/` e `log/` non si modificano mai a mano: li scrive il
  generatore. Lo stesso vale per `inventario.csv` e `allarmi.csv`.
- Dopo una modifica a `generatore/` si rigenera con
  `python3 progetti/rete/genera.py`, si rifanno i due controlli, e i file
  rigenerati vanno nello stesso commit della modifica.

## Un apparato nuovo

1. Si aggiunge l'apparato alla topologia, in `generatore/topologia.py`.
2. Si rigenera, e si guarda che la sua configurazione esca nel dialetto
   giusto.
3. Si fanno i due controlli.
4. Si avvisa chi fa gli audit, perché lo aggiunga al suo giro.

## Preferenze

- Marco Prova: «Gli esiti dei controlli li voglio in una tabella, un
  controllo per riga.»
