"""lib_stampa_prove.py -- la tabella che tools/lib_controlla_prove.py stampa
per ogni iterazione delle prove di una skill: per ogni caso e configurazione
la chiamata a Skill, le asserzioni passate, turni, token e secondi; i passi
negati dal permesso, come dato, su una riga a sé; il confronto con la baseline,
come campione di una sola esecuzione per caso; le asserzioni non passate, con
la prova; le near-miss; i conteggi grezzi e il delta; le asserzioni che non
distinguono; il consumo.

La guida dello standard (https://agentskills.io/skill-creation/
evaluating-skills) dice che nelle prime iterazioni, con pochi casi e una sola
esecuzione, contano i conteggi grezzi e il delta: la tabella stampa quelli, e
ogni confronto dice che è un campione.

Riceve gli oggetti di lib_controlla_prove.py (Iterazione, Prova, NearMiss) e
non li importa, per non girare in tondo: quel modulo importa questo. Di qui
vengono baseline() e verdetto(), che lib_controlla_prove.py ridà ai suoi
chiamanti. Non è un modulo da eseguire: nessun bit di esecuzione.
"""
from __future__ import annotations

from typing import Dict, List, Optional

SEMPRE_PASSATE = ("La guida dello standard: «Remove or replace assertions "
                  "that always pass in both configurations.»")
# Una sola esecuzione per caso, come fa un partecipante: un campione, non una
# misura; l'output lo dice a ogni confronto.
CAMPIONE = "una sola esecuzione per caso"
ORDINE_STAMPA = ("without_skill", "old_skill", "with_skill")
# Di un passo negato si stampa al più questo: il dato è che c'è stato.
LIMITE_PASSO = 80


def baseline(configurazioni: object) -> Optional[str]:
    """La baseline dello standard: la versione precedente, se c'è."""
    for nome in ("old_skill", "without_skill"):
        if nome in configurazioni:
            return nome
    return None


def verdetto(a: int, b: int) -> str:
    """Le parole del confronto fra due conteggi."""
    if a > b:
        return "confermata"
    if a == b:
        return "non distinguibile"
    return "non confermata in questa misura"


def _decimale(valore: float, cifre: int) -> str:
    return f"{valore:.{cifre}f}".replace(".", ",")


def _con_segno(valore: float, cifre: int) -> str:
    return f"{valore:+.{cifre}f}".replace(".", ",")


def _quanti(numero: int, uno: str, molti: str) -> str:
    """«1 turno», «2 turni», «0 turni»: il nome si accorda con il numero."""
    return f"{numero} {uno if numero == 1 else molti}"


def _skill_chiamata(esec, skill: str) -> str:
    altre = sorted({nome for nome in esec.chiamate_skill if nome != skill})
    if skill in esec.chiamate_skill:
        stato = "sì"
        if not esec.chiamata_riuscita(skill):
            stato = ("sì, ma negata dal permesso"
                     if skill in esec.chiamate_negate
                     else "sì, ma respinta con un errore")
        return stato + (f" (anche: {', '.join(altre)})" if altre else "")
    return "no" + (f" (altre: {', '.join(altre)})" if altre else "")


def _consumo(turni: float, token: float, secondi: float, segmenti: int = 1,
             token_usage: Optional[float] = None) -> str:
    pezzi = f" in {segmenti} segmenti" if segmenti > 1 else ""
    altri = ""
    if token_usage is not None and token_usage != token:
        altri = f" (usage: {int(token_usage)})"
    return (f"{_quanti(int(turni), 'turno', 'turni')}{pezzi}, "
            f"{int(token)} token{altri}, {_decimale(secondi, 1)} s")


def _consumo_di(esec) -> str:
    fine = "; local_command nel result" if esec.locale else ""
    return _consumo(esec.turni, esec.token_totali, esec.secondi, esec.segmenti,
                    esec.token_usage) + fine


