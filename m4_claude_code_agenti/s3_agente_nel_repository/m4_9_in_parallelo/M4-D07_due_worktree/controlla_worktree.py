"""controlla_worktree.py -- due filoni, due worktree: le garanzie di
`claude -w` alla prova (M4-D07).

Legge, nello spazio di lavoro (la cartella data, o quella corrente), i due
bracci di esecuzioni/, in ognuno le due sessioni partite insieme sullo
stesso file, progetti/urgenze/urgenza.py: «esempio» (un esempio d'uso in
formato doctest nella docstring) e «rinomina» (il parametro giorni_aperta
che diventa giorni_di_apertura):
  senza-worktree/  esempio.jsonl e rinomina.jsonl, lo stream-json delle due
      sessioni partite nel checkout principale; checkout.txt, il suo
      `git status --porcelain` subito dopo; urgenza.py, la copia del file
      del checkout;
  con-worktree/    esempio.jsonl e rinomina.jsonl, le due sessioni partite
      con `claude -p -w <nome>`; checkout.txt, il `git status --porcelain`
      del checkout principale subito dopo; <nome>.status, il
      `git status --porcelain --branch` di .claude/worktrees/<nome> (vuoto
      se il worktree non c'era); <nome>.py, la copia del suo urgenza.py.
Le fotografie le prende fotografa.sh subito dopo ogni braccio, prima di
ogni pulizia: il controllo decide dagli stream e da quelle, e si può
rifare anche dopo aver tolto i worktree.

Per il braccio con i worktree, tre affermazioni di Anthropic, garanzie del
prodotto (una che non tiene è una segnalazione, uscita 1):
  «Con -w, un worktree isolato su un ramo nuovo, e Claude parte lì», per
      ogni sessione: la cartella dell'avvio è .claude/worktrees/<nome> del
      checkout principale (dove la registrazione del corso li ha trovati),
      e il worktree c'era, sul ramo worktree-<nome>;
  «Le modifiche al checkout principale sono bloccate», nell'ambito della
      frase della pagina (un Edit, un Write o un NotebookEdit diretto a un
      percorso del checkout principale): una segnalazione se il checkout
      principale ha modifiche ai file tracciati, o se una modifica di file
      (Edit, Write, NotebookEdit) riuscita è uscita dal worktree della sua
      sessione; altrimenti confermata se almeno una sessione ha provato a
      modificare il checkout principale e lo stream mostra il blocco: la
      chiamata è nell'elenco permission_denials del risultato. Un tentativo
      fallito che l'elenco non nomina non si distingue da un altro errore
      (un file non ancora letto, per esempio: il testo con cui Claude Code
      blocca questa modifica non è in una registrazione del corso), e con
      soltanto tentativi così, o nessun tentativo, il verdetto è non
      distinguibile (il blocco non è stato messo alla prova);
  «Ogni worktree tiene soltanto la modifica della sua sessione», per ogni
      sessione: i file tracciati cambiati nel worktree sono fra quelli che
      la sua sessione ha modificato, e il suo urgenza.py non ha il segno
      dell'altra modifica (una riga >>> per l'esempio, giorni_di_apertura
      per la rinomina), salvo che l'abbia scritto la sessione stessa; non
      distinguibile se l'altra sessione non ha modificato niente.
Un percorso relativo si legge dalla cartella della sessione. Lo stream si
divide in righe soltanto a ogni a capo (\\n): un testo può contenere altri
separatori di riga di Unicode, che JSON lascia così come sono.
Il braccio senza worktree è un dato: che cosa c'è in urgenza.py del
checkout (l'esempio, la rinomina, tutte e due, una rinomina a metà, un
file che non è più Python valido) e gli Edit con errore. Prima di decidere
controlla che i bracci siano una coppia: le due sessioni senza worktree
sono partite dallo stesso checkout, non in un worktree; i due bracci
vengono dallo stesso checkout; tutte e quattro le sessioni hanno lo stesso
modello e la stessa modalità. Mai «smentita». Il controllo non scrive
niente.

Uso:    python3 controlla_worktree.py [<spazio di lavoro>]
Uscita: 0 i due bracci ci sono, si leggono, e le garanzie tengono
        1 manca esecuzioni/ o un braccio; uno stream o una fotografia che
          manca o non va; una coppia che non è una coppia; oppure una
          segnalazione
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import ast
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

CARTELLA = "esecuzioni"
SENZA, CON = "senza-worktree", "con-worktree"
BRACCI = (SENZA, CON)
NOMI = ("esempio", "rinomina")
FILE = "progetti/urgenze/urgenza.py"
WORKTREE = "/.claude/worktrees/"
STRUMENTI_DI_MODIFICA = ("Edit", "Write", "NotebookEdit")
NUOVO = re.compile(r"\bgiorni_di_apertura\b")
VECCHIO = re.compile(r"\bgiorni_aperta\b")
S_WT = "Con -w, un worktree isolato su un ramo nuovo, e Claude parte lì"
S_CO = "Le modifiche al checkout principale sono bloccate"
S_IS = "Ogni worktree tiene soltanto la modifica della sua sessione"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
SEGNALAZIONE = "una segnalazione"
PARTENZA = ("Manca la cartella esecuzioni/ con i due bracci, "
            "senza-worktree/ e con-worktree/: eseguite i passi del README.")
NON_ANCORA = ("Non ancora: uno stream, una fotografia o un braccio manca o "
              "non va; rifate ciò che è indicato sopra come nel README, poi "
              "rilanciate il controllo.")
SEGNALAZIONI = ("Segnalazioni: %d. Una garanzia del prodotto deve valere a "
                "ogni esecuzione: i dettagli sono qui sopra.")
USO = "Uso: python3 controlla_worktree.py [<spazio di lavoro>]\n"
NA = "—"


class Precondizione(Exception):
    """Un file che non si legge: uscita 2."""


class Mancante(Exception):
    """Uno stream o una fotografia che manca o non va: uscita 1."""


class Modifica(NamedTuple):
    """Una chiamata a uno strumento che modifica un file: il percorso, il
    testo nuovo, se è riuscita (None se il risultato non c'è) e se è
    nell'elenco permission_denials del risultato."""
    percorso: str
    nuovo: str
    riuscita: Optional[bool]
    negata: bool


class Sessione(NamedTuple):
    """Che cosa dice lo stream di una sessione."""
    braccio: str
    nome: str
    cwd: str
    modello: str
    modo: str
    strumenti: Dict[str, int]
    errori: int
    modifiche: Tuple[Modifica, ...]


class Contenuto(NamedTuple):
    """Che cosa c'è in un urgenza.py: Python valido o no, l'esempio, la
    rinomina («sì», «no», «a metà»)."""
    valido: bool
    esempio: bool
    rinomina: str


class Esame(NamedTuple):
    """Che cosa non va in una sessione con il suo worktree: i problemi del
    worktree e del ramo, quelli dell'isolamento, le modifiche riuscite
    fuori dal worktree; i tentativi di modificare il checkout principale
    negati (nell'elenco permission_denials), e quelli falliti senza esserci,
    che non si distinguono da un altro errore."""
    worktree: List[str]
    isolamento: List[str]
    fuori: List[str]
    rifiutati: int
    indistinti: int


def quanti(n: int, uno: str, molti: str) -> str:
    """«1 tentativo» oppure «n tentativi»."""
    return "%d %s" % (n, uno if n == 1 else molti)


def leggi_testo(percorso: str) -> str:
    """Il testo di una fotografia; Mancante se manca, Precondizione se non
    si legge."""
    if not os.path.lexists(percorso):
        braccio = os.path.basename(os.path.dirname(percorso))
        raise Mancante("manca la fotografia %s: lanciate bash fotografa.sh "
                       "%s subito dopo le due sessioni del braccio"
                       % (percorso, braccio))
    try:
        with open(percorso, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))


