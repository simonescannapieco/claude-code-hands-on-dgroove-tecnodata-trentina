#!/bin/bash
#
# test_lib_controlla_prove.sh -- le prove di tools/lib_controlla_prove.py, su
# stream costruiti qui, in una cartella temporanea: hanno la forma di quelli
# di `claude -p --output-format stream-json --verbose`, ma sono finti, e
# nessuno è una risposta di Claude. Provano:
#   - leggi_stream: due risultati sommati, una chiamata ripetuta in un'altra
#     riga contata una volta, nessun risultato (completa falso), una riga
#     rovinata e gli altri illeggibili (Problema, mai un conteggio più
#     piccolo), una chiamata a un'altra skill;
#   - timing, giudica (una prova vuota è un Problema; senza giudice «da
#     valutare a mano», fuori dai conti), leggi_evals, leggi_query,
#     riepilogo (i numeri fatti a mano), scrivi_json, verdetto;
#   - esamina: che cosa scrive, che cosa stampa, che un grading.json vecchio
#     lo ignora e lo sovrascrive, che con scrivi falso non scrive niente;
#   - manca_per_finire, per ogni pezzo che manca; reperti, per ogni garanzia;
#   - principale, e i comandi «casi» ed «esito» di tools/prove_skill_casi.py.
#
# Uso:    tests/test_lib_controlla_prove.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3)
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly LIB="${REPO}/tools/lib_controlla_prove.py"
readonly CASI="${REPO}/tools/prove_skill_casi.py"
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue il codice Python letto su STDIN con il pilota; RC e OUT.
py() {
  OUT="$(PN_TMP="${TMP}" PN_TOOLS="${REPO}/tools" \
    python3 -B -I "${TMP}/pilota.py" 2>&1)"
  RC=$?
}

# Uscita attesa E parole attese (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Uscita attesa E parole assenti (RU-01.T5).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect_no() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (c'è «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Il pilota: importa il modulo, costruisce gli stream finti, esegue il codice
# della prova letto su STDIN.
scrivi_pilota() {
  cat > "${TMP}/pilota.py" <<'PY'
"""Il pilota delle prove: tutti gli stream che costruisce sono finti."""
import json
import os
import shutil
import sys
import tempfile

TMP = os.environ["PN_TMP"]
sys.path.insert(0, os.environ["PN_TOOLS"])
import lib_controlla_prove as prove  # noqa: E402

SKILL = "prova-skill"


def nuova():
    return tempfile.mkdtemp(dir=TMP)


def init(skills=(SKILL, "code-review")):
    return {"type": "system", "subtype": "init", "skills": list(skills)}


def chiama(nome, ingresso, ident):
    return {"type": "assistant", "message": {"content": [
        {"type": "tool_use", "id": ident, "name": nome, "input": ingresso}]}}


def skill_usata(nome=SKILL, ident="t-skill"):
    return chiama("Skill", {"skill": nome}, ident)


def respinta(ident="t-skill"):
    """Il tool_result con is_error di una chiamata che lo strumento respinge."""
    return {"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": ident, "is_error": True,
         "content": "non si può invocare"}]}}


def risultato(testo="ok", turni=1, ms=1000, usage=(10, 20, 30, 40),
              errore=False, negati=()):
    return {"type": "result", "subtype": "success", "is_error": errore,
            "num_turns": turni, "duration_ms": ms, "result": testo,
            "permission_denials": list(negati),
            "usage": {"input_tokens": usage[0],
                      "cache_creation_input_tokens": usage[1],
                      "cache_read_input_tokens": usage[2],
                      "output_tokens": usage[3]}}


def stream(percorso, *righe):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        for riga in righe:
            testo = riga if isinstance(riga, str) else json.dumps(riga)
            fh.write(testo + "\n")
    return percorso


def tentativo(funzione, *argomenti, **nominati):
    """Stampa «PROBLEMA: …» se la funzione solleva Problema."""
    try:
        print("VALORE:", funzione(*argomenti, **nominati))
    except prove.Problema as exc:
        print("PROBLEMA:", exc)


def evals_di(ws, ids=(1, 2, 3), skill=SKILL, assertions=("A", "B", "Z", "C")):
    cartella = os.path.join(ws, ".claude", "skills", skill)
    os.makedirs(os.path.join(cartella, "evals"), exist_ok=True)
    dati = {"skill_name": skill, "evals": [
        {"id": i, "prompt": f"richiesta {i}", "expected_output": "x",
         "files": [], "assertions": list(assertions)} for i in ids]}
    with open(os.path.join(cartella, "evals", "evals.json"), "w",
              encoding="utf-8") as fh:
        json.dump(dati, fh)
    with open(os.path.join(cartella, "evals", "eval_queries.json"), "w",
              encoding="utf-8") as fh:
        json.dump([{"query": "una richiesta vicina",
                    "should_trigger": False}], fh)
    return cartella


# I giudici delle prove: A passa sempre, B solo con la skill, Z mai; C non
# ha giudice.
def _cerca(parola):
    def giudice(esec, _contesto):
        return parola in esec.testo, f"la risposta è «{esec.testo}»"
    return giudice


GIUDICI = {"A": _cerca("PASSA-A"), "B": _cerca("PASSA-B"),
           "Z": _cerca("MAI-QUESTA")}


def braccio(ws, n, ident, conf, skill=SKILL):
    return os.path.join(ws, f"{skill}-workspace", f"iteration-{n}",
                        f"eval-{ident}", conf)


def esegui_baseline(ws, n, ident, conf="without_skill", skill=SKILL):
    return stream(os.path.join(braccio(ws, n, ident, conf, skill), "outputs",
                               "stream.jsonl"),
                  init(("code-review",)),
                  risultato("PASSA-A", 1, 1000, (10, 20, 30, 40)))


def esegui_con(ws, n, ident, conf="with_skill", skill=SKILL):
    return stream(os.path.join(braccio(ws, n, ident, conf, skill), "outputs",
                               "stream.jsonl"),
                  init(), skill_usata(skill),
                  risultato("PASSA-A PASSA-B", 2, 2000, (20, 40, 60, 80)))


def esegui_vecchia(ws, n, ident, skill=SKILL):
    """old_skill: la versione di prima, che passa soltanto A."""
    return stream(os.path.join(braccio(ws, n, ident, "old_skill", skill),
                               "outputs", "stream.jsonl"),
                  init(), skill_usata(skill),
                  risultato("PASSA-A", 1, 1000, (10, 20, 30, 40)))


def near_miss(ws, n, k=1, chiamata=False, skill=SKILL):
    righe = [init()]
    if chiamata:
        righe.append(skill_usata(skill))
    righe.append(risultato("niente skill", 1, 500, (1, 2, 3, 4)))
    return stream(os.path.join(ws, f"{skill}-workspace", f"iteration-{n}",
                               f"near-miss-{k}", "with_skill", "outputs",
                               "stream.jsonl"), *righe)


def fotografia(ws, n, testo, skill=SKILL):
    cartella = os.path.join(ws, f"{skill}-workspace", f"iteration-{n}",
                            "skill-snapshot")
    os.makedirs(cartella, exist_ok=True)
    with open(os.path.join(cartella, "SKILL.md"), "w", encoding="utf-8") as fh:
        fh.write(testo)


def commenti(ws, dati, skill=SKILL):
    percorso = os.path.join(ws, f"{skill}-workspace", "iteration-1",
                            "feedback.json")
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(dati if isinstance(dati, str) else json.dumps(dati))


def tutto(ws, ids=(1, 2, 3)):
    """Uno spazio di lavoro con tutto ciò che serve per «fatto»."""
    evals_di(ws, ids)
    for ident in ids:
        esegui_baseline(ws, 1, ident)
        esegui_con(ws, 1, ident)
        esegui_vecchia(ws, 2, ident)
        esegui_con(ws, 2, ident)
    near_miss(ws, 1)
    near_miss(ws, 2)
    fotografia(ws, 1, "v1")
    fotografia(ws, 2, "v2")
    commenti(ws, {f"eval-{i}": "" for i in ids})


def manca(ws):
    esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
    print("---")
    for riga in prove.manca_per_finire(esame, ws, SKILL):
        print("MANCA:", riga)


exec(compile(sys.stdin.read(), "<prova>", "exec"))
PY
}

# --- leggi_stream ----------------------------------------------------------

test_leggi_stream() {
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl",
    init(), skill_usata(), chiama("Bash", {"command": "ls"}, "t2"),
    risultato("la risposta", 4, 2500, (1, 2, 3, 4),
              negati=[{"tool_name": "Bash"}])))
