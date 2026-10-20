#!/usr/bin/env python3
"""kit.py -- gli attrezzi di misura delle esercitazioni del Modulo 2.

Li usa misura.sh; si possono usare anche da soli, dalla cartella
dell'esercizio. <cartella> è la cartella del prompt da misurare (quella
che contiene prompt/, dati/, rubrica.md e controlli.tsv): «.» se c'è un
prompt solo, altrimenti la sua famiglia (sviluppo, supporto, sistemi).

  componi   <cartella> <versione>  il prompt di prompt/<versione>.md, con
                                   ogni {{nome}} sostituito dal file
                                   dati/<nome>.<estensione>; prima della
                                   chiamata controlla anche controlli.tsv,
                                   la rubrica e il peso della consegna al
                                   giudice senza la risposta
  estrai    <cartella> <versione>  il campo «result» di
                                   risposte/<versione>.json, scritto in
                                   risposte/<versione>.md
  controlla <cartella> <versione>  i controlli di controlli.tsv sulla
                                   risposta: controlli/<versione>.txt
  consegna  <cartella> <versione>  il testo che riceve il giudice: la
                                   rubrica, i dati, la risposta
  giudizio  <cartella> <versione>  il riepilogo di giudizi/<versione>.json
  confronta <cartella> <v1> <v2>   controlli e giudizi di due versioni,
                                   fianco a fianco

Il prompt composto e la consegna al giudice arrivano a claude -p come un
argomento solo: oltre i 100000 byte componi e consegna li rifiutano, con i
file da cui vengono e il loro peso.

Formati:
  rubrica.md     un'affermazione verificabile per riga:
                 «- **id**: testo» (id in minuscolo, lettere e _)
  controlli.tsv  intestazione «tipo<TAB>valore<TAB>descrizione», poi una
                 riga per controllo; tipo: assente o presente (valore:
                 un'espressione regolare, senza distinzione tra maiuscole
                 e minuscole), parole_max, parole_min, righe_max (valore:
                 un numero)

Uscita: 0 fatto; per controlla, ogni controllo superato ·
        1 per controlla, almeno un controllo non superato (un esito
        normale: v0 ne manca qualcuno); per gli altri comandi, un file di
        misura incompleto o con un errore (una risposta con is_error o con
        un usage non numerico, un giudizio senza structured_output) ·
        2 uso sbagliato, file assente o illeggibile, formato non valido,
        testo oltre il limite; per controlla, anche una risposta da
        rimisurare. Mai un traceback: un errore inatteso esce 2, con un
        messaggio di una riga.
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NoReturn, Optional, Tuple

PLACEHOLDER = re.compile(r"\{\{([a-z][a-z0-9_]*)\}\}")
CLAIM = re.compile(r"^- \*\*([a-z][a-z0-9_]*)\*\*:\s+(\S.*)$")
VERSIONE = re.compile(r"v(?:0|[1-9][0-9]*)")  # con fullmatch
NUMERO = re.compile(r"[0-9]+")              # con fullmatch: cifre ASCII
TIPI = ("assente", "presente", "parole_max", "parole_min", "righe_max")
# I conteggi di usage che kit.py legge: i primi tre fanno l'entrata.
ENTRATA = ("input_tokens", "cache_creation_input_tokens",
           "cache_read_input_tokens")
RIGHE_RISPOSTA = 25   # quante righe della risposta stampa «estrai»
# Il prompt composto e la consegna viaggiano come un argomento solo di
# claude -p, e il sistema operativo ne limita la lunghezza (su Linux
# 128 KiB): oltre questo limite kit.py li ferma prima della chiamata.
LIMITE_BYTE = 100000


class Errore(Exception):
    """Un problema dei dati: l'uscita è il codice che porta (1 o 2)."""

    def __init__(self, messaggio: str, codice: int = 2) -> None:
        super().__init__(messaggio)
        self.codice = codice