def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi dello stream, se l'ultimo è il risultato riuscito.
    Mancante se manca o non va; Precondizione se non si legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quel braccio" % percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    eventi: List[dict] = []
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            evento = None
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un evento dello stream-json "
                           "di claude -p; rifate quel braccio"
                           % (percorso, numero))
        eventi.append(evento)
    if not eventi:
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? Rifate "
                       "quel braccio" % percorso)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato (la "
                       "chiamata si è interrotta?); rifate quel braccio"
                       % percorso)
    if len(eventi) == 1:
        raise Mancante("%s: c'è soltanto il risultato, senza gli eventi "
                       "che lo precedono (è l'uscita di --output-format "
                       "json?); rifate il braccio con --output-format "
                       "stream-json --verbose" % percorso)
    if ultimo.get("is_error") or ultimo.get("subtype", "success") \
            != "success":
        raise Mancante("%s: claude ha restituito un errore; rifate quel "
                       "braccio" % percorso)
    return eventi


def blocchi(evento: dict) -> List[dict]:
    """I blocchi del messaggio di un evento della conversazione principale
    (nessuno per gli eventi dei subagent)."""
    messaggio = evento.get("message")
    if evento.get("parent_tool_use_id") or not isinstance(messaggio, dict):
        return []
    contenuto = messaggio.get("content")
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)]