print(e.init_skills, e.chiamate_skill, e.testo)
print([tuple(s) for s in e.strumenti])
print(e.turni, e.duration_ms, e.secondi, e.token_totali, e.segmenti)
print(e.negati, e.errore, e.completa, os.path.basename(e.cartella) != "")
PY
  expect 'uno stream: i campi' 0 "['prova-skill', 'code-review']" \
    "['prova-skill'] la risposta" "('Bash', {'command': 'ls'})" \
    "('Skill', {'skill': 'prova-skill'})" '4 2500 2.5 10 1' \
    "[{'tool_name': 'Bash'}] False True True"
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(),
    risultato("primo", 2, 1000, (1, 2, 3, 4), negati=[{"a": 1}]),
    risultato("ultimo", 3, 2000, (10, 20, 30, 40), negati=[{"b": 2}])))
print(e.turni, e.duration_ms, e.secondi, e.token_totali, e.segmenti)
print(e.testo, e.negati)
PY
  expect 'due risultati: si sommano, il testo è dell ultimo' 0 \
    '5 3000 3.0 110 2' "ultimo [{'a': 1}, {'b': 2}]"
  py <<'PY'
d = nuova()
ripetuta = skill_usata()
altra = dict(ripetuta)
altra["type"] = "user"
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), ripetuta, altra,
    {"type": "transcript", "message": ripetuta["message"]},
    skill_usata(ident="t-skill"),
    {"type": "user", "message": {"content": [
        {"type": "tool_use", "id": "t-solo", "name": "Skill",
         "input": {"skill": "fantasma"}}]}},
    risultato()))
print(e.chiamate_skill, len(e.strumenti))
PY
  expect 'una chiamata ripetuta conta una volta, solo da assistant' 0 \
    "['prova-skill'] 1"
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), skill_usata()))
print(e.completa, e.turni, e.testo == "", e.chiamate_skill)
e = prove.leggi_stream(stream(d + "/v.jsonl"))
print(e.completa, e.init_skills)
PY
  expect 'nessun risultato: completa falso' 0 "False 0 True ['prova-skill']" \
    'False None'
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(),
    skill_usata("code-review"), risultato()))
print(e.chiamate_skill)
e = prove.leggi_stream(stream(d + "/e.jsonl", init(), risultato(errore=True)))
print("errore", e.errore, e.completa)
e = prove.leggi_stream(stream(d + "/b.jsonl", init(), "", risultato(), ""))
print("vuote", e.completa)
e = prove.leggi_stream(stream(d + "/n.jsonl", {"type": "system",
    "subtype": "init"}, risultato()))
print("senza skills", e.init_skills)
s = risultato()
del s["result"]
s["subtype"] = "error_max_turns"
e = prove.leggi_stream(stream(d + "/t.jsonl", init(), s))
print("senza testo", repr(e.testo), e.errore)
PY
  expect 'altra skill, errore, righe vuote, campi che mancano' 0 \
    "['code-review']" 'errore True True' 'vuote True' 'senza skills None' \
    "senza testo '' True"
  # Una chiamata che il tool respinge, per esempio una skill spenta con
  # skillOverrides: tentata, ma il corpo non è arrivato.
  py <<'PY'
d = nuova()
respinta = {"type": "user", "message": {"content": [
    {"type": "tool_result", "tool_use_id": "t-skill", "is_error": True,
     "content": "<tool_use_error>Skill x is disabled</tool_use_error>"}]}}
buona = {"type": "user", "message": {"content": [
    {"type": "tool_result", "tool_use_id": "t-skill", "content": "ok"}]}}
e = prove.leggi_stream(stream(d + "/r.jsonl", init(), skill_usata(), respinta,
                              risultato()))
print("respinta", e.chiamate_skill, e.chiamate_respinte,
      e.chiamata_riuscita(SKILL))
e = prove.leggi_stream(stream(d + "/b.jsonl", init(), skill_usata(), buona,
                              risultato()))
print("buona", e.chiamate_respinte, e.chiamata_riuscita(SKILL))
s = risultato()
s["permission_denials"] = [{"tool_name": "Skill", "tool_use_id": "t-skill"}]
e = prove.leggi_stream(stream(d + "/n.jsonl", init(), skill_usata(), respinta,
                              s))
print("negata", e.chiamate_negate, e.chiamate_respinte,
      e.chiamata_riuscita(SKILL))
PY
  expect 'una chiamata respinta dal tool non è riuscita' 0 \
    "respinta ['prova-skill'] ['prova-skill'] False" 'buona [] True' \
    "negata ['prova-skill'] [] False"
}

test_leggi_stream_problemi() {
  py <<'PY'
d = nuova()
tentativo(prove.leggi_stream, stream(d + "/s.jsonl", init(), "{non json",
                                     risultato()))
PY
  expect 'una riga rovinata: Problema, con la riga' 0 'PROBLEMA:' 'riga 2'
  py <<'PY'
tentativo(prove.leggi_stream, nuova() + "/non-esiste.jsonl")
PY
  expect 'un file che non c è: Problema' 0 'PROBLEMA:' 'non-esiste.jsonl'
  py <<'PY'
d = nuova()
with open(d + "/b.jsonl", "wb") as fh:
    fh.write(b'\xff\xfe{}\n')
tentativo(prove.leggi_stream, d + "/b.jsonl")
PY
  expect 'un file che non è UTF-8: Problema' 0 'PROBLEMA:' 'b.jsonl'
  py <<'PY'
d = nuova()
tentativo(prove.leggi_stream, stream(d + "/s.jsonl", "[1, 2]"))
PY
  expect 'una riga che non è un oggetto: Problema' 0 'PROBLEMA:' 'riga 1'
  py <<'PY'
d = nuova()
s = risultato()
del s["usage"]
tentativo(prove.leggi_stream, stream(d + "/s.jsonl", s))
s = risultato()
s["usage"]["output_tokens"] = "molti"
tentativo(prove.leggi_stream, stream(d + "/t.jsonl", s))
s = risultato()
del s["num_turns"]
tentativo(prove.leggi_stream, stream(d + "/u.jsonl", s))
s = risultato()
s["duration_ms"] = True
tentativo(prove.leggi_stream, stream(d + "/w.jsonl", s))
for valore in ("NaN", "Infinity"):
    with open(d + "/x.jsonl", "w", encoding="utf-8") as fh:
        fh.write(json.dumps(risultato()).replace(
            '"duration_ms": 1000', f'"duration_ms": {valore}') + "\n")
    tentativo(prove.leggi_stream, d + "/x.jsonl")
PY
  expect_no 'i conteggi che non si leggono: Problema, mai zero' 0 'VALORE'
  expect 'i conteggi che non si leggono: i nomi' 0 'usage' 'output_tokens' \
    'num_turns' 'duration_ms'
  py <<'PY'
d = nuova()
tentativo(prove.leggi_stream, stream(d + "/s.jsonl",
    chiama("Skill", {"altro": 1}, "t1"), risultato()))
PY
  expect 'una chiamata Skill senza input.skill: Problema' 0 'PROBLEMA:' \
    'input.skill'
}

test_file_cambiati() {
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/stream.jsonl", init(), risultato()))
with open(d + "/file-cambiati.txt", "w", encoding="utf-8") as fh:
    fh.write(" M a.txt\n?? b.txt\n")
print(prove.file_cambiati(e))
os.remove(d + "/file-cambiati.txt")
tentativo(prove.file_cambiati, e)
PY
  expect 'file_cambiati legge il file; se manca è un Problema' 0 \
    "[' M a.txt', '?? b.txt']" 'PROBLEMA:' 'file-cambiati.txt'
}

# Una chiamata Skill negata dal permesso: tentata, non riuscita. La forma è
# quella degli stream veri di una skill con allowed-tools sotto dontAsk.
test_chiamata_negata() {
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), skill_usata(),
    risultato("non ci sono riuscito", negati=[
        {"tool_name": "Skill", "tool_use_id": "t-skill",
         "tool_input": {"skill": SKILL}}])))
print("negata", e.chiamate_skill, e.chiamate_negate,
      e.chiamata_riuscita(SKILL))
e = prove.leggi_stream(stream(d + "/r.jsonl", init(),
    skill_usata(ident="t-1"), skill_usata(ident="t-2"),
    risultato("alla seconda sì", negati=[
        {"tool_name": "Skill", "tool_use_id": "t-1"}])))
