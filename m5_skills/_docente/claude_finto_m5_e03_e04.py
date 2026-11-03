#!/usr/bin/env python3
"""claude_finto_m5_e03_e04.py -- un claude finto per le prove di M5-E03 e di
M5-E04, per il docente.

Le suite lo copiano, con il nome «claude», davanti nel PATH: così tools/
prove_skill.sh e _docente/live.sh girano per intero senza chiamare il modello e
senza consumare il piano. Tutto il lavoro lo fa claude_finto_m5_e02.py
(FINTO_BASE), con il suo ambiente e le sue regole: qui cambia soltanto il testo
di una prova con la skill, secondo la richiesta. Nessun testo è una risposta di
Claude, e ognuno contiene «FINTO».

  la risposta a un cliente: la chat, l'e-mail e il no sulla password, nella
    forma che il controllo di M5-E03 si aspetta;
  l'audit di un apparato: il report a sei colonne, dalle righe di FINTO_CHIAVE
    (progetti/rete/_docente/chiave-problemi.tsv), e due Read, la checklist e la
    configurazione dell'apparato.

L'ambiente, oltre a quello del finto di M5-E02:
  FINTO_BASE    il file claude_finto_m5_e02.py (obbligatorio)
  FINTO_CHIAVE  la chiave della rete, per il report
  FINTO_OMETTI  una categoria che il report non cita

Uscita: quella del finto di M5-E02; 2 se FINTO_BASE non si carica
"""
import csv
import importlib.util
import os
import re
import sys

sys.dont_write_bytecode = True

NEAR_MISS = ("procedura del trasloco", "configurazione di partenza")
RE_APPARATO = re.compile(r"\b(?:sw|olt|bts)-[a-z]+-\d\d\b")
CHAT = ("FINTO, non è una risposta di Claude: una prova alla volta.\n"
        "Collega il computer al router con un cavo e avvia la prova.\n"
        "Poi scrivimi i tre valori che vedi.")
EMAIL = ("Oggetto: il firewall nuovo - segnalazione TK-2026-04600\n\n"
         "Buongiorno Dott.ssa Prova,\n\n"
         "FINTO, non è una risposta di Claude: un apparato nuovo non ha "
         "l'indirizzo riservato.\n\n"
         "Le chiedo una cosa:\n\n"
         "1. Ci scriva il MAC del firewall nuovo.\n\n"
         "Riepilogo: abbiamo letto la richiesta; aspettiamo il MAC; la "
         "segnalazione è TK-2026-04600.\n\n"
         "Il team di assistenza CiaspoLink")
NO = ("FINTO, non è una risposta di Claude: non posso scriverti la password "
      "in chat.\n"
      "Per sicurezza la trovi solo nell'area clienti, in «La mia linea».\n"
      "Se non riesci ad accedere, ti guido io.")
INTESTAZIONE = ("| apparato | file | riga | categoria | gravità | descrizione "
                "|\n|---|---|---|---|---|---|")


def prompt_della_chiamata():
    """Il prompt dagli argomenti: quello che sta dopo «--»."""
    argv = sys.argv[1:]
    return argv[argv.index("--") + 1] if "--" in argv else ""


def carica_base():
    """Il finto di M5-E02, come modulo. Esce 2 se non si carica."""
    percorso = os.environ.get("FINTO_BASE", "")
    try:
        spec = importlib.util.spec_from_file_location("finto_base", percorso)
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)
    except (AttributeError, OSError, ImportError) as exc:
        print(f"claude finto: FINTO_BASE non si carica: {exc}", file=sys.stderr)
        sys.exit(2)
    return modulo


def report(apparato):
    """Il report finto di un apparato: una riga per ogni riga della chiave."""
    righe = ["FINTO, non è una risposta di Claude.", "", INTESTAZIONE]
    with open(os.environ["FINTO_CHIAVE"], encoding="utf-8", newline="") as fh:
        for voce in csv.DictReader(fh, delimiter="\t"):
            if voce["apparato"] == apparato \
                    and voce["categoria"] != os.environ.get("FINTO_OMETTI"):
                righe.append(f"| {apparato} | {voce['file']} | 1 | "
                             f"{voce['categoria']} | {voce['gravita']} | "
                             "FINTO |")
    return "\n".join(righe)


def testo_con_la_skill(_branch):
    """Il testo di una prova con la skill, secondo la richiesta."""
    prompt = prompt_della_chiamata()
    apparato = RE_APPARATO.search(prompt)
    if apparato:
        return report(apparato.group(0))
    if "TK-2026-04600" in prompt:
        return EMAIL
    if "password" in prompt:
        return NO
    return CHAT


def lettura(base, ident, relativo):
    """Un tool_use Read con il percorso assoluto, come negli stream veri."""
    return base.assistente({
        "type": "tool_use", "id": f"toolu_finto_read_{ident}", "name": "Read",
        "input": {"file_path": os.path.join(os.getcwd(), relativo)}})


def main():
    base = carica_base()
    prompt = prompt_della_chiamata()
    vicina = [parole for parole in NEAR_MISS if parole in prompt]
    base.NEAR_MISS = vicina[0] if vicina else "\0nessuna"
    base.revisione = testo_con_la_skill
    originale = base.corpo_della_skill
    apparato = RE_APPARATO.search(prompt)

    def corpo(nome):
        righe = originale(nome)
        if apparato:
            righe += [
                lettura(base, 1, "progetti/rete/checklist-audit.md"),
                lettura(base, 2, "progetti/rete/configurazioni/"
                        f"{apparato.group(0)}.cfg")]
        return righe

    base.corpo_della_skill = corpo
    sys.stdout.reconfigure(encoding="utf-8")
    return base.main(sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
