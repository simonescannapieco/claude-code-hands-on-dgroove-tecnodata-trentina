"""verifica.py di M6-E01 «Che cosa vede Claude»: i controlli di verifica.sh.

Decidono l'uscita, e solo questi:
  - prima.md è l'uscita di /context all e sotto «Memory files» non ha il
    CLAUDE.md dello spazio di lavoro;
  - CLAUDE.md c'è, nella cartella dello spazio di lavoro;
  - dopo.md è l'uscita di /context all e sotto «Memory files» ha quel
    CLAUDE.md, con i suoi token: «To confirm the file loaded, run /context
    all in a session and check the list under Memory files.»
    (https://code.claude.com/docs/en/memory);
  - il registro dell'hook InstructionsLoaded, .claude/caricamenti.jsonl, ha
    almeno una riga session_start per CLAUDE.md: l'evento «Fires at session
    start» (https://code.claude.com/docs/en/hooks).
Le ultime due sono garanzie del prodotto: se in questa esecuzione non
tengono, la verifica lo dice, «non confermata in questa esecuzione», ed esce
1. Nella tabella di /context i percorsi sono assoluti: il CLAUDE.md dello
spazio di lavoro è la riga il cui percorso finisce con
/<nome dello spazio di lavoro>/CLAUDE.md. Così un CLAUDE.md di una cartella
più in alto non conta, e la registrazione del corso vale anche in un altro
spazio di lavoro con lo stesso nome (soluzione/).

Come dati, mai come uscita: la risposta alla domanda del README, da
risposta.txt (il /export della sessione) o, se manca, da domanda.jsonl (lo
stream di _docente/live.sh); i comandi fra apici inversi di CLAUDE.md che vi
compaiono; le altre righe sotto «Memory files»; le righe del registro. Una
risposta che non si legge è anch'essa un dato: l'uscita non ne dipende.
Legge i file ogni volta, mai un file di esiti. Non stampa mai un percorso
assoluto né la cartella di casa, che le uscite di /context e di /export
contengono: al loro posto «<spazio di lavoro>» e «~».

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora, o una garanzia che non tiene · 2
        precondizione (spazio di lavoro assente, tools/ del repository;
        prima.md, dopo.md, CLAUDE.md, le impostazioni o il registro che non
        si leggono o non sono UTF-8; un'uscita di /context con «Memory
        files» ma senza la tabella dei file) o un errore inatteso: mai un
        «fatto» quando non può decidere
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
RADICE = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
    os.path.join(ELEMENTO, *[os.pardir] * 4))
sys.path.insert(0, os.path.join(RADICE, "tools"))
try:
    # pylint: disable=wrong-import-position
    import lib_controlla_prove as prove
    import lib_leggi_contesto as contesto
except ImportError as exc:
    sys.stderr.write("verifica: manca tools/ del repository: %s\n" % exc)
    sys.exit(2)

Problema = prove.Problema

PRIMA = "prima.md"
DOPO = "dopo.md"
CLAUDE_MD = "CLAUDE.md"
REGISTRO = ".claude/caricamenti.jsonl"
IMPOSTAZIONI = ".claude/settings.json"
HOOK = ".claude/hooks/registra_caricamenti.py"
RISPOSTA = "risposta.txt"
STREAM = "domanda.jsonl"
DOMANDA = "Con quale comando si eseguono i test di questo progetto?"
RESET = "tools/reset_esercizio.sh M6-E01"
ALL_AVVIO = "session_start"
INIZIO = 300
RE_TITOLO = re.compile(r"^#{1,6}\s+(.*?)\s*$")
RE_COMANDO = re.compile(r"`([^`\n]+)`")
RE_STRUMENTO = re.compile(r"^[A-Z][A-Za-z]*\(.*\)\s*$")
RE_CASA = re.compile(r"/(?:home|Users)/[^/\s]+")
G_CONTEXT = ("/context all elenca sotto «Memory files» il CLAUDE.md "
             "caricato all'avvio")
G_HOOK = ("l'hook InstructionsLoaded scatta all'avvio (load_reason "
          "session_start)")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
FATTO = ("Fatto: CLAUDE.md è sotto «Memory files» in dopo.md e non in "
         "prima.md, e il registro dell'hook ha il suo caricamento "
         "all'avvio. Le righe (dato) dicono che cosa ha risposto Claude: "
         "non decidono.")


class Voce(NamedTuple):
    """Una riga della tabella «Memory Files» di /context: tipo, percorso,
    token, così come /context li stampa."""
    tipo: str
    percorso: str
    token: str


class Esito(NamedTuple):
    """Che cosa manca per finire, e le garanzie che non tengono."""
    manca: List[str]
    non_tiene: List[str]


def leggi_testo(ws: str, nome: str) -> Optional[str]:
    """Il testo di un file dello spazio di lavoro; None se non c'è.
    Raises: Problema se non è un file, non si legge o non è UTF-8."""
    percorso = os.path.join(ws, nome)
    if not os.path.lexists(percorso):
        return None
    if not os.path.isfile(percorso):
        raise Problema(f"{nome} c'è, ma non è un file")
    try:
        with open(percorso, "rb") as fh:
            dati = fh.read()
    except OSError as exc:
        raise Problema(f"{nome} non si legge: {exc.strerror or exc}") \
            from exc
    try:
        return dati.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise Problema(f"{nome} non è testo UTF-8") from exc


def celle(riga: str) -> List[str]:
    """Le celle di una riga di tabella Markdown, «| a | b |»."""
    return [c.strip() for c in riga.strip().strip("|").split("|")]


def tabella(righe: List[str], da: int) -> List[List[str]]:
    """Le righe di una tabella Markdown che comincia a da o dopo, saltate
    le righe vuote: l'intestazione per prima, senza la riga dei trattini."""
    i = da
    while i < len(righe) and not righe[i].strip():
        i += 1
    trovate: List[List[str]] = []
    while i < len(righe) and righe[i].lstrip().startswith("|"):
        riga = celle(righe[i])
        if not all(set(c) <= set("-: ") for c in riga):
            trovate.append(riga)
        i += 1
    return trovate


