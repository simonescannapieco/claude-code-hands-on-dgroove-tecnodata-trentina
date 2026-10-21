#!/usr/bin/env python3
"""genera_dashboard.py -- la dashboard della settimana, dal file anonimo.

Legge anonimo/ticket-anonimi.csv, calcola i dieci indicatori di
kpi_definizioni.md con le sue regole e scrive dashboard.html: un file solo,
che si apre senza rete, con il CSS e i grafici a barre (SVG) dentro la
pagina, i numeri scritti nel testo e, tutti e dieci gli indicatori, anche in
un blocco <script type="application/json" id="kpi">. Niente script, fogli di
stile, font o immagini da fuori. Lo stesso file dà sempre la stessa pagina.

Uso:    python3 genera_dashboard.py [entrata] [uscita]
          default anonimo/ticket-anonimi.csv e dashboard.html
"""
import csv
import datetime as dt
import html
import json
import os
import statistics
import sys
from decimal import ROUND_HALF_UP, Decimal

ENTRATA = os.path.join("anonimo", "ticket-anonimi.csv")
USCITA = "dashboard.html"
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")

STILE = """
body { font-family: system-ui, sans-serif; margin: 2rem; color: #1f2933;
       background: #f5f7fa; }
h1 { font-size: 1.6rem; margin: 0 0 .25rem; }
h2 { font-size: 1.1rem; margin: 0 0 .75rem; }
.sotto { color: #52606d; margin: 0 0 1.5rem; }
.riquadri { display: grid; gap: 1rem; margin-bottom: 1.5rem;
            grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); }
.riquadro, section { background: #fff; border: 1px solid #d9e2ec;
                     border-radius: .5rem; padding: 1rem 1.25rem; }
section { margin-bottom: 1.5rem; }
.numero { font-size: 1.8rem; font-weight: 600; }
.etichetta { color: #52606d; font-size: .9rem; }
svg text { font-size: 12px; fill: #1f2933; }
.barra { fill: #3e7cb1; }
"""


def arrotonda(valore, decimali):
    """La metà per eccesso; None resta None."""
    if valore is None:
        return None
    passo = Decimal(1).scaleb(-decimali)
    return float(Decimal(valore).quantize(passo, rounding=ROUND_HALF_UP))


def media(valori):
    return Decimal(sum(valori)) / Decimal(len(valori)) if valori else None


def interi(righe, colonna):
    return [int(r[colonna]) for r in righe if r[colonna].strip()]


def indicatori(righe):
    """I dieci indicatori di kpi_definizioni.md."""
    per_giorno = {g: 0 for g in GIORNI}
    per_categoria, per_tecnologia, per_cliente = {}, {}, {}
    for r in righe:
        data = dt.date.fromisoformat(r["aperto_il"].strip()[:10])
        per_giorno[GIORNI[data.weekday()]] += 1
        categoria = r["categoria"].strip()
        if categoria:
            per_categoria[categoria] = per_categoria.get(categoria, 0) + 1
        tecnologia = r["tecnologia"].strip()
        if r["minuti_risoluzione"].strip() and tecnologia:
            per_tecnologia.setdefault(tecnologia, []).append(
                int(r["minuti_risoluzione"]))
        cliente = r["cliente"].strip()
        if cliente:
            per_cliente[cliente] = per_cliente.get(cliente, 0) + 1
    prima = interi(righe, "minuti_prima_risposta")
    voti = interi(righe, "soddisfazione")
    mediana = Decimal(str(statistics.median(prima))) if prima else None
    return {
        "segnalazioni": len(righe),
        "per_giorno": per_giorno,
        "aperte_fine_settimana": sum(1 for r in righe
                                     if not r["chiuso_il"].strip()),
        "annullate": sum(1 for r in righe if r["stato"].strip() == "annullato"),
        "per_categoria": per_categoria,
        "mediana_minuti_prima_risposta": arrotonda(mediana, 1),
        "media_minuti_risoluzione_per_tecnologia": {
            t: arrotonda(media(v), 1) for t, v in per_tecnologia.items()},
        "voti": len(voti),
        "soddisfazione_media": arrotonda(media(voti), 2),
        "clienti_ricorrenti": sum(1 for n in per_cliente.values() if n >= 3),
    }


def numero(valore, decimali=0):
    """Un numero all'italiana, con la virgola: 8,5; un None diventa «—»."""
    if valore is None:
        return "—"
    return ("%.*f" % (decimali, valore)).replace(".", ",")


def riquadro(valore, etichetta):
    return ('<div class="riquadro"><div class="numero">%s</div>'
            '<div class="etichetta">%s</div></div>'
            % (valore, html.escape(etichetta)))