print("riprova", e.chiamate_skill, e.chiamate_negate,
      e.chiamata_riuscita(SKILL))
e = prove.leggi_stream(stream(d + "/a.jsonl", init(),
    skill_usata(), chiama("Bash", {"command": "x"}, "t-b"),
    risultato("ok", negati=[{"tool_name": "Bash", "tool_use_id": "t-b"}])))
print("altra", e.chiamate_skill, e.chiamate_negate, e.chiamata_riuscita(SKILL))
e = prove.leggi_stream(stream(d + "/n.jsonl", init(), risultato("ok")))
print("nessuna", e.chiamata_riuscita(SKILL))
PY
  expect 'una chiamata negata: tentata, non riuscita' 0 \
    "negata ['prova-skill'] ['prova-skill'] False"
  expect 'negata e poi riuscita: riuscita' 0 \
    "riprova ['prova-skill', 'prova-skill'] ['prova-skill'] True"
  expect 'un altro strumento negato non conta' 0 \
    "altra ['prova-skill'] [] True" 'nessuna False'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(),
       risultato("niente", negati=[{"tool_name": "Skill",
                                    "tool_use_id": "t-skill"}]))
near = os.path.join(ws, SKILL + "-workspace", "iteration-1", "near-miss-1",
                    "with_skill", "outputs", "stream.jsonl")
stream(near, init(), skill_usata(),
       risultato("niente", negati=[{"tool_name": "Skill",
                                    "tool_use_id": "t-skill"}]))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
for riga in prove.reperti(esame, SKILL):
    print("REPERTO:", riga)
PY
  expect 'la tabella dice che è negata, non «sì»' 0 \
    'with_skill: Skill chiamata: sì, ma negata dal permesso' \
    'near-miss 1: Skill chiamata: sì, ma negata dal permesso'
  expect 'una chiamata negata è un reperto, e dice che cosa fare' 0 \
    'REPERTO: iterazione 1, eval-1, with_skill: la chiamata Skill a '\
'prova-skill è negata dal permesso' 'Skill(prova-skill)' \
    'REPERTO: iterazione 1, near-miss 1:'
}

# Il dato di modelUsage, e un result con local_command.
test_altri_token() {
  py <<'PY'
d = nuova()
s = risultato("r", 1, 1000, (10, 20, 30, 40))
s["modelUsage"] = {"m": {"inputTokens": 10, "outputTokens": 40,
                         "cacheReadInputTokens": 500,
                         "cacheCreationInputTokens": 20}}
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), s))
print("modelli", e.token_totali, e.token_usage, e.token_modelli, e.locale)
print("timing", prove.timing(e)["total_tokens"])
t = risultato("r", 0, 90, (0, 0, 0, 0))
t["local_command"] = {"name": "x"}
t["modelUsage"] = {}
e = prove.leggi_stream(stream(d + "/t.jsonl", init(), t))
print("locale", e.token_totali, e.token_modelli, e.locale)
u = risultato("r", 1, 1000, (10, 20, 30, 40))
u["modelUsage"] = {"m": "non un oggetto"}
e = prove.leggi_stream(stream(d + "/u.jsonl", init(), u))
print("strano", e.token_totali, e.token_modelli)
e = prove.leggi_stream(stream(d + "/v.jsonl", init()))
print("vuoto", e.token_modelli, e.locale)
PY
  # Tutto l'albero dei subagent: modelUsage, dove c'è; usage altrimenti.
  expect 'i token: modelUsage se c è, altrimenti usage' 0 \
    'modelli 570 100 570 False' 'timing 570' 'locale 0 None True' \
    'strano 100 None' 'vuoto None False'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
s = risultato("PASSA-A", 2, 2000, (10, 20, 30, 40))
s["modelUsage"] = {"m": {"inputTokens": 500}}
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)), s)
u = risultato("PASSA-A", 2, 2000, (10, 20, 30, 40))
u["modelUsage"] = {"m": {"inputTokens": 100}}
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"), init(), skill_usata(), u)
t = risultato("x", 0, 90, (0, 0, 0, 0))
t["local_command"] = {}
stream(os.path.join(braccio(ws, 1, 1, "altra"), "outputs", "stream.jsonl"),
       init(), t)
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'la tabella: usage accanto, quando è diverso' 0 \
    '500 token (usage: 100)' '100 token, ' 'local_command nel result'
  expect_no 'la tabella: usage uguale non si stampa' 0 \
    'usage: 500'
}

# --- timing, giudica --------------------------------------------------------

test_timing() {
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(),
    risultato("a", 1, 1500, (1, 2, 3, 4)),
    risultato("b", 1, 500, (5, 5, 5, 5))))
print(json.dumps(prove.timing(e), sort_keys=True))
n = prove.leggi_stream(stream(d + "/n.jsonl", init()))
tentativo(prove.timing, n)
PY
  expect 'timing: la forma dello standard; senza risultato un Problema' 0 \
    '{"duration_ms": 2000, "total_tokens": 30}' 'PROBLEMA:'
}

test_giudica() {
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), risultato("PASSA-A")))
visti = []
def conta(esec, contesto):
    visti.append(contesto)
    return True, "ok"
g = prove.giudica(["A", "B", "C", "D"],
                  {"A": _cerca("PASSA-A"), "B": _cerca("NO"), "D": conta},
                  e, {"chiave": 1})
print(json.dumps(g, ensure_ascii=False))
print(visti)
PY
  expect 'giudica: la forma dello standard, il conto, il contesto' 0 \
    '"text": "A", "passed": true' '"text": "B", "passed": false' \
    '"text": "C", "passed": null, "evidence": "da valutare a mano"' \
    '"summary": {"passed": 2, "failed": 1, "total": 3, "pass_rate": 0.6667}' \
    "[{'chiave': 1}]"
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), risultato()))
tentativo(prove.giudica, ["A"], {"A": lambda _e, _c: (True, "")}, e, None)
tentativo(prove.giudica, ["A"], {"A": lambda _e, _c: (False, "   ")}, e, None)
tentativo(prove.giudica, ["A"], {"A": lambda _e, _c: (1, "x")}, e, None)
tentativo(prove.giudica, ["A"], {"A": lambda _e, _c: "x"}, e, None)
def rotto(_e, _c):
    raise KeyError("manca")
tentativo(prove.giudica, ["A"], {"A": rotto}, e, None)
PY
  expect_no 'un giudice che non va: sempre un Problema' 0 'VALORE'
  expect 'un giudice che non va: i motivi' 0 'senza evidenza' 'vero o falso' \
    'KeyError'
  py <<'PY'
d = nuova()
e = prove.leggi_stream(stream(d + "/s.jsonl", init(), risultato()))
g = prove.giudica(["C"], {}, e, None)
print(json.dumps(g["summary"]))
g = prove.giudica([], {}, e, None)
print(json.dumps(g))
PY
  expect 'nessuna asserzione giudicata: nessun tasso' 0 \
    '{"passed": 0, "failed": 0, "total": 0, "pass_rate": null}' \
    '{"assertion_results": [], "summary"'
}

# --- evals, query -----------------------------------------------------------

