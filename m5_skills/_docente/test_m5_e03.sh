#!/bin/bash
#
# test_m5_e03.sh -- le prove di M5-E03 «Una skill di risposta nel tono di voce
# dell'assistenza», per il docente:
#   - l'elemento e lo spazio di lavoro (lib_test_lab_m5.sh);
#   - i sei giudici di verifica.py su stream scritti qui, buoni, cattivi e
#     mancanti; le parole da evitare contro la guida del tono e la tabella del
#     SKILL.md di esempio; i casi di prova contro i canali e le procedure;
#   - i dati che non decidono l'uscita, il testo stampato per una persona; le
#     precondizioni (2, mai un traceback);
#   - il ciclo del README e _docente/live.sh con il claude finto, le garanzie;
#   - il README, shellcheck, check_handson, la sintassi di Python 3.8.
# Mai il claude vero. CASES è il numero dei casi: se ne girano di più o di meno
# la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_e03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2034,SC2016,SC2119  # le variabili le legge
# lib_test_lab_m5.sh; backtick e $ sono il testo delle prove; le funzioni comuni
# prendono argomenti facoltativi
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly ITEM="${MOD}/s4_skills/m5_e2_laboratorio/M5-E03_risposta_assistenza"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_e03_e04.py"
FINTO_BASE="${MOD}/_docente/claude_finto_m5_e02.py"
readonly ESEMPIO="${RADICE}/riferimenti/skill-di-esempio/risposta-assistenza"
readonly SUITE=test_m5_e03
readonly ID=M5-E03
readonly SKILL=risposta-assistenza
readonly PROGETTO=progetti/assistenza-clienti
readonly FILE_DEL_PROGETTO="${PROGETTO}/tono-di-voce.md"
readonly NEAR_MISS='procedura del trasloco'
readonly RICHIESTA='Rispondi a questa cliente'
readonly CASES=219
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_test_lab_m5.sh
source "${MOD}/_docente/lib_test_lab_m5.sh"

readonly A_TESTO='Contiene il solo testo'
readonly A_PAROLE='Non usa le parole'
readonly A_EMOJI='Non contiene emoji'
readonly A_CANALE='Rispetta la forma'
readonly A_NUMERO='Riporta il numero'
readonly A_PASSWORD='Non scrive una password'
readonly CHAT_BUONA='Mi dispiace, Marta: la linea va e viene da ieri sera.
Collega il computer al router con un cavo e rifai la prova.
Poi scrivimi i tre valori.'
readonly EMAIL_BUONA='Oggetto: il firewall nuovo - segnalazione TK-2026-04600

Buongiorno Dott.ssa Prova,

il firewall nuovo ha un indirizzo MAC diverso da quello di prima.

Per riservargli l'"'"'indirizzo le chiediamo una cosa:

1. Ci scriva il MAC, che trova sull'"'"'etichetta.

2. Poi riavvii il firewall.

Riepilogo: abbiamo letto la segnalazione TK-2026-04600; aspettiamo il MAC.

Il team di assistenza CiaspoLink'

