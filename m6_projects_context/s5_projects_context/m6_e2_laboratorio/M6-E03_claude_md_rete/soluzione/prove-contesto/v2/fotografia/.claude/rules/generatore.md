---
paths:
  - progetti/rete/generatore/**
---

# Modifiche al generatore

- Dopo ogni modifica si rigenera con `python3 progetti/rete/genera.py` (dalla radice), poi si rifanno `--check` e `--canone`.
- I file rigenerati vanno nello stesso commit della modifica.
- Un apparato nuovo si aggiunge in `progetti/rete/generatore/topologia.py`; dopo la rigenerazione si controlla che la sua configurazione esca nel dialetto giusto.