def identificativo(blocco: dict, chiave: str) -> Optional[str]:
    """L'id di un blocco (chiave «id» o «tool_use_id»), o None se manca."""
    valore = blocco.get(chiave)
    return valore if isinstance(valore, str) and valore else None


def esiti(eventi: List[dict]) -> Tuple[set, set]:
    """(gli id con un risultato, gli id con un risultato d'errore o un
    permesso negato)."""
    visti, errori = set(), set()
    for evento in eventi:
        if evento.get("type") != "user":
            continue
        for blocco in blocchi(evento):
            ident = identificativo(blocco, "tool_use_id")
            if blocco.get("type") != "tool_result" or ident is None:
                continue
            visti.add(ident)
            if blocco.get("is_error"):
                errori.add(ident)
    errori |= negate(eventi)
    return visti, errori


def negate(eventi: List[dict]) -> set:
    """Gli id delle chiamate nell'elenco permission_denials del risultato:
    le sole che lo stream dà come negate."""
    elenco = eventi[-1].get("permission_denials")
    return {d["tool_use_id"] for d in elenco or []
            if isinstance(d, dict)
            and identificativo(d, "tool_use_id") is not None}


def chiamate_di(eventi: List[dict]) -> List[dict]:
    """I blocchi tool_use della conversazione principale, una volta per id
    (un blocco senza id conta ogni volta che compare)."""
    visti = set()
    trovati: List[dict] = []
    for evento in eventi:
        if evento.get("type") != "assistant":
            continue
        for blocco in blocchi(evento):
            if blocco.get("type") != "tool_use":
                continue
            ident = identificativo(blocco, "id")
            if ident is not None:
                if ident in visti:
                    continue
                visti.add(ident)
            trovati.append(blocco)
    return trovati


def assoluto(percorso: str, cwd: str) -> str:
    """Il percorso, letto dalla cartella della sessione se è relativo."""
    if not percorso:
        return percorso
    if not os.path.isabs(percorso):
        percorso = os.path.join(cwd, percorso)
    return os.path.normpath(percorso)


def leggi_sessione(braccio: str, nome: str) -> Sessione:
    """Lo stream di una sessione dello spazio di lavoro."""
    percorso = "%s/%s/%s.jsonl" % (CARTELLA, braccio, nome)
    eventi = eventi_di(percorso)
    avvio = next((e for e in eventi if e.get("type") == "system"
                  and e.get("subtype") == "init"), None)
    if not isinstance(avvio, dict) or not isinstance(avvio.get("cwd"), str) \
            or not avvio["cwd"]:
        raise Mancante("%s: manca l'evento di avvio con la cartella della "
                       "sessione; rifate quel braccio" % percorso)
    cwd = avvio["cwd"].rstrip("/") or "/"
    visti, errori = esiti(eventi)
    negati = negate(eventi)
    strumenti: Dict[str, int] = {}
    modifiche: List[Modifica] = []
    falliti = 0
    for blocco in chiamate_di(eventi):
        ident = identificativo(blocco, "id")
        nome_s = blocco.get("name")
        nome_s = nome_s if isinstance(nome_s, str) and nome_s else "?"
        strumenti[nome_s] = strumenti.get(nome_s, 0) + 1
        errore = ident in errori
        falliti += 1 if errore else 0
        ingresso = blocco.get("input")
        if nome_s not in STRUMENTI_DI_MODIFICA \
                or not isinstance(ingresso, dict):
            continue
        file_ = ingresso.get("file_path") or ingresso.get(
            "notebook_path") or ""
        nuovo = ingresso.get("new_string") or ingresso.get(
            "content") or ingresso.get("new_source") or ""
        riuscita = None if ident not in visti and not errore else not errore
        modifiche.append(Modifica(assoluto(str(file_), cwd), str(nuovo),
                                  riuscita, ident in negati))
    modello, modo = (str(avvio.get(k)) if avvio.get(k) else NA
                     for k in ("model", "permissionMode"))
    return Sessione(braccio, nome, cwd, modello, modo, strumenti, falliti,
                    tuple(modifiche))