test_giudice_testo() {
  local a="${A_TESTO}"
  giudica "premessa: un messaggio senza, passa, e cita la prima riga" 1 \
    "${CHAT_BUONA}" "${a}" true 'prima riga: «Mi dispiace, Marta'
  giudica "premessa: «Ecco»" 1 $'Ecco la risposta per Marta:\n\nCiao.' "${a}" \
    false 'prima riga: «Ecco la risposta'
  giudica "premessa: «Ecco una»" 1 'Ecco una possibile risposta' "${a}" false \
    'Ecco una'
  giudica "premessa: «Risposta:»" 1 $'Risposta:\nCiao Marta.' "${a}" false \
    'Risposta:'
  giudica "premessa: **Risposta suggerita:**" 1 \
    $'**Risposta suggerita:**\nCiao Marta.' "${a}" false 'Risposta suggerita'
  giudica "premessa: «Messaggio per il cliente:»" 1 \
    $'Messaggio per il cliente:\nCiao.' "${a}" false 'Messaggio per il cliente'
  giudica "premessa: «Puoi rispondere»" 3 'Puoi rispondere così: non posso.' \
    "${a}" false 'Puoi rispondere'
  giudica "premessa: «Puoi rispondergli»" 3 'Puoi rispondergli così: no.' \
    "${a}" false 'Puoi rispondergli'
  giudica "premessa: «Ti propongo»" 1 'Ti propongo questo testo: ciao.' "${a}" \
    false 'Ti propongo'
  giudica "premessa: «Gli risponderei»" 3 'Gli risponderei così: no.' "${a}" \
    false 'Gli risponderei'
  giudica "premessa: un titolo" 1 $'# Risposta a Marta\n\nCiao.' "${a}" false \
    '# Risposta a Marta'
  giudica "premessa: un titolo in grassetto" 1 \
    $'**Il messaggio**\n\nCiao Marta.' "${a}" false '**Il messaggio**'
  giudica "nessun falso allarme: «Puoi rispondermi con i valori?»" 1 \
    'Puoi rispondermi con i tre valori?' "${a}" true 'prima riga'
  giudica "nessun falso allarme: «Oggetto:» in grassetto" 2 \
    "**Oggetto: la linea**"$'\n\nBuongiorno Dott.ssa Prova,' "${a}" true \
    'prima riga'
  giudica "un commento dopo: «Nota:»" 1 $'Ciao Marta.\n\nNota: ho usato il tu.' \
    "${a}" false 'Nota: ho usato'
  giudica "un commento dopo: «Ho usato il tu»" 1 \
    $'Ciao Marta.\n\nHo usato il tu perché è una chat.' "${a}" false 'Ho usato'
  giudica "un commento dopo: «Se vuoi lo adatto»" 1 \
    $'Ciao Marta.\n\nSe vuoi lo adatto per il telefono.' "${a}" false \
    'Se vuoi lo adatto'
  giudica "un commento dopo: «Questo messaggio segue»" 1 \
    $'Ciao Marta.\n\nQuesto messaggio segue la guida.' "${a}" false \
    'Questo messaggio'
  giudica "un commento dopo una riga ---" 1 \
    $'Ciao Marta.\n\n---\nUna versione più breve: ciao.' "${a}" false \
    'Una versione più breve'
  giudica "un commento dopo un blocco di codice" 1 \
    $'```\nCiao Marta.\n```\nDimmi se va bene.' "${a}" false 'Dimmi se va bene'
  giudica "un commento dopo la firma" 2 \
    "${EMAIL_BUONA}"$'\n\nHo tenuto il lei.' "${a}" false 'Ho tenuto il lei'
  giudica "nessun falso allarme: «Se non riesci, ti guido io.»" 3 \
    $'Non posso.\nSe non riesci ad accedere, ti guido io.' "${a}" true \
    'nessun commento'
  giudica "nessun falso allarme: «Se vuoi, ti guido io.»" 3 \
    $'Non posso.\nSe vuoi, ti guido io.' "${a}" true 'nessun commento'
  giudica "nessun falso allarme: «Posso aiutarti in altro?»" 3 \
    $'Non posso.\nPosso aiutarti in altro?' "${a}" true 'nessun commento'
  giudica "una risposta vuota non passa" 1 ' ' "${a}" false 'vuota'
}

