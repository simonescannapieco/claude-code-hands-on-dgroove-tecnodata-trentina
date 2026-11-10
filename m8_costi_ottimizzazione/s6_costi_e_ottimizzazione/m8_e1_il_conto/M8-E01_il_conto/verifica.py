"""verifica.py di M8-E01 «Quanto costa una risposta».

Legge, nello spazio di lavoro, risposte/prima.json (il JSON della chiamata del
passo 2 del README), listino.json e volume.txt, e ricalcola da sé i due numeri
dell'esercizio: il costo della chiamata, ognuno dei cinque conteggi di usage al
suo prezzo, e il costo del mese al volume dichiarato. Confronta il costo
ricalcolato con total_cost_usd del JSON: una dimostrazione del metodo, stampata
come dato con la differenza; non decide l'uscita.

Poi lancia conto.py dello spazio di lavoro, due volte: la prima così com'è, e
controlla che nella sua uscita ci siano i due numeri (il costo entro un
centesimo di centesimo di dollaro, il mese entro un centesimo, numeri scritti
con il punto o con la virgola); la seconda su una copia dello spazio di lavoro
con altri numeri negli stessi tre file, e controlla che i due numeri siano
quelli nuovi: devono venire dai file, non dal codice. Una verifica che legge
soltanto l'uscita non distinguerebbe un conto calcolato da un total_cost_usd
ricopiato, e i due, sulla stessa chiamata, sono uguali.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Env:    PN_TIMEOUT_CONTO  i secondi concessi a conto.py, ogni volta (default 20)
Uscita: 0 = prima.json è una chiamata riuscita su haiku e conto.py stampa i due
        numeri, anche con altri numeri nei file · 1 = prima.json o conto.py
        che mancano, una chiamata non riuscita o non su haiku, conto.py che non
        gira, non finisce o non stampa i due numeri · 2 = precondizione: uso
        sbagliato, spazio di lavoro assente, listino.json o volume.txt che
        mancano o non vanno, un file che c'è ma non si legge, un errore
        inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

USO = "Uso: python3 -B -I verifica.py <spazio di lavoro>\n"
MODELLO = "haiku"
MILIONE = 1_000_000.0
TOLLERANZA_COSTO = 0.0001    # un centesimo di centesimo di dollaro
TOLLERANZA_MESE = 0.01       # un centesimo di dollaro
TIMEOUT_DEFAULT = 20
CHIAVI_PREZZI = ("input", "output", "cache_write_5m", "cache_write_1h",
                 "cache_read")
CHIAVI_VOLUME = ("ticket_al_mese", "token_input_per_ticket",
                 "token_output_per_ticket")
# I cinque conteggi: il campo, come si chiama nel conto, il prezzo.
CONTEGGI = (("input_tokens", "input_tokens", "input"),
            ("ephemeral_5m_input_tokens", "scrittura in cache, 5 min",
             "cache_write_5m"),
            ("ephemeral_1h_input_tokens", "scrittura in cache, 1 ora",
             "cache_write_1h"),
            ("cache_read_input_tokens", "lettura dalla cache", "cache_read"),
            ("output_tokens", "output_tokens", "output"))
RIGA_VOLUME = re.compile(r"^\s*([a-z_]+)\s*=\s*([0-9]+)\s*$")
NUMERO = re.compile(r"(?<![\w.,])[0-9]+(?:[.,][0-9]+)*(?:[eE][-+]?[0-9]+)?")
# La copia con altri numeri: conteggi lontani fra loro, così nessun numero
# stampato dal conto vale per un altro; total_cost_usd finto.
ALTRI_CONTEGGI = {"input_tokens": 1500, "ephemeral_5m_input_tokens": 200000,
                  "ephemeral_1h_input_tokens": 100000,
                  "cache_read_input_tokens": 400000, "output_tokens": 30000}
ALTRO_TOTALE = 9.876543
ALTRO_VOLUME = {"ticket_al_mese": 20000, "token_input_per_ticket": 2000,
                "token_output_per_ticket": 300}
MOLTIPLICATORE_PREZZI = 7
FATTO = ("Fatto: conto.py stampa il conto della chiamata e quello del mese;\n"
         "il confronto con total_cost_usd è qui sopra, come dato.")


ELEMENTO = os.path.dirname(os.path.abspath(__file__))


class Precondizione(Exception):
    """Qualcosa impedisce di partire: uscita 2."""


class NonAncora(Exception):
    """Il lavoro non è ancora completo: uscita 1."""


class Chiamata(NamedTuple):
    """Una chiamata riuscita: ciò che serve del suo JSON."""
    conteggi: Dict[str, int]
    totale: float
    dati: Dict[str, Any]


def virgola(valore: float, decimali: int = 6) -> str:
    """Un numero con la virgola."""
    return ("%.*f" % (decimali, valore)).replace(".", ",")


def dollari(valore: float, decimali: int = 6) -> str:
    """Una cifra in dollari, con la virgola."""
    return virgola(valore, decimali) + " $"


def leggi_testo(percorso: str) -> Optional[str]:
    """Il testo del file, None se non c'è. Raises: Precondizione se c'è ma
    non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, getattr(exc, "strerror", None) or exc)) from exc


