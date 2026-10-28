"""blocca_rm.py -- l'hook PreToolUse della demo M4-D04: blocca i comandi
di Bash che eseguono rm.

Claude Code lo esegue prima di ogni chiamata allo strumento Bash (il
matcher «Bash» di .claude/settings.json) e gli passa la chiamata in JSON
su STDIN: «Command hooks receive JSON data via stdin and communicate
results through exit codes, stdout, and stderr.»
(https://code.claude.com/docs/en/hooks). Lo script legge il comando in
tool_input.command. Se il comando esegue rm in
una posizione di comando (all'inizio; dopo ;, &&, ||, |, &, (, $(, un a
capo o un apice inverso; dopo if, then, else, elif, do, while, until, ! o
{; dopo -exec di find; dopo sudo, xargs, env, command, exec, nohup, nice,
time o timeout e le loro opzioni), l'hook esce con 2 e scrive il motivo su
STDERR. Altrimenti esce con 0 e non scrive niente: la chiamata prosegue
con i permessi di sempre. Un ingresso che non riesce a leggere (non è
JSON, manca il comando, una virgoletta non si chiude, qualunque errore) lo
blocca per prudenza. Il carattere # non apre un commento: un rm dopo un
commento si vede lo stesso.

Legge il testo del comando così come lo scrive Claude: è un esempio per il
corso, non un confine di sicurezza (bash -c "rm …", per esempio, non lo
riconosce).

Uscita: 0 la chiamata prosegue · 2 la chiamata è bloccata
"""
import json
import re
import shlex
import sys

OPERATORI = set(";&|()$")
PAROLE_CHIAVE = {"if", "then", "else", "elif", "do", "while", "until", "!",
                 "{"}
ESEGUE = {"-exec", "-execdir", "-ok", "-okdir"}
PREFISSI = {"sudo", "xargs", "env", "command", "exec", "nohup", "nice",
            "time", "timeout"}
ASSEGNAZIONE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
NUMERO = re.compile(r"^[0-9.]+[smhd]?$")
BLOCCO = "Bloccato dall'hook del progetto: "


def parole(comando):
    """Le parole del comando, con gli operatori della shell a parte; un a
    capo e un apice inverso valgono come «;», e # non apre un commento.
    ValueError se una virgoletta non si chiude."""
    testo = comando.replace("\n", " ; ").replace("`", " ; ")
    lex = shlex.shlex(testo, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)


def esegue_rm(comando):
    """Vero se una parola in posizione di comando è rm (anche /bin/rm),
    anche dentro un $(…) fra virgolette."""
    in_testa = True
    dopo_prefisso = False
    for parola in parole(comando):
        if "$(" in parola and esegue_rm(parola.split("$(", 1)[1]):
            return True
        if set(parola) <= OPERATORI or parola in PAROLE_CHIAVE \
                or parola in ESEGUE:
            in_testa, dopo_prefisso = True, False
            continue
        if not in_testa:
            continue
        if ASSEGNAZIONE.match(parola) or parola.startswith("-") \
                or (dopo_prefisso and NUMERO.match(parola)):
            continue
        nome = parola.rsplit("/", 1)[-1]
        if nome == "rm":
            return True
        in_testa = dopo_prefisso = nome in PREFISSI
    return False


def main():
    try:
        comando = json.load(sys.stdin)["tool_input"]["command"]
        if not isinstance(comando, str):
            raise TypeError("il comando non è un testo")
        blocca = esegue_rm(comando)
    except Exception as exc:  # fallisce chiuso: ogni errore blocca
        sys.stderr.write("%snon riesco a leggere il comando (%s: %s).\n"
                         % (BLOCCO, type(exc).__name__, exc))
        return 2
    if blocca:
        sys.stderr.write("%srm non è consentito qui (comando: %s).\n"
                         % (BLOCCO, comando))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