test_giudice_parole() {
  local a="${A_PAROLE}"
  giudica "parole: nessuna" 1 "${CHAT_BUONA}" "${a}" true 'nessuna'
  giudica "parole: «sicuramente», e la nomina" 1 'È sicuramente il Wi-Fi.' \
    "${a}" false 'sicuramente'
  giudica "parole: maiuscole o minuscole" 1 'GENTILE CLIENTE, buongiorno.' \
    "${a}" false 'GENTILE CLIENTE'
  giudica "parole: «a breve», e tutte quelle trovate" 1 \
    'Un disservizio risolto a breve.' "${a}" false 'disservizio, a breve'
  giudica "parole: la stessa parola al plurale" 1 'Ci sono disservizi.' "${a}" \
    false 'disservizi'
  giudica "parole: «ti faremo sapere», nel registro del tu" 1 \
    'Ti faremo sapere.' "${a}" false 'Ti faremo sapere'
  giudica "parole: su due righe" 1 $'La presa\nin carico è fatta.' "${a}" false \
    'presa'
  giudica "parole: «ticket»" 1 'Il ticket è aperto.' "${a}" false 'ticket'
  giudica "parole: a parola intera: «ticketing» non vale" 1 'Il ticketing.' \
    "${a}" true 'nessuna'
  giudica "parole: una sigla della guida" 1 'La OLT è ferma.' "${a}" false 'OLT'
  giudica "parole: il nome di un apparato" 1 'olt-pergine-01 è fermo.' "${a}" \
    false 'olt-pergine-01'
  giudica "parole: una risposta vuota non passa" 1 ' ' "${a}" false 'vuota'
}

# Le parole di verifica.py contro la guida e la tabella dello SKILL.md.
test_parole_e_guida() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I - "${ITEM}/verifica.py" \
    "${RADICE}/${PROGETTO}/tono-di-voce.md" "${ESEMPIO}/SKILL.md" <<'PY'
import importlib.util
import re
import sys

spec = importlib.util.spec_from_file_location("controlli", sys.argv[1])
controlli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controlli)
parole = controlli.PAROLE_DA_EVITARE
guida = open(sys.argv[2], encoding="utf-8").read()
skill = open(sys.argv[3], encoding="utf-8").read()
def sezione(testo, titolo):
    return testo.split(titolo, 1)[1].split("\n## ", 1)[0]
def colonna(testo):
    celle = [r.split("|")[1] for r in testo.splitlines()
             if r.startswith("|") and not r.startswith("|---")][1:]
    return celle, [p for c in celle for p in re.findall(r"«([^»]+)»", c)]
celle_g, voci_g = colonna(sezione(guida, "## Parole da usare e parole da evitare"))
celle_s, voci_s = colonna(sezione(skill, "## Parole da evitare"))
tutte = " ".join(celle_g + celle_s).lower()
for parola in parole:
    if parola.lower() not in tutte:
        sys.exit("«%s» non è nella guida" % parola)
for voce in voci_g + voci_s:
    if not any(p.lower() in voce.lower() for p in parole):
        sys.exit("la voce «%s» non è fra le parole" % voce)
for parola, forme in parole.items():
    if not forme or len(forme) != len(set(forme)):
        sys.exit("le forme di «%s»: %r" % (parola, forme))
print(len(voci_g), "voci della guida e", len(voci_s), "dello SKILL.md")
PY
  expect "le parole: ogni voce della guida e dello SKILL.md, e viceversa" 0 \
    'voci della guida' 'dello SKILL.md'
}

test_giudice_emoji() {
  local a="${A_EMOJI}"
  giudica "emoji: nessuna" 1 "${CHAT_BUONA}" "${a}" true 'nessuna emoji'
  giudica "emoji: una faccina, e la nomina" 1 'Ciao Marta 🙂' "${a}" false '🙂'
  giudica "emoji: un simbolo del blocco U+2600" 1 'Fatto ✅' "${a}" false '✅'
  giudica "emoji: una bandiera" 1 'Ciao 🇮🇹' "${a}" false 'emoji'
  giudica "esclamativi in serie: «!!»" 1 'Grazie!!' "${a}" false '!!'
  giudica "esclamativi in serie: «! !»" 1 'Grazie! !' "${a}" false '!!'
  giudica "un solo punto esclamativo va" 1 'Grazie!' "${a}" true 'nessuna emoji'
  giudica "una freccia non è un'emoji" 1 '«La mia linea» → «Credenziali»' "${a}" \
    true 'nessuna emoji'
  giudica "emoji: una risposta vuota non passa" 1 ' ' "${a}" false 'vuota'
}

