"""impacchetta.py -- i tre ZIP di M5-D05, dalla skill di esempio
risposta-assistenza, con il modulo zipfile di Python, senza lo zip di sistema:
  risposta-assistenza.zip                 la skill, senza evals/
  risposta-assistenza-settimo-campo.zip   la stessa skill, con il nome uguale,
                                          e argument-hint nel frontmatter
  risposta-assistenza-tag-xml.zip         la stessa skill, con il nome uguale,
                                          e la description fra due tag XML
In tutti e tre la cartella della skill sta al primo livello:
risposta-assistenza/SKILL.md. Gli stessi file danno gli stessi ZIP, byte per
byte: date fisse e ordine fisso.

Uso:    python3 -B -I impacchetta.py <cartella della skill> <cartella ZIP>
Uscita: 0 i tre ZIP · 2 una cartella o uno SKILL.md che non vanno (una riga su
        STDERR, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import zipfile
from typing import List, Tuple

NOME = "risposta-assistenza"
ZIP_BUONO = f"{NOME}.zip"
ZIP_SETTIMO = f"{NOME}-settimo-campo.zip"
ZIP_XML = f"{NOME}-tag-xml.zip"
SETTIMO_CAMPO = 'argument-hint: "[canale]"'
DESCRIZIONE = "description: "
TAG_XML = "scopo"
DATA_FISSA = (1980, 1, 1, 0, 0, 0)
DA_SALTARE = ("__pycache__", ".git")
SKILL_MD = "SKILL.md"


class Problema(Exception):
    """Un ingresso che non va: uscita 2."""


def file_della_skill(sorgente: str) -> List[Tuple[str, bytes]]:
    """(il percorso relativo, i byte) di ogni file, senza evals/, in ordine."""
    voci: List[Tuple[str, bytes]] = []
    for radice, cartelle, nomi in os.walk(sorgente):
        cartelle[:] = sorted(c for c in cartelle if c not in DA_SALTARE
                             and not (radice == sorgente and c == "evals"))
        for nome in sorted(nomi):
            pieno = os.path.join(radice, nome)
            if os.path.islink(pieno):
                raise Problema(f"un collegamento simbolico: {pieno}")
            with open(pieno, "rb") as fh:
                voci.append((os.path.relpath(pieno, sorgente), fh.read()))
    return voci


def righe_e_fine(testo: bytes) -> Tuple[List[str], int]:
    """Le righe di SKILL.md e l'indice del --- che chiude il frontmatter."""
    righe = testo.decode("utf-8").split("\n")
    if not righe or righe[0].rstrip() != "---":
        raise Problema("SKILL.md non comincia con ---")
    fine = next((i for i in range(1, len(righe))
                 if righe[i].rstrip() == "---"), None)
    if fine is None:
        raise Problema("SKILL.md non chiude il frontmatter")
    return righe, fine


def con_settimo_campo(testo: bytes) -> bytes:
    """SKILL.md con il settimo campo in fondo al frontmatter."""
    righe, fine = righe_e_fine(testo)
    cornice = "\n".join(righe[1:fine])
    if re.search(rf"(?m)^name: {re.escape(NOME)}\s*$", cornice) is None:
        raise Problema(f"il name di SKILL.md non è {NOME}")
    if re.search(r"(?m)^argument-hint:", cornice) is not None:
        raise Problema("SKILL.md ha già argument-hint")
    return "\n".join(righe[:fine] + [SETTIMO_CAMPO] + righe[fine:]).encode(
        "utf-8")


def con_tag_xml(testo: bytes) -> bytes:
    """SKILL.md con la description fra due tag XML: cambia solo quella riga."""
    righe, fine = righe_e_fine(testo)
    indice = next((i for i in range(1, fine)
                   if righe[i].startswith(DESCRIZIONE)), None)
    if indice is None:
        raise Problema("SKILL.md non ha una description su una riga sola")
    valore = righe[indice][len(DESCRIZIONE):]
    nuova = f"{DESCRIZIONE}<{TAG_XML}>{valore}</{TAG_XML}>"
    return "\n".join(righe[:indice] + [nuova] + righe[indice + 1:]).encode(
        "utf-8")


def scrivi_zip(percorso: str, voci: List[Tuple[str, bytes]]) -> None:
    """Lo ZIP, con la cartella della skill al primo livello; sostituisce il
    vecchio solo quando il nuovo è finito."""
    provvisorio = percorso + ".tmp"
    with zipfile.ZipFile(provvisorio, "w") as archivio:
        for relativo, dati in voci:
            info = zipfile.ZipInfo(f"{NOME}/{relativo}", DATA_FISSA)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archivio.writestr(info, dati)
    os.replace(provvisorio, percorso)


def impacchetta(sorgente: str, uscita: str) -> None:
    voci = file_della_skill(sorgente)
    if not any(relativo == SKILL_MD for relativo, _ in voci):
        raise Problema(f"{sorgente}: manca {SKILL_MD}")
    settimo = [(r, con_settimo_campo(d) if r == SKILL_MD else d)
               for r, d in voci]
    tag_xml = [(r, con_tag_xml(d) if r == SKILL_MD else d) for r, d in voci]
    os.makedirs(uscita, exist_ok=True)
    for nome, contenuto in ((ZIP_BUONO, voci), (ZIP_SETTIMO, settimo),
                            (ZIP_XML, tag_xml)):
        scrivi_zip(os.path.join(uscita, nome), contenuto)
        print(f"{os.path.join(uscita, nome)}: {len(contenuto)} file sotto "
              f"{NOME}/, senza evals/")


def main(argv: List[str]) -> int:
    if len(argv) != 2:
        print("Uso: impacchetta.py <cartella della skill> <cartella ZIP>",
              file=sys.stderr)
        return 2
    try:
        impacchetta(argv[0], argv[1])
    except (Problema, OSError, UnicodeDecodeError) as exc:
        print(f"impacchetta: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
