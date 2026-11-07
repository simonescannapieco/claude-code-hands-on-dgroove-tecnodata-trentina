---
paths:
  - "progetti/gestionale-php/legacy/**"
---

# Il codice legacy

- In `legacy/` valgono solo le regole della sezione 9 di `docs/convenzioni.md`: leggile prima di cambiare un file.
- Si corregge un difetto o si sposta logica in `src/`; le funzionalità nuove vanno in `src/`.
- Prima di cambiare un comportamento, un test di caratterizzazione fissa il comportamento attuale.
- Una riformattazione va in un commit suo, mai insieme a una correzione.
