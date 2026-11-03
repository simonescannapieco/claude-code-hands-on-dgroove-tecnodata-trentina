#!/usr/bin/env python3
"""Controlla un messaggio per un cliente prima che l'operatore lo copi.

Uso: python3 -B -I scripts/controlla_messaggio.py <chat|email|telefono> file.txt
     (oppure il testo da stdin al posto del file)

Esce con 0 se il messaggio è a posto, con 1 e l'elenco dei problemi se no.
"""
import re
import sys

EVITA = [
    "problematica", "disservizio", "degrado", "ticket", "presa in carico",
    "preso in carico", "le faremo sapere", "sarà nostra cura", "gentile cliente",
    "sicuramente", "garantito", "a breve", "inconveniente", "come già detto",
    "ha sbagliato a collegare", "olt", "bng", "sbc", "pon",
]
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")


def frasi(testo):
    pezzi = re.split(r"(?<=[.!?:])\s+", testo.strip())
    return [p for p in pezzi if re.search(r"\w", p)]


def controlla(canale, testo):
    problemi = []
    minuscolo = testo.lower()
    for parola in EVITA:
        if re.search(r"(?<!\w)" + re.escape(parola) + r"(?!\w)", minuscolo):
            problemi.append(f"parola da evitare: «{parola}»")
    if EMOJI.search(testo):
        problemi.append("c'è un'emoji")
    if re.search(r"!{2,}|!\s*!", testo) or len(re.findall("!", testo)) > 1:
        problemi.append("più di un punto esclamativo")
    if re.search(r"\b[A-Z]{4,}\b", testo.replace("TK", "")):
        problemi.append("parola tutta in maiuscolo")
    elenco = re.search(r"^\s*(\d+[.)]|[-*•])\s", testo, re.M)
    if canale == "chat":
        n = len(frasi(testo))
        if n > 3:
            problemi.append(f"chat di {n} frasi: al massimo 3, e un solo passo")
        if elenco or "**" in testo:
            problemi.append("chat con elenco o grassetto: un passo per messaggio")
        if re.search(r"^(oggetto|buongiorno|cordiali|il team)", minuscolo, re.M):
            problemi.append("forma da e-mail in una chat")
    elif canale == "telefono":
        if elenco or "**" in testo or re.search(r"[→#*•]", testo):
            problemi.append("telefono con elenchi o simboli: il testo si legge a voce")
        if "riepilog" not in minuscolo and "ricapitol" not in minuscolo:
            problemi.append("manca il riepilogo prima di salutare")
    elif canale == "email":
        if not re.match(r"\s*Oggetto:", testo):
            problemi.append("manca la riga «Oggetto:» in testa")
        if not re.search(r"Riepilogo:", testo):
            problemi.append("manca il «Riepilogo:» in tre parti")
        if not testo.rstrip().endswith("Il team di assistenza CiaspoLink"):
            problemi.append("l'ultima riga deve essere la firma del team, senza altro dopo")
        if "**" in testo.split("\n", 1)[0] or "**" in testo:
            problemi.append("grassetto: solo testo semplice")
        if not re.search(r"TK-\d{4}-\d+", testo):
            problemi.append("nessun numero di segnalazione (ignora se il cliente non ne ha)")
    else:
        problemi.append("canale sconosciuto: usa chat, email o telefono")
    return problemi


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    canale = sys.argv[1]
    testo = open(sys.argv[2], encoding="utf-8").read() if len(sys.argv) > 2 else sys.stdin.read()
    problemi = controlla(canale, testo)
    for p in problemi:
        print("DA CORREGGERE:", p)
    if not problemi:
        print("messaggio a posto")
    return 1 if problemi else 0


if __name__ == "__main__":
    sys.exit(main())
