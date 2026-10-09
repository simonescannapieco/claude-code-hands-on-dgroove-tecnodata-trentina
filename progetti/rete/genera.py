#!/usr/bin/env python3
"""Genera il materiale sintetico della rete di CiaspoLink.

Uso:
  python3 genera.py              rigenera i file accanto a questo script
  python3 genera.py --out DIR    rigenera in un'altra cartella
  python3 genera.py --check      rigenera in una cartella temporanea e
                                 confronta byte per byte con i file presenti
  python3 genera.py --canone     controlla le regole dei dati sintetici su
                                 ogni file della cartella

Uscita: 0 tutto in ordine, 1 file diversi (o regole violate), 2 errore.
Python 3.8 o successivo, solo libreria standard, seme fisso.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import csv  # noqa: E402
import filecmp  # noqa: E402
import io  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

try:
    from generatore import base, canone, topologia as T
    from generatore import conf_airos, conf_cisco, conf_junos
    from generatore import conf_olt, conf_routeros, conf_server
    from generatore import eventi, inventario, log_rete, log_servizi
except ImportError as missing:
    print("genera.py: errore: generatore incompleto: %s" % missing,
          file=sys.stderr)
    sys.exit(2)

GENERATED_DIRS = ["configurazioni", "log"]
KEY_FILE = os.path.join("_docente", "chiave-problemi.tsv")
TRUTH_FILE = os.path.join("_docente", "problemi-inseriti.csv")
TRUTH_FIELDS = ["id", "apparato", "file", "riga", "categoria", "gravita",
                "descrizione", "estratto"]
SKIP_DIRS = ["__pycache__", ".git"]


class GenerationError(Exception):
    pass


def _configs(lines):
    rng = base.root_rng()
    files = {}
    for dev in T.DEVICES:
        name, dialect = dev["name"], dev["dialect"]
        drng = rng.fork("configurazione/" + name)
        folder = "configurazioni/%s/" % name
        if dialect in ("ios", "ios-xe"):
            files["configurazioni/%s.cfg" % name] = conf_cisco.render(dev, drng)
        elif dialect == "junos":
            files["configurazioni/%s.conf" % name] = conf_junos.render(dev,
                                                                        drng)
        elif dialect == "routeros":
            files["configurazioni/%s.rsc" % name] = conf_routeros.render(
                dev, drng, lines)
        elif dialect == "olt":
            files["configurazioni/%s.cfg" % name] = conf_olt.render(dev, drng,
                                                                     lines)
        elif dialect == "airos":
            files[folder + "system.cfg"] = conf_airos.render(dev, drng, lines)
        elif dialect == "freeradius":
            files[folder + "clients.conf"] = conf_server.radius_clients(dev,
                                                                        drng)
            files[folder + "authorize"] = conf_server.radius_authorize(dev,
                                                                       drng)
        elif dialect == "kea":
            files[folder + "kea-dhcp4.conf"] = conf_server.kea(dev, drng,
                                                               lines)
        elif dialect == "kamailio":
            files[folder + "kamailio.cfg"] = conf_server.kamailio(dev, drng)
            files[folder + "dispatcher.list"] = conf_server.dispatcher_list(
                dev, drng)
        elif dialect == "asterisk":
            files[folder + "pjsip.conf"] = conf_server.pjsip(dev, drng, lines)
        else:
            raise GenerationError("dialetto sconosciuto: %s" % dialect)
    return files


def _read_key(root):
    path = os.path.join(root, KEY_FILE)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t",
                                   quoting=csv.QUOTE_NONE))
    required = ["id", "apparato", "file", "marcatore", "occorrenza",
                "categoria", "gravita", "descrizione"]
    for row in rows:
        if any(not row.get(field) for field in required):
            raise GenerationError("chiave incompleta alla riga %s" % row)
    return rows


def _ground_truth(key, files):
    """Risolve ogni voce della chiave nella riga del file generato."""
    out = []
    for row in key:
        text = files.get(row["file"])
        if text is None:
            raise GenerationError("%s: file non generato: %s"
                                  % (row["id"], row["file"]))
        wanted = int(row["occorrenza"])
        matches = [n for n, content in enumerate(text.split("\n"), 1)
                   if row["marcatore"] in content]
        if len(matches) < wanted:
            raise GenerationError("%s: marcatore non trovato in %s: %r"
                                  % (row["id"], row["file"], row["marcatore"]))
        number = matches[wanted - 1]
        excerpt = text.split("\n")[number - 1].strip()
        out.append([row["id"], row["apparato"], row["file"], number,
                    row["categoria"], row["gravita"], row["descrizione"],
                    excerpt])
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(TRUTH_FIELDS)
    writer.writerows(out)
    return buffer.getvalue()


def build(root):
    """Tutti i file generati: {percorso relativo: testo}."""
    lines = T.build_lines()
    week = eventi.Week(lines)
    files = _configs(lines)
    files.update(log_rete.syslog_files(week))
    service_files, dhcp, sip = log_servizi.all_service_logs(week)
    files.update(service_files)
    files["inventario.csv"] = inventario.inventory()
    files["allarmi.csv"] = inventario.alarms_csv(week, dhcp, sip)
    key = _read_key(root)
    if key is not None:
        files[TRUTH_FILE.replace(os.sep, "/")] = _ground_truth(key, files)
    errors = []
    for path in sorted(files):
        errors += canone.controlla_testo(files[path], path)
    if errors:
        raise GenerationError("regole dei dati sintetici violate:\n  "
                              + "\n  ".join(errors[:20]))
    return files


def write(files, target):
    for path in sorted(files):
        full = os.path.join(target, *path.split("/"))
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(files[path])


def _walk(root, top):
    found = []
    for folder, dirs, names in os.walk(os.path.join(root, top)):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(names):
            full = os.path.join(folder, name)
            found.append(os.path.relpath(full, root).replace(os.sep, "/"))
    return found


def check(root):
    files = build(root)
    scratch = tempfile.mkdtemp(prefix="rete-check-")
    try:
        write(files, scratch)
        different = []
        for path in sorted(files):
            mine = os.path.join(root, *path.split("/"))
            fresh = os.path.join(scratch, *path.split("/"))
            if not os.path.isfile(mine):
                different.append("manca: %s" % path)
            elif not filecmp.cmp(mine, fresh, shallow=False):
                different.append("diverso: %s" % path)
        for top in GENERATED_DIRS:
            for path in _walk(root, top):
                if path not in files:
                    different.append("in piu': %s" % path)
    finally:
        shutil.rmtree(scratch)
    for item in different:
        print(item, file=sys.stderr)
    if different:
        print("genera.py --check: %d file non corrispondono" % len(different),
              file=sys.stderr)
        return 1
    print("genera.py --check: %d file identici" % len(files))
    return 0


def check_canon(root):
    errors = []
    count = 0
    for path in _walk(root, "."):
        full = os.path.join(root, *path.split("/"))
        try:
            with open(full, encoding="utf-8") as handle:
                text = handle.read()
        except UnicodeDecodeError:
            errors.append("%s: non e' testo UTF-8" % path)
            continue
        count += 1
        errors += canone.controlla_testo(text, path)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print("genera.py --canone: %d violazioni" % len(errors),
              file=sys.stderr)
        return 1
    print("genera.py --canone: %d file conformi" % count)
    return 0


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true",
                       help="confronta con una rigenerazione temporanea")
    group.add_argument("--canone", action="store_true",
                       help="controlla le regole dei dati sintetici")
    group.add_argument("--out", metavar="DIR",
                       help="cartella di destinazione (predefinita: questa)")
    args = parser.parse_args(argv)
    try:
        if args.check:
            return check(HERE)
        if args.canone:
            return check_canon(HERE)
        target = os.path.abspath(args.out) if args.out else HERE
        files = build(HERE)
        write(files, target)
        print("genera.py: %d file scritti in %s" % (len(files), target))
        return 0
    except (GenerationError, OSError, ValueError) as error:
        print("genera.py: errore: %s" % error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