def voci_memoria(righe: List[str], nome: str, da: int) -> List[Voce]:
    """Le righe della tabella «Memory Files», con le colonne
    dall'intestazione. Raises: Problema senza la tabella o le colonne."""
    trovate = tabella(righe, da)
    if not trovate:
        raise Problema(f"{nome}: «Memory Files» senza la tabella dei file: "
                       "un'uscita di /context che questo controllo non sa "
                       "leggere")
    intestazione = [c.lower() for c in trovate[0]]
    try:
        tipo, percorso, token = (intestazione.index(c)
                                 for c in ("type", "path", "tokens"))
    except ValueError as exc:
        raise Problema(f"{nome}: la tabella «Memory Files» non ha le "
                       f"colonne Type, Path e Tokens: {trovate[0]}") from exc
    voci = []
    for riga in trovate[1:]:
        if len(riga) != len(intestazione):
            raise Problema(f"{nome}: una riga di «Memory Files» con "
                           f"{len(riga)} celle invece di {len(intestazione)}")
        voci.append(Voce(riga[tipo], riga[percorso], riga[token]))
    return voci


def leggi_rapporto(testo: str, nome: str) -> Optional[List[Voce]]:
    """Le righe di «Memory Files» di un'uscita di /context all (vuota se la
    sezione non c'è: nessun file caricato); None se il testo non è
    un'uscita di /context (manca il titolo «Context Usage»).
    Raises: Problema su una sezione che non si legge."""
    righe = testo.splitlines()
    titoli = [(i, m.group(1).lower()) for i, m in
              ((i, RE_TITOLO.match(r)) for i, r in enumerate(righe)) if m]
    if not any(t == "context usage" for _, t in titoli):
        return None
    for i, titolo in titoli:
        if titolo == "memory files":
            return voci_memoria(righe, nome, i + 1)
    categorie = [celle(r)[0].lower() for r in righe
                 if r.lstrip().startswith("|")]
    if "memory files" in categorie:
        raise Problema(f"{nome}: «Memory files» fra le categorie, ma senza "
                       "la tabella dei file: un'uscita di /context che "
                       "questo controllo non sa leggere")
    return []


