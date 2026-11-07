---
paths:
  - "progetti/gestionale-php/legacy/**"
---

# Regole per legacy/

- Si corregge un difetto e basta: niente funzionalità nuove (le novità vanno in `src/`).
- Prima di cambiare un comportamento si scrive un test di caratterizzazione che fissa quello attuale, anche se sbagliato.
- Mai una riformattazione insieme a una correzione: due commit o due pull request distinte.
- Il titolo della pull request dice che si tratta di una correzione in `legacy/`.
