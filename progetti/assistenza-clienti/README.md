# Assistenza clienti di CiaspoLink

Il materiale dell'assistenza clienti dell'operatore immaginario CiaspoLink S.r.l. (l'azienda e le regole dei dati sintetici sono in `../README.md`): un assistente virtuale «versione 0», volutamente mediocre, e tutto ciò che serve per misurarlo, migliorarlo e metterlo alla prova.

| cartella o file | che cosa contiene |
|---|---|
| `v0/` | l'assistente virtuale versione 0: le istruzioni (`system-prompt.md`), gli strumenti (`strumenti.json`), le regole di passaggio all'operatore (`regole-escalation.md`). È il punto di partenza degli esercizi: va misurato e migliorato, non preso a modello |
| `kb/` | la base di conoscenza: 16 procedure di assistenza guidata, dalla fibra senza connessione alle situazioni delicate |
| `tono-di-voce.md` | come parla l'assistenza CiaspoLink: registro, «tu» o «lei», parole, scuse, rifiuti, chiusure, esempi prima e dopo |
| `scenari/` | 20 scenari di prova, 7 dei quali ostili, ciascuno con la «verità nascosta» che gli strumenti restituirebbero |
| `golden/` | 10 conversazioni di riferimento, in JSON e in una versione Markdown generata |
| `valutazione/rubrica.md` | la rubrica con cui giudicare una conversazione, a mano o con un giudice automatico |
| `dati/` | una settimana di ticket dell'assistenza (CSV) e il dizionario delle colonne |
| `genera.py`, `generatore/` | il generatore deterministico dei file generati, il controllo del canone dei dati sintetici e le verifiche di struttura |

## La settimana

Tutti i file raccontano la stessa settimana, da lunedì 7 a domenica 13 settembre 2026, con gli stessi clienti e gli stessi guasti degli altri due progetti (`../gestionale-php/` e `../rete/`).

| cliente | linea | chi è |
|---|---|---|
| CL-000101 | LN-000201 | Laura Prova, Casa Fibra 1 Giga, Pergine Valsugana |
| CL-000102 | LN-000202 | Rifugio Campione, Business Radio, Cles |
| CL-000103 | LN-000203 | Falegnameria Fittizia S.n.c., Business Fibra 2,5 Giga e Centralino Cloud con 6 interni, Rovereto |
| CL-000104 | LN-000204 | Mario Esempio, Casa Radio, Cles |
| CL-000105 | LN-000205 | Albergo Modello, Business Fibra 1 Giga e Hotspot Wi-Fi, Riva del Garda |
| CL-000106 | LN-000206 | Giulia Fittizio, Casa Fibra 2,5 Giga, Trento |

| quando | che cosa |
|---|---|
| martedì 8, 10:12–11:40 | fibra interrotta da lavori stradali a Pergine Valsugana, circa 40 linee ferme |
| mercoledì 9, 07:52–16:50 | collegamento radio della zona di Cles instabile |
| giovedì 10, 02:00–02:30 | manutenzione programmata notturna; al mattino qualche router non si ricollega |
| venerdì 11, 08:04–10:40 | i telefoni del Centralino Cloud non si registrano |
| sabato 12, dalle 9 circa alle 10:55 | indirizzi esauriti per i nuovi apparati sulla rete business di Rovereto |

## Rigenerare e controllare

Serve Python 3.8 o successivo, solo con la libreria standard (su Windows il comando può essere `py -3` invece di `python3`).

```bash
python3 genera.py            # rigenera dati/ticket-settimana.csv e golden/gc-*.md
python3 genera.py --check    # rigenera in una cartella temporanea e confronta: 0 identici, 1 diversi, 2 errore
python3 genera.py --canone   # controlla il canone dei dati sintetici su ogni file di testo: 0 rispettato, 1 violazioni, 2 errore
python3 genera.py --verifica # controlla la struttura di scenari, conversazioni, strumenti, procedure e dati: 0 corretta, 1 problemi, 2 errore
```

Dalla radice del repository, la batteria di test di questo progetto (Linux, macOS, oppure WSL2 o Git Bash su Windows):

```bash
bash tests/test_progetti_assistenza.sh
```

## Che cosa è generato

- **Generati, da non modificare a mano:** `dati/ticket-settimana.csv` e `golden/gc-*.md`. Il generatore li riscrive identici, byte per byte, su ogni versione di Python dalla 3.8 alla 3.14.
- **Scritti a mano:** tutto il resto. I testi con cui il generatore compone i ticket sono in `generatore/testi.py`; le conversazioni di riferimento si modificano nei file `golden/gc-*.json`, poi si rigenera.
- **Chi aggiunge file a questa cartella** rispetta il canone dei dati sintetici: `python3 genera.py --canone` lo controlla.