def controlla_listino(ws: str) -> None:
    """Il listino dello spazio di lavoro è quello dell'elemento.
    Raises: NonAncora, Precondizione."""
    riferimento = leggi_testo(os.path.join(ELEMENTO, "esercizio",
                                           "listino.json"))
    if riferimento is None:
        raise Precondizione("nell'elemento manca esercizio/listino.json")
    copia = leggi_testo(os.path.join(ws, "listino.json"))
    if copia is not None and copia != riferimento:
        raise NonAncora("listino.json è cambiato: rimettetelo com'era "
                        "(git checkout -- listino.json)")


def leggi_listino(ws: str) -> Tuple[Dict[str, Any], Dict[str, float]]:
    """Il listino intero e i prezzi di haiku. Raises: Precondizione."""
    testo = leggi_testo(os.path.join(ws, "listino.json"))
    if testo is None:
        raise Precondizione("manca listino.json nello spazio di lavoro: "
                            "ricopiatelo con git checkout -- listino.json")
    try:
        listino = json.loads(testo)
    except ValueError as exc:
        raise Precondizione("listino.json non è un JSON valido: "
                            "git checkout -- listino.json") from exc
    modelli = listino.get("modelli") if isinstance(listino, dict) else None
    voce = modelli.get(MODELLO) if isinstance(modelli, dict) else None
    if not isinstance(voce, dict):
        raise Precondizione("listino.json non ha la voce del modello %s"
                            % MODELLO)
    prezzi: Dict[str, float] = {}
    for chiave in CHIAVI_PREZZI:
        valore = voce.get(chiave)
        if isinstance(valore, bool) or not isinstance(valore, (int, float)) \
                or valore < 0:
            raise Precondizione("listino.json: il prezzo %s di %s non è un "
                                "numero" % (chiave, MODELLO))
        prezzi[chiave] = float(valore)
    return listino, prezzi


def leggi_volume(ws: str) -> Tuple[Dict[str, int], str]:
    """I tre numeri di volume.txt e il suo testo. Raises: Precondizione."""
    testo = leggi_testo(os.path.join(ws, "volume.txt"))
    if testo is None:
        raise Precondizione("manca volume.txt nello spazio di lavoro: "
                            "ricopiatelo con git checkout -- volume.txt")
    volume: Dict[str, int] = {}
    for riga in testo.splitlines():
        if not riga.strip() or riga.lstrip().startswith("#"):
            continue
        trovata = RIGA_VOLUME.match(riga)
        if not trovata or trovata.group(1) not in CHIAVI_VOLUME:
            raise Precondizione("volume.txt: riga non valida: «%s» (attesa "
                                "nome = numero)" % riga.strip())
        volume[trovata.group(1)] = int(trovata.group(2))
    for chiave in CHIAVI_VOLUME:
        if chiave not in volume:
            raise Precondizione("volume.txt: manca %s" % chiave)
        if volume[chiave] <= 0:
            raise Precondizione("volume.txt: %s: servono numeri positivi"
                                % chiave)
    return volume, testo