def dello_spazio(voce: Voce, nomi: List[str]) -> bool:
    """Vero se la riga è il CLAUDE.md alla radice dello spazio di lavoro."""
    percorso = voce.percorso.replace("\\", "/")
    return any(percorso.endswith(f"/{n}/{CLAUDE_MD}") for n in nomi)


def nomi_dello_spazio(ws: str) -> List[str]:
    """Il nome della cartella dello spazio di lavoro, anche quello reale."""
    nomi = {os.path.basename(os.path.normpath(ws)),
            os.path.basename(os.path.realpath(ws))}
    return sorted(n for n in nomi if n)


def altre_voci(voci: List[Voce], nomi: List[str]) -> str:
    """Le altre righe di «Memory Files», senza i percorsi."""
    altre = [f"{v.tipo}, {v.token} token" for v in voci
             if not dello_spazio(v, nomi)]
    return "%d (%s)" % (len(altre), "; ".join(altre)) if altre else "nessuna"


def mostra(testo: str, ws: str) -> str:
    """Un testo senza la cartella dello spazio di lavoro e senza la casa."""
    for percorso in sorted({os.path.realpath(ws), os.path.abspath(ws)},
                           key=len, reverse=True):
        if percorso and percorso != os.sep:
            testo = testo.replace(percorso, "<spazio di lavoro>")
    casa = os.environ.get("HOME", "")
    if casa and casa != os.sep:
        testo = testo.replace(casa, "~")
    return RE_CASA.sub("~", testo)


def una_riga(testo: str) -> str:
    """Il testo su una riga, al massimo INIZIO caratteri."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= INIZIO else riga[:INIZIO] + "…"


def controlla_prima(ws: str, nomi: List[str], esito: Esito) -> bool:
    """prima.md: l'uscita di /context all, senza il CLAUDE.md dello spazio.
    Returns: vero se è così."""
    testo = leggi_testo(ws, PRIMA)
    if testo is None:
        print(f"Manca {PRIMA}: è il passo 2.")
        esito.manca.append(f"manca {PRIMA} (il passo 2)")
        return False
    voci = leggi_rapporto(testo, PRIMA)
    if voci is None:
        print(f"{PRIMA} non è l'uscita di /context all: non c'è «Context "
              "Usage». Rifate il passo 2.")
        esito.manca.append(f"{PRIMA} non è l'uscita di /context all")
        return False
    if any(dello_spazio(v, nomi) for v in voci):
        print(f"{PRIMA} ha già CLAUDE.md sotto «Memory files»: è stato fatto "
              f"dopo aver scritto CLAUDE.md. Ricominciate con {RESET}.")
        esito.manca.append(f"{PRIMA} fatto dopo CLAUDE.md ({RESET})")
        return False
    print(f"{PRIMA}: l'uscita di /context all; sotto «Memory files» il "
          "CLAUDE.md dello spazio di lavoro non c'è.")
    print(f"(dato) {PRIMA}, le righe sotto «Memory files»: "
          f"{altre_voci(voci, nomi)}")
    return True


def leggi_claude_md(ws: str, esito: Esito) -> Optional[str]:
    """Il testo di CLAUDE.md, se c'è."""
    testo = leggi_testo(ws, CLAUDE_MD)
    if testo is None:
        print(f"Manca {CLAUDE_MD}: è il passo 3.")
        esito.manca.append(f"manca {CLAUDE_MD} (il passo 3)")
        return None
    print(f"{CLAUDE_MD}: c'è, {len(testo.splitlines())} righe.")
    return testo


