"""lib_leggi_frontmatter.py -- il lettore del frontmatter di tools/
controlla_skill.py, con la sola libreria standard: il sottoinsieme di YAML
che le skill usano, e un errore con il numero di riga per ciò che non è in
quel sottoinsieme.

Legge: «chiave: valore» (semplice, anche su più righe rientrate; fra apici;
fra virgolette, chiuse sulla stessa riga), i blocchi > >- | |-, una mappa
sotto metadata (un livello, valori stringa), le liste e le mappe chiuse su
una riga; una lista o una mappa rientrata sotto un altro campo (paths,
hooks…) non la apre: è opaca. Non apre nemmeno una lista in colonna 1 sotto
una chiave senza valore, che YAML ammette: è una lista.

Non è un lettore YAML completo. Dove un lettore YAML direbbe altro: un commento
fra le righe di un valore semplice non lo interrompe, e .inf, 0x1f o una data
restano stringhe.

leggi_frontmatter(righe) riceve le righe fra i due ---, come coppie (numero
di riga nel file, testo), e restituisce (campi, errori): un dizionario nome
-> Campo(valore, tipo, riga) e gli errori di sintassi, ciascuno «riga N:
perché e che cosa fare». I tipi di un campo:
  stringa  il valore è il testo
  mappa    il valore è un dizionario per metadata, altrimenti None
  lista    una lista
  opaco    un blocco rientrato che non si apre
  altro    un numero, un booleano o null per YAML
  vuoto    una chiave senza valore
  rotto    un errore di sintassi già segnalato: nessun altro errore su quel
           campo
Non è un modulo da eseguire: nessun bit di esecuzione.
"""
from __future__ import annotations

import re
from typing import Dict, List, NamedTuple, Optional, Tuple

CAMPI_STRINGA = ("name", "description", "compatibility", "allowed-tools")
SEGNI_VIETATI = "*&!|>%@`,]}"
RE_CHIAVE = re.compile(r"^([A-Za-z0-9_][A-Za-z0-9_.-]*):(?:[ \t]+(.*))?$")
RE_BLOCCO = re.compile(r"^[|>][+-]?[1-9]?[+-]?(?:[ \t]+#.*)?$")
RE_NON_STRINGA = re.compile(
    r"^(?:~|null|Null|NULL|true|True|TRUE|false|False|FALSE|yes|Yes|YES|no|No"
    r"|NO|on|On|ON|off|Off|OFF|[-+]?[0-9]+"
    r"|[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?)$")
RE_COMMENTO = re.compile(r"[ \t]#.*$")
RE_ESADECIMALE = re.compile(r"^[0-9A-Fa-f]+$")
# Gli escape di YAML fra virgolette doppie; x, u e U vogliono 2, 4 e 8 cifre.
ESCAPE = {"0": "\0", "a": "\a", "b": "\b", "t": "\t", "\t": "\t", "n": "\n",
          "v": "\v", "f": "\f", "r": "\r", "e": "\x1b", " ": " ", '"': '"',
          "/": "/", "\\": "\\", "N": "\x85", "_": "\xa0",
          "L": "\N{LINE SEPARATOR}", "P": "\N{PARAGRAPH SEPARATOR}"}
CIFRE_ESCAPE = {"x": 2, "u": 4, "U": 8}

Riga = Tuple[int, str]


class _EscapeSbagliato(Exception):
    """Un \\X che YAML non conosce, fra virgolette doppie."""


class Campo(NamedTuple):
    """Un campo del frontmatter: il valore, il tipo, la sua riga."""
    valore: object
    tipo: str
    riga: int


def _rotto(numero: int) -> Campo:
    return Campo(None, "rotto", numero)


def _rientro(testo: str) -> str:
    return testo[:len(testo) - len(testo.lstrip(" \t"))]


def _spazi(testo: str) -> int:
    return len(testo) - len(testo.lstrip(" "))


def _commento_o_vuota(testo: str) -> bool:
    pulita = testo.strip()
    return not pulita or pulita.startswith("#")


def _senza_commento(testo: str) -> str:
    return RE_COMMENTO.sub("", testo).rstrip()


def _ha_due_punti(testo: str) -> bool:
    return ": " in testo or ":\t" in testo or testo.endswith(":")


