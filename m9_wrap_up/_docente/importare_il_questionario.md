# Importare il questionario in Moodle

Per il docente: una volta per edizione, prima dell'aula. I nomi sono quelli dell'interfaccia inglese di Moodle 4.5; su una piattaforma in italiano conviene passare all'inglese, dal menu utente (**Language**), per questi passi.

1. Nel corso si aggiunge un'attività **Feedback** intitolata *Questionario di gradimento*: è il nome che i partecipanti cercano, e che la slide del Modulo 9 dice. Nelle impostazioni, in **Question and submission settings**, **Record user names** su *Anonymous* e **Allow multiple submissions** su *No*.
2. Nella scheda **Questions** dell'attività, menu **Actions** → **Import questions**; si sceglie `m9_wrap_up/questionario/questionario-gradimento.xml` e si preme **Import**. Solo su un'attività ancora senza risposte: l'opzione già scelta, *Delete old items*, cancella le domande e tutte le risposte date.
3. Nella scheda **Questions** si controlla il risultato: 27 domande e 7 testi, la scala da 1 a 5; le domande sui moduli 1–8 e quella sul piano Pro si possono lasciare vuote, le altre no.
4. Le risposte si leggono nella scheda **Analysis**, con le medie delle domande a punteggio; una domanda lasciata vuota non entra nella media.

**Il file non è stato provato su una piattaforma Moodle vera.** Segue il formato che Moodle stesso esporta e importa (`mod/feedback/export.php` e `import.php` di Moodle 4.5), e `controlla_materiali.py` ne controlla la forma, ma la prima importazione è anche la sua prova. Se non riesce, il ripiego: le domande di `questionario-gradimento.md`, inserite a mano nell'attività, una decina di minuti.

Il testo delle domande si cambia in `genera_questionario.py`, poi `python3 -B -I genera_questionario.py` riscrive i due file; `test_m9_materiali.sh` controlla che siano quelli generati.