def conteggio(valore: Any, nome: str) -> int:
    """Un conteggio di token: un intero, positivo o zero. Raises: NonAncora."""
    if isinstance(valore, bool) or not isinstance(valore, int) or valore < 0:
        raise NonAncora("risposte/prima.json: %s non è un conteggio di token: "
                        "rifate il passo 2 del README" % nome)
    return valore


def leggi_conteggi(uso: Dict[str, Any]) -> Dict[str, int]:
    """I cinque conteggi di usage. Raises: NonAncora."""
    scrittura = uso.get("cache_creation")
    if not isinstance(scrittura, dict) \
            or "ephemeral_5m_input_tokens" not in scrittura \
            or "ephemeral_1h_input_tokens" not in scrittura:
        raise NonAncora("risposte/prima.json: usage non ha la suddivisione "
                        "della scrittura in cache (cache_creation): rifate "
                        "il passo 2 del README")
    conteggi = {"input_tokens": conteggio(uso.get("input_tokens"),
                                          "input_tokens"),
                "cache_read_input_tokens": conteggio(
                    uso.get("cache_read_input_tokens"),
                    "cache_read_input_tokens"),
                "output_tokens": conteggio(uso.get("output_tokens"),
                                           "output_tokens"),
                "ephemeral_5m_input_tokens": conteggio(
                    scrittura.get("ephemeral_5m_input_tokens"),
                    "ephemeral_5m_input_tokens"),
                "ephemeral_1h_input_tokens": conteggio(
                    scrittura.get("ephemeral_1h_input_tokens"),
                    "ephemeral_1h_input_tokens")}
    somma = conteggio(uso.get("cache_creation_input_tokens"),
                      "cache_creation_input_tokens")
    if somma != conteggi["ephemeral_5m_input_tokens"] \
            + conteggi["ephemeral_1h_input_tokens"]:
        raise NonAncora("risposte/prima.json: cache_creation_input_tokens "
                        "non torna con la suddivisione: rifate il passo 2 "
                        "del README")
    return conteggi


def controlla_modello(dati: Dict[str, Any]) -> None:
    """La chiamata è andata su un solo modello, haiku. Raises: NonAncora."""
    modelli = dati.get("modelUsage")
    if not isinstance(modelli, dict) or not modelli:
        raise NonAncora("risposte/prima.json non ha modelUsage: rifate il "
                        "passo 2 del README")
    if len(modelli) > 1:
        raise NonAncora("risposte/prima.json: più di un modello (%s): rifate "
                        "il passo 2 del README" % ", ".join(modelli))
    nome = next(iter(modelli))
    if MODELLO not in nome.lower():
        raise NonAncora("risposte/prima.json: la chiamata è su %s, non su "
                        "haiku: rifate il passo 2 del README, il comando dà "
                        "--model haiku" % nome)