def _righe_sotto(righe: List[Riga], i: int) -> Tuple[List[Riga], int]:
    """Le righe rientrate o vuote da i in poi, senza le vuote in fondo."""
    sotto: List[Riga] = []
    while i < len(righe):
        if righe[i][1].strip() and not _rientro(righe[i][1]):
            break
        sotto.append(righe[i])
        i += 1
    while sotto and not sotto[-1][1].strip():
        sotto.pop()
    return sotto, i


def _senza_tabulazioni(sotto: List[Riga], errori: List[str]) -> List[Riga]:
    """Segnala le righe con una tabulazione nel rientro e le toglie."""
    buone: List[Riga] = []
    for numero, testo in sotto:
        if "\t" in _rientro(testo) and testo.strip():
            errori.append(
                f"riga {numero}: una tabulazione nel rientro: YAML rientra "
                "solo con gli spazi. Sostituiscila con due spazi.")
        else:
            buone.append((numero, testo))
    return buone


def _leggi_escape(resto: str, i: int) -> Tuple[str, int]:
    """Il carattere di un escape in posizione i, e dove riprendere."""
    lettera = resto[i + 1]
    if lettera in ESCAPE:
        return ESCAPE[lettera], i + 2
    quante = CIFRE_ESCAPE.get(lettera, 0)
    cifre = resto[i + 2:i + 2 + quante]
    if quante and len(cifre) == quante and RE_ESADECIMALE.match(cifre):
        try:
            return chr(int(cifre, 16)), i + 2 + quante
        except (ValueError, OverflowError):
            pass
    raise _EscapeSbagliato(resto[i:i + 2])


def _chiudi_virgolette(resto: str) -> Optional[Tuple[str, str]]:
    """Il valore fra apici o virgolette e ciò che segue; None se non chiude.

    Raises: _EscapeSbagliato per un \\X che YAML non conosce.
    """
    corpo: List[str] = []
    i = 1
    if resto[0] == "'":
        while i < len(resto):
            if resto[i] == "'":
                if resto[i + 1:i + 2] == "'":
                    corpo.append("'")
                    i += 2
                    continue
                return "".join(corpo), resto[i + 1:]
            corpo.append(resto[i])
            i += 1
        return None
    while i < len(resto):
        if resto[i] == "\\" and i + 1 < len(resto):
            carattere, i = _leggi_escape(resto, i)
            corpo.append(carattere)
            continue
        if resto[i] == '"':
            return "".join(corpo), resto[i + 1:]
        corpo.append(resto[i])
        i += 1
    return None


def _riga_di_troppo(sotto: List[Riga], errori: List[str]) -> None:
    """Dopo un valore già chiuso non può seguire una riga rientrata."""
    for numero, testo in sotto:
        if not _commento_o_vuota(testo):
            errori.append(
                f"riga {numero}: un rientro che qui non va: il valore sopra è "
                "già chiuso. Le chiavi stanno in colonna 1.")
            return


def _fra_virgolette(resto: str, numero: int, sotto: List[Riga],
                    errori: List[str]) -> Campo:
    try:
        letto = _chiudi_virgolette(resto)
    except _EscapeSbagliato as exc:
        errori.append(
            f"riga {numero}: «{exc}» non è un escape di YAML fra virgolette "
            "doppie: scrivi \\\\ per una barra rovesciata, o usa gli apici "
            "singoli.")
        return _rotto(numero)
    if letto is None:
        errori.append(
            f"riga {numero}: virgolette non chiuse: questo controllo vuole il "
            "valore e la chiusura sulla stessa riga.")
        return _rotto(numero)
    valore, dopo = letto
    dopo = dopo.strip()
    if dopo and not dopo.startswith("#"):
        consiglio = ("un apice dentro un valore fra apici si raddoppia ('')"
                     if resto[0] == "'" else
                     "tutto il valore va dentro le virgolette")
        errori.append(
            f"riga {numero}: c'è del testo dopo le virgolette che chiudono: "
            f"{consiglio}.")
        return _rotto(numero)
    _riga_di_troppo(sotto, errori)
    return Campo(valore, "stringa", numero)