test_leggi_evals() {
  py <<'PY'
ws = nuova()
c = evals_di(ws)
dati = prove.leggi_evals(c)
print(dati["skill_name"], [x["id"] for x in dati["evals"]])
print(prove.leggi_query(c))
PY
  expect 'evals e query che vanno bene' 0 'prova-skill [1, 2, 3]' \
    "[{'query': 'una richiesta vicina', 'should_trigger': False}]"
  py <<'PY'
ws = nuova()
c = evals_di(ws)
percorso = c + "/evals/evals.json"
def prova(dati):
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(dati if isinstance(dati, str) else json.dumps(dati))
    tentativo(prove.leggi_evals, c)
buono = {"id": 1, "prompt": "p", "expected_output": "e"}
prova({"evals": [buono]})
prova({"skill_name": "altra", "evals": [buono]})
prova({"skill_name": SKILL, "evals": []})
prova({"skill_name": SKILL})
prova({"skill_name": SKILL, "evals": [dict(buono, id="1")]})
prova({"skill_name": SKILL, "evals": [dict(buono, id=True)]})
prova({"skill_name": SKILL, "evals": [dict(buono, id=-1)]})
prova({"skill_name": SKILL, "evals": [buono, buono]})
prova({"skill_name": SKILL, "evals": [dict(buono, prompt="")]})
prova({"skill_name": SKILL, "evals": [dict(buono, expected_output=" ")]})
prova({"skill_name": SKILL, "evals": [dict(buono, files="a")]})
prova({"skill_name": SKILL, "evals": [dict(buono, assertions=[1])]})
prova({"skill_name": SKILL, "evals": ["x"]})
prova("{non json")
prova("[]")
os.remove(percorso)
tentativo(prove.leggi_evals, c)
PY
  expect_no 'evals che non vanno: sempre un Problema' 0 'VALORE'
  expect 'evals che non vanno: i motivi' 0 'skill_name' 'evals' '«id»' \
    'ripetuto' '«prompt»' '«expected_output»' '«files»' '«assertions»' \
    'non si legge'
  py <<'PY'
ws = nuova()
c = evals_di(ws)
percorso = c + "/evals/eval_queries.json"
def prova(dati):
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(dati if isinstance(dati, str) else json.dumps(dati))
    tentativo(prove.leggi_query, c)
prova([])
prova({"query": "x"})
prova([{"query": "", "should_trigger": False}])
prova([{"query": "x"}])
prova([{"query": "x", "should_trigger": "no"}])
prova("{non json")
os.remove(percorso)
tentativo(prove.leggi_query, c)
PY
  expect_no 'query che non vanno: sempre un Problema' 0 'VALORE'
  expect 'query che non vanno: i motivi' 0 'eval_queries.json' \
    '«should_trigger»' '«query»'
}

# --- riepilogo, scrivi_json, verdetto ----------------------------------------

test_riepilogo() {
  py <<'PY'
def run(rate, ms, token):
    return ({"summary": {"pass_rate": rate}},
            {"duration_ms": ms, "total_tokens": token})
r = prove.riepilogo({"with_skill": [run(1.0, 10000, 100), run(0.5, 20000, 300)],
                     "without_skill": [run(0.5, 5000, 50), run(0.0, 5000, 50)]})
print(list(r), list(r["run_summary"]))
s = r["run_summary"]
print(s["with_skill"]["pass_rate"], s["with_skill"]["time_seconds"])
print(s["with_skill"]["tokens"])
print(s["without_skill"]["pass_rate"], s["without_skill"]["time_seconds"])
print(s["without_skill"]["tokens"], s["delta"])
PY
  expect 'riepilogo: i numeri fatti a mano' 0 \
    "['run_summary'] ['with_skill', 'without_skill', 'delta']" \
    "{'mean': 0.75, 'stddev': 0.3536} {'mean': 15.0, 'stddev': 7.0711}" \
    "{'mean': 200.0, 'stddev': 141.4214}" \
    "{'mean': 0.25, 'stddev': 0.3536} {'mean': 5.0, 'stddev': 0.0}" \
    "{'pass_rate': 0.5, 'time_seconds': 10.0, 'tokens': 150.0}"
  py <<'PY'
def run(rate, ms, token):
    return ({"summary": {"pass_rate": rate}},
            {"duration_ms": ms, "total_tokens": token})
r = prove.riepilogo({"old_skill": [run(0.25, 1000, 10)],
                     "without_skill": [run(0.0, 1000, 10)],
                     "with_skill": [run(0.75, 3000, 40)]})
print("base", r["run_summary"]["delta"])
print("uno", r["run_summary"]["with_skill"]["pass_rate"])
r = prove.riepilogo({"with_skill": [run(1.0, 1000, 10)]})
print("solo", r["run_summary"]["delta"])
r = prove.riepilogo({"with_skill": [run(None, 1000, 10), run(0.5, 1000, 10)],
                     "old_skill": [run(None, 1000, 10)]})
print("null", r["run_summary"]["with_skill"]["pass_rate"],
      r["run_summary"]["old_skill"]["pass_rate"],
      r["run_summary"]["delta"]["pass_rate"])
PY
  expect "riepilogo: la base, un'esecuzione, nessuna base, i tassi nulli" 0 \
    "base {'pass_rate': 0.5, 'time_seconds': 2.0, 'tokens': 30.0}" \
    "uno {'mean': 0.75, 'stddev': 0.0}" \
    "solo {'pass_rate': None, 'time_seconds': None, 'tokens': None}" \
    "null {'mean': 0.5, 'stddev': 0.0} {'mean': None, 'stddev': None} None"
}

test_scrivi_json_verdetto() {
  py <<'PY'
d = nuova()
prove.scrivi_json(d + "/x.json", {"zeta": "è", "alfa": [1]})
with open(d + "/x.json", "rb") as fh:
    print(repr(fh.read().decode("utf-8")))
tentativo(prove.scrivi_json, d + "/manca/x.json", {})
print(prove.verdetto(3, 1), "|", prove.verdetto(2, 2), "|",
      prove.verdetto(1, 3))
PY
  expect 'scrivi_json: la forma' 0 \
    "'{\\n  \"zeta\": \"è\",\\n  \"alfa\": [\\n    1\\n  ]\\n}\\n'" 'PROBLEMA:'
  expect 'verdetto: le tre parole' 0 \
    'confermata | non distinguibile | non confermata in questa misura'
}

# --- esamina ----------------------------------------------------------------

test_esamina_scrive() {
  py <<'PY'
ws = nuova()
tutto(ws)
base = os.path.join(ws, SKILL + "-workspace")
vecchio = os.path.join(base, "iteration-1", "eval-1", "with_skill",
                       "grading.json")
with open(vecchio, "w", encoding="utf-8") as fh:
    json.dump({"vecchio": True, "summary": {"passed": 99}}, fh)
with open(os.path.join(base, "iteration-1", "benchmark.json"), "w",
          encoding="utf-8") as fh:
    fh.write("{non è JSON")
with open(os.path.join(base, "iteration-1", "eval-2", "with_skill",
                       "timing.json"), "w", encoding="utf-8") as fh:
    fh.write("nemmeno questo")
esame = prove.esamina(ws, SKILL, GIUDICI, None, True)
print("---")
g = json.load(open(vecchio, encoding="utf-8"))
print("vecchio" in g, g["summary"])
t = json.load(open(os.path.join(os.path.dirname(vecchio), "timing.json"),
                   encoding="utf-8"))
print(t)
b = json.load(open(os.path.join(base, "iteration-1", "benchmark.json"),
                   encoding="utf-8"))
print(b["run_summary"]["delta"])
b2 = json.load(open(os.path.join(base, "iteration-2", "benchmark.json"),
                    encoding="utf-8"))
print(sorted(b2["run_summary"]))
print(open(os.path.join(os.path.dirname(vecchio), "outputs", "risposta.md"),
           encoding="utf-8").read())
print(open(os.path.join(base, "iteration-1", "near-miss-1", "with_skill",
                        "outputs", "risposta.md"), encoding="utf-8").read())
p = esame.prova(1, 1, "with_skill")
print(p.configurazione, p.esec.turni, p.grading["summary"]["passed"])
print(esame.prova(9, 1, "with_skill"), sorted(esame.iterazioni))
print(len(esame.iterazioni[1].prove), len(esame.iterazioni[1].near_miss))
print(esame.evals["skill_name"], esame.skill)
PY
  expect 'esamina scrive: grading e timing ricalcolati, il vecchio ignorato' 0 \
    "False {'passed': 2, 'failed': 1, 'total': 3, 'pass_rate': 0.6667}" \
    "{'total_tokens': 200, 'duration_ms': 2000}"
  expect 'esamina scrive: benchmark e risposta' 0 \
    "'pass_rate': 0.3333, 'time_seconds': 1.0, 'tokens': 100.0" \
    "['delta', 'old_skill', 'with_skill']" 'PASSA-A PASSA-B' 'niente skill'
  expect 'esamina restituisce: prova, iterazioni, near-miss, evals' 0 \
    'with_skill 2 2' 'None [1, 2]' '6 1' 'prova-skill prova-skill'
}