test_giudice_chat() {
  local a="${A_CANALE}"
  giudica "chat: tre frasi" 1 "${CHAT_BUONA}" "${a}" true '3 frasi'
  giudica "chat: quattro frasi non passano" 1 'Uno. Due. Tre. Quattro.' "${a}" \
    false '4 frasi'
  giudica "chat: un passo numerato, con tre frasi intorno" 1 \
    $'Uno. Due.\n1. Collega il cavo. Avvia la prova.\nTre.' "${a}" true \
    '1 passo'
  giudica "chat: due passi numerati non passano" 1 \
    $'Uno.\n1. Collega il cavo.\n2. Avvia la prova.' "${a}" false '2 passi'
  giudica "chat: l'indirizzo con i punti non spezza una frase" 1 \
    'Apri speedtest.ciaspolink.example.org e prova.' "${a}" true '1 frase,'
  giudica "chat: «Dott.ssa» e «es.» non spezzano una frase" 3 \
    'La Dott.ssa Prova ha chiamato, es. ieri.' "${a}" true '1 frase,'
  giudica "chat: la riga a capo chiude una frase" 3 $'Uno\nDue\nTre\nQuattro' \
    "${a}" false '4 frasi'
  giudica "chat: tre frasi e una domanda sono quattro" 3 \
    'Uno! Due. Tre… Quattro?' "${a}" false '4 frasi'
  giudica "chat: una risposta vuota non passa" 1 ' ' "${a}" false 'vuota'
}

test_giudice_email() {
  local a="${A_CANALE}" t
  giudica "e-mail: la forma, e i conteggi" 2 "${EMAIL_BUONA}" "${a}" true \
    '3 paragrafi'
  giudica "e-mail: l'evidenza cita il saluto" 2 "${EMAIL_BUONA}" "${a}" true \
    'Buongiorno Dott.ssa Prova'
  t="${EMAIL_BUONA/Oggetto: /Tema: }"
  giudica "e-mail: senza Oggetto" 2 "${t}" "${a}" false 'Oggetto: no'
  t="${EMAIL_BUONA/Oggetto: il firewall/**Oggetto:** il firewall}"
  giudica "e-mail: Oggetto in grassetto vale" 2 "${t}" "${a}" true 'Oggetto: sì'
  t="${EMAIL_BUONA/Buongiorno Dott.ssa Prova,/Buongiorno,}"
  giudica "e-mail: un saluto senza nome" 2 "${t}" "${a}" false \
    'saluto con un nome: no'
  t="${EMAIL_BUONA/Buongiorno Dott.ssa Prova,/Gentile Cliente,}"
  giudica "e-mail: «Gentile Cliente» non è un nome" 2 "${t}" "${a}" false \
    'saluto con un nome: no'
  t="${EMAIL_BUONA/Buongiorno Dott.ssa Prova,/Buongiorno signor Esempio,}"
  giudica "e-mail: «signor Esempio» è un nome" 2 "${t}" "${a}" true \
    'signor Esempio'
  t="${EMAIL_BUONA/Il team di assistenza CiaspoLink/Il team}"
  giudica "e-mail: senza la firma" 2 "${t}" "${a}" false 'firma: no'
  t=$'Oggetto: x\n\nBuongiorno Dott.ssa Prova,\n\nUno solo.\n\n'
  t+='Il team di assistenza CiaspoLink'
  giudica "e-mail: un paragrafo solo" 2 "${t}" "${a}" false '1 paragrafo,'
  t=$'Oggetto: x\n\nBuongiorno Dott.ssa Prova,\n\nA.\n\nB.\n\nC.\n\nD.\n\nE.\n\n'
  t+='Il team di assistenza CiaspoLink'
  giudica "e-mail: cinque paragrafi" 2 "${t}" "${a}" false '5 paragrafi'
  t=$'Oggetto: x\n\nBuongiorno Dott.ssa Prova,\n\nA.\n\nB.\n\nC.\n\nD.\n\n'
  t+=$'Cordiali saluti,\n\nIl team di assistenza CiaspoLink'
  giudica "e-mail: i saluti finali non sono un paragrafo" 2 "${t}" "${a}" true \
    '4 paragrafi'
  giudica "e-mail: una risposta vuota non passa" 2 ' ' "${a}" false 'vuota'
}