def leggi(percorso: str) -> str:
    """Il testo di un file in UTF-8; Errore(2) se manca o non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        raise Errore("manca il file %s" % percorso)
    except (OSError, UnicodeDecodeError) as exc:
        raise Errore("non riesco a leggere %s (%s)" % (percorso, exc))


def scrivi(percorso: str, testo: str) -> None:
    """Scrive un file di testo in UTF-8, creando la cartella se serve;
    Errore(2) se non si scrive."""
    cartella = os.path.dirname(percorso)
    try:
        if cartella:
            os.makedirs(cartella, exist_ok=True)
        with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Errore("non riesco a scrivere %s (%s)" % (percorso, exc))


def controlla_versione(versione: str) -> None:
    """Rifiuta un nome di versione diverso da v0, v1, v2, ...: «v» e un
    numero senza zeri davanti, come in misura.sh."""
    if not VERSIONE.fullmatch(versione):
        raise Errore("versione «%s» non valida: si scrive v0, v1, v2, ..."
                     % versione)


def dati(cartella: str) -> Dict[str, Tuple[str, str]]:
    """I file di <cartella>/dati, per nome senza estensione:
    {nome: (percorso, testo)}."""
    base = os.path.join(cartella, "dati")
    if not os.path.isdir(base):
        return {}
    try:
        nomi = sorted(os.listdir(base))
    except OSError as exc:
        raise Errore("non riesco a leggere la cartella %s (%s)" % (base, exc))
    trovati: Dict[str, Tuple[str, str]] = {}
    for nome in nomi:
        percorso = os.path.join(base, nome)
        if nome.startswith(".") or not os.path.isfile(percorso):
            continue
        radice = nome.split(".", 1)[0]
        if radice in trovati:
            raise Errore("in %s due file si chiamano «%s»: il segnaposto "
                         "{{%s}} sarebbe ambiguo" % (base, radice, radice))
        trovati[radice] = (percorso, leggi(percorso).rstrip("\n"))
    return trovati


def nel_limite(testo: str, cosa: str, fonti: List[Tuple[str, str]],
               rimedio: str) -> str:
    """Il testo, se in UTF-8 non supera LIMITE_BYTE; altrimenti Errore(2)
    con il peso del testo e di ogni sua fonte (percorso, testo)."""
    peso = len(testo.encode("utf-8"))
    if peso <= LIMITE_BYTE:
        return testo
    raise Errore("%s: %d byte, oltre il limite di %d byte (%s); %s" % (
        cosa, peso, LIMITE_BYTE, ", ".join(
            "%s %d byte" % (os.path.normpath(p), len(t.encode("utf-8")))
            for p, t in fonti), rimedio))


def componi(cartella: str, versione: str) -> str:
    """Il prompt di una versione con i dati al posto dei segnaposto; prima
    della chiamata a pagamento, controlla anche ciò che serve dopo."""
    controlla_versione(versione)
    percorso = os.path.join(cartella, "prompt", versione + ".md")
    testo = leggi(percorso)
    disponibili = dati(cartella)
    usati = sorted(set(PLACEHOLDER.findall(testo)))
    mancanti = [n for n in usati if n not in disponibili]
    if mancanti:
        raise Errore("il prompt %s usa %s, ma in %s/dati non c'è un file "
                     "con quel nome (ci sono: %s)" % (
                         versione, ", ".join("{{%s}}" % n for n in mancanti),
                         cartella, ", ".join(sorted(disponibili)) or "nessuno"))
    composto = PLACEHOLDER.sub(lambda m: disponibili[m.group(1)][1], testo)
    if not composto.strip():
        raise Errore("il prompt %s è vuoto" % versione)
    prompt = nel_limite(composto.rstrip("\n"),
                        "il prompt composto di %s è troppo lungo" % versione,
                        [(percorso, testo)] + [disponibili[n] for n in usati],
                        "accorciate i file di dati/")
    # Ciò che serve dopo la risposta si controlla prima di chiederla: le
    # righe di controlli.tsv, la rubrica, la consegna al giudice senza la
    # risposta (la rubrica e ogni file di dati/, anche quelli non usati).
    controlli(cartella)
    parti, fonti = consegna_fissa(cartella)
    nel_limite("\n".join(parti),
               "la consegna al giudice di %s è troppo lunga" % versione,
               fonti, "accorciate i file di dati/ o la rubrica")
    return prompt


def json_di_claude(percorso: str) -> dict:
    """Il JSON di claude -p --output-format json; Errore(1) se è un errore."""
    try:
        doc = json.loads(leggi(percorso))
    except (ValueError, RecursionError) as exc:
        raise Errore("%s non è un JSON valido (%s)" % (percorso, exc), 1)
    if not isinstance(doc, dict) or doc.get("type") != "result":
        raise Errore("%s non è il JSON di claude -p" % percorso, 1)
    if doc.get("is_error"):
        raise Errore("%s contiene un errore di Claude Code: %s" % (
            percorso, str(doc.get("result"))[:200]), 1)
    return doc


def risposta(cartella: str, versione: str) -> str:
    """Il testo della risposta di una versione (risposte/<v>.json)."""
    doc = json_di_claude(os.path.join(cartella, "risposte", versione + ".json"))
    testo = doc.get("result")
    if not isinstance(testo, str) or not testo.strip():
        raise Errore("la risposta di %s è vuota" % versione, 1)
    return testo


def token(doc: dict, percorso: str) -> Tuple[int, int]:
    """(token in entrata, token in uscita) del campo usage del JSON di
    percorso; Errore(1) se un conteggio non è un numero intero."""
    uso = doc.get("usage") or {}
    if not isinstance(uso, dict):
        raise Errore("%s: usage non è un oggetto: misurate di nuovo la "
                     "versione" % percorso, 1)
    conti: Dict[str, int] = {}
    for chiave in ENTRATA + ("output_tokens",):
        valore = uso.get(chiave)
        if valore is None:
            conti[chiave] = 0
        elif isinstance(valore, int) and not isinstance(valore, bool):
            conti[chiave] = valore
        elif isinstance(valore, str) and NUMERO.fullmatch(valore):
            conti[chiave] = int(valore)
        else:
            raise Errore("%s: usage.%s non è un numero (%s): misurate di "
                         "nuovo la versione" % (percorso, chiave, json.dumps(
                             valore, ensure_ascii=False)[:40]), 1)
    return sum(conti[k] for k in ENTRATA), conti["output_tokens"]


def estrai(cartella: str, versione: str) -> None:
    """Scrive risposte/<v>.md e ne stampa l'inizio, con i token."""
    controlla_versione(versione)
    percorso = os.path.join(cartella, "risposte", versione + ".json")
    doc = json_di_claude(percorso)
    testo = risposta(cartella, versione)
    entrata, uscita = token(doc, percorso)
    scrivi(os.path.join(cartella, "risposte", versione + ".md"), testo + "\n")
    modelli = ", ".join(sorted((doc.get("modelUsage") or {}).keys()))
    print("Risposta %s (%s): %d token in entrata, %d in uscita"
          % (versione, modelli or "modello non indicato", entrata, uscita))
    righe = testo.strip("\n").split("\n")
    for riga in righe[:RIGHE_RISPOSTA]:
        print("  | " + riga)
    if len(righe) > RIGHE_RISPOSTA:
        print("  | […] (la risposta intera è in %s)" % os.path.join(
            cartella, "risposte", versione + ".md"))