def classifica(testo: str) -> Contenuto:
    """Che cosa c'è in un urgenza.py: l'esempio (una riga che comincia con
    >>>), la rinomina (giorni_di_apertura senza giorni_aperta; con tutti e
    due, a metà), e se è ancora Python valido."""
    try:
        ast.parse(testo)
        valido = True
    except (SyntaxError, ValueError):
        valido = False
    esempio = any(r.strip().startswith(">>>") for r in testo.splitlines())
    nuovo, vecchio = NUOVO.search(testo), VECCHIO.search(testo)
    rinomina = "sì" if nuovo and not vecchio else (
        "a metà" if nuovo else "no")
    return Contenuto(valido, esempio, rinomina)


def descrivi(contenuto: Contenuto) -> str:
    """Il contenuto in parole."""
    return "l'esempio %s, la rinomina %s" % (
        "sì" if contenuto.esempio else "no", contenuto.rinomina)


def righe_di_stato(testo: str) -> Tuple[Optional[str], List[str]]:
    """(il ramo della riga «## …», o None; le altre righe, senza spazi
    attorno)."""
    ramo = None
    righe = []
    for riga in testo.splitlines():
        if riga.startswith("## "):
            ramo = riga[3:].split("...")[0].split(" [")[0].strip()
        elif riga.strip():
            righe.append(riga.strip())
    return ramo, righe


def percorso_di(riga: str) -> str:
    """Il percorso di una riga di git status --porcelain (quello nuovo, se
    è una rinomina)."""
    percorso = riga[2:].strip() if len(riga) > 2 else riga
    if " -> " in percorso:
        percorso = percorso.split(" -> ", 1)[1]
    return percorso.strip('"')


def tracciate(righe: List[str]) -> List[str]:
    """Le righe di stato dei file tracciati (non «??»)."""
    return [r for r in righe if not r.startswith("??")]


def dentro(percorso: str, cartella: str) -> bool:
    """Vero se percorso sta in cartella (o è cartella)."""
    percorso = os.path.normpath(percorso)
    cartella = os.path.normpath(cartella)
    return percorso == cartella or percorso.startswith(cartella + os.sep)


def relativo(percorso: str, base: str) -> str:
    """Il percorso relativo a base, se ci sta; altrimenti il solo nome."""
    if dentro(percorso, base):
        return os.path.relpath(os.path.normpath(percorso),
                               os.path.normpath(base))
    return os.path.basename(percorso.rstrip("/")) or percorso


def strumenti_in_parole(sessione: Sessione) -> str:
    """«Edit 2, Read 1 (1 con errore)»."""
    testo = ", ".join("%s %d" % (k, v) for k, v
                      in sorted(sessione.strumenti.items())) or "nessuno"
    if sessione.errori:
        testo += " (%d con errore)" % sessione.errori
    return testo


def checkout_in_parole(righe: List[str]) -> str:
    """Le righe di stato del checkout principale in parole."""
    modificati = tracciate(righe)
    non_tracciati = [percorso_di(r) for r in righe if r.startswith("??")]
    testo = "; ".join(modificati) or "nessuna modifica ai file tracciati"
    if non_tracciati:
        testo += "; non tracciati: " + ", ".join(non_tracciati)
    return testo


class Prova:
    """I due bracci letti dallo spazio di lavoro (la cartella corrente),
    con i problemi trovati strada facendo."""

    def __init__(self) -> None:
        self.mancanti: List[str] = []
        self.sessioni: Dict[Tuple[str, str], Sessione] = {}
        self.foto: Dict[str, str] = {}

    def sessione(self, braccio: str, nome: str) -> Optional[Sessione]:
        """Una sessione, o None (con il motivo fra i mancanti)."""
        try:
            letta = leggi_sessione(braccio, nome)
        except Mancante as exc:
            self.mancanti.append(str(exc))
            return None
        self.sessioni[(braccio, nome)] = letta
        return letta

    def fotografia(self, braccio: str, nome: str) -> Optional[str]:
        """Il testo di una fotografia, o None (con il motivo)."""
        percorso = "%s/%s/%s" % (CARTELLA, braccio, nome)
        try:
            testo = leggi_testo(percorso)
        except Mancante as exc:
            self.mancanti.append(str(exc))
            return None
        self.foto["%s/%s" % (braccio, nome)] = testo
        return testo


