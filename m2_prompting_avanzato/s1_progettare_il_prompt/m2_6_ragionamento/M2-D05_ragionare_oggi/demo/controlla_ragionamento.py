"""Il controllo di M2-D05, «Ragionare, oggi»: legge ragionamento.tsv, la
tabella dei passi del README, e mette alla prova quattro affermazioni di
Anthropic sul ragionamento dei modelli 5.5.

La tabella ha l'intestazione modello, effort, thinking_off, modello_id,
orario, token_uscita, token_thinking (separati da un TAB) e una riga per
chiamata. Le sette chiamate:
  R1 haiku low     R2 haiku low con MAX_THINKING_TOKENS=0     R3 haiku high
  R4 sonnet low    R5 sonnet high    R6 opus low    R7 opus high
Se una chiamata compare più volte conta la sua ultima riga; una riga che
non è una delle sette si segnala e non conta.

Stampa i numeri che legge, poi una riga per affermazione:
  V1 (una garanzia) in ogni chiamata 0 <= token_thinking <= token_uscita;
  V2 R1 ragiona (token_thinking > 0) anche se il prompt chiede di
     rispondere direttamente;
  V3 R2 ragiona anche con MAX_THINKING_TOKENS=0; uno 0 la lascia non
     dimostrata, perché Claude decide a ogni richiesta se ragionare;
  V4 per modello, più token di ragionamento a high che a low; 0 a tutti e
     due i livelli non si distingue da una suddivisione non riportata.
L'orario e i token in uscita sono dati: nessun verdetto li giudica (i token
in uscita servono soltanto a V1).

Uso:    python3 controlla_ragionamento.py [ragionamento.tsv]
Uscita: 0 la tabella è completa e V1 è confermata, qualunque sia l'esito di
          V2, V3 e V4
        1 la tabella manca o è incompleta, o V1 non è confermata
        2 il file non si legge; in una riga ha risposto un modello diverso
          da quello della riga (claude-haiku-5-5, claude-sonnet-5-5,
          claude-opus-5-5); un uso sbagliato
"""
from __future__ import annotations

import re
import sys
from typing import Dict, List, NamedTuple, Tuple

INTESTAZIONE = "\t".join(("modello", "effort", "thinking_off", "modello_id",
                          "orario", "token_uscita", "token_thinking"))
SPENTO = "MAX_THINKING_TOKENS=0"
# Le sette chiamate: etichetta, modello, effort, thinking_off.
CHIAMATE = (("R1", "haiku", "low", "no"), ("R2", "haiku", "low", SPENTO),
            ("R3", "haiku", "high", "no"), ("R4", "sonnet", "low", "no"),
            ("R5", "sonnet", "high", "no"), ("R6", "opus", "low", "no"),
            ("R7", "opus", "high", "no"))
# Il modello che deve aver risposto, per alias.
MODELLI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5",
           "opus": "claude-opus-5-5"}
# V4: per modello, la chiamata a low e quella a high.
CONFRONTI = (("Haiku", "R1", "R3"), ("Sonnet", "R4", "R5"),
             ("Opus", "R6", "R7"))
# Un conteggio di token: cifre ASCII, al più dodici, così int() non riceve
# mai un testo senza limiti.
NUMERO = re.compile(r"-?[0-9]{1,12}")
CONTROLLO = re.compile(r"[\x00-\x1f\x7f]")
TABELLA = "  {:<4}{:<8}{:<7}{:<23}{:<8}{:>7}{:>10}{:>12}"
ZERO = "uno 0 compare anche quando la suddivisione non è riportata"

Chiave = Tuple[str, str, str]


class Chiamata(NamedTuple):
    """Una riga completa: l'etichetta R1–R7 e i dati che si stampano."""
    etichetta: str
    modello: str
    effort: str
    spento: str
    orario: str
    uscita: int
    thinking: int


def mostra(testo: str, massimo: int = 40) -> str:
    """Il testo su una riga, senza caratteri di controllo, al più
    `massimo` caratteri: un dato rovinato non rompe lo schermo."""
    pulito = CONTROLLO.sub("?", testo)
    if len(pulito) > massimo:
        return pulito[:massimo - 1] + "…"
    return pulito