def rubrica(cartella: str) -> List[Tuple[str, str]]:
    """Le affermazioni di rubrica.md: [(id, testo)], almeno una."""
    percorso = os.path.join(cartella, "rubrica.md")
    voci: List[Tuple[str, str]] = []
    visti = set()
    for riga in leggi(percorso).splitlines():
        m = CLAIM.match(riga.strip())
        if not m:
            continue
        if m.group(1) in visti:
            raise Errore("%s: l'id «%s» compare due volte"
                         % (percorso, m.group(1)))
        visti.add(m.group(1))
        voci.append((m.group(1), m.group(2).strip()))
    if not voci:
        raise Errore("%s non contiene affermazioni nel formato "
                     "«- **id**: testo»" % percorso)
    return voci


def controlli(cartella: str) -> List[Tuple[str, str, str]]:
    """Le righe di controlli.tsv: [(tipo, valore, descrizione)]."""
    percorso = os.path.join(cartella, "controlli.tsv")
    righe = leggi(percorso).splitlines()
    if not righe or righe[0].rstrip("\r") != "tipo\tvalore\tdescrizione":
        raise Errore("%s: la prima riga deve essere "
                     "«tipo<TAB>valore<TAB>descrizione»" % percorso)
    voci: List[Tuple[str, str, str]] = []
    for n, riga in enumerate(righe[1:], start=2):
        riga = riga.rstrip("\r")
        if not riga.strip():
            continue
        campi = riga.split("\t")
        if len(campi) != 3 or campi[0] not in TIPI:
            raise Errore("%s, riga %d: attesi tre campi, e un tipo tra %s"
                         % (percorso, n, ", ".join(TIPI)))
        tipo, valore, descrizione = campi
        if tipo in ("assente", "presente"):
            try:
                re.compile(valore)
            except (re.error, OverflowError, RecursionError) as exc:
                raise Errore("%s, riga %d: espressione non valida (%s)"
                             % (percorso, n, exc))
        elif not NUMERO.fullmatch(valore):
            raise Errore("%s, riga %d: «%s» vuole un numero" % (
                percorso, n, tipo))
        voci.append((tipo, valore, descrizione))
    if not voci:
        raise Errore("%s non contiene controlli" % percorso)
    return voci