def _passo_negato(voce: object) -> str:
    """Un permission_denial in poche parole: lo strumento e la prima riga del
    suo comando, o il file, o la skill, se ci sono."""
    if not isinstance(voce, dict):
        return str(voce)
    nome = str(voce.get("tool_name", "uno strumento"))
    ingresso = voce.get("tool_input")
    if not isinstance(ingresso, dict):
        return nome
    for chiave in ("command", "file_path", "skill"):
        testo = ingresso.get(chiave)
        righe = testo.strip().splitlines() if isinstance(testo, str) else []
        if righe:
            taglio = "…" if len(righe[0]) > LIMITE_PASSO else ""
            return f"{nome} «{righe[0][:LIMITE_PASSO]}{taglio}»"
    return nome


def _riga_negati(chi: str, esec) -> Optional[str]:
    """I passi che il permesso ha negato, come dato, su una riga a sé: la riga
    dell'esecuzione resta com'è, e chi legge vede che cosa non è girato."""
    if esec is None or not esec.negati:
        return None
    return (f"(dato) {chi}: {_quanti(len(esec.negati), 'passo', 'passi')} "
            f"{'negato' if len(esec.negati) == 1 else 'negati'} dal permesso: "
            + "; ".join(_passo_negato(voce) for voce in esec.negati))


def _riga_prova(prova, skill: str) -> str:
    nome = prova.configurazione
    esec = prova.esec
    if esec is None:
        return f"{nome}: manca lo stream (outputs/stream.jsonl)"
    if not esec.completa:
        return f"{nome}: incompleta: lo stream non ha un risultato"
    chiamata = f"Skill chiamata: {_skill_chiamata(esec, skill)}"
    if prova.grading is None:
        return (f"{nome}: finita con un errore: {esec.testo[:200]}; "
                f"{chiamata}; {_consumo_di(esec)}")
    summary = prova.grading["summary"]
    totale = _quanti(summary["total"], "asserzione", "asserzioni")
    return (f"{nome}: {chiamata}; {summary['passed']} su {totale}; "
            f"{_consumo_di(esec)}")


def _riga_confronto(prove: List) -> Optional[str]:
    """with_skill contro la baseline, su una sola esecuzione per caso. Il nome
    si accorda con il secondo conteggio, quello che ha accanto."""
    per_conf = {prova.configurazione: prova for prova in prove}
    base = baseline(per_conf)
    con = per_conf.get("with_skill")
    if con is None or base is None:
        return None
    voti_con, voti_base = con.grading, per_conf[base].grading
    if voti_con is None or voti_base is None:
        return f"with_skill e {base} non si confrontano: una non è riuscita"
    if not voti_con["summary"]["total"] or not voti_base["summary"]["total"]:
        return f"with_skill e {base}: nessuna asserzione giudicata"
    a, b = voti_con["summary"]["passed"], voti_base["summary"]["passed"]
    passate = "asserzione passata" if b == 1 else "asserzioni passate"
    return (f"with_skill {a}, {base} {b} {passate}: {verdetto(a, b)} "
            f"({CAMPIONE})")


def _stampa_dettagli(prove: List) -> None:
    """Che cosa non è passato, con la prova; che cosa resta a una persona."""
    for prova in prove:
        for voce in (prova.grading or {}).get("assertion_results", []):
            if voce["passed"] is False:
                print(f"    non passata in {prova.configurazione}: "
                      f"«{voce['text']}»: {voce['evidence']}")
            elif voce["passed"] is None:
                print(f"    da valutare a mano in {prova.configurazione}: "
                      f"«{voce['text']}»")


def _riga_near_miss(vicina, skill: str) -> str:
    inizio = f"near-miss {vicina.k}"
    esec = vicina.esec
    if esec is None:
        return f"{inizio}: manca lo stream (outputs/stream.jsonl)"
    if not esec.completa:
        return f"{inizio}: incompleta: lo stream non ha un risultato"
    pezzi = [f"Skill chiamata: {_skill_chiamata(esec, skill)}"]
    if vicina.should_trigger is not None:
        pezzi.append("dovrebbe attivarla: "
                     + ("sì" if vicina.should_trigger else "no"))
    pezzi.append(_consumo_di(esec))
    if vicina.query:
        pezzi.append(f"«{vicina.query}»")
    return f"{inizio}: " + "; ".join(pezzi)


