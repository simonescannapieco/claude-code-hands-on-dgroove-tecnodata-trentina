"""controlla_stop.py -- il controllo che non si salta: uno Stop hook che
esegue i test, e tre affermazioni di Anthropic alla prova (M4-D05).

Legge, nello spazio di lavoro (la cartella data, o quella corrente), le
esecuzioni dei due bracci, esecuzioni/con-hook-<n>/ ed
esecuzioni/senza-hook-<n>/: in ognuna stream.jsonl, lo stream-json di
`claude -p --output-format stream-json --verbose` partito nella copia
urgenze/ accanto, e la copia stessa, con le sue impostazioni
(.claude/settings.json). I due bracci differiscono soltanto nello Stop
hook delle impostazioni: con l'hook c'è, senza no. Per ogni esecuzione
stampa:
  - dall'evento di avvio, la versione di Claude Code, il modello e la
    modalità di permesso;
  - quante volte lo Stop hook ha bloccato la fine del turno (i messaggi
    «Stop hook feedback» della conversazione principale) e quanti blocchi
    di fila al massimo, senza chiamate a strumenti in mezzo; gli strumenti
    chiamati, i permessi negati, la durata;
  - quali file del progetto sono cambiati nella copia rispetto a
    progetti/urgenze/ dello spazio di lavoro;
  - i test, rieseguiti ora nella copia (python3 -m unittest).
Poi, per ogni esecuzione con l'hook:
  «L'uscita 2 dello Stop hook blocca la fine del turno», una garanzia: i
      test verdi alla fine la confermano, se l'hook ha bloccato almeno
      una volta (senza blocchi: non distinguibile); i test rossi con
      otto blocchi di fila senza strumenti in fondo allo stream sono il
      tetto che la documentazione descrive (Claude Code chiude il turno),
      e si stampano come tali; i test rossi senza il tetto in fondo sono
      una segnalazione: non confermata in questa esecuzione, uscita 1;
  «Claude continua finché il controllo passa», un comportamento: con
      almeno un blocco, confermata se alla fine i test sono verdi,
      altrimenti non confermata in questa esecuzione; senza blocchi, non
      distinguibile. Poi «confermata n su N».
Se in nessuna esecuzione con l'hook lo Stop hook ha bloccato, la garanzia
non si è potuta mettere alla prova: «Non ancora», uscita 1.
E, come dato, «Senza lo Stop hook, i test verdi alla fine: n su N».
Mai «smentita». Prima di decidere controlla che la coppia sia una coppia:
ci sono i due bracci; ogni copia ha le impostazioni del suo braccio, e
tolto l'hook sono uguali in tutte; tutte le esecuzioni hanno lo stesso
modello e la stessa modalità; nessuna esecuzione senza hook mostra
blocchi. Il controllo non scrive niente. Divide lo stream in righe
soltanto a ogni a capo (\\n): un testo può contenere altri separatori di
riga di Unicode, che JSON lascia così come sono.

Uso:    python3 controlla_stop.py [<spazio di lavoro>]
Env:    PN_URGENZE_TIMEOUT  i secondi concessi ai test (default 60)
Uscita: 0 la coppia c'è, si legge, almeno un'esecuzione con l'hook mostra
          un blocco, e la garanzia tiene
        1 manca esecuzioni/, o un braccio; un'esecuzione che manca o non
          va (lo stream, la copia, le impostazioni); una coppia che
          differisce in più dell'hook; nessun blocco in nessuna
          esecuzione con l'hook; oppure una segnalazione
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import filecmp
import json
import os
import re
import subprocess
import sys
import tempfile
from typing import Dict, List, NamedTuple, Optional, Tuple

CARTELLA = "esecuzioni"
BRACCI = ("con-hook", "senza-hook")
NOME = re.compile(r"^(con-hook|senza-hook)-([1-9][0-9]*)$")
STREAM = "stream.jsonl"
COPIA = "urgenze"
IMPOSTAZIONI = os.path.join(".claude", "settings.json")
ORIGINALE = os.path.join("progetti", "urgenze")
FILE_DEL_PROGETTO = ("test_urgenza.py", "urgenza.py")
TETTO = 8
TIMEOUT = 60
FEEDBACK = "Stop hook feedback"
S_BLOCCA = "L'uscita 2 dello Stop hook blocca la fine del turno"
S_CONTINUA = "Claude continua finché il controllo passa"
S_SENZA = "Senza lo Stop hook, i test verdi alla fine"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
PARTENZA = ("Manca la cartella esecuzioni/ con le esecuzioni con-hook-<n> e "
            "senza-hook-<n>: eseguite i passi del README.")
# Il controllo vuole buone tutte le esecuzioni di esecuzioni/: una che non
# va si toglie prima di rifarla (la sua copia ha oggetti git in sola
# lettura, quindi rm -rf), altrimenti resta e la verifica dice ancora 1.
NON_ANCORA = ("Non ancora: un'esecuzione o un braccio manca o non va. "
              "Un'esecuzione che non va si toglie prima di rifarla, con rm "
              "-rf esecuzioni/<braccio>-<n>; poi rifate ciò che è indicato "
              "sopra come nel README (o ripartite da capo con "
              "tools/reset_esercizio.sh M4-D05), e rilanciate il controllo.")
NESSUNA_PROVA = ("Non ancora: in nessuna esecuzione con l'hook lo Stop hook "
                 "ha bloccato la fine del turno, e la garanzia non si è "
                 "potuta mettere alla prova: aggiungete un'esecuzione per "
                 "braccio, con il numero successivo.")
SEGNALAZIONI = ("Segnalazioni: %d. Una garanzia del prodotto deve valere a "
                "ogni esecuzione: i dettagli sono qui sopra.")
USO = "Uso: python3 controlla_stop.py [<spazio di lavoro>]\n"
NA = "—"
RAN = re.compile(r"^Ran (\d+) tests?\b", re.M)


class Precondizione(Exception):
    """Un file che non si legge, un valore che non va: uscita 2."""


class Mancante(Exception):
    """Un'esecuzione che manca o non va: uscita 1."""


