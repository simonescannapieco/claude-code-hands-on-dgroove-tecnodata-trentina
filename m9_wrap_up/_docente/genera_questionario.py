#!/usr/bin/env python3
"""Genera il questionario di gradimento del corso (Modulo 9).

Una sola fonte, l'elenco SEZIONI qui sotto, per due file in ../questionario/:

  questionario-gradimento.xml   da importare nell'attività Feedback di Moodle
                                (scheda Questions, menu Actions, comando
                                Import questions: importare_il_questionario.md)
  questionario-gradimento.md    lo stesso questionario, da leggere

Il file XML segue il formato di Moodle: lo stesso che mod/feedback/export.php
scrive e mod/feedback/import.php legge (radice FEEDBACK con VERSION="200701",
un ITEM per domanda, i campi fra CDATA). Le domande sui moduli e quella sul
piano Pro sono facoltative: chi non ha seguito un modulo la lascia vuota, e
il vuoto non entra nelle medie (opzione i di Moodle).

Uso:     python3 -B -I genera_questionario.py          scrive i due file
         python3 -B -I genera_questionario.py --check  li confronta con quelli
                                                       che scriverebbe
Env:     PN_QUESTIONARIO_DIR  la cartella di uscita (default: ../questionario)
Uscita:  0 = scritti, o coerenti · 1 = un file è diverso da quello generato
         2 = uso sbagliato, cartella o file illeggibile
"""

from __future__ import annotations

import os
import sys
from typing import NamedTuple

NOME_BASE = "questionario-gradimento"
ANTEPRIMA = "Questionario di gradimento"

# La scala delle domande con voto: valore e parola. Moodle mostra il valore
# accanto alla parola e calcola la media dei valori.
SCALA = ("Per niente", "Poco", "Abbastanza", "Molto", "Del tutto")
RITMO = ("Troppo lento", "Giusto", "Troppo veloce")
SPIEGAZIONE_SCALA = "; ".join(
    f"{i} = {parola}" for i, parola in enumerate(SCALA, start=1)
)
INTRODUZIONE = (
    "Il questionario del corso «Claude e Claude Code in pratica» è "
    f"anonimo. Dove c'è una scala: {SPIEGAZIONE_SCALA}."
)
COLONNE_TESTO = 60
RIGHE_TESTO = 5

VOTO = "voto"
SCELTA = "scelta"
APERTA = "aperta"


class Domanda(NamedTuple):
    """Una domanda del questionario."""

    etichetta: str
    tipo: str
    testo: str
    facoltativa: bool = False


def _modulo(numero: int, titolo: str) -> Domanda:
    """La domanda facoltativa su un modulo."""
    return Domanda(f"modulo{numero}", VOTO, f"Modulo {numero} — {titolo}",
                   facoltativa=True)