test_giudice_numero() {
  local a="${A_NUMERO}"
  giudica "il numero: c'è, e cita la riga" 2 "${EMAIL_BUONA}" "${a}" true \
    'segnalazione TK-2026-04600'
  giudica "il numero: non c'è" 2 'Oggetto: la linea' "${a}" false \
    'TK-2026-04600'
  giudica "il numero: un altro numero non vale" 2 'TK-2026-04302' "${a}" false \
    'TK-2026-04600'
}

test_giudice_password() {
  local a="${A_PASSWORD}"
  giudica "password: nessun valore, l'area clienti" 3 \
    'Non posso scriverti la password: la trovi nell'"'"'area clienti.' "${a}" \
    true 'area clienti'
  giudica "password: «la password è nell'area clienti»" 3 \
    'La password è nell'"'"'area clienti.' "${a}" true 'nessun valore'
  giudica "password: «password: la trovi nell'area clienti»" 3 \
    'Password: la trovi nell'"'"'area clienti.' "${a}" true 'nessun valore'
  giudica "password: «Area Clienti», maiuscole o minuscole" 3 \
    'La trovi in Area Clienti.' "${a}" true 'Area Clienti'
  giudica "password: senza l'area clienti" 3 'Non posso scriverla in chat.' \
    "${a}" false 'area clienti'
  giudica "password: un valore dopo i due punti" 3 \
    'Password: Xy7kLm2 e area clienti.' "${a}" false 'un valore'
  expect_absent "password: l'evidenza non ripete il valore" 'Xy7kLm2'
  giudica "password: «la password è ciaspola2024»" 3 \
    'La password è ciaspola2024, area clienti.' "${a}" false 'un valore'
  expect_absent "password: l'evidenza non ripete nemmeno questo" 'ciaspola2024'
  giudica "password: «password della linea: abc»" 3 \
    'password della linea: abc1 (area clienti)' "${a}" false 'un valore'
  giudica "password: un valore fra virgolette" 3 \
    'La password è `segreta`, dall'"'"'area clienti.' "${a}" false 'un valore'
  giudica "password: una parola sola alla fine della riga" 3 \
    $'Area clienti.\nPassword: segreta' "${a}" false 'un valore'
  giudica "password: una risposta vuota non passa" 3 ' ' "${a}" false 'vuota'
}

# I tre casi di prova contro i canali di verifica.py, e il numero della
# segnalazione; le procedure che li riguardano.
test_casi_di_prova() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I - "${ITEM}/verifica.py" \
    "${ITEM}/esercizio/.claude/skills/${SKILL}/evals/evals.json" <<'PY'
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("controlli", sys.argv[1])
controlli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controlli)
casi = json.load(open(sys.argv[2], encoding="utf-8"))["evals"]
if sorted(c["id"] for c in casi) != sorted(controlli.CANALI):
    sys.exit("gli id: %r" % [c["id"] for c in casi])
for caso in casi:
    if controlli.CANALI[caso["id"]] not in caso["prompt"].lower():
        sys.exit("il canale di %r" % caso["id"])
    fuori = [a for a in caso["assertions"] if a not in controlli.GIUDICI]
    if fuori:
        sys.exit("senza giudice: %r" % fuori)
if controlli.NUMERO not in casi[1]["prompt"]:
    sys.exit("il numero non è nel caso 2")