class Test(NamedTuple):
    """I test rieseguiti: verdi o no, e in parole."""
    verdi: bool
    testo: str


class Esecuzione(NamedTuple):
    """Che cosa dicono lo stream e la copia di un'esecuzione."""
    nome: str
    braccio: str
    modello: str
    modo: str
    versione: str
    blocchi: int
    di_fila: int
    in_fondo: int
    strumenti: Dict[str, int]
    dinieghi: int
    secondi: Optional[int]
    file: str
    test: Test
    impostazioni: dict


def quanti(n: int, uno: str, molti: str) -> str:
    """«1 blocco» oppure «n blocchi»."""
    return "%d %s" % (n, uno if n == 1 else molti)


def taglia(testo: str, quanti_caratteri: int) -> str:
    """Il testo, al massimo quanti_caratteri, con «…» se è tagliato."""
    if len(testo) <= quanti_caratteri:
        return testo
    return testo[:quanti_caratteri - 1] + "…"


def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi dello stream, se l'ultimo è il risultato riuscito.
    Mancante se manca o non va; Precondizione se non si legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quell'esecuzione" % percorso)
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
                           "di claude -p; rifate quell'esecuzione"
                           % (percorso, numero))
        eventi.append(evento)
    if not eventi:
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? "
                       "Rifatela" % percorso)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato (la "
                       "chiamata si è interrotta?); rifatela" % percorso)
    if len(eventi) == 1:
        raise Mancante("%s: c'è soltanto il risultato, senza gli eventi "
                       "che lo precedono (è l'uscita di --output-format "
                       "json?); rifate la chiamata con --output-format "
                       "stream-json --verbose" % percorso)
    if ultimo.get("is_error") or ultimo.get("subtype", "success") \
            != "success":
        raise Mancante("%s: claude ha restituito un errore; rifate "
                       "quell'esecuzione" % percorso)
    return eventi


def blocchi_di(contenuto: object) -> List[dict]:
    """I blocchi di un messaggio (un testo semplice diventa un blocco)."""
    if isinstance(contenuto, str):
        return [{"type": "text", "text": contenuto}]
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)]


def principale(evento: dict) -> List[dict]:
    """I blocchi di un evento della conversazione principale (nessuno per
    gli eventi dei subagent)."""
    if evento.get("parent_tool_use_id"):
        return []
    messaggio = evento.get("message")
    if not isinstance(messaggio, dict):
        return []
    return blocchi_di(messaggio.get("content"))


def leggi_blocchi(eventi: List[dict]) -> Tuple[int, int, int]:
    """(i blocchi dello Stop hook, i blocchi di fila al massimo senza
    chiamate a strumenti in mezzo, quelli di fila in fondo allo stream,
    dopo l'ultima chiamata a uno strumento)."""
    blocchi = di_fila = massimo = 0
    for evento in eventi:
        tipo = evento.get("type")
        if tipo == "user" and any(
                b.get("type") == "text"
                and str(b.get("text", "")).startswith(FEEDBACK)
                for b in principale(evento)):
            blocchi += 1
            di_fila += 1
            massimo = max(massimo, di_fila)
        elif tipo == "assistant" and any(
                b.get("type") == "tool_use" for b in principale(evento)):
            di_fila = 0
    return blocchi, massimo, di_fila