def piu_recente(ws: str, uno: str, altro: str) -> bool:
    """Vero se il file uno è stato modificato dopo il file altro."""
    return os.stat(os.path.join(ws, uno)).st_mtime_ns \
        > os.stat(os.path.join(ws, altro)).st_mtime_ns


def controlla_dopo(ws: str, nomi: List[str], c_e_claude: bool,
                   esito: Esito) -> bool:
    """dopo.md: l'uscita di /context all, con il CLAUDE.md dello spazio.
    Returns: vero se è così."""
    testo = leggi_testo(ws, DOPO)
    if testo is None:
        print(f"Manca {DOPO}: è il passo 4.")
        esito.manca.append(f"manca {DOPO} (il passo 4)")
        return False
    voci = leggi_rapporto(testo, DOPO)
    if voci is None:
        print(f"{DOPO} non è l'uscita di /context all: non c'è «Context "
              "Usage». Rifate il passo 4.")
        esito.manca.append(f"{DOPO} non è l'uscita di /context all")
        return False
    nostre = [v for v in voci if dello_spazio(v, nomi)]
    if nostre:
        print(f"{DOPO}: l'uscita di /context all; sotto «Memory files» c'è "
              f"CLAUDE.md, {nostre[0].token} token ({nostre[0].tipo}).")
        print(f"(dato) {DOPO}, le altre righe sotto «Memory files»: "
              f"{altre_voci(voci, nomi)}")
        return True
    if not c_e_claude:
        print(f"{DOPO}: sotto «Memory files» CLAUDE.md non c'è, e CLAUDE.md "
              "non c'è nemmeno nello spazio di lavoro.")
    elif piu_recente(ws, CLAUDE_MD, DOPO):
        print(f"{DOPO}: sotto «Memory files» CLAUDE.md non c'è, ma {DOPO} è "
              "di prima di CLAUDE.md. Rifate il passo 4.")
        esito.manca.append(f"{DOPO} fatto prima di CLAUDE.md (il passo 4)")
    else:
        print(f"{DOPO}: sotto «Memory files» CLAUDE.md non c'è, e CLAUDE.md "
              f"c'era già quando è stato fatto {DOPO}.")
        print(f"{G_CONTEXT}: {NON_CONFERMATA}")
        print("  La documentazione dice di controllare con /context all che "
              "il file si sia caricato,\n  sotto «Memory files»: in questa "
              "esecuzione CLAUDE.md non c'è.")
        esito.non_tiene.append(G_CONTEXT)
    return False


def hook_configurato(ws: str) -> bool:
    """Vero se .claude/settings.json chiama l'hook dello spazio di lavoro
    per InstructionsLoaded e il suo script c'è. Raises: Problema se le
    impostazioni non si leggono."""
    testo = leggi_testo(ws, IMPOSTAZIONI)
    if testo is None or not os.path.isfile(os.path.join(ws, HOOK)):
        return False
    try:
        dati = json.loads(testo)
    except ValueError as exc:
        raise Problema(f"{IMPOSTAZIONI} non è JSON: {exc}") from exc
    gruppi = dati.get("hooks", {}).get("InstructionsLoaded") \
        if isinstance(dati, dict) and isinstance(dati.get("hooks"), dict) \
        else None
    for gruppo in gruppi if isinstance(gruppi, list) else []:
        voci = gruppo.get("hooks") if isinstance(gruppo, dict) else None
        for voce in voci if isinstance(voci, list) else []:
            if isinstance(voce, dict) and os.path.basename(HOOK) in str(
                    voce.get("command", "")):
                return True
    return False


def conta_motivi(caricamenti: List[contesto.Caricamento]) -> str:
    """Le righe del registro per motivo e file, «session_start CLAUDE.md
    ×2»."""
    conti: Dict[str, int] = {}
    for caricamento in caricamenti:
        chiave = f"{caricamento.load_reason} {caricamento.file_path}"
        conti[chiave] = conti.get(chiave, 0) + 1
    return "; ".join(f"{k} ×{n}" for k, n in conti.items()) or "nessuna"