test_esamina_stampa() {
  py <<'PY'
ws = nuova()
tutto(ws)
near_miss(ws, 2, 2, chiamata=True)
stream(os.path.join(braccio(ws, 1, 2, "without_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata("code-review"), risultato("PASSA-A"))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'la tabella: le righe di ogni esecuzione' 0 'Iterazione 1' \
    'Iterazione 2' 'eval-1' \
    'without_skill: Skill chiamata: no; 1 su 3 asserzioni; 1 turno, '\
'100 token, 1,0 s' \
    'with_skill: Skill chiamata: sì; 2 su 3 asserzioni; 2 turni, '\
'200 token, 2,0 s' \
    'old_skill: Skill chiamata: sì; 1 su 3 asserzioni'
  expect 'la tabella: un altra skill è un dato' 0 \
    'Skill chiamata: no (altre: code-review)'
  expect "la tabella: il confronto, come campione di un'esecuzione" 0 \
    'with_skill 2, without_skill 1 asserzione passata: confermata '\
'(una sola esecuzione per caso)' \
    'with_skill 2, old_skill 1 asserzione passata: confermata'
  expect 'la tabella: che cosa non è passato, con la prova' 0 \
    'non passata in without_skill: «B»: la risposta è «PASSA-A»' \
    'non passata in with_skill: «Z»: la risposta è «PASSA-A PASSA-B»'
  expect 'la tabella: da valutare a mano, fuori dai conti' 0 \
    'da valutare a mano in with_skill: «C»'
  expect 'la tabella: i conteggi e il delta' 0 \
    'Conteggi: without_skill 3 su 9; with_skill 6 su 9' \
    'Delta, with_skill meno without_skill: pass rate +0,333; tempo +1,0 s; '\
'token +100' \
    'Delta, with_skill meno old_skill:'
  expect 'la tabella: la near-miss, chiamata o no' 0 \
    'near-miss 1: Skill chiamata: no; dovrebbe attivarla: no;' \
    'near-miss 2: Skill chiamata: sì;' '«una richiesta vicina»'
  expect 'la tabella: sempre passate, sempre fallite' 0 \
    'Passano sempre in entrambe le configurazioni: «A»' \
    'Remove or replace assertions that always pass in both configurations.' \
    'Falliscono sempre in entrambe le configurazioni: «Z»'
  expect 'la tabella: il consumo, senza le riusate' 0 \
    'Consumo, senza le esecuzioni riusate: 7 chiamate, 10 turni, 910 token, '\
'9,5 s' \
    'Consumo, senza le esecuzioni riusate: 5 chiamate, 8 turni, 620 token, '\
'7,0 s'
  expect_no 'la tabella: nessuna «smentita»' 0 'smentita'
  py <<'PY'
ws = nuova()
evals_di(ws)
esegui_con(ws, 1, 1)
esegui_baseline(ws, 1, 1)
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)),
       risultato("PASSA-A PASSA-B", 1, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
print("===")
ws = nuova()
evals_di(ws)
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs", "stream.jsonl"),
       init(), risultato("niente", 1, 1000, (10, 20, 30, 40)))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)),
       risultato("PASSA-A", 1, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'il confronto: pari e sotto' 0 'non distinguibile' \
    'non confermata in questa misura'
  expect_no 'nessuna «smentita», nemmeno quando la skill fa peggio' 0 \
    'smentita'
}

# La tabella si accorda con il numero: «1 turno», «1 asserzione», «1 chiamata».
# Nel confronto il nome si accorda con il secondo conteggio, quello accanto.
test_stampa_plurali() {
  py <<'PY'
ws = nuova()
evals_di(ws, (1,), assertions=("A",))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(), risultato("PASSA-A", 1, 1000, (10, 20, 30, 40)))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)),
       risultato("PASSA-A", 2, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'al singolare: un turno, una asserzione' 0 \
    'with_skill: Skill chiamata: sì; 1 su 1 asserzione; 1 turno, 100 token, '\
'1,0 s' \
    'with_skill 1, without_skill 1 asserzione passata: non distinguibile'
  expect 'al plurale: due turni' 0 \
    'without_skill: Skill chiamata: no; 1 su 1 asserzione; 2 turni, 100 token'
  expect_no 'mai «1 asserzioni» né «1 turni»' 0 '1 asserzioni' '1 turni'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,), assertions=("A", "B", "Z"))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(), risultato("PASSA-A", 0, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
print("===")
ws = nuova()
evals_di(ws, (1,), assertions=("A", "B", "Z"))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(), risultato("PASSA-A", 1, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
print("===")
ws = nuova()
evals_di(ws, (1,), assertions=("A", "B"))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(),
       risultato("PASSA-A PASSA-B", 1, 1000, (10, 20, 30, 40)))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)),
       risultato("niente", 1, 1000, (10, 20, 30, 40)))