def descrizione(modello: str, effort: str, spento: str) -> str:
    """Una chiamata a parole: «haiku, effort low, MAX_THINKING_TOKENS=0»."""
    testo = "%s, effort %s" % (modello, effort)
    return testo if spento == "no" else "%s, %s" % (testo, spento)


def leggi_righe(testo: str) -> Tuple[bool, Dict[Chiave, Tuple[int, List[str]]],
                                     List[str]]:
    """(l'intestazione è giusta, l'ultima riga di ogni chiamata con il suo
    numero, le note sulle righe ignorate)."""
    righe = testo.split("\n")
    if righe[0].lstrip("﻿").rstrip("\r") != INTESTAZIONE:
        return False, {}, []
    attese = {(c[1], c[2], c[3]) for c in CHIAMATE}
    trovate: Dict[Chiave, Tuple[int, List[str]]] = {}
    note: List[str] = []
    for numero, riga in enumerate(righe[1:], start=2):
        riga = riga.rstrip("\r")
        if not riga.strip():
            continue
        campi = riga.split("\t")
        chiave = (campi[0], campi[1] if len(campi) > 1 else "",
                  campi[2] if len(campi) > 2 else "")
        if chiave in attese:
            trovate[chiave] = (numero, campi)
        else:
            note.append("Riga %d ignorata: «%s» non è una delle sette "
                        "chiamate." % (numero, mostra(", ".join(campi[:3]))))
    return True, trovate, note


def esamina(trovate: Dict[Chiave, Tuple[int, List[str]]]
            ) -> Tuple[List[Chiamata], List[str], List[str]]:
    """Le chiamate complete; i difetti che rendono la tabella incompleta
    (uscita 1); i modelli diversi da quello della riga (uscita 2)."""
    chiamate: List[Chiamata] = []
    incomplete: List[str] = []
    estranei: List[str] = []
    for etichetta, modello, effort, spento in CHIAMATE:
        nome = "%s (%s)" % (etichetta, descrizione(modello, effort, spento))
        trovata = trovate.get((modello, effort, spento))
        if trovata is None:
            incomplete.append("Manca la riga di %s: fate quella chiamata dei "
                              "passi del README." % nome)
            continue
        numero, campi = trovata
        if len(campi) != 7:
            incomplete.append("Riga %d, %s: %d campi invece di 7: rifate "
                              "quella chiamata." % (numero, nome, len(campi)))
            continue
        modello_id, orario, uscita, thinking = campi[3:]
        difetti = ["%s «%s» non è un numero" % (campo, mostra(valore))
                   for campo, valore in (("token_uscita", uscita),
                                         ("token_thinking", thinking))
                   if not NUMERO.fullmatch(valore)]
        if not modello_id:
            difetti.insert(0, "modello_id vuoto")
        if difetti:
            incomplete.append("Riga %d, %s: %s: rifate quella chiamata."
                              % (numero, nome, "; ".join(difetti)))
        elif modello_id != MODELLI[modello]:
            estranei.append("Riga %d, %s: ha risposto «%s», non %s."
                            % (numero, nome, mostra(modello_id),
                               MODELLI[modello]))
        else:
            chiamate.append(Chiamata(etichetta, modello, effort, spento,
                                     orario, int(uscita), int(thinking)))
    return chiamate, incomplete, estranei


def stampa_numeri(chiamate: List[Chiamata]) -> None:
    """La tabella letta, chiamata per chiamata: l'orario e i token come
    dati; la differenza approssima la parte dell'output che non è
    ragionamento."""
    print("I numeri di ragionamento.tsv (token in uscita, token di "
          "ragionamento, e la loro")
    print("differenza, che approssima la parte dell'output che non è "
          "ragionamento):")
    print(TABELLA.format("", "modello", "effort", "thinking_off", "orario",
                         "uscita", "thinking", "differenza"))
    for c in chiamate:
        resto = (str(c.uscita - c.thinking) if 0 <= c.thinking <= c.uscita
                 else "—")
        print(TABELLA.format(c.etichetta, c.modello, c.effort, c.spento,
                             mostra(c.orario, 7) or "—", c.uscita,
                             c.thinking, resto))
    print("In ogni riga ha risposto il modello della riga: claude-haiku-5-5 "
          "(R1–R3),")
    print("claude-sonnet-5-5 (R4, R5), claude-opus-5-5 (R6, R7).")