def leggi_strumenti(eventi: List[dict]) -> Dict[str, int]:
    """Le chiamate a ogni strumento della conversazione principale, una
    volta per id."""
    visti = set()
    strumenti: Dict[str, int] = {}
    for evento in eventi:
        if evento.get("type") != "assistant":
            continue
        for blocco in principale(evento):
            if blocco.get("type") != "tool_use":
                continue
            ident = blocco.get("id")
            if isinstance(ident, str) and ident:
                if ident in visti:
                    continue
                visti.add(ident)
            nome = blocco.get("name")
            nome = nome if isinstance(nome, str) and nome else "?"
            strumenti[nome] = strumenti.get(nome, 0) + 1
    return strumenti


def leggi_impostazioni(copia: str) -> dict:
    """Le impostazioni della copia; Mancante se mancano o non sono JSON."""
    percorso = "%s/%s" % (copia, IMPOSTAZIONI)
    try:
        with open(percorso, encoding="utf-8") as fh:
            impostazioni = json.load(fh)
    except (OSError, ValueError, RecursionError):
        impostazioni = None
    if not isinstance(impostazioni, dict):
        raise Mancante("%s manca o non è JSON: rifate quell'esecuzione con "
                       "nuova_copia.sh" % percorso)
    return impostazioni


def ha_lo_hook(impostazioni: dict) -> bool:
    """Vero se le impostazioni hanno almeno un comando nello Stop hook."""
    hooks = impostazioni.get("hooks")
    if not isinstance(hooks, dict) or not isinstance(hooks.get("Stop"),
                                                     list):
        return False
    return any(isinstance(voce, dict) and any(
        isinstance(h, dict) and h.get("command")
        for h in voce.get("hooks") or [])
        for voce in hooks["Stop"])


def senza_hook(impostazioni: dict) -> dict:
    """Le impostazioni senza la chiave hooks."""
    return {k: v for k, v in impostazioni.items() if k != "hooks"}


def file_cambiati(copia: str) -> str:
    """Quali file del progetto la copia ha cambiato, in parole."""
    if not os.path.isdir(ORIGINALE):
        return "cambiati: %s; invariati: %s (manca %s/)" % (NA, NA,
                                                            ORIGINALE)
    cambiati, invariati = [], []
    for nome in FILE_DEL_PROGETTO:
        prima = os.path.join(ORIGINALE, nome)
        dopo = os.path.join(copia, nome)
        uguali = (os.path.isfile(prima) and os.path.isfile(dopo)
                  and filecmp.cmp(prima, dopo, shallow=False))
        (invariati if uguali else cambiati).append(nome)
    return "cambiati: %s; invariati: %s" % (", ".join(cambiati) or "nessuno",
                                            ", ".join(invariati) or "nessuno")


def secondi_dei_test() -> int:
    """I secondi concessi ai test: PN_URGENZE_TIMEOUT, oppure 60."""
    valore = os.environ.get("PN_URGENZE_TIMEOUT", "")
    if not valore:
        return TIMEOUT
    if not valore.isdigit() or int(valore) <= 0:
        raise Precondizione("PN_URGENZE_TIMEOUT non è un numero di secondi: "
                            "%s" % valore)
    return int(valore)


def riesegui_test(copia: str) -> Test:
    """I test della copia, rieseguiti ora; verdi soltanto se ce n'è almeno
    uno e passano tutti."""
    secondi = secondi_dei_test()
    with tempfile.TemporaryDirectory(prefix="pycache-") as cache:
        try:
            fatto = subprocess.run(
                [sys.executable, "-B", "-I", "-X",
                 "pycache_prefix=" + cache, "-m", "unittest", "-q"],
                cwd=copia, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, universal_newlines=True,
                errors="replace", timeout=secondi)
        except subprocess.TimeoutExpired:
            return Test(False, "non finiscono entro %d s" % secondi)
        except OSError as exc:
            return Test(False, "non partono (%s)" % (exc.strerror or exc))
    righe = [r.strip() for r in fatto.stdout.splitlines() if r.strip()]
    ultima = righe[-1] if righe else NA
    trovati = RAN.search(fatto.stdout)
    if trovati is None:
        return Test(False, "non partono (%s)" % taglia(ultima, 80))
    numero = int(trovati.group(1))
    if numero == 0:
        return Test(False, "nessun test (Ran 0 tests)")
    if fatto.returncode == 0:
        return Test(True, "verdi (%d test, %s)" % (numero, taglia(ultima, 80)))
    return Test(False, "rossi (%d test, %s)" % (numero, taglia(ultima, 80)))