def colonne(voci):
    """Un grafico a barre verticali: voci è un elenco (etichetta, valore)."""
    alto, largo, base = 160, 56, 190
    massimo = max(v for _, v in voci) or 1
    parti = ['<svg role="img" aria-label="segnalazioni per giorno" '
             'width="%d" height="%d">' % (largo * len(voci) + 10, base + 22)]
    for i, (etichetta, valore) in enumerate(voci):
        h = round(alto * valore / massimo)
        x = 10 + i * largo
        parti.append('<rect class="barra" x="%d" y="%d" width="%d" '
                     'height="%d"/>' % (x, base - h, largo - 16, h))
        parti.append('<text x="%d" y="%d" text-anchor="middle">%s</text>'
                     % (x + (largo - 16) // 2, base - h - 4, numero(valore)))
        parti.append('<text x="%d" y="%d" text-anchor="middle">%s</text>'
                     % (x + (largo - 16) // 2, base + 16,
                        html.escape(etichetta)))
    parti.append("</svg>")
    return "\n".join(parti)


def righe_orizzontali(voci, decimali, descrizione):
    """Un grafico a barre orizzontali: voci è un elenco (etichetta,
    valore)."""
    riga, testo, lungo = 24, 200, 300
    massimo = max(v for _, v in voci) or 1
    parti = ['<svg role="img" aria-label="%s" width="%d" height="%d">'
             % (html.escape(descrizione), testo + lungo + 70,
                riga * len(voci) + 6)]
    for i, (etichetta, valore) in enumerate(voci):
        y = 3 + i * riga
        w = round(lungo * valore / massimo)
        parti.append('<text x="%d" y="%d" text-anchor="end">%s</text>'
                     % (testo - 8, y + 15, html.escape(etichetta)))
        parti.append('<rect class="barra" x="%d" y="%d" width="%d" '
                     'height="%d"/>' % (testo, y + 3, w, riga - 8))
        parti.append('<text x="%d" y="%d">%s</text>'
                     % (testo + w + 6, y + 15, numero(valore, decimali)))
    parti.append("</svg>")
    return "\n".join(parti)


def pagina(kpi):
    """La pagina intera, dai dieci indicatori."""
    categorie = sorted(kpi["per_categoria"].items(),
                       key=lambda kv: (-kv[1], kv[0]))
    tecnologie = sorted(kpi["media_minuti_risoluzione_per_tecnologia"].items())
    blocco = json.dumps(kpi, ensure_ascii=False, indent=2, sort_keys=True)
    blocco = blocco.replace("</", "<\\/")
    riquadri = [
        riquadro(numero(kpi["segnalazioni"]), "segnalazioni"),
        riquadro(numero(kpi["aperte_fine_settimana"]),
                 "aperte a fine settimana"),
        riquadro(numero(kpi["annullate"]), "annullate"),
        riquadro(numero(kpi["mediana_minuti_prima_risposta"], 1),
                 "minuti alla prima risposta (mediana)"),
        riquadro(numero(kpi["soddisfazione_media"], 2),
                 "soddisfazione media, su %d voti" % kpi["voti"]),
        riquadro(numero(kpi["clienti_ricorrenti"]),
                 "clienti ricorrenti (almeno 3 segnalazioni)"),
    ]
    return "\n".join([
        "<!DOCTYPE html>",
        '<html lang="it">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>La settimana dell'assistenza clienti</title>",
        "<style>%s</style>" % STILE,
        "</head>",
        "<body>",
        "<h1>La settimana dell'assistenza clienti</h1>",
        '<p class="sotto">%s segnalazioni, dal file anonimo della '
        "settimana.</p>" % numero(kpi["segnalazioni"]),
        '<div class="riquadri">',
        "\n".join(riquadri),
        "</div>",
        "<section>",
        "<h2>Segnalazioni per giorno</h2>",
        colonne([(g, kpi["per_giorno"][g]) for g in GIORNI]),
        "</section>",
        "<section>",
        "<h2>Segnalazioni per categoria</h2>",
        righe_orizzontali(categorie, 0, "segnalazioni per categoria"),
        "</section>",
        "<section>",
        "<h2>Minuti di risoluzione per tecnologia (media)</h2>",
        righe_orizzontali(tecnologie, 1, "minuti di risoluzione per "
                          "tecnologia"),
        "</section>",
        '<script type="application/json" id="kpi">',
        blocco,
        "</script>",
        "</body>",
        "</html>",
        "",
    ])


def main(argv):
    entrata = argv[0] if len(argv) > 0 else ENTRATA
    uscita = argv[1] if len(argv) > 1 else USCITA
    with open(entrata, encoding="utf-8", newline="") as fh:
        righe = list(csv.DictReader(fh))
    kpi = indicatori(righe)
    with open(uscita, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(pagina(kpi))
    print("genera_dashboard: %s scritto, %d segnalazioni." % (uscita,
                                                             len(righe)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