def esito_controllo(tipo: str, valore: str, testo: str) -> Tuple[bool, str]:
    """(superato, dettaglio) di un controllo sul testo della risposta. Il
    dettaglio sta su una riga: TAB e a capo del testo trovato diventano
    spazi."""
    if tipo in ("assente", "presente"):
        trovato = re.search(valore, testo, re.IGNORECASE)
        if tipo == "assente":
            return (trovato is None,
                    "trovato «%s»" % " ".join(trovato.group(0).split())
                    if trovato else "")
        return trovato is not None, "" if trovato else "non trovato"
    limite = int(valore)
    if tipo == "righe_max":
        n = len([r for r in testo.splitlines() if r.strip()])
        return n <= limite, "%d righe" % n
    n = len(testo.split())
    if tipo == "parole_max":
        return n <= limite, "%d parole" % n
    return n >= limite, "%d parole" % n


def controlla(cartella: str, versione: str) -> bool:
    """Scrive controlli/<v>.txt (OK/KO per riga, poi il totale) e lo stampa.
    Returns: vero se ogni controllo è superato."""
    controlla_versione(versione)
    testo = risposta(cartella, versione)
    righe = []
    superati = 0
    voci = controlli(cartella)
    for tipo, valore, descrizione in voci:
        ok, dettaglio = esito_controllo(tipo, valore, testo)
        superati += ok
        righe.append("\t".join(["OK" if ok else "KO", descrizione, dettaglio]))
    righe.append("totale\t%d/%d" % (superati, len(voci)))
    scrivi(os.path.join(cartella, "controlli", versione + ".txt"),
           "\n".join(righe) + "\n")
    print("Controlli %s: %d %s su %d" % (
        versione, superati, "superato" if superati == 1 else "superati",
        len(voci)))
    for riga in righe[:-1]:
        esito, descrizione, dettaglio = riga.split("\t", 2)
        print("  %s %s%s" % ("✓" if esito == "OK" else "✗", descrizione,
                             " (%s)" % dettaglio if dettaglio else ""))
    return superati == len(voci)