def _stampa_conteggi(iterazione) -> None:
    conteggi: Dict[str, List[int]] = {}
    for prova in iterazione.prove:
        if prova.grading is not None:
            somma = conteggi.setdefault(prova.configurazione, [0, 0])
            somma[0] += prova.grading["summary"]["passed"]
            somma[1] += prova.grading["summary"]["total"]
    if conteggi:
        print("  Conteggi: " + "; ".join(
            f"{nome} {conteggi[nome][0]} su {conteggi[nome][1]}"
            for nome in ORDINE_STAMPA + tuple(
                n for n in sorted(conteggi) if n not in ORDINE_STAMPA)
            if nome in conteggi))
    base = baseline(conteggi)
    delta = iterazione.benchmark["run_summary"]["delta"]
    if not base or "with_skill" not in conteggi:
        return
    if delta["time_seconds"] is None:
        print("  Delta: non si calcola: i casi riusciti non sono gli stessi "
              f"in with_skill e {base}.")
    else:
        tasso = ("non calcolabile" if delta["pass_rate"] is None
                 else _con_segno(delta["pass_rate"], 3))
        print(f"  Delta, with_skill meno {base}: pass rate {tasso}; tempo "
              f"{_con_segno(delta['time_seconds'], 1)} s; token "
              f"{_con_segno(delta['tokens'], 0)}")


def _stampa_sempre(prove: List) -> None:
    """Le asserzioni che non distinguono: sempre passate o sempre fallite in
    entrambe le configurazioni."""
    esiti: Dict[str, Dict[str, List[bool]]] = {}
    for prova in prove:
        for voce in (prova.grading or {}).get("assertion_results", []):
            if voce["passed"] is not None:
                esiti.setdefault(voce["text"], {}).setdefault(
                    prova.configurazione, []).append(voce["passed"])
    base = baseline({prova.configurazione for prova in prove})
    passano: List[str] = []
    falliscono: List[str] = []
    for testo, per_conf in esiti.items():
        if base in per_conf and "with_skill" in per_conf:
            tutti = per_conf[base] + per_conf["with_skill"]
            if all(tutti):
                passano.append(f"«{testo}»")
            elif not any(tutti):
                falliscono.append(f"«{testo}»")
    if passano:
        print("  Passano sempre in entrambe le configurazioni: "
              f"{'; '.join(passano)}. {SEMPRE_PASSATE}")
    if falliscono:
        print("  Falliscono sempre in entrambe le configurazioni: "
              f"{'; '.join(falliscono)}.")


def _stampa_consumo(iterazione) -> None:
    fatte = [prova.esec for prova in iterazione.prove
             if prova.configurazione != "old_skill" and prova.esec is not None
             and prova.esec.completa]
    fatte += [vicina.esec for vicina in iterazione.near_miss
              if vicina.esec is not None and vicina.esec.completa]
    print("  Consumo, senza le esecuzioni riusate: "
          f"{_quanti(len(fatte), 'chiamata', 'chiamate')}, "
          + _consumo(sum(e.turni for e in fatte),
                     sum(e.token_totali for e in fatte),
                     sum(e.secondi for e in fatte)))


def stampa_iterazione(iterazione, skill: str) -> None:
    """La tabella di una Iterazione su STDOUT."""
    print(f"Iterazione {iterazione.numero}")
    ident_visti = sorted({prova.eval_id for prova in iterazione.prove})
    for ident in ident_visti:
        prove = [p for p in iterazione.prove if p.eval_id == ident]
        print(f"  eval-{ident}")
        for prova in prove:
            print(f"    {_riga_prova(prova, skill)}")
            negati = _riga_negati(prova.configurazione, prova.esec)
            if negati:
                print(f"    {negati}")
        confronto = _riga_confronto(prove)
        if confronto:
            print(f"    {confronto}")
        _stampa_dettagli(prove)
    for vicina in iterazione.near_miss:
        print(f"  {_riga_near_miss(vicina, skill)}")
        negati = _riga_negati(f"near-miss {vicina.k}", vicina.esec)
        if negati:
            print(f"  {negati}")
    _stampa_conteggi(iterazione)
    _stampa_sempre(iterazione.prove)
    _stampa_consumo(iterazione)