stream(os.path.join(braccio(ws, 2, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(), risultato("niente", 1, 1000, (10, 20, 30, 40)))
stream(os.path.join(braccio(ws, 2, 1, "old_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(),
       risultato("PASSA-A PASSA-B", 1, 1000, (10, 20, 30, 40)))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'zero turni: il plurale' 0 '1 su 3 asserzioni; 0 turni, 100 token'
  expect 'una chiamata nel consumo: «1 chiamata»' 0 \
    'Consumo, senza le esecuzioni riusate: 1 chiamata, 1 turno, 100 token, '\
'1,0 s'
  expect 'due chiamate nel consumo: il plurale' 0 \
    'Consumo, senza le esecuzioni riusate: 2 chiamate, 2 turni, 200 token, '\
'2,0 s'
  expect 'il secondo conteggio a zero e a due: il plurale' 0 \
    'with_skill 2, without_skill 0 asserzioni passate: confermata' \
    'with_skill 0, old_skill 2 asserzioni passate: non confermata'
  expect_no 'nel consumo mai «1 chiamate»' 0 '1 chiamate'
}

# I passi che il permesso ha negato: una riga a sé, «(dato)», così che le altre
# restino com'erano; niente riga, se non ne ha negato nessuno.
test_dato_negati() {
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(),
       risultato("PASSA-A PASSA-B", 2, 2000, (20, 40, 60, 80), negati=[
           {"tool_name": "Bash", "tool_use_id": "t-1", "tool_input": {
               "command": "cd /tmp/x && cat > y <<'EOF'\nil testo\nEOF"}}]))
stream(os.path.join(ws, SKILL + "-workspace", "iteration-1", "near-miss-1",
                    "with_skill", "outputs", "stream.jsonl"),
       init(), risultato("niente", 1, 500, (1, 2, 3, 4), negati=[
           {"tool_name": "Bash", "tool_use_id": "t-2",
            "tool_input": {"command": "x" * 200}},
           {"tool_name": "Write", "tool_use_id": "t-3",
            "tool_input": {"file_path": "/tmp/x/y.cfg", "content": "il testo"}},
           {"tool_name": "Altro", "tool_use_id": "t-4"},
           "una voce strana"]))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  local atteso="(dato) with_skill: 1 passo negato dal permesso: "
  atteso+="Bash «cd /tmp/x && cat > y <<'EOF'»"
  expect 'un passo negato: il comando, la sua prima riga' 0 "${atteso}"
  local ottanta
  ottanta="$(printf 'x%.0s' {1..80})"
  atteso="(dato) near-miss 1: 4 passi negati dal permesso: "
  atteso+="Bash «${ottanta}…»; Write «/tmp/x/y.cfg»; Altro; una voce strana"
  expect 'più passi: ciascuno, un comando lungo tagliato' 0 "${atteso}"
  expect 'la riga dell esecuzione resta com era' 0 \
    'with_skill: Skill chiamata: sì; 2 su 3 asserzioni; 2 turni, 200 token, '\
'2,0 s'
  expect_no 'solo la prima riga del comando, niente contenuto' 0 'il testo' \
    "${ottanta}x"
  py <<'PY'
ws = nuova()
tutto(ws)
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect_no 'nessun passo negato: nessuna riga (dato)' 0 '(dato)' \
    'negato dal permesso'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"),
       init(), skill_usata(),
       risultato("niente", negati=[
           {"tool_name": "Skill", "tool_use_id": "t-skill",
            "tool_input": {"skill": SKILL}},
           {"tool_name": "Bash", "tool_use_id": "t-1",
            "tool_input": {"command": "   \n "}}]))
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'la skill negata si nomina; un comando vuoto, solo lo strumento' 0 \
    '(dato) with_skill: 2 passi negati dal permesso: Skill «prova-skill»; Bash'
}

test_esamina_bordi() {
  py <<'PY'
ws = nuova()
evals_di(ws)
esame = prove.esamina(ws, SKILL, GIUDICI, None, True)
print("iterazioni", esame.iterazioni)
PY
  expect 'nessuna prova ancora: nessun errore' 0 'iterazioni {}' \
    'Nessuna iterazione'
  py <<'PY'
ws = nuova()
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
PY
  expect 'senza evals.json: Problema' 0 'PROBLEMA:' 'evals.json'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
esegui_con(ws, 1, 7)
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
PY
  expect 'una eval che evals.json non ha: Problema' 0 'PROBLEMA:' 'eval-7'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
os.makedirs(os.path.join(ws, SKILL + "-workspace", "iteration-x"))
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
ws = nuova()
evals_di(ws, (1,))
os.makedirs(os.path.join(ws, SKILL + "-workspace", "iteration-1", "eval-a"))
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
ws = nuova()
evals_di(ws, (1,))
os.makedirs(os.path.join(ws, SKILL + "-workspace", "iteration-1",
                         "near-miss-x"))
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
PY
  expect_no 'una cartella che non si riconosce: Problema' 0 'VALORE'
  expect 'una cartella che non si riconosce: il nome' 0 'iteration-x' \
    'eval-a' 'near-miss-x'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs", "stream.jsonl"),
       init(), "{rovinata")
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
PY
  expect 'uno stream rovinato: Problema, non un conteggio più piccolo' 0 \
    'PROBLEMA:' 'riga 2'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
b = braccio(ws, 1, 1, "with_skill")
stream(os.path.join(b, "outputs", "stream.jsonl"), init(), skill_usata())
os.makedirs(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs"))
for nome in ("grading.json", "timing.json"):
    with open(os.path.join(b, nome), "w", encoding="utf-8") as fh:
        fh.write("vecchio")
esame = prove.esamina(ws, SKILL, GIUDICI, None, True)
print("---", esame.prova(1, 1, "with_skill").grading)
print(sorted(os.listdir(b)), esame.prova(1, 1, "without_skill").esec)
print(esame.iterazioni[1].benchmark["run_summary"]["delta"]["pass_rate"])
PY
  expect 'un esecuzione incompleta: non si giudica, il vecchio se ne va' 0 \
    'with_skill: incompleta' 'without_skill: manca lo stream' '--- None' \
    "['outputs'] None" 'None'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
b = braccio(ws, 1, 1, "with_skill")
stream(os.path.join(b, "outputs", "stream.jsonl"), init(),
       risultato("limite", 1, 10, (0, 0, 0, 0), errore=True))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---", esame.prova(1, 1, "with_skill").grading)
PY
  expect 'un esecuzione con un errore: non si giudica' 0 \
    'with_skill: finita con un errore' '--- None'
  py <<'PY'
ws = nuova()
tutto(ws, (1,))
prima = {}
for radice, _, nomi in os.walk(ws):
    for nome in nomi:
        p = os.path.join(radice, nome)
        prima[p] = open(p, "rb").read()
visti = []
def contesto_di(ident, conf):
    visti.append((ident, conf))
    return {"chi": conf}
def giudice(esec, contesto):
    return True, "per " + contesto["chi"]
prove.esamina(ws, SKILL, {"A": giudice}, contesto_di, False)
dopo = {}
for radice, _, nomi in os.walk(ws):
    for nome in nomi:
        p = os.path.join(radice, nome)
        dopo[p] = open(p, "rb").read()
print("---", prima == dopo)
print(sorted(set(visti)))
PY
  expect 'scrivi falso: niente di scritto; contesto_di arriva ai giudici' 0 \
    '--- True' "(1, 'old_skill'), (1, 'with_skill'), (1, 'without_skill')"
}

# Bordi trovati da chi ha riletto il modulo: ognuno farebbe dire al controllo
# qualcosa che le esecuzioni non dicono.
test_esamina_altri_bordi() {
  py <<'PY'
ws = nuova()
evals_di(ws, (1, 2, 3))
for ident in (1, 2, 3):
    esegui_con(ws, 1, ident)
esegui_baseline(ws, 1, 1)
esegui_baseline(ws, 1, 2)
stream(os.path.join(braccio(ws, 1, 3, "without_skill"), "outputs",
                    "stream.jsonl"),
       init(("code-review",)), risultato("limite", errore=True))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---", esame.iterazioni[1].benchmark["run_summary"]["delta"])
PY
  expect 'casi riusciti diversi: il delta è nullo, e la tabella lo dice' 0 \
    "--- {'pass_rate': None, 'time_seconds': None, 'tokens': None}" \
    'Delta: non si calcola'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
b = braccio(ws, 1, 1, "with_skill")
os.makedirs(os.path.join(b, "outputs"))
for nome in ("grading.json", "timing.json", "outputs/risposta.md"):
    with open(os.path.join(b, nome), "w", encoding="utf-8") as fh:
        fh.write('{"summary": {"passed": 2, "total": 2}}')
prove.esamina(ws, SKILL, GIUDICI, None, True)
print("---", sorted(os.listdir(b)), os.listdir(os.path.join(b, "outputs")))
PY
  expect 'lo stream sparito: i file vecchi se ne vanno' 0 "--- ['outputs'] []"
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
esegui_con(ws, 1, 1)
os.rename(os.path.join(ws, SKILL + "-workspace", "iteration-1", "eval-1"),
          os.path.join(ws, SKILL + "-workspace", "iteration-1", "eval-01"))
tentativo(prove.esamina, ws, SKILL, GIUDICI, None, False)
PY
  expect 'eval-01: un nome che non torna, Problema' 0 'PROBLEMA:' 'eval-01'
  py <<'PY'
ws = nuova()
tutto(ws, (1,))
def contesto_rotto(_ident, _conf):
    raise FileNotFoundError("verita.json")
tentativo(prove.esamina, ws, SKILL, GIUDICI, contesto_rotto, False)
PY
  expect 'un contesto_di che non riesce: Problema' 0 'PROBLEMA:' 'verita.json'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
near = near_miss(ws, 1)
with open(os.path.join(os.path.dirname(near), "prompt.txt"), "w",
          encoding="utf-8") as fh:
    fh.write("la richiesta di allora")
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'la near-miss: il prompt di allora, non quello di adesso' 0 \
    '«la richiesta di allora»'
  expect_no 'la near-miss: niente etichetta presa dal file di adesso' 0 \
    'dovrebbe attivarla' 'una richiesta vicina'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
near = near_miss(ws, 1)
with open(os.path.join(os.path.dirname(near), "prompt.txt"), "w",
          encoding="utf-8") as fh:
    fh.write("una richiesta vicina")
prove.esamina(ws, SKILL, GIUDICI, None, False)
PY
  expect 'la near-miss: lo stesso prompt, con la sua etichetta' 0 \
    'dovrebbe attivarla: no' '«una richiesta vicina»'
  py <<'PY'
ws = nuova()
tutto(ws)
percorso = os.path.join(ws, SKILL + "-workspace", "iteration-1",
                        "feedback.json")
with open(percorso, encoding="utf-8") as fh:
    testo = fh.read()
with open(percorso, "w", encoding="utf-8-sig") as fh:
    fh.write(testo)
c = os.path.join(ws, ".claude", "skills", SKILL, "evals", "evals.json")
with open(c, encoding="utf-8") as fh:
    testo = fh.read()
with open(c, "w", encoding="utf-8-sig") as fh:
    fh.write(testo)
manca(ws)
print("FINE")
PY
  expect_no 'evals.json e feedback.json con un BOM si leggono' 0 'MANCA:' \
    'BOM'
}

# --- manca_per_finire, reperti --------------------------------------------

test_manca_per_finire() {
  py <<'PY'
ws = nuova()
tutto(ws)
manca(ws)
print("FINE")
PY
  expect_no 'tutto c è: niente da fare' 0 'MANCA:'
  py <<'PY'
ws = nuova()
tutto(ws, (1, 2))
manca(ws)
PY
  expect 'meno di tre evals' 0 'MANCA: evals/evals.json ha 2 casi' 'almeno 3'
  py <<'PY'
ws = nuova()
tutto(ws, (1,))
manca(ws)
PY
  expect 'un solo caso: «1 caso»' 0 'MANCA: evals/evals.json ha 1 caso:'
  py <<'PY'
ws = nuova()
tutto(ws)
for n, ident, conf in ((1, 2, "without_skill"), (1, 3, "with_skill"),
                       (2, 1, "with_skill"), (2, 2, "old_skill")):
    shutil.rmtree(braccio(ws, n, ident, conf))
manca(ws)
PY
  expect 'ogni configurazione che manca' 0 \
    'MANCA: iterazione 1, eval-2: manca without_skill' \
    'MANCA: iterazione 1, eval-3: manca with_skill' \
    'MANCA: iterazione 2, eval-1: manca with_skill' \
    'MANCA: iterazione 2, eval-2: manca old_skill'
  py <<'PY'
ws = nuova()
tutto(ws)
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs", "stream.jsonl"),
       init(), skill_usata())
stream(os.path.join(braccio(ws, 2, 2, "with_skill"), "outputs", "stream.jsonl"),
       init(), risultato("limite", errore=True))
os.remove(os.path.join(braccio(ws, 2, 3, "old_skill"), "outputs",
                       "stream.jsonl"))
manca(ws)
PY
  expect 'incompleta, con un errore, senza lo stream' 0 \
    'MANCA: iterazione 1, eval-1, with_skill: incompleta' \
    'MANCA: iterazione 2, eval-2, with_skill: finita con un errore' \
    'MANCA: iterazione 2, eval-3: manca old_skill'
  py <<'PY'
ws = nuova()
tutto(ws)
shutil.rmtree(os.path.join(ws, SKILL + "-workspace", "iteration-1",
                           "near-miss-1"))
stream(os.path.join(ws, SKILL + "-workspace", "iteration-2", "near-miss-1",
                    "with_skill", "outputs", "stream.jsonl"), init())
manca(ws)
PY
  expect 'la near-miss nelle due iterazioni' 0 \
    'MANCA: iterazione 1: manca la near-miss' \
    'MANCA: iterazione 2: manca la near-miss'
  py <<'PY'
ws = nuova()
tutto(ws)
os.remove(os.path.join(ws, SKILL + "-workspace", "iteration-1",
                       "feedback.json"))
manca(ws)
ws = nuova()
tutto(ws)
commenti(ws, "{non json")
manca(ws)
ws = nuova()
tutto(ws)
commenti(ws, ["x"])
manca(ws)
ws = nuova()
tutto(ws)
commenti(ws, {"eval-1": "", "eval-3": 7})
manca(ws)
PY
  expect 'feedback.json, ogni difetto' 0 \
    'MANCA: iteration-1/feedback.json: manca' \
    'MANCA: iteration-1/feedback.json: non è JSON' \
    'MANCA: iteration-1/feedback.json: non è un oggetto' \
    'MANCA: iteration-1/feedback.json: manca la voce eval-2' \
    'MANCA: iteration-1/feedback.json: la voce eval-3 non è una stringa'
  py <<'PY'
ws = nuova()
tutto(ws)
shutil.rmtree(os.path.join(ws, SKILL + "-workspace", "iteration-1",
                           "skill-snapshot"))
manca(ws)
ws = nuova()
tutto(ws)
shutil.rmtree(os.path.join(ws, SKILL + "-workspace", "iteration-2",
                           "skill-snapshot"))
manca(ws)
ws = nuova()
tutto(ws)
fotografia(ws, 2, "v1")
manca(ws)
PY
  expect 'le fotografie: mancano, o sono uguali' 0 \
    'MANCA: iteration-1/skill-snapshot: manca' \
    'MANCA: iteration-2/skill-snapshot: manca' \
    'MANCA: le due versioni della skill sono uguali'
  py <<'PY'
ws = nuova()
tutto(ws)
fotografia(ws, 2, "v1")
cartella = os.path.join(ws, SKILL + "-workspace", "iteration-2",
                        "skill-snapshot", "evals")
os.makedirs(cartella)
with open(cartella + "/evals.json", "w", encoding="utf-8") as fh:
    fh.write("diversa solo qui")
manca(ws)
PY
  expect 'nelle fotografie evals/ non conta' 0 \
    'MANCA: le due versioni della skill sono uguali'
  py <<'PY'
ws = nuova()
tutto(ws)
fotografia(ws, 2, "v1")
cartella = os.path.join(ws, SKILL + "-workspace", "iteration-2",
                        "skill-snapshot", "references")
os.makedirs(cartella)
with open(cartella + "/guida.md", "w", encoding="utf-8") as fh:
    fh.write("un file in più")
manca(ws)
PY
  expect_no 'nelle fotografie un file in più conta' 0 'MANCA:'
  py <<'PY'
ws = nuova()
evals_di(ws)
manca(ws)
PY
  expect 'il punto di partenza: manca tutto, senza errori' 0 \
    'MANCA: iterazione 1, eval-1: manca without_skill' \
    'MANCA: iterazione 2: manca la near-miss' \
    'MANCA: iteration-1/feedback.json: manca'
}