def principale_di(sessione: Sessione) -> str:
    """Il checkout principale di una sessione: la sua cartella, senza
    /.claude/worktrees/<nome> se c'è."""
    coda = WORKTREE + sessione.nome
    if sessione.cwd.endswith(coda):
        return sessione.cwd[:-len(coda)] or "/"
    return sessione.cwd


def controlla_senza(prova: Prova) -> Optional[str]:
    """Il braccio senza worktree: i dati, e il suo checkout (None se il
    braccio non va)."""
    sessioni = [prova.sessione(SENZA, n) for n in NOMI]
    stato = prova.fotografia(SENZA, "checkout.txt")
    copia = prova.fotografia(SENZA, "urgenza.py")
    if None in sessioni:
        return None
    cartelle = sorted({s.cwd for s in sessioni if s is not None})
    for s in sessioni:
        if s is not None and WORKTREE in s.cwd + "/":
            prova.mancanti.append(
                "la sessione %s del braccio senza worktree è partita in un "
                "worktree: rifate il braccio nel checkout principale"
                % s.nome)
            return None
    if len(cartelle) != 1:
        prova.mancanti.append(
            "le due sessioni del braccio senza worktree non sono partite "
            "dalla stessa cartella: rifate il braccio dal checkout "
            "principale")
        return None
    for s in sessioni:
        if s is not None:
            print("%s/%s: partita nel checkout principale; strumenti: %s"
                  % (SENZA, s.nome, strumenti_in_parole(s)))
    if stato is not None:
        print("senza worktree, il checkout principale: %s"
              % checkout_in_parole(righe_di_stato(stato)[1]))
    if copia is not None:
        contenuto = classifica(copia)
        testa = "senza worktree, urgenza.py nel checkout"
        if not contenuto.valido:
            testa += " non è più Python valido;"
        else:
            testa += ":"
        coda = ""
        if contenuto.esempio and contenuto.rinomina == "sì":
            coda = ": le due modifiche nello stesso file, nello stesso checkout"
        print("%s %s%s" % (testa, descrivi(contenuto), coda))
    return cartelle[0]


def segno_estraneo(nome: str, testo: str,
                   sessione: Sessione) -> Optional[str]:
    """L'altra modifica, se c'è nel file del worktree di nome e la sua
    sessione non l'ha scritta; altrimenti None."""
    contenuto = classifica(testo)
    if nome == "esempio":
        presente, altra = contenuto.rinomina != "no", "la rinomina"
        scritto = any(NUOVO.search(m.nuovo) for m in sessione.modifiche
                      if m.riuscita is not False)
    else:
        presente, altra = contenuto.esempio, "l'esempio"
        scritto = any(">>>" in m.nuovo for m in sessione.modifiche
                      if m.riuscita is not False)
    return altra if presente and not scritto else None


def modifiche_fuori(sessione: Sessione,
                    principale: str) -> Tuple[set, List[str], int, int]:
    """(i file del worktree che la sessione ha modificato, relativi al
    worktree; le modifiche riuscite fuori dal worktree, in parole; i
    tentativi di modificare il checkout principale negati, cioè
    nell'elenco permission_denials; quelli falliti senza esserci, che non
    si distinguono da un altro errore)."""
    toccati = set()
    fuori: List[str] = []
    rifiutati = indistinti = 0
    for modifica in sessione.modifiche:
        if dentro(modifica.percorso, sessione.cwd):
            if modifica.riuscita is not False:
                toccati.add(relativo(modifica.percorso, sessione.cwd))
        elif modifica.riuscita is False:
            if dentro(modifica.percorso, principale):
                if modifica.negata:
                    rifiutati += 1
                else:
                    indistinti += 1
        elif dentro(modifica.percorso, principale):
            fuori.append("la sessione %s ha modificato %s del checkout "
                         "principale" % (sessione.nome, relativo(
                             modifica.percorso, principale)))
        else:
            fuori.append("la sessione %s ha modificato %s fuori dal suo "
                         "worktree" % (sessione.nome, relativo(
                             modifica.percorso, principale)))
    return toccati, fuori, rifiutati, indistinti


