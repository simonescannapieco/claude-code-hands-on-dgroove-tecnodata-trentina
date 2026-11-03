---
name: riassunto-modifiche
description: Riassume le modifiche non ancora committate e segnala ciò che è rischioso. Da usare quando si chiede che cosa è cambiato, un messaggio di commit o di rivedere le proprie modifiche.
compatibility: Requires Claude Code and git
---

# Riassunto delle modifiche

## Le modifiche

I file cambiati:

!`git status --short`

La differenza:

!`git diff HEAD`

## Istruzioni

1. Riassumi le modifiche qui sopra in due o tre punti, nominando i file.
2. Elenca i rischi che noti: errori non gestiti, valori scritti nel codice, test da aggiornare.
3. Se non ci sono modifiche, di' che non ci sono modifiche non committate.

## Modello della risposta

```markdown
- <file>: <che cosa è cambiato>

Rischi:
- <il rischio>, oppure «nessuno»
```

## Esempio

```markdown
- src/tariffe.py: la soglia dello sconto passa da 100 a 80 euro.

Rischi:
- test_tariffe.py prova ancora la soglia di 100: il test va aggiornato.
```