test_reperti() {
  py <<'PY'
ws = nuova()
tutto(ws)
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---", prove.reperti(esame, SKILL))
PY
  expect 'tutto in ordine: nessun reperto' 0 '--- []'
  py <<'PY'
ws = nuova()
tutto(ws)
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)), skill_usata(),
       risultato())
stream(os.path.join(braccio(ws, 1, 2, "without_skill"), "outputs",
                    "stream.jsonl"), init(), risultato())
stream(os.path.join(braccio(ws, 1, 3, "with_skill"), "outputs", "stream.jsonl"),
       init(("code-review",)), risultato())
stream(os.path.join(braccio(ws, 2, 1, "old_skill"), "outputs", "stream.jsonl"),
       init(("code-review",)), risultato())
stream(os.path.join(ws, SKILL + "-workspace", "iteration-2", "near-miss-1",
                    "with_skill", "outputs", "stream.jsonl"),
       init(("code-review",)), risultato())
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
for riga in prove.reperti(esame, SKILL):
    print("REPERTO:", riga)
PY
  expect 'ogni garanzia che non regge' 0 \
    'REPERTO: iterazione 1, eval-1, without_skill: una chiamata Skill a '\
'prova-skill' \
    'REPERTO: iterazione 1, eval-2, without_skill: prova-skill è fra le '\
'skill disponibili' \
    'REPERTO: iterazione 1, eval-3, with_skill: prova-skill non è fra le '\
'skill disponibili' \
    'REPERTO: iterazione 2, eval-1, old_skill: prova-skill non è fra le '\
'skill disponibili' \
    'REPERTO: iterazione 2, near-miss 1: prova-skill non è fra le skill '\
'disponibili'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), risultato())
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
tentativo(prove.reperti, esame, SKILL)
PY
  expect 'uno stream senza init: la garanzia non si legge, Problema' 0 \
    'PROBLEMA:' 'system/init'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)), skill_usata())
os.makedirs(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs"))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
for riga in prove.reperti(esame, SKILL):
    print("REPERTO:", riga)
PY
  expect 'una chiamata in uno stream a metà è comunque un reperto' 0 \
    'REPERTO: iterazione 1, eval-1, without_skill: una chiamata Skill'
  test_reperti_tentativi
}

# Una chiamata tentata e non riuscita: senza la skill è un dato, la garanzia
# dice che la skill non c'è; con la skill è un reperto, «negata» o «respinta» a
# seconda di chi l'ha fermata, ciascuna con il suo rimedio.
test_reperti_tentativi() {
  py <<'PY'
ws = nuova()
evals_di(ws, (1, 2))
stream(os.path.join(braccio(ws, 1, 1, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)), skill_usata(),
       respinta(), risultato())
stream(os.path.join(braccio(ws, 1, 2, "without_skill"), "outputs",
                    "stream.jsonl"), init(("code-review",)), skill_usata(),
       risultato(negati=[{"tool_name": "Skill", "tool_use_id": "t-skill"}]))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---", prove.reperti(esame, SKILL))
PY
  expect 'without_skill: un tentativo fermato non è un reperto' 0 '--- []'
  expect 'without_skill: il tentativo resta un dato, nella tabella' 0 \
    'without_skill: Skill chiamata: sì, ma respinta con un errore' \
    'without_skill: Skill chiamata: sì, ma negata dal permesso'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"), init(), skill_usata(), respinta(),
       risultato())
stream(os.path.join(ws, SKILL + "-workspace", "iteration-1", "near-miss-1",
                    "with_skill", "outputs", "stream.jsonl"), init(),
       skill_usata(), respinta(), risultato())
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
for riga in prove.reperti(esame, SKILL):
    print("REPERTO:", riga)
PY
  expect 'with_skill: una chiamata respinta è un reperto, con quella parola' \
    0 'REPERTO: iterazione 1, eval-1, with_skill: la chiamata Skill a '\
'prova-skill è respinta dallo strumento' 'il corpo non è arrivato' \
    'il motivo è nel tool_result' \
    'REPERTO: iterazione 1, near-miss 1: la chiamata Skill a prova-skill è '\
'respinta dallo strumento'
  expect_no 'una chiamata respinta non è negata: niente prove/config' 0 \
    'è negata dal permesso' 'prove/config'
  py <<'PY'