def una_sessione_con(prova: Prova, sessione: Sessione,
                     principale: str) -> Esame:
    """I dati di una sessione con il suo worktree, stampati, e che cosa
    non va."""
    nome = sessione.nome
    stato = prova.foto.get("%s/%s.status" % (CON, nome), "")
    ramo, righe = righe_di_stato(stato)
    worktree: List[str] = []
    if sessione.cwd != principale.rstrip("/") + WORKTREE + nome:
        worktree.append("la sessione non è partita in .claude/worktrees/%s"
                        % nome)
    if not stato.strip():
        worktree.append("il worktree .claude/worktrees/%s non c'era dopo "
                        "l'esecuzione" % nome)
    elif ramo != "worktree-" + nome:
        worktree.append("il worktree è sul ramo %s, non su worktree-%s"
                        % (ramo or NA, nome))
    toccati, fuori, rifiutati, indistinti = modifiche_fuori(sessione,
                                                            principale)
    isolamento = ["nel worktree è cambiato %s, che la sua sessione non ha "
                  "modificato" % percorso_di(r) for r in tracciate(righe)
                  if percorso_di(r) not in toccati]
    copia = prova.foto.get("%s/%s.py" % (CON, nome))
    descrizione = NA
    if copia is not None:
        descrizione = descrivi(classifica(copia))
        estraneo = segno_estraneo(nome, copia, sessione)
        if estraneo:
            isolamento.append("nel worktree c'è %s, che la sua sessione "
                              "non ha scritto" % estraneo)
    partita = relativo(sessione.cwd, principale) \
        if sessione.cwd != principale else "il checkout principale"
    print("%s/%s: partita in %s, ramo %s; strumenti: %s; nel worktree: %s; "
          "urgenza.py: %s"
          % (CON, nome, partita, ramo or NA, strumenti_in_parole(sessione),
             "; ".join(righe) or "nessuna modifica non committata",
             descrizione))
    return Esame(worktree, isolamento, fuori, rifiutati, indistinti)


def verdetto(affermazione: str, problemi: List[str], conferma: str) -> bool:
    """Stampa il verdetto di una garanzia; vero se è una segnalazione."""
    if problemi:
        print("%s: %s: %s; %s" % (affermazione, NON_CONFERMATA,
                                  "; ".join(problemi), SEGNALAZIONE))
        return True
    print("%s: %s%s" % (affermazione, CONFERMATA, conferma))
    return False


def ha_modificato(sessione: Sessione) -> bool:
    """Vero se la sessione ha almeno una modifica di file non fallita."""
    return any(m.riuscita is not False for m in sessione.modifiche)


def isolamento_di(prova: Prova, nome: str, esame: Esame) -> int:
    """Il verdetto dell'isolamento di un worktree; 1 se è una
    segnalazione. Non distinguibile se il worktree non c'era, o se l'altra
    sessione non ha modificato niente (non c'era niente da isolare)."""
    altra = prova.sessioni[(CON, NOMI[1 - NOMI.index(nome)])]
    if not prova.foto.get("%s/%s.status" % (CON, nome), "").strip():
        print("%s (%s): %s: il worktree non c'era"
              % (S_IS, nome, NON_DISTINGUIBILE))
        return 0
    if not esame.isolamento and not ha_modificato(altra):
        print("%s (%s): %s: l'altra sessione non ha modificato niente"
              % (S_IS, nome, NON_DISTINGUIBILE))
        return 0
    return verdetto("%s (%s)" % (S_IS, nome), esame.isolamento, "")


def blocco_del_checkout(righe: List[str], fuori: List[str],
                        rifiutati: int, indistinti: int) -> int:
    """Il verdetto sul blocco delle modifiche al checkout principale; 1 se
    è una segnalazione. Confermata solo se una sessione ha provato a
    modificarlo e la chiamata è nell'elenco permission_denials; non
    distinguibile se i tentativi sono falliti senza esserci (un errore
    qualunque non dice che il blocco c'è stato), o se nessuna sessione ci
    ha provato."""
    problemi = ["il checkout principale è cambiato: %s" % r
                for r in tracciate(righe)] + fuori
    if problemi:
        return verdetto(S_CO, problemi, "")
    pulito = "il checkout principale non ha modifiche ai file tracciati"
    if rifiutati:
        print("%s: %s: %s di modificare il checkout principale, %s "
              "(nell'elenco permission_denials); %s"
              % (S_CO, CONFERMATA,
                 quanti(rifiutati, "tentativo", "tentativi"),
                 "negato" if rifiutati == 1 else "negati", pulito))
    elif indistinti:
        print("%s: %s: %s di modificare il checkout principale %s, ma non "
              "nell'elenco permission_denials: l'errore non si distingue da "
              "un altro; %s"
              % (S_CO, NON_DISTINGUIBILE,
                 quanti(indistinti, "tentativo", "tentativi"),
                 "non riuscito" if indistinti == 1 else "non riusciti",
                 pulito))
    else:
        print("%s: %s: nessuna sessione ha provato a modificare il "
              "checkout principale; %s" % (S_CO, NON_DISTINGUIBILE, pulito))
    return 0


