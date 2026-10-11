# Confronto: lo stesso prompt su tre modelli

Prompt usato: prompt/sistemi.md

| modello | secondi | token in entrata | token in uscita | che cosa cambia nella risposta |
|---|---|---|---|---|
| haiku | 5.6 | 1544 | 926 | corretta e completa, lunga quanto quella di Sonnet (circa 200 parole): dei 926 token in uscita, 400 sono di ragionamento, che nella risposta non compare; aggiunge che un cliente business può avere più ONT, da verificare in anagrafica |
| sonnet | 5.6 | 1546 | 562 | corretta e ordinata; prudente sul numero dei clienti, da confermare contando le righe; chiama la porta «1/3» invece di 0/1/3 |
| opus | 5.5 | 1542 | 393 | corretta e la più asciutta: porta 0/1/3, un solo guasto a monte, primo controllo sull'ottica dell'OLT |

Per questo compito sceglierei: sonnet

Perché: le tre risposte dicono la stessa cosa sostanziale; Sonnet la dice in ordine e con la prudenza giusta sui numeri, Opus è più asciutto ma consuma più quota, Haiku spende più token di tutti per una risposta lunga quanto quella di Sonnet.
