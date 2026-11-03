#!/usr/bin/env python3
"""verifica.py di M5-E01 «La prima skill»: i controlli di verifica.sh.

Decidono l'uscita, e solo questi:
  - tools/controlla_skill.py del repository, non la copia dello spazio di
    lavoro, non trova errori in .claude/skills/riassunto-modifiche/;
  - il corpo ha almeno una riga !`comando`, fuori dai blocchi di codice;
  - la prova, prova/stream.jsonl, c'è ed è completa: un risultato, senza errori.
Come dati, mai come uscita: la chiamata Skill sulla domanda naturale, il file
cambiato nella risposta, gli strumenti prima della risposta, il corpo arrivato a
Claude, tutte le prove di prova/, il consumo. Se ci sono, gli altri stream che
_docente/live.sh lascia in prova/: la richiesta, /riassunto-modifiche e
/skill-doctor. Legge gli stream ogni volta, mai un file di esiti.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora · 2 precondizione (spazio di lavoro, tools/ del
        repository, git che non risponde, un file che non si legge) o un errore
        inatteso: mai un «fatto» quando non può decidere
"""
import glob
import json
import os
import re
import subprocess
import sys
from typing import List, Optional

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
RADICE = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
    os.path.join(ELEMENTO, *[os.pardir] * 4))
sys.path.insert(0, os.path.join(RADICE, "tools"))
try:
    # pylint: disable=wrong-import-position
    import controlla_skill
    import lib_controlla_prove as prove
except ImportError as exc:
    sys.stderr.write("verifica: manca tools/ del repository: %s\n" % exc)
    sys.exit(2)

SKILL = "riassunto-modifiche"
RE_INIEZIONE = re.compile(r"(?:^|\s)!`[^`]+`")
RE_RECINTO = re.compile(r"^[ \t]*(`{3,}|~{3,})")
INIZIO_CORPO = "Base directory for this skill:"
FATTO = ("Fatto: la skill passa il controllo, ha una riga !`comando` e la "
         "prova è completa. Le righe (dato) dicono che cosa è successo: non "
         "decidono.")


def quanti(numero: int, uno: str, molti: str) -> str:
    """«1 errore», «2 errori», «0 errori»: il nome si accorda con il numero."""
    return "%d %s" % (numero, uno if numero == 1 else molti)


def corpo_di(percorso: str) -> str:
    """Il testo dopo il frontmatter di SKILL.md."""
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        testo = fh.read()
    parti = testo.split("---\n", 2)
    return parti[2] if len(parti) == 3 else ""


def righe_iniezione(corpo: str) -> List[str]:
    """Le righe !`comando` del corpo, fuori dai blocchi di codice."""
    trovate: List[str] = []
    recinto = ""
    for riga in corpo.split("\n"):
        aperto = RE_RECINTO.match(riga)
        if aperto:
            if not recinto:
                recinto = aperto.group(1)[0]
            elif aperto.group(1)[0] == recinto:
                recinto = ""
        elif not recinto and RE_INIEZIONE.search(riga):
            trovate.append(riga.strip())
    return trovate


def controlla_la_skill(ws: str) -> List[str]:
    """Il controllo della skill: che cosa manca."""
    cartella = os.path.join(ws, ".claude", "skills", SKILL)
    percorso = os.path.join(cartella, "SKILL.md")
    if not os.path.isfile(percorso):
        print("Manca .claude/skills/%s/SKILL.md." % SKILL)
        return ["manca la skill: .claude/skills/%s/SKILL.md" % SKILL]
    try:
        referto = controlla_skill.esamina_skill(cartella)
    except controlla_skill.Illeggibile as exc:
        raise prove.Problema(str(exc))
    for errore in referto.errori:
        print("ERRORE %s" % errore)
    for avviso in referto.avvisi:
        print("AVVISO %s" % avviso)
    errori = quanti(len(referto.errori), "errore", "errori")
    print("controlla_skill: %s: %s, %s" % (
        referto.nome, errori, quanti(len(referto.avvisi), "avviso", "avvisi")))
    manca = []
    if referto.errori:
        manca.append("la skill ha %s (qui sopra)" % errori)
    righe = righe_iniezione(corpo_di(percorso))
    if righe:
        print("Le righe !`comando` del corpo: %s" % ", ".join(righe))
    else:
        print("Nessuna riga !`comando` nel corpo, fuori dai blocchi di codice.")
        manca.append("nessuna riga !`comando` nel corpo")
    return manca