def leggi_chiamata(testo: str) -> Chiamata:
    """Il JSON della chiamata. Raises: NonAncora."""
    try:
        dati = json.loads(testo)
    except ValueError as exc:
        raise NonAncora("risposte/prima.json non è un JSON: rifate il passo "
                        "2 del README") from exc
    if not isinstance(dati, dict):
        raise NonAncora("risposte/prima.json non è il JSON di una chiamata "
                        "di claude -p: rifate il passo 2 del README")
    if dati.get("is_error") is not False or dati.get("type") != "result" \
            or dati.get("subtype") != "success":
        raise NonAncora("risposte/prima.json: la chiamata non è finita bene "
                        "(is_error %s, subtype %s): rifate il passo 2 del "
                        "README" % (dati.get("is_error"), dati.get("subtype")))
    uso = dati.get("usage")
    if not isinstance(uso, dict):
        raise NonAncora("risposte/prima.json non ha il campo usage: rifate "
                        "il passo 2 del README")
    controlla_modello(dati)
    totale = dati.get("total_cost_usd")
    if isinstance(totale, bool) or not isinstance(totale, (int, float)) \
            or totale < 0:
        raise NonAncora("risposte/prima.json: total_cost_usd manca o non è "
                        "un numero: rifate il passo 2 del README")
    return Chiamata(leggi_conteggi(uso), float(totale), dati)


def costo_chiamata(conteggi: Dict[str, int],
                   prezzi: Dict[str, float]) -> float:
    """Il costo: ognuno dei cinque conteggi al suo prezzo."""
    return sum(conteggi[campo] * prezzi[prezzo]
               for campo, _, prezzo in CONTEGGI) / MILIONE


def costo_mese(volume: Dict[str, int], prezzi: Dict[str, float]) -> float:
    """Il mese: ticket × (token di input e di output ai prezzi base)."""
    return volume["ticket_al_mese"] * (
        volume["token_input_per_ticket"] * prezzi["input"]
        + volume["token_output_per_ticket"] * prezzi["output"]) / MILIONE


def secondi_concessi() -> int:
    """I secondi per conto.py. Raises: Precondizione."""
    dato = os.environ.get("PN_TIMEOUT_CONTO", "")
    if not dato:
        return TIMEOUT_DEFAULT
    if not dato.isdigit() or int(dato) == 0:
        raise Precondizione("PN_TIMEOUT_CONTO: un numero di secondi, non "
                            "«%s»" % dato)
    return int(dato)


def esegui_conto(cartella: str, secondi: int) -> str:
    """L'uscita di conto.py lanciato nella cartella. Raises: NonAncora."""
    comando = [sys.executable, "-B", "-I", "conto.py"]
    try:
        esito = subprocess.run(comando, cwd=cartella, capture_output=True,
                               stdin=subprocess.DEVNULL, timeout=secondi,
                               check=False)
    except subprocess.TimeoutExpired as exc:
        raise NonAncora("conto.py non è finito in %d secondi" % secondi) \
            from exc
    except OSError as exc:
        raise Precondizione("non riesco a lanciare conto.py (%s)"
                            % (exc.strerror or exc)) from exc
    if esito.returncode != 0:
        errore = esito.stderr.decode("utf-8", "replace").strip().splitlines()
        coda = "\n".join("  " + r for r in errore[-5:])
        raise NonAncora("conto.py non gira: è uscito con %d%s"
                        % (esito.returncode, ("\n" + coda) if coda else ""))
    return esito.stdout.decode("utf-8", "replace")


def valori_di(token: str) -> List[float]:
    """I valori che una cifra può avere: il punto e la virgola possono
    separare i decimali o le migliaia, in italiano e in inglese."""
    base, _, esponente = token.lower().partition("e")
    fattore = 10.0 ** int(esponente) if esponente else 1.0
    pezzi = re.split(r"[.,]", base)
    valori = [float("".join(pezzi)) * fattore]
    if len(pezzi) > 1:
        valori.append(float("".join(pezzi[:-1]) + "." + pezzi[-1]) * fattore)
    return valori


def numeri_stampati(uscita: str) -> List[float]:
    """Tutti i valori possibili dei numeri nell'uscita di conto.py."""
    numeri: List[float] = []
    for trovato in NUMERO.finditer(uscita):
        try:
            numeri.extend(valori_di(trovato.group(0)))
        except (ValueError, OverflowError):
            continue
    return numeri


def vicino(numeri: List[float], atteso: float) -> Optional[float]:
    """Il numero stampato più vicino a quello atteso, None se non ce n'è."""
    if not numeri:
        return None
    return min(numeri, key=lambda n: abs(n - atteso))