print("casi, canali, giudici")
PY
  expect "ogni asserzione di evals.json ha il suo giudice; canali e numero" 0 \
    'casi, canali, giudici'
}

test_dati() {
  echo "I dati:"
  local w="${G_WS}" base
  base="${w}/${SKILL}-workspace/iteration-1"
  rm -rf -- "${w}/${SKILL}-workspace"
  stream_di "${base}/eval-1/without_skill" \
    $'Ecco una risposta lunga.\n\nHo usato il lei.'
  stream_di "${base}/eval-1/with_skill" "${CHAT_BUONA}"
  verifica_py "${w}" --solo-prove
  expect "un confronto: confermata, una sola esecuzione per caso, uscita 0" 0 \
    'confermata (una sola esecuzione per caso)'
  expect "il testo, per una persona: intero, con la configurazione" 0 \
    'per una persona' 'iterazione 1, eval-1, with_skill' 'Mi dispiace, Marta' \
    'Poi scrivimi i tre valori.' 'iterazione 1, eval-1, without_skill' \
    'Ho usato il lei.'
  expect "la lunghezza, in parole, come dato" 0 '28 parole'
  expect_absent "nessun esito dice «smentita»" 'smentit'
  stream_di "${base}/eval-1/with_skill" 'Ecco una. Due. Tre. Quattro.'
  verifica_py "${w}" --solo-prove
  expect "meno asserzioni con la skill: mai smentita, uscita 0" 0 \
    'non confermata in questa misura'
  expect_absent "e nessun esito dice «smentita»" 'smentit'
  stream_di "${base}/eval-1/with_skill" 'Ecco una risposta lunga.'
  stream_di "${base}/eval-1/without_skill" 'Ecco una risposta lunga.'
  verifica_py "${w}" --solo-prove
  expect "stesso numero: non distinguibile, uscita 0" 0 'non distinguibile'
  mkdir -p "${w}/${SKILL}-workspace/iteration-2/eval-1"
  cp -R "${base}/eval-1/with_skill" \
    "${w}/${SKILL}-workspace/iteration-2/eval-1/old_skill"
  stream_di "${w}/${SKILL}-workspace/iteration-2/eval-1/with_skill" 'Testo due.'
  verifica_py "${w}" --solo-prove
  expect "la seconda iterazione: il suo testo" 0 'Testo due.'
  expect_absent "old_skill riusa: il suo testo non si ristampa" \
    'iterazione 2, eval-1, old_skill'
  stream_di "${w}/${SKILL}-workspace/iteration-2/eval-1/with_skill" 'Ciao.'
  verifica_py "${w}" --solo-prove
  expect "la lunghezza di una parola: il singolare" 0 'with_skill, 1 parola:'
  rm -rf -- "${w}/${SKILL}-workspace"
  test_asserzione_a_mano 1 0 "${CHAT_BUONA}"
}

test_precondizioni() {
  local w="${G_WS}" evals="${G_WS}/.claude/skills/${SKILL}/evals/evals.json"
  test_precondizioni_comuni
  cp -- "${evals}" "${TMP}/evals.salvati"
  python3 -B -I - "${evals}" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["evals"].append(dict(dati["evals"][0], id=9))
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
  stream_di "${w}/${SKILL}-workspace/iteration-1/eval-9/with_skill" 'Ciao.'
  verifica_py "${w}"
  expect "un caso senza il suo canale: 2, e lo dice" 2 'eval-9' 'canale'
  cp -- "${TMP}/evals.salvati" "${evals}"
  rm -rf -- "${w}/${SKILL}-workspace"
}

test_giudici() {
  echo "I giudici:"
  nuovo_ws
  G_WS="${WS}"
  test_giudice_testo
  test_giudice_parole
  test_parole_e_guida
  test_giudice_emoji
  test_giudice_chat
  test_giudice_email
  test_giudice_numero
  test_giudice_password
  test_casi_di_prova
  test_dati
  test_precondizioni
}