def controlla_registro(ws: str, dopo_con: bool, esito: Esito) -> None:
    """Il registro dell'hook: almeno una riga session_start per CLAUDE.md.
    È una garanzia quando dopo.md mostra che una sessione l'ha caricato."""
    if not hook_configurato(ws):
        print("L'hook InstructionsLoaded non è configurato in "
              f"{IMPOSTAZIONI}, o manca {HOOK}.")
        esito.manca.append("l'hook non è configurato: lo spazio di lavoro "
                           f"non è più quello di partenza ({RESET})")
        return
    percorso = os.path.join(ws, REGISTRO)
    if os.path.lexists(percorso) and not os.path.isfile(percorso):
        raise Problema(f"{REGISTRO} c'è, ma non è un file")
    caricamenti = contesto.leggi_caricamenti(percorso) \
        if os.path.lexists(percorso) else None
    quante = sum(1 for c in caricamenti or []
                 if c.load_reason == ALL_AVVIO and c.file_path == CLAUDE_MD)
    if caricamenti is not None:
        print(f"(dato) il registro dell'hook, {REGISTRO}: "
              f"{len(caricamenti)} righe: {conta_motivi(caricamenti)}")
    if quante:
        print(f"{REGISTRO}: CLAUDE.md caricato all'avvio in {quante} "
              f"righe.")
        print(f"{G_HOOK}: {CONFERMATA}")
        return
    if not dopo_con:
        return
    if caricamenti is None:
        print(f"{REGISTRO}: non c'è, e dopo.md mostra CLAUDE.md caricato.")
    else:
        print(f"{REGISTRO}: nessuna riga session_start per CLAUDE.md, e "
              "dopo.md mostra CLAUDE.md caricato.")
    print(f"{G_HOOK}: {NON_CONFERMATA}")
    print("  La documentazione dice che InstructionsLoaded scatta quando un "
          "CLAUDE.md entra nel\n  contesto, anche all'avvio: in questa "
          "esecuzione il registro non lo mostra.")
    esito.non_tiene.append(G_HOOK)


def risposta_da_export(testo: str) -> Optional[str]:
    """Dal testo di /export, la risposta alla domanda del README: le righe
    dopo l'ultima «❯ <domanda>», fino al prompt seguente o alla riga di
    stato «✻», senza le chiamate agli strumenti e il loro esito («⎿»).
    None se la domanda non c'è."""
    righe = testo.splitlines()
    inizio = None
    for i, riga in enumerate(righe):
        if riga.startswith("❯ ") and " ".join(riga[2:].split()) == DOMANDA:
            inizio = i + 1
    if inizio is None:
        return None
    blocchi: List[List[str]] = []
    corrente: Optional[List[str]] = None
    for riga in righe[inizio:]:
        if riga.startswith(("❯ ", "✻ ")):
            break
        if riga.startswith("● "):
            corrente = [riga[2:]]
            blocchi.append(corrente)
        elif riga.startswith("  ⎿"):
            corrente = None
        elif corrente is not None and (riga.startswith("  ")
                                       or not riga.strip()):
            corrente.append(riga[2:])
        else:
            corrente = None
    testi = ["\n".join(b).strip() for b in blocchi
             if not RE_STRUMENTO.match(b[0])]
    return "\n\n".join(t for t in testi if t)


def risposta_dal_file(ws: str) -> Optional[str]:
    """La risposta da risposta.txt, il /export della sessione; None se il
    file non c'è o non la contiene."""
    testo = leggi_testo(ws, RISPOSTA)
    if testo is None:
        return None
    if not any(r.startswith("❯ ") for r in testo.splitlines()):
        print(f"(dato) {RISPOSTA} non è l'uscita di /export: lo leggo tutto "
              "come risposta")
        return testo
    trovata = risposta_da_export(testo)
    if trovata is None:
        print(f"(dato) {RISPOSTA}: la domanda del README non c'è")
    return trovata