def cerca(uscita: str, atteso: float,
          tolleranza: float) -> Tuple[bool, Optional[float]]:
    """(c'è un numero entro la tolleranza, il numero più vicino)."""
    piu_vicino = vicino(numeri_stampati(uscita), atteso)
    if piu_vicino is None:
        return False, None
    return abs(piu_vicino - atteso) <= tolleranza, piu_vicino


def scrivi_conto(chiamata: Chiamata, prezzi: Dict[str, float], listino: Any,
                 costo: float) -> None:
    """Il ricalcolo, voce per voce, e il confronto con il JSON (dati)."""
    print("== Il conto della chiamata, ricalcolato da questa verifica ==")
    print("(listino del %s, %s, dollari per milione di token)"
          % (listino.get("letto_il", "?"), MODELLO))
    for campo, nome, prezzo in CONTEGGI:
        token = chiamata.conteggi[campo]
        print("  %-27s %9d × %s = %s" % (
            nome, token, virgola(prezzi[prezzo], 3),
            dollari(token * prezzi[prezzo] / MILIONE)))
    print("  %-27s %24s" % ("totale ricalcolato", dollari(costo)))
    entrata = chiamata.conteggi["input_tokens"] \
        + chiamata.conteggi["ephemeral_5m_input_tokens"] \
        + chiamata.conteggi["ephemeral_1h_input_tokens"] \
        + chiamata.conteggi["cache_read_input_tokens"]
    print("(dato) token in entrata, i tre campi sommati: %d" % entrata)
    print("(dato) total_cost_usd del JSON: %s" % dollari(chiamata.totale))
    differenza = abs(chiamata.totale - costo)
    esito = "il calcolo riproduce total_cost_usd entro" \
        if differenza <= TOLLERANZA_COSTO \
        else "il calcolo non riproduce total_cost_usd entro"
    print("(dato) differenza dal ricalcolo: %s" % dollari(differenza))
    print("       %s un centesimo\n       di centesimo (%s)"
          % (esito, dollari(TOLLERANZA_COSTO, 4)))


def quanto_vicino(piu_vicino: Optional[float], decimali: int = 6) -> str:
    """Una frase sul numero stampato più vicino a quello atteso."""
    if piu_vicino is None:
        return "nell'uscita non c'è nessun numero"
    return "il numero stampato più vicino è %s" % dollari(piu_vicino, decimali)


def controlla_costo(uscita: str, costo: float, proposta: str) -> None:
    """Il costo della chiamata nell'uscita. Raises: NonAncora."""
    trovato, piu_vicino = cerca(uscita, costo, TOLLERANZA_COSTO)
    if not trovato:
        raise NonAncora("conto.py non stampa il costo della chiamata: il "
                        "ricalcolo dà %s, e %s; %s" % (
                            dollari(costo), quanto_vicino(piu_vicino),
                            proposta))
    print("il costo della chiamata: stampa %s (differenza dal\n"
          "  ricalcolo %s, entro %s)" % (
              dollari(piu_vicino or 0.0),
              dollari(abs((piu_vicino or 0.0) - costo)),
              dollari(TOLLERANZA_COSTO, 4)))


def controlla_mese(uscita: str, mese: float, volume: Dict[str, int]) -> None:
    """Il costo del mese nell'uscita. Raises: NonAncora."""
    trovato, piu_vicino = cerca(uscita, mese, TOLLERANZA_MESE)
    if not trovato:
        raise NonAncora("conto.py non stampa il costo del mese: il ricalcolo "
                        "dà %s, e %s" % (dollari(mese, 2),
                                         quanto_vicino(piu_vicino, 2)))
    print("il costo del mese (%d ticket da %d token in entrata e\n"
          "  %d in uscita): stampa %s, ricalcolo %s" % (
              volume["ticket_al_mese"], volume["token_input_per_ticket"],
              volume["token_output_per_ticket"],
              dollari(piu_vicino or 0.0, 2), dollari(mese, 2)))


