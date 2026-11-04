"""verifica.py di M5-D05 «La stessa skill in claude.ai»: i controlli di
verifica.sh. Nessuna chiamata al modello: ciò che fa il caricamento si legge
sullo schermo.

Decidono l'uscita i tre ZIP di pacchetti/: ci sono e si aprono; ogni file sta
sotto risposta-assistenza/, con risposta-assistenza/SKILL.md; niente evals/;
il frontmatter ha il name giusto, nel primo i campi ammessi, nel secondo anche
argument-hint e nel terzo dei tag XML nella description. E, se avete fatto la
prova, risposta_claude_ai.md non è vuoto.

Di risposta_claude_ai.md stampa i criteri della risposta, come dati, mai come
uscita: le parole da evitare, le stesse di M5-E03, con le forme della stessa
parola; le frasi; le parole; la forma del canale; la premessa; e il testo, per
una persona.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora · 2 precondizione (spazio di lavoro assente, una
        risposta che non si legge) o un errore inatteso: mai un traceback
"""
from __future__ import annotations

import os
import re
import sys
import zipfile
from typing import Dict, List, Optional

NOME = "risposta-assistenza"
CARTELLA = "pacchetti"
ZIP_BUONO = f"{NOME}.zip"
ZIP_SETTIMO = f"{NOME}-settimo-campo.zip"
ZIP_XML = f"{NOME}-tag-xml.zip"
RISPOSTA = "risposta_claude_ai.md"
TOP = f"{NOME}/"
SKILL_MD = f"{TOP}SKILL.md"
AMMESSI = {"name", "description", "license", "compatibility", "metadata",
           "allowed-tools"}
SETTIMO = "argument-hint"
MASSIMO_FRASI = 3
RE_FRASE = re.compile(r"(?<=[.!?…])\s+|\n+")
RE_PREMESSA = re.compile(
    r"^\W*(?:ecco|certo|bozza|risposta|messaggio|proposta|di seguito|"
    r"ti propongo|potresti|puoi rispondere|ho preparato)\b", re.IGNORECASE)
RE_TITOLO = re.compile(r"(?m)^#{1,6}\s")
RE_VOCE = re.compile(r"(?m)^\s*(?:[-*•]|\d+[.)])\s")
RE_EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")
RE_CAMPO = re.compile(r"^([A-Za-z_-]+):")
RE_TAG_XML = re.compile(r"<[^<>]+>")
# Le parole delle tabelle «invece di» della guida del tono e dello SKILL.md di
# esempio, ciascuna con le forme della stessa parola, che valgono uguale: la
# guida vieta la parola, non il suo singolare. La suite le confronta con quelle
# di M5-E03.
PAROLE_DA_EVITARE = {
    "la sua problematica": ("problematica", "problematiche"),
    "disservizio": ("disservizio", "disservizi"),
    "degrado": ("degrado",),
    "ticket": ("ticket",),
    "presa in carico": ("presa in carico", "preso in carico",
                        "prese in carico", "presi in carico"),
    "le faremo sapere": ("le faremo sapere", "ti faremo sapere",
                         "vi faremo sapere"),
    "sarà nostra cura": ("sarà nostra cura",),
    "Gentile Cliente": ("gentile cliente",),
    "sicuramente": ("sicuramente",),
    "garantito": ("garantito", "garantita", "garantiti", "garantite"),
    "a breve": ("a breve",),
    "inconveniente": ("inconveniente", "inconvenienti"),
    "ha sbagliato a collegare": ("ha sbagliato a collegare",
                                 "hai sbagliato a collegare"),
    "come già detto": ("come già detto",),
    "OLT": ("olt",),
    "BNG": ("bng",),
    "SBC": ("sbc",),
    "PON": ("pon",),
}


def _espressione_parole() -> "re.Pattern":
    forme = sorted({f for voci in PAROLE_DA_EVITARE.values() for f in voci},
                   key=len, reverse=True)
    pezzi = [r"\s+".join(re.escape(p) for p in f.split()) for f in forme]
    # I nomi degli apparati hanno la forma <ruolo>-<comune>-<nn>.
    pezzi.append(r"[a-z]+-[a-z]+-\d\d")
    return re.compile(r"(?<![\w-])(?:" + "|".join(pezzi) + r")(?![\w-])",
                      re.IGNORECASE)


RE_PAROLE = _espressione_parole()


class Precondizione(Exception):
    """Un controllo che non può partire: il messaggio, uscita 2."""


def campi_di(testo: str) -> Optional[Dict[str, str]]:
    """I campi di primo livello del frontmatter; None se non c'è."""
    righe = testo.split("\n")
    if not righe or righe[0].rstrip() != "---":
        return None
    campi: Dict[str, str] = {}
    for riga in righe[1:]:
        if riga.rstrip() == "---":
            return campi
        trovato = RE_CAMPO.match(riga)
        if trovato:
            campi[trovato.group(1)] = riga[len(trovato.group(0)):].strip()
    return None


def problemi_dei_nomi(nomi: List[str]) -> List[str]:
    """Che cosa non va nella forma dello ZIP."""
    problemi: List[str] = []
    if any(not nome.startswith(TOP) for nome in nomi):
        problemi.append(f"al primo livello dev'esserci la sola cartella {TOP}")
    if SKILL_MD not in nomi:
        problemi.append(f"manca {SKILL_MD}")
    if any(nome.startswith(f"{TOP}evals/") for nome in nomi):
        problemi.append("c'è evals/: le prove restano fuori dallo ZIP")
    return problemi