def _piega(righe: List[str]) -> str:
    """Un blocco >: le righe si uniscono con uno spazio, la vuota va a capo."""
    pezzi: List[str] = []
    for riga in righe:
        if not riga:
            pezzi.append("\n")
        elif pezzi and pezzi[-1] != "\n":
            pezzi.append(" " + riga)
        else:
            pezzi.append(riga)
    return "".join(pezzi)


def _blocco(resto: str, numero: int, sotto: List[Riga],
            errori: List[str]) -> Campo:
    piene = [testo for _, testo in sotto if testo.strip()]
    if not piene:
        return Campo("", "stringa", numero)
    base = _spazi(piene[0])
    righe: List[str] = []
    rotto = False
    for n, testo in sotto:
        if not testo.strip():
            righe.append("")
        elif base == 0 or _spazi(testo) < base:
            errori.append(
                f"riga {n}: una tabulazione nel rientro: YAML rientra solo "
                "con gli spazi. Sostituiscila con due spazi."
                if "\t" in _rientro(testo) else
                f"riga {n}: un rientro che cala dentro un blocco: ogni riga "
                "del blocco ha almeno il rientro della prima.")
            rotto = True
        else:
            righe.append(testo[base:])
    if rotto:
        return _rotto(numero)
    valore = "\n".join(righe) if resto[0] == "|" else _piega(righe)
    return Campo(valore, "stringa", numero)


def _chiusura_flusso(testo: str) -> int:
    """L'indice dopo la parentesi che chiude quella in testa; -1 se manca.

    Un apice apre solo in testa a un elemento: quello di «l'assistenza» non
    è una virgoletta. Le parentesi vanno a coppie: [ con ], { con }.
    """
    aperte: List[str] = []
    chiuso_da = ""
    precedente = "["
    i = 0
    while i < len(testo):
        c = testo[i]
        if chiuso_da:
            if c == "\\" and chiuso_da == '"':
                i += 1
            elif c == chiuso_da:
                chiuso_da = ""
        elif c in "\"'" and precedente in "[{,:":
            chiuso_da = c
        elif c in "[{":
            aperte.append(c)
        elif c in "]}":
            if not aperte or aperte.pop() != ("[" if c == "]" else "{"):
                return -1
            if not aperte:
                return i + 1
        if not c.isspace():
            precedente = c
        i += 1
    return -1


def _dividi_flusso(interno: str) -> List[str]:
    """Gli elementi di una mappa o di una lista, divisi dalle virgole esterne.
    """
    pezzi: List[str] = []
    profondita = 0
    chiuso_da = ""
    attuale = ""
    precedente = ","
    for c in interno:
        if chiuso_da:
            chiuso_da = "" if c == chiuso_da else chiuso_da
        elif c in "\"'" and precedente in "[{,:":
            chiuso_da = c
        elif c in "[{":
            profondita += 1
        elif c in "]}":
            profondita -= 1
        if c == "," and not chiuso_da and profondita == 0:
            pezzi.append(attuale)
            attuale = ""
        else:
            attuale += c
        if not c.isspace():
            precedente = c
    if attuale.strip():
        pezzi.append(attuale)
    return pezzi


def _scalare(testo: str) -> Optional[str]:
    """Una stringa in una mappa su una riga; None se per YAML non è una
    stringa o non si legge."""
    testo = testo.strip()
    if not testo or testo[0] in "[{" or testo[0] in SEGNI_VIETATI:
        return None
    if testo[0] in "\"'":
        try:
            letto = _chiudi_virgolette(testo)
        except _EscapeSbagliato:
            return None
        return letto[0] if letto is not None and not letto[1].strip() else None
    return None if RE_NON_STRINGA.match(testo) else testo


def _mappa_flusso(testo: str) -> Dict[str, Optional[str]]:
    mappa: Dict[str, Optional[str]] = {}
    for pezzo in _dividi_flusso(testo[1:-1]):
        chiave, _, valore = pezzo.partition(":")
        mappa[(_scalare(chiave) or chiave).strip()] = _scalare(valore)
    return mappa