def controlla_uscita(uscita: str, costo: float, mese: float,
                     volume: Dict[str, int]) -> None:
    """I due numeri nell'uscita di conto.py, sulla chiamata vera; li
    controlla tutti e due, e dice in una volta che cosa manca.
    Raises: NonAncora."""
    mancano: List[str] = []
    for prova in (lambda: controlla_costo(
            uscita, costo, "stampate almeno sei decimali, un dollaro diviso "
            "un milione non si vede con due"),
                  lambda: controlla_mese(uscita, mese, volume)):
        try:
            prova()
        except NonAncora as exc:
            mancano.append(str(exc))
    if mancano:
        raise NonAncora("\n".join(mancano))


def altro_listino(listino: Dict[str, Any]) -> Dict[str, Any]:
    """Il listino della copia: ogni prezzo moltiplicato, il resto uguale."""
    copia = json.loads(json.dumps(listino))
    for voce in copia.get("modelli", {}).values():
        if isinstance(voce, dict):
            for chiave in CHIAVI_PREZZI:
                if isinstance(voce.get(chiave), (int, float)):
                    voce[chiave] = round(voce[chiave] * MOLTIPLICATORE_PREZZI,
                                         6)
    return copia


def altro_volume(testo: str) -> str:
    """Il volume.txt della copia: stesse righe, altri numeri."""
    for chiave, valore in ALTRO_VOLUME.items():
        testo = re.sub(r"(?m)^(\s*%s\s*=\s*)[0-9]+" % chiave,
                       lambda m, v=valore: m.group(1) + str(v), testo)
    return testo


def altra_chiamata(dati: Dict[str, Any]) -> Dict[str, Any]:
    """Il JSON della copia: i conteggi e total_cost_usd cambiati, gli stessi
    in usage, nelle sue iterazioni e in modelUsage."""
    copia = json.loads(json.dumps(dati))
    uso = copia["usage"]
    n = ALTRI_CONTEGGI
    scrittura = n["ephemeral_5m_input_tokens"] + n["ephemeral_1h_input_tokens"]
    secchi = {"ephemeral_5m_input_tokens": n["ephemeral_5m_input_tokens"],
              "ephemeral_1h_input_tokens": n["ephemeral_1h_input_tokens"]}
    uso.update({"input_tokens": n["input_tokens"],
                "cache_creation_input_tokens": scrittura,
                "cache_read_input_tokens": n["cache_read_input_tokens"],
                "output_tokens": n["output_tokens"],
                "cache_creation": dict(secchi)})
    if "iterations" in uso:
        uso["iterations"] = [{
            "input_tokens": n["input_tokens"],
            "output_tokens": n["output_tokens"],
            "cache_read_input_tokens": n["cache_read_input_tokens"],
            "cache_creation_input_tokens": scrittura,
            "cache_creation": dict(secchi), "type": "message"}]
    copia["total_cost_usd"] = ALTRO_TOTALE
    for voce in copia.get("modelUsage", {}).values():
        if isinstance(voce, dict):
            voce.update({"inputTokens": n["input_tokens"],
                         "outputTokens": n["output_tokens"],
                         "cacheReadInputTokens": n["cache_read_input_tokens"],
                         "cacheCreationInputTokens": scrittura,
                         "cacheCreationEphemeral5mInputTokens":
                             n["ephemeral_5m_input_tokens"],
                         "cacheCreationEphemeral1hInputTokens":
                             n["ephemeral_1h_input_tokens"],
                         "costUSD": ALTRO_TOTALE})
    return copia


def scrivi_json(percorso: str, dati: Any) -> None:
    """Un file JSON. Raises: OSError."""
    with open(percorso, "w", encoding="utf-8") as fh:
        json.dump(dati, fh, ensure_ascii=False, indent=2)