def consegna_fissa(cartella: str) -> Tuple[List[str], List[Tuple[str, str]]]:
    """Le righe della consegna al giudice prima della risposta (l'invito,
    la rubrica, i dati) e le loro fonti, (percorso, testo)."""
    affermazioni = ["- %s: %s" % (i, t) for i, t in rubrica(cartella)]
    fonti = [(os.path.join(cartella, "rubrica.md"), "\n".join(affermazioni))]
    parti = ["Valuta la risposta qui sotto con la rubrica: per ogni "
             "affermazione decidi se la risposta la rispetta.", "",
             "<rubrica>"] + affermazioni + ["</rubrica>", "", "<dati>"]
    for nome, (percorso, contenuto) in dati(cartella).items():
        parti += ["<%s>" % nome, contenuto, "</%s>" % nome]
        fonti.append((percorso, contenuto))
    return parti + ["</dati>", ""], fonti


def consegna(cartella: str, versione: str) -> str:
    """Il testo per il giudice: rubrica, dati e risposta, fra tag."""
    controlla_versione(versione)
    parti, fonti = consegna_fissa(cartella)
    testo = risposta(cartella, versione).strip("\n")
    fonti.append((os.path.join(cartella, "risposte", versione + ".md"), testo))
    return nel_limite("\n".join(parti + ["<risposta>", testo, "</risposta>"]),
                      "la consegna al giudice di %s è troppo lunga" % versione,
                      fonti, "accorciate i file di dati/ o la risposta")


def giudizi(cartella: str, versione: str) -> Dict[str, Tuple[bool, str]]:
    """{id: (rispettato, motivo)} di giudizi/<v>.json, ids della rubrica."""
    percorso = os.path.join(cartella, "giudizi", versione + ".json")
    doc = json_di_claude(percorso)
    uscita = doc.get("structured_output")
    if not isinstance(uscita, dict) or not isinstance(
            uscita.get("criteri"), list):
        raise Errore("%s non contiene il giudizio strutturato "
                     "(structured_output.criteri)" % percorso, 1)
    attesi = [i for i, _ in rubrica(cartella)]
    trovati: Dict[str, Tuple[bool, str]] = {}
    for voce in uscita["criteri"]:
        if not isinstance(voce, dict):
            continue
        ident = voce.get("id")
        if ident in attesi and ident not in trovati and isinstance(
                voce.get("rispettato"), bool):
            trovati[ident] = (voce["rispettato"], str(voce.get("motivo", "")))
    for ident in attesi:
        trovati.setdefault(ident, (False, "non valutato dal giudice"))
    return {i: trovati[i] for i in attesi}


def stampa_giudizio(cartella: str, versione: str) -> None:
    """Il riepilogo del giudizio: quante affermazioni, e ognuna."""
    controlla_versione(versione)
    doc = json_di_claude(os.path.join(cartella, "giudizi",
                                      versione + ".json"))
    esiti = giudizi(cartella, versione)
    modelli = ", ".join(sorted((doc.get("modelUsage") or {}).keys()))
    rispettate = sum(1 for ok, _ in esiti.values() if ok)
    print("Giudizio %s (%s): %d %s su %d" % (
        versione, modelli or "modello non indicato", rispettate,
        "affermazione rispettata" if rispettate == 1
        else "affermazioni rispettate", len(esiti)))
    for ident, (ok, motivo) in esiti.items():
        print("  %s %s: %s" % ("✓" if ok else "✗", ident, motivo))


def esiti_controlli(cartella: str, versione: str) -> Dict[str, bool]:
    """{descrizione: superato} di controlli/<v>.txt."""
    percorso = os.path.join(cartella, "controlli", versione + ".txt")
    esiti: Dict[str, bool] = {}
    for riga in leggi(percorso).splitlines():
        campi = riga.split("\t", 2)
        if len(campi) >= 2 and campi[0] in ("OK", "KO"):
            esiti[campi[1]] = campi[0] == "OK"
    return esiti