def _flusso(chiave: str, resto: str, numero: int, sotto: List[Riga],
            errori: List[str]) -> Campo:
    fine = _chiusura_flusso(resto)
    if fine < 0:
        errori.append(
            f"riga {numero}: il valore comincia con «{resto[0]}» e la "
            "parentesi non si chiude sulla stessa riga: per YAML è una lista "
            "o una mappa rimasta aperta. Se è un testo, mettilo fra "
            "virgolette.")
        return _rotto(numero)
    dopo = resto[fine:].strip()
    if dopo and not dopo.startswith("#"):
        errori.append(
            f"riga {numero}: dopo la parentesi che chiude c'è dell'altro: se "
            "è un testo, mettilo tutto fra virgolette.")
        return _rotto(numero)
    _riga_di_troppo(sotto, errori)
    if resto[0] == "[":
        return Campo(None, "lista", numero)
    valore = _mappa_flusso(resto[:fine]) if chiave == "metadata" else None
    return Campo(valore, "mappa", numero)


def _semplice(resto: str, numero: int, sotto: List[Riga],
              errori: List[str]) -> Campo:
    """Un valore senza virgolette, anche su più righe rientrate."""
    parti: List[str] = []
    rotto = False
    for n, testo in [(numero, resto)] + sotto:
        if _commento_o_vuota(testo):
            continue
        pezzo = _senza_commento(testo.strip())
        if _ha_due_punti(pezzo):
            rotto = True
            if n == numero:
                errori.append(
                    f"riga {n}: due punti seguiti da uno spazio dentro il "
                    "valore: per YAML è una seconda chiave. Metti il valore "
                    "fra virgolette, o togli i due punti.")
            else:
                errori.append(
                    f"riga {n}: una riga rientrata con i due punti: o è una "
                    "chiave con il rientro sbagliato (le chiavi stanno in "
                    "colonna 1), o è un valore da mettere fra virgolette.")
        parti.append(pezzo)
    if rotto:
        return _rotto(numero)
    valore = " ".join(parti)
    tipo = "altro" if RE_NON_STRINGA.match(valore) else "stringa"
    return Campo(valore, tipo, numero)


def _valore_metadata(chiave: str, valore: str, numero: int,
                     mappa: Dict[str, Optional[str]],
                     errori: List[str]) -> None:
    """Il valore di una riga sotto metadata, con gli stessi controlli di uno
    di primo livello; una sintassi rotta non entra, ciò che non è una stringa
    entra come None."""
    campo = _leggi_campo(chiave, valore, numero, [], errori)
    if campo.tipo != "rotto":
        mappa[chiave] = campo.valore if campo.tipo == "stringa" else None


def _mappa_metadata(numero: int, utili: List[Riga],
                    errori: List[str]) -> Campo:
    """La mappa sotto metadata: un livello, lo stesso rientro."""
    base = len(_rientro(utili[0][1]))
    mappa: Dict[str, Optional[str]] = {}
    viste: Dict[str, int] = {}
    for n, testo in utili:
        trovata = RE_CHIAVE.match(testo.strip())
        if len(_rientro(testo)) != base:
            errori.append(
                f"riga {n}: metadata è una mappa da stringa a stringa: niente "
                "livelli annidati, e lo stesso rientro per ogni riga.")
        elif trovata is None:
            errori.append(f"riga {n}: sotto metadata ogni riga è una coppia "
                          "«chiave: valore».")
        elif trovata.group(1) in viste:
            errori.append(
                f"riga {n}: chiave ripetuta: {trovata.group(1)} è già alla "
                f"riga {viste[trovata.group(1)]}. Tienine una sola.")
        else:
            viste[trovata.group(1)] = n
            _valore_metadata(trovata.group(1),
                             (trovata.group(2) or "").strip(), n, mappa,
                             errori)
    return Campo(mappa, "mappa", numero)


def _senza_valore(chiave: str, numero: int, sotto: List[Riga],
                  errori: List[str]) -> Campo:
    """Una chiave senza valore sulla sua riga: ciò che sta sotto decide."""
    utili = [riga for riga in sotto if not _commento_o_vuota(riga[1])]
    if not utili:
        return Campo(None, "vuoto", numero)
    if chiave == "metadata":
        return _mappa_metadata(numero, utili, errori)
    if chiave not in CAMPI_STRINGA:
        return Campo(None, "opaco", numero)
    prima = utili[0][1].strip()
    if prima == "-" or prima.startswith("- "):
        return Campo(None, "lista", numero)
    # Il valore sta sulla riga sotto: gli stessi controlli della riga della
    # chiave, virgolette e segni vietati compresi.
    campo = _leggi_campo(chiave, prima, utili[0][0], utili[1:], errori)
    return campo._replace(riga=numero)


