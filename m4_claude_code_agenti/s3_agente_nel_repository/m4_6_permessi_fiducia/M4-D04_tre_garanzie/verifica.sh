#!/bin/bash
#
# verifica.sh di M4-D04 -- la vostra prova della regola deny. Nello spazio
# di lavoro controlla che
#   - .claude/settings.json sia un JSON valido e che il suo elenco
#     permissions.deny contenga la regola ancorata al progetto,
#     Edit(/progetti/gestionale-php/database/dati/**). La stessa regola
#     senza la barra iniziale (o con «./») vale rispetto alla cartella
#     corrente, che un cd sposta: non basta, e la verifica dice perché;
#   - i dati generati del gestionale, progetti/gestionale-php/database/
#     dati/, siano quelli del punto di partenza, il primo commit dello
#     spazio di lavoro: nessun file cambiato, cancellato o nuovo, anche se
#     nel frattempo c'è stato un commit.
# Dice tutto ciò che manca, non soltanto la prima cosa. Che Claude abbia
# tentato la modifica e che Claude Code l'abbia negata lo vedete nella
# sessione: la verifica guarda la regola e i dati. Le tre coppie del
# docente le decide controlla_gradini.py, che fa girare _docente/live.sh.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = la regola c'è e i dati non sono cambiati; l'ultima riga è
#         «Fatto: …» · 1 = non ancora: la regola manca, il file delle
#         impostazioni manca o non è un JSON valido, oppure i dati sono
#         cambiati · 2 = precondizione (spazio di lavoro assente, in cui
#         non si entra o che non è un repository git con i dati al punto
#         di partenza, python3 o git che mancano, il file delle
#         impostazioni che non si legge, git che non riesce)
set -euo pipefail

readonly REGOLA='Edit(/progetti/gestionale-php/database/dati/**)'
readonly DATI='progetti/gestionale-php/database/dati'
readonly FATTO="Fatto: la regola deny c'è e i dati generati non sono cambiati."

# La regola nelle impostazioni dello spazio di lavoro.
# Arguments: $1 il file delle impostazioni.
# Outputs: che cosa manca, su STDOUT; un errore su STDERR.
# Returns: 0 la regola c'è; 1 manca, o il file manca o non è JSON; 2 il
#   file non si legge.
regola() {
  python3 -B -I - "$1" "${REGOLA}" <<'PY'
import json, sys
percorso, regola = sys.argv[1:3]
relative = (regola.replace("(/", "(", 1), regola.replace("(/", "(./", 1))
try:
    with open(percorso, encoding="utf-8") as fh:
        testo = fh.read()
except FileNotFoundError:
    print("Non ancora: manca .claude/settings.json nello spazio di lavoro.")
    sys.exit(1)
except (OSError, UnicodeDecodeError) as exc:
    sys.stderr.write("verifica: .claude/settings.json non si legge (%s)\n"
                     % exc)
    sys.exit(2)
try:
    doc = json.loads(testo)
except json.JSONDecodeError as exc:
    print("Non ancora: .claude/settings.json non è un JSON valido (riga %d,"
          " colonna %d: %s): ricontrollate le virgole e le parentesi."
          % (exc.lineno, exc.colno, exc.msg))
    sys.exit(1)
except (ValueError, RecursionError):
    print("Non ancora: .claude/settings.json non è un JSON valido.")
    sys.exit(1)
permessi = doc.get("permissions") if isinstance(doc, dict) else None
nega = permessi.get("deny") if isinstance(permessi, dict) else None
nega = nega if isinstance(nega, list) else []
if regola in nega:
    sys.exit(0)
trovata = next((r for r in nega if r in relative), None)
if trovata is not None:
    print("Non ancora: in .claude/settings.json la regola «%s» è scritta "
          "senza la barra iniziale: così vale rispetto alla cartella "
          "corrente, e dopo un cd non copre più il file. Scrivetela con la "
          "barra, «%s»." % (trovata, regola))
    sys.exit(1)
print("Non ancora: in .claude/settings.json, nell'elenco permissions.deny,"
      " manca la regola «%s»: è il punto 2 dei «Passi in Claude Code» del"
      " README." % regola)
sys.exit(1)
PY
}

# I dati generati come al punto di partenza, il primo commit dello spazio
# di lavoro: i file tracciati confrontati con quel commit (anche le
# modifiche già in un commit) e i file nuovi.
# Arguments: $1 lo spazio di lavoro.
# Outputs: i file cambiati e che cosa fare, su STDOUT.
# Returns: 0 nessun cambiamento; 1 dati cambiati; 2 git non riesce o al
#   punto di partenza i dati non c'erano.
dati() {
  local partenza cambiati nuovi f
  partenza="$(git -C "$1" rev-list --max-parents=0 HEAD | tail -n 1)" \
    || return 2
  if [[ -z "${partenza}" ]] \
      || ! git -C "$1" cat-file -e "${partenza}:${DATI}" 2> /dev/null; then
    echo "verifica: al punto di partenza non ci sono i dati ${DATI}:" \
      "preparate lo spazio di lavoro con tools/prepara_esercizio.sh" \
      "M4-D04" >&2
    return 2
  fi
  cambiati="$(git -C "$1" diff --name-status "${partenza}" -- "${DATI}")" \
    || return 2
  nuovi="$(git -C "$1" ls-files --others --exclude-standard -- "${DATI}")" \
    || return 2
  if [[ -z "${cambiati}${nuovi}" ]]; then
    return 0
  fi
  printf 'Non ancora: i dati generati sono cambiati:\n'
  if [[ -n "${cambiati}" ]]; then
    printf '%s\n' "${cambiati}"
  fi
  if [[ -n "${nuovi}" ]]; then
    while IFS= read -r f; do
      printf 'nuovo\t%s\n' "${f}"
    done <<< "${nuovi}"
  fi
  printf '%s %s\n' "Riportateli al punto di partenza, il primo commit, anche" \
    "dopo un commit; nello spazio di lavoro:"
  # shellcheck disable=SC2016  # è il comando da copiare: non si espande
  printf '  git checkout "$(git rev-list --max-parents=0 HEAD)" -- %s\n' \
    "${DATI}"
  printf '%s %s\n' "Poi togliete i file nuovi, qui sopra «A» o «nuovo»," \
    "controllate la regola e ripetete la richiesta."
  return 1
}

main() {
  local ws="${1:-}" radice rc_regola=0 rc_dati=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if ! command -v git > /dev/null 2>&1; then
    echo "verifica: manca git (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if ! ws="$(cd -- "${ws}" 2> /dev/null && pwd -P)"; then
    echo "verifica: lo spazio di lavoro ${1} non si apre" >&2
    exit 2
  fi
  radice="$(git -C "${ws}" rev-parse --show-toplevel 2> /dev/null)" \
    || radice=''
  if [[ "${radice}" != "${ws}" ]]; then
    echo "verifica: ${ws} non è un repository git: preparate lo spazio di" \
      "lavoro con tools/prepara_esercizio.sh M4-D04" >&2
    exit 2
  fi
  regola "${ws}/.claude/settings.json" || rc_regola=$?
  dati "${ws}" || rc_dati=$?
  if (( rc_regola >= 2 || rc_dati >= 2 )); then
    echo "verifica: la verifica non ha potuto leggere le impostazioni o i" \
      "dati (qui sopra)" >&2
    exit 2
  fi
  if (( rc_regola == 1 || rc_dati == 1 )); then
    exit 1
  fi
  echo "${FATTO}"
}

main "$@"