def controlla_con(prova: Prova, principale: str) -> int:
    """Il braccio con i worktree: i dati e le tre garanzie; quante
    segnalazioni."""
    segnalazioni = 0
    rifiutati = indistinti = 0
    rimasti = []
    fuori: List[str] = []
    for nome in NOMI:
        esame = una_sessione_con(prova, prova.sessioni[(CON, nome)],
                                 principale)
        rifiutati += esame.rifiutati
        indistinti += esame.indistinti
        fuori += esame.fuori
        stato = prova.foto.get("%s/%s.status" % (CON, nome), "")
        if stato.strip():
            rimasti.append(nome)
        segnalazioni += verdetto(
            "%s (%s)" % (S_WT, nome), esame.worktree,
            ": partita in .claude/worktrees/%s, sul ramo %s"
            % (nome, righe_di_stato(stato)[0]))
        segnalazioni += isolamento_di(prova, nome, esame)
    righe = righe_di_stato(prova.foto.get("%s/checkout.txt" % CON, ""))[1]
    print("con i worktree, il checkout principale: %s"
          % checkout_in_parole(righe))
    if rimasti:
        print("dopo claude -p i worktree c'erano ancora: %s (la pulizia è "
              "in «Se qualcosa va storto» del README)" % ", ".join(rimasti))
    return segnalazioni + blocco_del_checkout(righe, fuori, rifiutati,
                                              indistinti)


def leggi_con(prova: Prova) -> bool:
    """Gli stream e le fotografie del braccio con i worktree; vero se ci
    sono tutti."""
    pronti = all([prova.sessione(CON, n) is not None for n in NOMI])
    pronti = prova.fotografia(CON, "checkout.txt") is not None and pronti
    for nome in NOMI:
        stato = prova.fotografia(CON, nome + ".status")
        if stato is None:
            pronti = False
        elif stato.strip() and prova.fotografia(CON, nome + ".py") is None:
            pronti = False
    return pronti


def problemi_della_coppia(prova: Prova, principale: str) -> List[str]:
    """Che cosa impedisce ai due bracci di essere una coppia."""
    problemi = []
    principali = {principale_di(prova.sessioni[(CON, n)]) for n in NOMI}
    if principali != {principale}:
        problemi.append("i due bracci non vengono dallo stesso checkout: "
                        "rifateli tutti e due nello stesso spazio di lavoro")
    modi = sorted({"%s, %s" % (s.modello, s.modo)
                   for s in prova.sessioni.values()})
    if len(modi) > 1:
        problemi.append("le sessioni non hanno lo stesso modello e la "
                        "stessa modalità: %s" % " | ".join(modi))
    return problemi


def avviso(messaggio: str) -> None:
    """Un braccio da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_worktree.py: %s\n" % messaggio)


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa
    e restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    presenti = [b for b in BRACCI
                if os.path.isdir(os.path.join(CARTELLA, b))]
    if not presenti:
        print(PARTENZA)
        return 1
    prova = Prova()
    for braccio in BRACCI:
        if braccio not in presenti:
            prova.mancanti.append("manca il braccio %s: eseguite i passi "
                                  "del README" % braccio)
    principale = controlla_senza(prova) if SENZA in presenti else None
    segnalazioni = 0
    if CON in presenti and leggi_con(prova) and principale is not None:
        problemi = problemi_della_coppia(prova, principale)
        prova.mancanti.extend(problemi)
        if not problemi:
            segnalazioni = controlla_con(prova, principale)
    for messaggio in prova.mancanti:
        avviso(messaggio)
    if prova.mancanti:
        print(NON_ANCORA)
    if segnalazioni:
        print(SEGNALAZIONI % segnalazioni)
    return 1 if prova.mancanti or segnalazioni else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    posizionali: List[str] = []
    for arg in argv:
        if arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