def problemi_dei_campi(campi: Optional[Dict[str, str]], con_settimo: bool,
                       con_xml: bool) -> List[str]:
    """Che cosa non va nel frontmatter dello ZIP."""
    if campi is None:
        return ["il frontmatter di SKILL.md non si legge"]
    problemi: List[str] = []
    if campi.get("name") != NOME:
        problemi.append(f"il name dev'essere {NOME}")
    altri = sorted(set(campi) - AMMESSI - {SETTIMO})
    if altri:
        problemi.append(f"campi inattesi: {', '.join(altri)}")
    if con_settimo and SETTIMO not in campi:
        problemi.append(f"questo ZIP deve avere {SETTIMO}: è lui il settimo "
                        "campo")
    if not con_settimo and SETTIMO in campi:
        problemi.append(f"questo ZIP non deve avere {SETTIMO}")
    ha_tag = RE_TAG_XML.search(campi.get("description", "")) is not None
    if con_xml and not ha_tag:
        problemi.append("questo ZIP deve avere dei tag XML nella description")
    if not con_xml and ha_tag:
        problemi.append("questo ZIP non deve avere tag XML nella description")
    return problemi


def controlla_zip(cartella: str, nome: str, con_settimo: bool = False,
                  con_xml: bool = False) -> List[str]:
    """Le mancanze di uno ZIP; stampa com'è fatto se va bene."""
    relativo = f"{CARTELLA}/{nome}"
    percorso = os.path.join(cartella, nome)
    if not os.path.isfile(percorso):
        return [f"manca {relativo}: ./impacchetta.sh {CARTELLA}"]
    if not zipfile.is_zipfile(percorso):
        return [f"{relativo} non è uno ZIP: ./impacchetta.sh {CARTELLA}"]
    try:
        with zipfile.ZipFile(percorso) as archivio:
            nomi = archivio.namelist()
            rotto = archivio.testzip()
            problemi = problemi_dei_nomi(nomi)
            if rotto is None and SKILL_MD in nomi:
                testo = archivio.read(SKILL_MD).decode("utf-8")
                problemi += problemi_dei_campi(campi_di(testo), con_settimo,
                                               con_xml)
    except (zipfile.BadZipFile, OSError, UnicodeDecodeError) as exc:
        return [f"{relativo} non è uno ZIP integro: {exc}"]
    if rotto is not None:
        return [f"{relativo} non è uno ZIP integro: {rotto}"]
    if problemi:
        return [f"{relativo}: {problema}" for problema in problemi]
    print(f"{relativo}: {len(nomi)} file sotto {TOP}, nessun evals/; "
          f"i campi: {', '.join(sorted(campi_di(testo) or {}))}")
    return []


def forma_del_canale(testo: str) -> List[str]:
    difetti = []
    if RE_TITOLO.search(testo):
        difetti.append("titoli")
    if "**" in testo:
        difetti.append("grassetto")
    if len(RE_VOCE.findall(testo)) > 1:
        difetti.append("elenco di più passi")
    if RE_EMOJI.search(testo):
        difetti.append("emoji")
    if "!!" in testo:
        difetti.append("punti esclamativi in serie")
    return difetti


def stampa_criteri(testo: str) -> None:
    """I criteri della risposta, come dati: non decidono l'uscita."""
    trovate = list(dict.fromkeys(
        " ".join(m.group(0).split()) for m in RE_PAROLE.finditer(testo)))
    frasi = [f for f in RE_FRASE.split(testo.strip()) if f.strip()]
    difetti = forma_del_canale(testo)
    premessa = RE_PREMESSA.match(testo.strip()) is not None
    print(f"{RISPOSTA}, come dati:")
    print(f"  parole da evitare: {', '.join(trovate) or 'nessuna'}")
    print(f"  frasi: {len(frasi)}, al massimo {MASSIMO_FRASI} nella chat")
    print(f"  parole: {len(testo.split())}")
    print("  forma del canale: " + (f"no: {', '.join(difetti)}" if difetti
                                    else "sì"))
    print(f"  senza premessa: {'no' if premessa else 'sì'}")
    print("  il testo, da leggere:")
    for riga in testo.strip().splitlines():
        print(f"    | {riga}".rstrip())


def controlla_risposta(ws: str) -> List[str]:
    """La prova facoltativa: i criteri, come dati. Le mancanze."""
    percorso = os.path.join(ws, RISPOSTA)
    if not os.path.exists(percorso):
        print(f"{RISPOSTA}: non c'è: la prova su claude.ai è facoltativa")
        return []
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione(f"{RISPOSTA} non si legge come testo UTF-8: "
                            f"{exc}") from exc
    if not testo.strip():
        return [f"{RISPOSTA} è vuoto: incollateci la risposta di Claude, o "
                "toglietelo se non fate la prova"]
    stampa_criteri(testo)
    return []


def controlla(ws: str) -> int:
    cartella = os.path.join(ws, CARTELLA)
    mancanze = controlla_zip(cartella, ZIP_BUONO)
    mancanze += controlla_zip(cartella, ZIP_SETTIMO, con_settimo=True)
    mancanze += controlla_zip(cartella, ZIP_XML, con_xml=True)
    if not mancanze:
        mancanze = controlla_risposta(ws)
    for voce in mancanze:
        print(f"NON ANCORA: {voce}")
    return 1 if mancanze else 0


def main(argv: List[str]) -> int:
    for canale in (sys.stdout, sys.stderr):
        if hasattr(canale, "reconfigure"):
            canale.reconfigure(encoding="utf-8", errors="replace")
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        print(f"verifica: spazio di lavoro assente: {' '.join(argv)}",
              file=sys.stderr)
        return 2
    try:
        return controlla(argv[0])
    except Precondizione as exc:
        print(f"verifica: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        print(f"verifica: errore inatteso: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