SEZIONI = (
    (
        "Il corso nel suo insieme",
        (
            Domanda("obiettivi", VOTO,
                    "Gli obiettivi del corso sono stati chiari "
                    "fin dall'inizio."),
            Domanda("utilita", VOTO,
                    "Quello che ho imparato mi servirà nel lavoro."),
            Domanda("livello", VOTO,
                    "Il livello era adeguato alla mia preparazione."),
            Domanda("ritmo", SCELTA, "Il ritmo del corso era:"),
            Domanda("pratica", VOTO,
                    "La parte pratica (demo ed esercitazioni) "
                    "era sufficiente."),
            Domanda("complessivo", VOTO,
                    "Nel complesso, il corso mi ha soddisfatto."),
        ),
    ),
    (
        "I moduli: quanto è stato utile ciascuno "
        "(vuoto, per un modulo non seguito)",
        (
            _modulo(1, "Fondamenti degli LLM"),
            _modulo(2, "Prompting avanzato"),
            _modulo(3, "Funzionalità core di Claude (piano Pro)"),
            _modulo(4, "Claude Code e agenti"),
            _modulo(5, "Skills"),
            _modulo(6, "Projects e Context Engineering"),
            _modulo(7, "Costruire e migliorare assistenti basati su LLM"),
            _modulo(8, "Costi, piano Pro e ottimizzazione"),
        ),
    ),
    (
        "I materiali",
        (
            Domanda("dispense", VOTO,
                    "Le dispense si capiscono anche senza la lezione."),
            Domanda("repository", VOTO,
                    "Il repository delle esercitazioni ha funzionato "
                    "senza intoppi."),
            Domanda("riferimenti", VOTO,
                    "I file della cartella riferimenti/ mi saranno utili "
                    "dopo il corso."),
            Domanda("demo", VOTO,
                    "Le demo hanno mostrato chiaramente che cosa "
                    "osservare."),
        ),
    ),
    (
        "Il docente",
        (
            Domanda("chiarezza", VOTO,
                    "Il docente ha spiegato con chiarezza."),
            Domanda("disponibilita", VOTO,
                    "Il docente è stato disponibile alle domande."),
            Domanda("domande", VOTO,
                    "Le domande fatte durante i moduli hanno avuto "
                    "risposta."),
        ),
    ),
    (
        "L'organizzazione",
        (
            Domanda("remoto", VOTO, "Il formato a distanza ha funzionato."),
            Domanda("sessioni", VOTO,
                    "La durata delle sessioni (quattro ore) era adatta."),
            Domanda("piano", VOTO,
                    "Il piano Pro è bastato per le esercitazioni.",
                    facoltativa=True),
        ),
    ),
    (
        "Le vostre parole (facoltative)",
        (
            Domanda("piu_utile", APERTA, "Che cosa vi è stato più utile?"),
            Domanda("cambiare", APERTA, "Che cosa cambiereste?"),
            Domanda("approfondire", APERTA,
                    "Che cosa vorreste approfondire?"),
        ),
    ),
)


def tipo_moodle(domanda: Domanda) -> str:
    """Il tipo di elemento di Moodle per una domanda."""
    return {VOTO: "multichoicerated", SCELTA: "multichoice",
            APERTA: "textarea"}[domanda.tipo]


def presentazione(domanda: Domanda) -> str:
    """Il campo PRESENTATION di Moodle per una domanda."""
    if domanda.tipo == VOTO:
        valori = "|".join(f"{i}####{p}" for i, p in enumerate(SCALA, start=1))
        return f"r>>>>>{valori}<<<<<1"
    if domanda.tipo == SCELTA:
        return "r>>>>>" + "|".join(RITMO) + "<<<<<1"
    return f"{COLONNE_TESTO}|{RIGHE_TESTO}"


def opzioni(domanda: Domanda) -> str:
    """Il campo OPTIONS: h nasconde «Not selected», i tiene i vuoti fuori
    dalle medie di un voto facoltativo."""
    if domanda.tipo == APERTA:
        return ""
    if domanda.tipo == VOTO and domanda.facoltativa:
        return "ih"
    return "h"


def _campo(nome: str, valore: str) -> str:
    """Un campo di un ITEM, con le rientranze di export.php."""
    spazio = " " * 15
    return (f"{spazio}<{nome}>\n{spazio}     <![CDATA[{valore}]]>\n"
            f"{spazio}</{nome}>\n")


def _item(numero: int, tipo: str, richiesta: bool, testo: str,
          etichetta: str, presenta: str, scelte: str) -> str:
    """Un ITEM completo: tutti i campi che import.php legge."""
    corpo = "".join((
        _campo("ITEMID", str(numero)),
        _campo("ITEMTEXT", testo),
        _campo("ITEMLABEL", etichetta),
        _campo("PRESENTATION", presenta),
        _campo("OPTIONS", scelte),
        _campo("DEPENDITEM", "0"),
        _campo("DEPENDVALUE", ""),
    ))
    return (f'          <ITEM TYPE="{tipo}" REQUIRED="{int(richiesta)}">\n'
            f"{corpo}          </ITEM>\n")