# Il README e la registrazione: le righe che cita sono quelle che la verifica
# stampa sugli stream di soluzione/.
test_readme_registrazione() {
  nuovo_ws
  cp -R "${ITEM}/soluzione/." "${WS}/" || exit 2
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica su soluzione/: 0" 0 'Fatto: la skill passa'
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${ITEM}/README.md" "${TMP}/uscita.txt" <<'FRASI'
= with_skill 3, without_skill 2 asserzioni passate: confermata (una sola esecuzione per caso)
= with_skill 5, without_skill 2 asserzioni passate: confermata (una sola esecuzione per caso)
= with_skill 5, without_skill 4 asserzioni passate: confermata (una sola esecuzione per caso)
= Conteggi: without_skill 8 su 14; with_skill 13 su 14
= Delta, with_skill meno without_skill: pass rate +0,350; tempo -3,1 s; token -24284
= with_skill 4, old_skill 3 asserzioni passate: confermata (una sola esecuzione per caso)
= with_skill 5, old_skill 5 asserzioni passate: non distinguibile (una sola esecuzione per caso)
= Conteggi: old_skill 13 su 14; with_skill 14 su 14
= Delta, with_skill meno old_skill: pass rate +0,083; tempo -2,7 s; token +24592
= (dato) with_skill: 1 passo negato dal permesso: Bash «cd /tmp/handson.TYFTas/esecuzione-0/.claude/skills/risposta-assistenza && cat > …»
= iterazione 1: risposta-assistenza chiamata 3 su 3 in with_skill
= iterazione 2: risposta-assistenza chiamata 3 su 3 in with_skill
= Skill chiamata: no; dovrebbe attivarla: no
= Da leggere, per una persona: il tono non lo decide il controllo.
= Consumo, senza le esecuzioni riusate: 7 chiamate, 33 turni, 503910 token, 107,1 s
= Consumo, senza le esecuzioni riusate: 4 chiamate, 20 turni, 320137 token, 49,5 s
= Fatto: la skill passa il controllo del file, le due iterazioni ci sono, i commenti anche, e le due versioni sono diverse.
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet
R sull'account del docente, un piano Max
R 824.047
R 262.792
R 438.371
R 701.163
R bozza/risposta-assistenza/
R Use modelUsage, or model_usage in Python, for whole-tree token accounting; the usage field undercounts as soon as nesting occurs.
R Rispetta il tono di voce dell'assistenza?
R Non dovrebbe essere quella caricata su claude.ai
R una sessione così non le elencava
! da 10 a 20 turni attesi
! da 4 a 8 turni attesi
! Parla come la guida?
! non esegue niente
FRASI
  expect "il README cita le righe del controllo" 0 'in ordine'
}

test_readme() {
  echo "Il README:"
  test_readme_sezioni
  test_readme_prompt "${FILE_DEL_PROGETTO}" 'qualunque messaggio'
  test_readme_frasi_comuni
  controlla_frasi "le frasi sul tono, parola per parola" <<'FRASI'
Subjective skills (writing style, design quality) are better evaluated qualitatively — don't force assertions onto things that need human judgment.
Every response in a certain voice, length, or format, or Claude in a different role | An output style
Claude loads it only when you invoke it or the task matches, so it doesn't shape unrelated responses
Write in my voice … A profile of how you write, saved as a skill. … Your real writing is the corpus.
A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use.
https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md
https://code.claude.com/docs/en/output-styles
https://academy.claude.com/use-cases/my-voice
https://github.com/anthropics/skills/blob/main/skills/internal-comms/SKILL.md
FRASI
  test_readme_parole
  test_readme_registrazione
}

main() {
  exec < /dev/null
  prepara_ambiente
  test_elemento_comune
  test_punto_di_partenza_comune
  test_giudici
  test_ciclo_comune
  test_versioni_uguali
  test_garanzie_comuni
  test_live_comune
  test_readme
  test_strumenti_comuni
  chiudi_suite "${CASES}"
}

main "$@"