def leggi_esecuzione(nome: str, braccio: str) -> Esecuzione:
    """Un'esecuzione dello spazio di lavoro (la cartella corrente)."""
    base = "%s/%s" % (CARTELLA, nome)
    eventi = eventi_di("%s/%s" % (base, STREAM))
    copia = "%s/%s" % (base, COPIA)
    if not os.path.isdir(copia):
        raise Mancante("manca la copia %s/: rifate quell'esecuzione"
                       % copia)
    impostazioni = leggi_impostazioni(copia)
    if ha_lo_hook(impostazioni) != (braccio == "con-hook"):
        raise Mancante("le impostazioni della copia %s/ non sono quelle del "
                       "braccio %s: rifate l'esecuzione con "
                       "impostazioni/%s.json" % (copia, braccio, braccio))
    blocchi, di_fila, in_fondo = leggi_blocchi(eventi)
    if blocchi and braccio == "senza-hook":
        raise Mancante("%s: lo stream mostra blocchi dello Stop hook in "
                       "un'esecuzione senza hook (%d): rifatela con le "
                       "impostazioni del braccio" % (base, blocchi))
    avvio = next((e for e in eventi if e.get("type") == "system"
                  and e.get("subtype") == "init"), {})
    risultato = eventi[-1]
    dinieghi = risultato.get("permission_denials")
    durata = risultato.get("duration_ms")
    secondi = (int(round(durata / 1000))
               if isinstance(durata, (int, float))
               and not isinstance(durata, bool) else None)
    modello, modo, versione = (
        str(avvio.get(k)) if avvio.get(k) else NA
        for k in ("model", "permissionMode", "claude_code_version"))
    return Esecuzione(
        nome, braccio, modello, modo, versione, blocchi, di_fila, in_fondo,
        leggi_strumenti(eventi),
        len(dinieghi) if isinstance(dinieghi, list) else 0, secondi,
        file_cambiati(copia), riesegui_test(copia), impostazioni)


def verdetto_blocca(esecuzione: Esecuzione) -> Tuple[str, bool]:
    """(la garanzia su un'esecuzione con l'hook, vero se è una
    segnalazione)."""
    testa = "%s (%s): " % (S_BLOCCA, esecuzione.nome)
    blocchi = quanti(esecuzione.blocchi, "blocco", "blocchi")
    if esecuzione.test.verdi and esecuzione.blocchi:
        return (testa + "%s: %s, e il turno si è chiuso con i test verdi"
                % (CONFERMATA, blocchi), False)
    if esecuzione.test.verdi:
        return (testa + "%s: lo Stop hook non ha mai bloccato: i test "
                "erano già verdi alla prima fine del turno"
                % NON_DISTINGUIBILE, False)
    if esecuzione.in_fondo >= TETTO:
        return (testa + "%s fino al tetto: %d blocchi di fila senza "
                "strumenti, in fondo allo stream: poi Claude Code ha chiuso "
                "il turno, come dice la documentazione; i test restano rossi"
                % (CONFERMATA, esecuzione.in_fondo), False)
    motivo = ""
    if not esecuzione.blocchi:
        motivo = " (nessun blocco nello stream: l'hook ha girato?)"
    return (testa + "%s: i test sono rossi e lo stream non finisce con il "
            "tetto degli otto blocchi di fila%s; una segnalazione"
            % (NON_CONFERMATA, motivo), True)


def verdetto_continua(esecuzione: Esecuzione) -> str:
    """Il comportamento, su un'esecuzione con l'hook."""
    if not esecuzione.blocchi:
        return NON_DISTINGUIBILE + ": nessun blocco"
    if esecuzione.test.verdi:
        return CONFERMATA
    return NON_CONFERMATA + ": alla fine il controllo non passa"