def prova_altri_numeri(ws: str, chiamata: Chiamata, listino: Dict[str, Any],
                       testo_volume: str, secondi: int) -> None:
    """conto.py su una copia dello spazio di lavoro con altri numeri negli
    stessi tre file: i due numeri nuovi devono esserci. Raises: NonAncora,
    Precondizione."""
    with tempfile.TemporaryDirectory(prefix="verifica_m8_e01.") as cartella:
        copia = os.path.join(cartella, "copia")
        try:
            shutil.copytree(ws, copia, symlinks=False, ignore=
                            shutil.ignore_patterns(".git", "__pycache__"))
            nuovo_listino = altro_listino(listino)
            scrivi_json(os.path.join(copia, "listino.json"), nuovo_listino)
            scrivi_json(os.path.join(copia, "risposte", "prima.json"),
                        altra_chiamata(chiamata.dati))
            with open(os.path.join(copia, "volume.txt"), "w",
                      encoding="utf-8") as fh:
                fh.write(altro_volume(testo_volume))
        except (OSError, shutil.Error) as exc:
            raise Precondizione("non riesco a preparare la copia dello "
                                "spazio di lavoro (%s)" % exc) from exc
        prezzi = {k: float(v) for k, v
                  in nuovo_listino["modelli"][MODELLO].items()
                  if k in CHIAVI_PREZZI}
        costo = costo_chiamata(ALTRI_CONTEGGI, prezzi)
        mese = costo_mese(ALTRO_VOLUME, prezzi)
        uscita = esegui_conto(copia, secondi)
    mancano = [nome for nome, trovato in (
        ("il costo della chiamata (%s)" % dollari(costo),
         cerca(uscita, costo, TOLLERANZA_COSTO)[0]),
        ("il costo del mese (%s)" % dollari(mese, 2),
         cerca(uscita, mese, TOLLERANZA_MESE)[0])) if not trovato]
    if mancano:
        raise NonAncora(
            "conto.py stampa i numeri giusti per questa chiamata, ma "
            "con altri numeri negli stessi file (usage, total_cost_usd, "
            "prezzi di listino.json, volume.txt) non stampa %s: deve "
            "calcolarli dai tre file, non scriverli nel codice né "
            "copiare total_cost_usd" % " né ".join(mancano))
    print("con altri numeri negli stessi file: il costo %s e il\n"
          "  mese %s, come devono" % (dollari(costo), dollari(mese, 2)))


def controlla(ws: str) -> int:
    """Il controllo; l'uscita del contratto. Raises: NonAncora,
    Precondizione."""
    if not os.path.isdir(ws):
        raise Precondizione("lo spazio di lavoro %s non esiste" % ws)
    secondi = secondi_concessi()
    listino, prezzi = leggi_listino(ws)
    controlla_listino(ws)
    volume, testo_volume = leggi_volume(ws)
    json_chiamata = leggi_testo(os.path.join(ws, "risposte", "prima.json"))
    mancano: List[str] = []
    if json_chiamata is None:
        mancano.append("Manca risposte/prima.json: eseguite la chiamata del "
                       "passo 2 del README.")
    if not os.path.exists(os.path.join(ws, "conto.py")):
        mancano.append("Manca conto.py nello spazio di lavoro: è lo script "
                       "del passo 3 del README.")
    if mancano:
        raise NonAncora("\n".join(mancano))
    chiamata = leggi_chiamata(json_chiamata or "")
    costo = costo_chiamata(chiamata.conteggi, prezzi)
    mese = costo_mese(volume, prezzi)
    scrivi_conto(chiamata, prezzi, listino, costo)
    print()
    print("== conto.py ==")
    uscita = esegui_conto(ws, secondi)
    controlla_uscita(uscita, costo, mese, volume)
    prova_altri_numeri(ws, chiamata, listino, testo_volume, secondi)
    print(FATTO)
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except NonAncora as exc:
        print(str(exc))
        return 1
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("verifica: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