def _leggi_campo(chiave: str, resto: str, numero: int, sotto: List[Riga],
                 errori: List[str]) -> Campo:
    # In un blocco una tabulazione dopo il rientro è testo: la guarda _blocco.
    if RE_BLOCCO.match(resto):
        return _blocco(resto, numero, sotto, errori)
    sotto = _senza_tabulazioni(sotto, errori)
    if not resto or resto.startswith("#"):
        return _senza_valore(chiave, numero, sotto, errori)
    if resto[0] in "\"'":
        return _fra_virgolette(resto, numero, sotto, errori)
    if resto[0] in "[{":
        return _flusso(chiave, resto, numero, sotto, errori)
    if resto[0] in SEGNI_VIETATI or resto in ("-", "?") \
            or resto[:2] in ("- ", "? "):
        errori.append(
            f"riga {numero}: il valore comincia con «{resto[0]}», un segno "
            "che per YAML vuol dire altro. Metti il valore fra virgolette.")
        return _rotto(numero)
    return _semplice(resto, numero, sotto, errori)


def _lista_in_colonna_1(righe: List[Riga], i: int,
                        errori: List[str]) -> Optional[int]:
    """Dove finisce la lista in colonna 1 che comincia da i; None se lì non
    c'è. Come una lista rientrata, non si apre: una voce può continuare su
    righe rientrate; la prima riga di colonna 1 che non è una voce la chiude.
    """
    fine: Optional[int] = None
    while i < len(righe):
        testo = righe[i][1]
        i += 1
        if _commento_o_vuota(testo):
            continue
        if testo.rstrip() != "-" and not testo.startswith("- ") \
                and (fine is None or not _rientro(testo)):
            break
        _senza_tabulazioni([righe[i - 1]], errori)
        fine = i
    return fine


def _campo_e_seguito(chiave: str, resto: str, numero: int, righe: List[Riga],
                     i: int, errori: List[str]) -> Tuple[Campo, int]:
    """Il campo di una chiave e la riga da cui riprendere."""
    sotto, i = _righe_sotto(righe, i)
    if (not resto or resto.startswith("#")) \
            and all(_commento_o_vuota(testo) for _, testo in sotto):
        fine = _lista_in_colonna_1(righe, i, errori)
        if fine is not None:
            return Campo(None, "lista", numero), fine
    return _leggi_campo(chiave, resto, numero, sotto, errori), i


def leggi_frontmatter(righe: List[Riga]) -> Tuple[Dict[str, Campo], List[str]]:
    """I campi e gli errori di sintassi delle righe del frontmatter."""
    campi: Dict[str, Campo] = {}
    errori: List[str] = []
    i = 0
    while i < len(righe):
        numero, testo = righe[i]
        i += 1
        if _commento_o_vuota(testo):
            continue
        if _rientro(testo):
            _senza_tabulazioni([(numero, testo)], errori)
            if "\t" not in _rientro(testo):
                errori.append(
                    f"riga {numero}: un rientro senza una chiave sopra: le "
                    "chiavi del frontmatter stanno in colonna 1.")
            continue
        trovata = RE_CHIAVE.match(testo)
        if trovata is None:
            errori.append(
                f"riga {numero}: non è una riga «chiave: valore» che questo "
                "controllo sa leggere: la chiave sta in colonna 1, i due "
                "punti subito dopo, poi uno spazio e il valore.")
            continue
        chiave = trovata.group(1)
        campo, i = _campo_e_seguito(chiave, (trovata.group(2) or "").strip(),
                                    numero, righe, i, errori)
        if chiave in campi:
            errori.append(
                f"riga {numero}: chiave ripetuta: {chiave} è già alla riga "
                f"{campi[chiave].riga}. Tienine una sola.")
        else:
            campi[chiave] = campo
    return campi, errori