def stampa(esecuzione: Esecuzione) -> None:
    """I dati di un'esecuzione."""
    nome = esecuzione.nome
    strumenti = ", ".join("%s %d" % (k, v) for k, v
                          in sorted(esecuzione.strumenti.items()))
    parti = ["%s dello Stop hook (di fila al massimo %d)"
             % (quanti(esecuzione.blocchi, "blocco", "blocchi"),
                esecuzione.di_fila),
             "strumenti: %s" % (strumenti or "nessuno"),
             quanti(esecuzione.dinieghi, "permesso negato",
                    "permessi negati")]
    if esecuzione.secondi is not None:
        parti.append("%d s" % esecuzione.secondi)
    print("%s: Claude Code %s, modello %s, modalità %s"
          % (nome, esecuzione.versione, esecuzione.modello, esecuzione.modo))
    print("%s: %s" % (nome, "; ".join(parti)))
    print("%s: %s" % (nome, esecuzione.file))
    print("%s: i test, rieseguiti ora nella copia: %s"
          % (nome, esecuzione.test.testo))


def avviso(messaggio: str) -> None:
    """Un'esecuzione da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_stop.py: %s\n" % messaggio)


def nomi_delle_esecuzioni() -> List[Tuple[str, str]]:
    """(nome, braccio) delle esecuzioni di esecuzioni/: prima il braccio
    con l'hook, poi quello senza, ognuno in ordine di numero."""
    if not os.path.isdir(CARTELLA):
        return []
    try:
        voci = os.listdir(CARTELLA)
    except OSError as exc:
        raise Precondizione("%s/ non si legge (%s)"
                            % (CARTELLA, exc.strerror or exc))
    trovate = []
    for voce in voci:
        trovata = NOME.match(voce)
        if trovata:
            trovate.append((BRACCI.index(trovata.group(1)),
                            int(trovata.group(2)), voce, trovata.group(1)))
    return [(voce, braccio) for _, _, voce, braccio in sorted(trovate)]


def problemi_della_coppia(nomi: List[Tuple[str, str]],
                          lette: List[Esecuzione]) -> List[str]:
    """Che cosa impedisce alla coppia di essere una coppia: un braccio che
    manca, impostazioni diverse in altro che l'hook, modelli o modalità
    diversi."""
    problemi = ["manca il braccio %s: eseguite i passi del README" % b
                for b in BRACCI if b not in {braccio for _, braccio in nomi}]
    resti = [senza_hook(e.impostazioni) for e in lette]
    if any(r != resti[0] for r in resti[1:]):
        problemi.append("le copie differiscono in più dello Stop hook: le "
                        "impostazioni, tolto l'hook, devono essere uguali")
    modi = sorted({"%s, %s" % (e.modello, e.modo) for e in lette})
    if len(modi) > 1:
        problemi.append("le esecuzioni non hanno lo stesso modello e la "
                        "stessa modalità: %s" % " | ".join(modi))
    return problemi


def riepiloghi(lette: List[Esecuzione]) -> None:
    """Il comportamento «n su N» e il braccio senza hook come dato."""
    con = [e for e in lette if e.braccio == "con-hook"]
    senza = [e for e in lette if e.braccio == "senza-hook"]
    if con:
        print("%s: %s %d su %d" % (S_CONTINUA, CONFERMATA, sum(
            1 for e in con if verdetto_continua(e) == CONFERMATA), len(con)))
    if senza:
        print("%s: %d su %d" % (S_SENZA, sum(1 for e in senza
                                              if e.test.verdi), len(senza)))


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa
    e restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    nomi = nomi_delle_esecuzioni()
    if not nomi:
        print(PARTENZA)
        return 1
    lette: List[Esecuzione] = []
    mancanti = segnalazioni = 0
    for nome, braccio in nomi:
        try:
            esecuzione = leggi_esecuzione(nome, braccio)
        except Mancante as exc:
            avviso(str(exc))
            mancanti += 1
            continue
        lette.append(esecuzione)
        stampa(esecuzione)
        if braccio == "con-hook":
            riga, segnalazione = verdetto_blocca(esecuzione)
            print(riga)
            print("%s (%s): %s" % (S_CONTINUA, nome,
                                   verdetto_continua(esecuzione)))
            segnalazioni += 1 if segnalazione else 0
    riepiloghi(lette)
    for problema in problemi_della_coppia(nomi, lette):
        avviso(problema)
        mancanti += 1
    if mancanti:
        print(NON_ANCORA)
    if segnalazioni:
        print(SEGNALAZIONI % segnalazioni)
    if mancanti or segnalazioni:
        return 1
    if not any(e.blocchi for e in lette if e.braccio == "con-hook"):
        # Senza un blocco la garanzia non è stata messa alla prova: ogni
        # verdetto è «non distinguibile», e la prova va rifatta.
        print(NESSUNA_PROVA)
        return 1
    return 0


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