def verdetti(chiamate: List[Chiamata]) -> bool:
    """Una riga per affermazione; True se la garanzia V1 è confermata."""
    per = {c.etichetta: c for c in chiamate}
    fuori = ["%s: %d su %d" % (c.etichetta, c.thinking, c.uscita)
             for c in chiamate if not 0 <= c.thinking <= c.uscita]
    print("Le affermazioni:")
    if fuori:
        print("  V1  la documentazione garantisce che thinking_tokens sia "
              "minore o uguale a output_tokens in ogni chiamata: in questa "
              "esecuzione no (%s)" % "; ".join(fuori))
    else:
        print("  V1  thinking_tokens è minore o uguale a output_tokens in "
              "ogni chiamata (%d su %d): confermata"
              % (len(chiamate), len(chiamate)))
    r1, r2 = per["R1"].thinking, per["R2"].thinking
    print("  V2  dire a Haiku 5.5 di rispondere direttamente non gli "
          "impedisce di ragionare (R1: %d token di ragionamento): %s"
          % (r1, "confermata" if r1 > 0
             else "non confermata in questa esecuzione"))
    print("  V3  con MAX_THINKING_TOKENS=0 il thinking di Haiku 5.5 non si "
          "spegne (R2: %d token di ragionamento): %s"
          % (r2, "confermata" if r2 > 0 else
             "non dimostrata in questa esecuzione: uno 0 può voler dire "
             "che Claude ha deciso di non ragionare"))
    print("  V4  un effort più elevato induce più ragionamento, modello per "
          "modello:")
    for nome, basso, alto in CONFRONTI:
        lo, hi = per[basso], per[alto]
        if hi.thinking > lo.thinking:
            esito = "confermata"
        elif hi.thinking == 0 and lo.thinking == 0:
            esito = "non distinguibile (%s)" % ZERO
        else:
            esito = "non confermata in questa esecuzione"
        print("      %s: token di ragionamento %d a low (%s), %d a high (%s);"
              " in uscita %d e %d: %s" % (nome, lo.thinking, basso,
                                          hi.thinking, alto, lo.uscita,
                                          hi.uscita, esito))
    return not fuori


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        if hasattr(flusso, "reconfigure"):
            flusso.reconfigure(errors="replace")
    if len(argv) > 1 or (argv and argv[0].startswith("-")):
        sys.stderr.write(__doc__)
        return 2
    percorso = argv[0] if argv else "ragionamento.tsv"
    nome = percorso.rstrip("/").rsplit("/", 1)[-1]
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except FileNotFoundError:
        print("Manca %s: eseguite i passi del README." % nome)
        return 1
    except OSError as exc:
        sys.stderr.write("controlla_ragionamento.py: %s non si legge (%s)\n"
                         % (nome, exc.strerror or type(exc).__name__))
        return 2
    giusta, trovate, note = leggi_righe(testo)
    if not giusta:
        print("%s: la prima riga deve essere l'intestazione dei passi del "
              "README, «%s»." % (nome, INTESTAZIONE.replace("\t", "<TAB>")))
        return 1
    for nota in note:
        print(nota)
    chiamate, incomplete, estranei = esamina(trovate)
    for difetto in incomplete:
        print(difetto)
    if estranei:
        for riga in estranei:
            sys.stderr.write("controlla_ragionamento.py: %s\n" % riga)
        sys.stderr.write("controlla_ragionamento.py: le affermazioni messe "
                         "alla prova riguardano claude-haiku-5-5, "
                         "claude-sonnet-5-5 e claude-opus-5-5; con un altro "
                         "modello il controllo non le giudica.\n")
        return 2
    if incomplete:
        return 1
    stampa_numeri(chiamate)
    return 0 if verdetti(chiamate) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