def _voci() -> list[str]:
    """Gli ITEM del questionario, nell'ordine di Moodle."""
    voci = [_item(1, "label", False, "", "",
                  f"<p><strong>{ANTEPRIMA}</strong></p>"
                  f"<p>{INTRODUZIONE}</p>", "")]
    numero = 1
    posizione = 0
    for titolo, domande in SEZIONI:
        numero += 1
        voci.append(_item(numero, "label", False, "", "",
                          f"<p><strong>{titolo}</strong></p>", ""))
        for domanda in domande:
            numero += 1
            posizione += 1
            richiesta = domanda.tipo != APERTA and not domanda.facoltativa
            voci.append(_item(numero, tipo_moodle(domanda), richiesta,
                              domanda.testo,
                              f"q{posizione:02d}_{domanda.etichetta}",
                              presentazione(domanda), opzioni(domanda)))
    return voci


def testo_xml() -> str:
    """Il file da importare in Moodle."""
    return ('<?xml version="1.0" encoding="UTF-8" ?>\n'
            '<FEEDBACK VERSION="200701" COMMENT="XML-Importfile for '
            'mod/feedback">\n     <ITEMS>\n' + "".join(_voci()) +
            "     </ITEMS>\n</FEEDBACK>\n")


def _coda(domanda: Domanda) -> str:
    """Che cosa si risponde a una domanda, nel file da leggere."""
    if domanda.tipo == VOTO:
        if domanda.facoltativa:
            return "*(da 1 a 5, facoltativa)*"
        return "*(da 1 a 5)*"
    if domanda.tipo == SCELTA:
        return "*(" + ", ".join(RITMO).lower() + ")*"
    return "*(risposta libera)*"


def testo_md() -> str:
    """Lo stesso questionario in Markdown."""
    righe = [f"# {ANTEPRIMA}", "", INTRODUZIONE, ""]
    posizione = 0
    for titolo, domande in SEZIONI:
        righe += [f"## {titolo}", ""]
        for domanda in domande:
            posizione += 1
            righe.append(f"{posizione}. {domanda.testo} {_coda(domanda)}")
        righe.append("")
    return "\n".join(righe).rstrip() + "\n"


def uscite(cartella: str) -> dict[str, str]:
    """I file da scrivere: percorso e contenuto."""
    return {os.path.join(cartella, f"{NOME_BASE}.xml"): testo_xml(),
            os.path.join(cartella, f"{NOME_BASE}.md"): testo_md()}


def scrivi(cartella: str) -> int:
    """Scrive i due file. Restituisce il codice d'uscita."""
    try:
        os.makedirs(cartella, exist_ok=True)
        for percorso, contenuto in uscite(cartella).items():
            with open(percorso, "w", encoding="utf-8",
                      newline="\n") as uscita:
                uscita.write(contenuto)
    except OSError as problema:
        print(f"errore: {problema}", file=sys.stderr)
        return 2
    print(f"scritti {NOME_BASE}.xml e {NOME_BASE}.md in {cartella}")
    return 0


def confronta(cartella: str) -> int:
    """Confronta i file con quelli generati. Restituisce il codice
    d'uscita."""
    diversi = 0
    for percorso, atteso in uscite(cartella).items():
        try:
            with open(percorso, encoding="utf-8", newline="") as ingresso:
                attuale = ingresso.read()
        except (OSError, UnicodeDecodeError) as problema:
            print(f"errore: {percorso}: {problema}", file=sys.stderr)
            return 2
        if attuale != atteso:
            print(f"DIVERSO: {percorso} non è quello generato")
            diversi += 1
    if diversi:
        return 1
    print(f"coerenti: {NOME_BASE}.xml e {NOME_BASE}.md")
    return 0


def main(argomenti: list[str]) -> int:
    """Il punto d'ingresso."""
    if len(argomenti) > 1 or (argomenti and argomenti[0] != "--check"):
        print(__doc__, file=sys.stderr)
        return 2
    qui = os.path.dirname(os.path.abspath(__file__))
    cartella = os.environ.get("PN_QUESTIONARIO_DIR") or os.path.join(
        qui, "..", "questionario")
    if argomenti:
        return confronta(cartella)
    return scrivi(cartella)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