def leggi_la_prova(ws: str, manca: List[str]) -> Optional[prove.Esecuzione]:
    """La prova, se c'è ed è completa; altrimenti dice in manca perché."""
    rel = os.path.join("prova", "stream.jsonl")
    percorso = os.path.join(ws, rel)
    if not os.path.lexists(percorso):
        print("\nManca la prova: %s." % rel)
        manca.append("manca la prova: lanciate bash prova.sh")
        return None
    if not os.path.isfile(percorso) or not os.access(percorso, os.R_OK):
        raise prove.Problema("%s c'è, ma non è un file che si legge" % rel)
    try:
        esec = prove.leggi_stream(percorso)
    except prove.Problema as exc:
        print("\nLa prova non si legge: %s" % exc)
        manca.append("%s non si legge: rilanciate bash prova.sh" % rel)
        return None
    if not esec.completa or esec.errore:
        print("\nLa prova, %s, non è completa: si è interrotta o è finita con "
              "un errore." % rel)
        manca.append("%s non è completa: rilanciate bash prova.sh" % rel)
        return None
    print("\nLa prova, %s, è completa." % rel)
    return esec


def file_cambiati(ws: str) -> List[str]:
    """I file cambiati rispetto all'ultimo commit, secondo git. Raises: Problema
    se git non risponde: «nessun file cambiato» sarebbe un dato falso."""
    fatto = subprocess.run(["git", "-C", ws, "diff", "--name-only", "HEAD"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           check=False)
    if fatto.returncode != 0:
        motivo = fatto.stderr.decode("utf-8", "replace").strip().split("\n")[0]
        raise prove.Problema("git diff non riesce in %s: %s" % (ws, motivo))
    return [r for r in fatto.stdout.decode("utf-8", "replace").split("\n") if r]


def corpo_arrivato(percorso: str) -> Optional[str]:
    """Il messaggio con il corpo della skill, se lo stream lo mostra."""
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        for riga in fh:
            if not riga.strip():
                continue
            evento = json.loads(riga)
            messaggio = evento.get("message")
            contenuto = messaggio.get("content") \
                if isinstance(messaggio, dict) else None
            if evento.get("type") != "user" or not isinstance(contenuto, list):
                continue
            for blocco in contenuto:
                testo = blocco.get("text") if isinstance(blocco, dict) else None
                if isinstance(testo, str) and testo.startswith(INIZIO_CORPO):
                    return testo
    return None


def strumenti_testo(esec: prove.Esecuzione) -> str:
    """Gli strumenti chiamati, oltre a Skill, con i loro conti e i comandi."""
    conti: dict = {}
    for strumento in esec.strumenti:
        if strumento.nome == "Skill":
            continue
        voce = conti.setdefault(strumento.nome, [0, []])
        voce[0] += 1
        comando = strumento.input.get("command") \
            if isinstance(strumento.input, dict) else None
        if comando:
            voce[1].append(str(comando))
    voci = []
    for nome, (quante, comandi) in conti.items():
        dettaglio = " (%s)" % ", ".join(comandi) if comandi else ""
        voci.append("%s %d%s" % (nome, quante, dettaglio))
    return "; ".join(voci) or "nessuno"


def dati_chiamata(esec: prove.Esecuzione) -> None:
    """La chiamata Skill sulla domanda naturale, come dato."""
    if esec.chiamata_riuscita(SKILL):
        valore = "sì"
    elif SKILL in esec.chiamate_negate:
        valore = "tentata, ma negata dal permesso"
    elif SKILL in esec.chiamate_respinte:
        valore = "tentata, ma respinta dallo strumento"
    else:
        valore = "no"
    print("(dato) la chiamata Skill sulla domanda naturale: %s" % valore)


def dati_file(esec: prove.Esecuzione, ws: str) -> List[str]:
    """Il file cambiato nella risposta, come dato. Returns: i nomi cercati."""
    nomi = [os.path.basename(f) for f in file_cambiati(ws)]
    if not nomi:
        print("(dato) il file cambiato nella risposta: nessun file cambiato "
              "rispetto all'ultimo commit (bash prepara_modifica.sh)")
    for nome in nomi:
        print("(dato) il file cambiato nella risposta: %s: %s" % (
            nome, "sì" if nome in esec.testo else "no"))
    return nomi


def dati_corpo(percorso: str, nomi: List[str]) -> None:
    """Il corpo arrivato a Claude, come dato."""
    corpo = corpo_arrivato(percorso)
    if corpo is None:
        print("(dato) il corpo arrivato a Claude: nello stream non c'è (si "
              "vede soltanto quando è Claude a chiamare la skill)")
        return
    pezzi = ["nessun !`comando` rimasto: %s" % (
        "no" if RE_INIEZIONE.search(corpo) else "sì")]
    pezzi += ["%s: %s" % (nome, "sì" if nome in corpo else "no")
              for nome in nomi]
    print("(dato) il corpo arrivato a Claude: %s" % "; ".join(pezzi))


def consumo(esec: prove.Esecuzione) -> str:
    """Turni, token e secondi, sommati su ogni risultato della chiamata."""
    secondi = ("%.1f" % esec.secondi).replace(".", ",")
    return "turni %d; token %d; %s s" % (esec.turni, esec.token_totali, secondi)


def dati_prove(cartella: str) -> None:
    """Tutte le prove di prova/: la chiamata Skill riuscita, n su N, e quelle
    che il conto lascia fuori: mai un N più piccolo senza dirlo."""
    streams = sorted(glob.glob(os.path.join(cartella, "stream*.jsonl")))
    riuscite = totale = fuori = 0
    for percorso in streams:
        try:
            esec = prove.leggi_stream(percorso)
        except prove.Problema:
            fuori += 1
            continue
        if esec.completa and not esec.errore:
            totale += 1
            riuscite += 1 if esec.chiamata_riuscita(SKILL) else 0
        else:
            fuori += 1
    riga = ("(dato) tutte le prove di prova/: la chiamata Skill riuscita in %d "
            "su %d" % (riuscite, totale))
    if fuori:
        riga += "; " + quanti(fuori, "non letta o fallita",
                              "non lette o fallite")
    print(riga)


def dati_altri(cartella: str, nomi: List[str]) -> None:
    """Gli altri stream che _docente/live.sh lascia in prova/, come dati."""
    richiesta = os.path.join(cartella, "richiesta.jsonl")
    if os.path.isfile(richiesta):
        esec = prove.leggi_stream(richiesta)
        print("(dato) la richiesta di scrivere la skill: strumenti: %s; %s" % (
            strumenti_testo(esec), consumo(esec)))
    nome = os.path.join(cartella, "nome.jsonl")
    if os.path.isfile(nome):
        esec = prove.leggi_stream(nome)
        trovati = ", ".join("%s: %s" % (f, "sì" if f in esec.testo else "no")
                            for f in nomi) or "nessun file cambiato"
        print("(dato) /riassunto-modifiche: chiamate Skill: %d; strumenti: %s; "
              "il file nella risposta: %s; %s" % (
                  len(esec.chiamate_skill), strumenti_testo(esec), trovati,
                  consumo(esec)))
    dottore = os.path.join(cartella, "skill-doctor.jsonl")
    if os.path.isfile(dottore):
        esec = prove.leggi_stream(dottore)
        righe = [r.strip() for r in esec.testo.split("\n") if SKILL in r]
        print("(dato) /skill-doctor: %s; turni %d" % (
            " ".join(righe) or "la skill non è nella tabella", esec.turni))


def main(argv: List[str]) -> int:
    if len(argv) != 1 or not argv[0] or not os.path.isdir(argv[0]):
        raise prove.Problema("spazio di lavoro assente: %s"
                             % (argv[0] if argv else ""))
    ws = os.path.abspath(argv[0])
    print("Verifica di M5-E01 «La prima skill»\n")
    manca = controlla_la_skill(ws)
    esec = leggi_la_prova(ws, manca)
    cartella = os.path.join(ws, "prova")
    nomi = [os.path.basename(f) for f in file_cambiati(ws)]
    if esec is not None:
        print()
        dati_chiamata(esec)
        nomi = dati_file(esec, ws)
        print("(dato) gli strumenti, oltre a Skill, prima della risposta: %s"
              % strumenti_testo(esec))
        dati_corpo(esec.percorso, nomi)
        print("(dato) il consumo della prova: %s" % consumo(esec))
        dati_prove(cartella)
    dati_altri(cartella, nomi)
    if manca:
        print("\nNon ancora: %s." % "; ".join(manca))
        return 1
    print("\n%s" % FATTO)
    return 0


if __name__ == "__main__":
    sys.exit(prove.principale(main, sys.argv[1:]))