ws = nuova()
evals_di(ws, (1, 2))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"), init(), skill_usata(ident="t-1"),
       respinta("t-1"), skill_usata(ident="t-2"), risultato())
stream(os.path.join(braccio(ws, 1, 2, "with_skill"), "outputs",
                    "stream.jsonl"), init(), skill_usata(ident="t-3"),
       skill_usata(ident="t-4"),
       risultato(negati=[{"tool_name": "Skill", "tool_use_id": "t-3"}]))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---", prove.reperti(esame, SKILL))
PY
  expect 'with_skill: fermata e poi riuscita: nessun reperto' 0 '--- []'
  py <<'PY'
ws = nuova()
evals_di(ws, (1,))
stream(os.path.join(braccio(ws, 1, 1, "with_skill"), "outputs",
                    "stream.jsonl"), init(), skill_usata(ident="t-1"),
       respinta("t-1"), skill_usata(ident="t-2"),
       risultato(negati=[{"tool_name": "Skill", "tool_use_id": "t-2"}]))
esame = prove.esamina(ws, SKILL, GIUDICI, None, False)
print("---")
for riga in prove.reperti(esame, SKILL):
    print("REPERTO:", riga)
PY
  expect 'with_skill: respinta e negata: vale il permesso, il suo rimedio' 0 \
    'REPERTO: iterazione 1, eval-1, with_skill: la chiamata Skill a '\
'prova-skill è negata dal permesso' 'Skill(prova-skill)'
}

# --- principale e i comandi -------------------------------------------------

test_principale() {
  py <<'PY'
sys.exit(prove.principale(lambda argv: 1, []))
PY
  expect 'principale: restituisce l uscita della funzione' 1
  py <<'PY'
def ko(_argv):
    raise prove.Problema("il motivo")
sys.exit(prove.principale(ko, []))
PY
  expect 'principale: Problema esce 2, una riga' 2 'FATALE: il motivo'
  expect_no 'principale: mai un traceback' 2 'Traceback'
  py <<'PY'
def rotta(_argv):
    raise ValueError("inatteso")
sys.exit(prove.principale(rotta, []))
PY
  expect 'principale: un errore inatteso esce 2' 2 'ValueError' 'inatteso'
  expect_no 'principale: mai un traceback, nemmeno lì' 2 'Traceback'
  py <<'PY'
sys.exit(prove.principale(lambda argv: None, []))
PY
  expect 'principale: un uscita fuori contratto è 2' 2 'contratto'
  py <<'PY'
import contextlib
import io
with contextlib.redirect_stdout(io.StringIO()):
    esito = prove.principale(lambda argv: 1, [])
sys.exit(esito)
PY
  expect 'principale: con uno STDOUT che non si riconfigura' 1
  expect_no 'principale: con uno STDOUT così, mai un traceback' 1 'Traceback'
  local solo="${TMP}/solo"
  mkdir -p "${solo}"
  cp -- "${LIB}" "${solo}/"
  OUT="$(python3 -B -I "${solo}/lib_controlla_prove.py" esito x 2>&1)"
  RC=$?
  expect 'senza i moduli accanto: uscita 2, una riga' 2 'manca un modulo'
  expect_no 'senza i moduli accanto: mai un traceback' 2 'Traceback'
}

test_comandi() {
  local d="${TMP}/comandi"
  mkdir -p "${d}/prova-skill/evals" "${d}/out"
  cat > "${d}/prova-skill/evals/evals.json" <<'EOF'
{"skill_name": "prova-skill", "evals": [
  {"id": 2, "prompt": "virgolette \" e ' e $HOME e `ls`\nseconda riga\n",
   "expected_output": "x"},
  {"id": 10, "prompt": "- comincia con un trattino", "expected_output": "x"}]}
EOF
  cat > "${d}/prova-skill/evals/eval_queries.json" <<'EOF'
[{"query": "vicina", "should_trigger": false},
 {"query": "dentro", "should_trigger": true}]
EOF
  OUT="$(python3 -B -I "${CASI}" casi "${d}/prova-skill" "${d}/out" 2>&1)"
  RC=$?
  expect 'casi: le righe' 0 'eval-2' 'eval-10'
  expect_no 'casi: senza --near-miss niente near-miss' 0 'near-miss'
  if printf 'virgolette " e '"'"' e $HOME e `ls`\nseconda riga\n' \
      | cmp -s - "${d}/out/eval-2.prompt"; then
    pass 'casi: il prompt byte per byte'
  else
    fail 'casi: il prompt byte per byte'
  fi
  OUT="$(python3 -B -I "${CASI}" casi "${d}/prova-skill" "${d}/out" \
    --near-miss 2>&1)"
  RC=$?
  expect 'casi --near-miss: anche le near-miss' 0 'near-miss-1' 'near-miss-2'
  if [[ "$(< "${d}/out/near-miss-2.prompt")" == 'dentro' ]]; then
    pass 'casi --near-miss: il file della query'
  else
    fail 'casi --near-miss: il file della query'
  fi
  OUT="$(python3 -B -I "${CASI}" casi "${d}/non-esiste" "${d}/out" 2>&1)"
  RC=$?
  expect 'casi: senza evals.json esce 2' 2 'FATALE' 'evals.json'
  printf '{"skill_name":"prova-skill","evals":[{"id":1,"prompt":"a\\u0000b",' \
    > "${d}/prova-skill/evals/evals.json"
  printf '"expected_output":"x"}]}' >> "${d}/prova-skill/evals/evals.json"
  OUT="$(python3 -B -I "${CASI}" casi "${d}/prova-skill" "${d}/out" 2>&1)"
  RC=$?
  expect 'casi: un carattere NUL nel prompt esce 2' 2 'FATALE' 'NUL'
  OUT="$(python3 -B -I "${CASI}" 2>&1)"
  RC=$?
  expect 'senza comando esce 2' 2 'Uso'
  OUT="$(python3 -B -I "${CASI}" boh 2>&1)"
  RC=$?
  expect 'un comando sconosciuto esce 2' 2 'Uso'
  py <<'PY'
d = nuova()
print(d)
stream(d + "/buono.jsonl", init(), risultato())
stream(d + "/errore.jsonl", init(), risultato(errore=True))
stream(d + "/monco.jsonl", init())
stream(d + "/rotto.jsonl", "{no")
PY
  local e="${OUT}"
  OUT="$(python3 -B -I "${CASI}" esito "${e}/buono.jsonl" 2>&1)"
  RC=$?
  expect_no 'esito: uno stream riuscito esce 0' 0 'FATALE'
  OUT="$(python3 -B -I "${CASI}" esito "${e}/errore.jsonl" 2>&1)"
  RC=$?
  expect 'esito: un errore esce 1' 1 'errore'
  OUT="$(python3 -B -I "${CASI}" esito "${e}/monco.jsonl" 2>&1)"
  RC=$?
  expect 'esito: nessun risultato esce 1' 1 'nessun risultato'
  OUT="$(python3 -B -I "${CASI}" esito "${e}/rotto.jsonl" 2>&1)"
  RC=$?
  expect 'esito: uno stream rovinato esce 2' 2 'FATALE'
  if [[ ! -x "${LIB}" ]]; then
    pass 'il modulo non è eseguibile'
  else
    fail 'il modulo non è eseguibile'
  fi
  local solo="${TMP}/solo-casi"
  mkdir -p "${solo}"
  cp -- "${CASI}" "${solo}/"
  OUT="$(python3 -B -I "${solo}/prove_skill_casi.py" esito x 2>&1)"
  RC=$?
  expect 'senza il modulo accanto: uscita 2, una riga' 2 \
    'lib_controlla_prove.py'
  expect_no 'senza il modulo accanto: mai un traceback' 2 'Traceback'
}

main() {
  command -v python3 >/dev/null 2>&1 || {
    echo "test_lib_controlla_prove: manca python3" >&2
    exit 2
  }
  TMP="$(mktemp -d)" || exit 2
  trap 'rm -rf -- "${TMP}"' EXIT
  scrivi_pilota
  test_leggi_stream
  test_leggi_stream_problemi
  test_file_cambiati
  test_chiamata_negata
  test_altri_token
  test_timing
  test_giudica
  test_leggi_evals
  test_riepilogo
  test_scrivi_json_verdetto
  test_esamina_scrive
  test_esamina_stampa
  test_stampa_plurali
  test_dato_negati
  test_esamina_bordi
  test_esamina_altri_bordi
  test_manca_per_finire
  test_reperti
  test_principale
  test_comandi
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