def risposta_dallo_stream(ws: str) -> Optional[str]:
    """La risposta da domanda.jsonl, lo stream di _docente/live.sh, con i
    suoi conti; None se lo stream non c'è."""
    percorso = os.path.join(ws, STREAM)
    if not os.path.isfile(percorso):
        print(f"(dato) la risposta: {RISPOSTA} non c'è (il passo 5, «/export "
              f"{RISPOSTA}» nella sessione)")
        return None
    esec = prove.leggi_stream(percorso)
    strumenti = ", ".join(s.nome for s in esec.strumenti) or "nessuno"
    secondi = ("%.1f" % esec.secondi).replace(".", ",")
    print(f"(dato) {STREAM}, la domanda in claude -p al posto della "
          f"sessione: turni {esec.turni}; token {esec.token_totali}; "
          f"{secondi} s; strumenti: {strumenti}")
    if not esec.completa or esec.errore:
        print(f"(dato) {STREAM}: la chiamata non è completa, o è finita con "
              "un errore")
    return esec.testo


def risposta(ws: str) -> Optional[str]:
    """La risposta alla domanda, da risposta.txt o, se manca, dallo stream;
    None se non c'è. È un dato: un file che non si legge si dice in una riga
    (dato) e non cambia l'uscita, che non dipende dalla risposta."""
    try:
        if os.path.lexists(os.path.join(ws, RISPOSTA)):
            return risposta_dal_file(ws)
        return risposta_dallo_stream(ws)
    except Problema as exc:
        print(f"(dato) la risposta non si legge: {exc}")
        return None


def dati_risposta(ws: str, claude_md: Optional[str]) -> None:
    """La risposta alla domanda, come dato: l'inizio e i comandi di
    CLAUDE.md che vi compaiono."""
    testo = risposta(ws)
    if not testo or not testo.strip():
        if testo is not None:
            print("(dato) la risposta è vuota")
        return
    print(f"(dato) la risposta alla domanda: «{una_riga(mostra(testo, ws))}»")
    if claude_md is None:
        return
    piatta = " ".join(testo.split())
    comandi: List[str] = []
    for comando in RE_COMANDO.findall(claude_md):
        if comando not in comandi:
            comandi.append(comando)
    voci = ["`%s`: %s" % (c, "sì" if " ".join(c.split()) in piatta else "no")
            for c in comandi]
    print("(dato) i comandi di CLAUDE.md nella risposta: %s"
          % ("; ".join(voci) or "CLAUDE.md non ha comandi fra apici inversi"))
    print("(dato) la risposta nomina CLAUDE.md: %s"
          % ("sì" if CLAUDE_MD in testo else "no"))


def main(argv: List[str]) -> int:
    if len(argv) != 1 or not argv[0] or not os.path.isdir(argv[0]):
        raise Problema("spazio di lavoro assente: %s"
                       % (argv[0] if argv else ""))
    ws = os.path.abspath(argv[0])
    nomi = nomi_dello_spazio(ws)
    esito = Esito([], [])
    print("Verifica di M6-E01 «Che cosa vede Claude»\n")
    prima_senza = controlla_prima(ws, nomi, esito)
    claude_md = leggi_claude_md(ws, esito)
    dopo_con = controlla_dopo(ws, nomi, claude_md is not None, esito)
    if prima_senza and dopo_con:
        print(f"{G_CONTEXT}: {CONFERMATA} ({PRIMA} senza, {DOPO} con)")
    controlla_registro(ws, dopo_con, esito)
    print()
    dati_risposta(ws, claude_md)
    if esito.manca:
        print("\nNon ancora: %s." % "; ".join(esito.manca))
    if esito.non_tiene:
        print("\nNon confermata in questa esecuzione: %s. È un esito da far "
              "vedere al docente." % "; ".join(esito.non_tiene))
    if esito.manca or esito.non_tiene:
        return 1
    print(f"\n{FATTO}")
    return 0


if __name__ == "__main__":
    sys.exit(prove.principale(main, sys.argv[1:]))