def segno(valore: Optional[bool]) -> str:
    """✓, ✗ o — (non misurato)."""
    if valore is None:
        return "—"
    return "✓" if valore else "✗"


def misura_completa(cartella: str, versione: str) -> None:
    """Errore(2) se della versione manca la risposta, i controlli o il
    giudizio: una misura fermata a metà, da rifare."""
    for nome in (os.path.join("risposte", versione + ".json"),
                 os.path.join("controlli", versione + ".txt"),
                 os.path.join("giudizi", versione + ".json")):
        percorso = os.path.normpath(os.path.join(cartella, nome))
        if not os.path.isfile(percorso):
            raise Errore("la misura di %s è incompleta (manca %s): misurate "
                         "di nuovo %s (./misura.sh%s %s)" % (
                             versione, percorso, versione,
                             "" if cartella == "." else " " + cartella,
                             versione))


def confronta(cartella: str, prima: str, dopo: str) -> None:
    """Controlli, giudizi e token di due versioni, fianco a fianco; mai
    una misura fermata a metà."""
    for v in (prima, dopo):
        controlla_versione(v)
        misura_completa(cartella, v)
    cp, cd = esiti_controlli(cartella, prima), esiti_controlli(cartella, dopo)
    gp, gd = giudizi(cartella, prima), giudizi(cartella, dopo)
    print("Confronto %s → %s%s" % (prima, dopo, "" if cartella == "." else
                                   " (%s)" % cartella))
    print("  controlli:")
    for descr in list(dict.fromkeys(list(cp) + list(cd))):
        print("    %s  %s  %s" % (segno(cp.get(descr)), segno(cd.get(descr)),
                                  descr))
    print("  giudice:")
    for ident in gp:
        print("    %s  %s  %s" % (segno(gp[ident][0]), segno(gd[ident][0]),
                                  ident))
    tot = (sum(cp.values()), len(cp), sum(cd.values()), len(cd),
           sum(ok for ok, _ in gp.values()), sum(ok for ok, _ in gd.values()),
           len(gp))
    print("  totali: controlli %d/%d → %d/%d; giudice %d → %d su %d" % tot)
    pp = os.path.join(cartella, "risposte", prima + ".json")
    pd = os.path.join(cartella, "risposte", dopo + ".json")
    ep, up = token(json_di_claude(pp), pp)
    ed, ud = token(json_di_claude(pd), pd)
    print("  token: in entrata %d → %d, in uscita %d → %d" % (ep, ed, up, ud))


def errore(messaggio: str, codice: int) -> NoReturn:
    """Il messaggio su STDERR e l'uscita."""
    sys.stderr.write("kit.py: %s\n" % messaggio)
    sys.exit(codice)


def main(argv: List[str]) -> int:
    comandi = {"componi": 2, "estrai": 2, "controlla": 2, "consegna": 2,
               "giudizio": 2, "confronta": 3}
    if not argv or argv[0] not in comandi or len(argv) != comandi[argv[0]] + 1:
        sys.stderr.write(__doc__)
        return 2
    comando, cartella = argv[0], argv[1]
    if not os.path.isdir(cartella):
        errore("la cartella «%s» non esiste" % cartella, 2)
    try:
        if comando == "componi":
            print(componi(cartella, argv[2]))
        elif comando == "estrai":
            estrai(cartella, argv[2])
        elif comando == "controlla":
            return 0 if controlla(cartella, argv[2]) else 1
        elif comando == "consegna":
            print(consegna(cartella, argv[2]))
        elif comando == "giudizio":
            stampa_giudizio(cartella, argv[2])
        else:
            confronta(cartella, argv[2], argv[3])
    except Errore as exc:
        # Per controlla l'uscita 1 dice «un controllo non superato»: ogni
        # altro problema, lì, esce 2.
        errore(str(exc), 2 if comando == "controlla" else exc.codice)
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        errore("errore inatteso (%s: %s): avvisate il docente" % (
            type(exc).__name__, " ".join(str(exc).split())), 2)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
