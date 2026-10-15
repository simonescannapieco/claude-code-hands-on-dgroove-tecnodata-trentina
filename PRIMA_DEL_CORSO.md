# Prima del corso

Circa un quarto d'ora di preparazione, da fare prima della prima sessione,
in ordine, dall'inizio alla fine. Si finisce con `tools/verifica_ambiente.sh`
che risponde «Tutto pronto per il corso.».

## Che cosa serve

- **Un abbonamento Claude Pro.** Claude Code richiede un account Pro, Max,
  Team, Enterprise o Console: il piano gratuito di claude.ai non lo include.
- **Un computer** con almeno 4 GB di RAM, un processore x64 o ARM64 e una
  connessione a internet.
- **Linux, oppure Windows con WSL 2**: il paragrafo qui sotto.

## Linux o Windows con WSL 2

Il corso presuppone uno di due ambienti, e tutti i comandi di questa pagina
si danno nel suo terminale:

- **Linux**: Ubuntu 20.04 o successivo, Debian 10 o successivo, oppure
  Alpine Linux 3.19 o successivo.
- **Windows 10 o 11 con WSL 2**, con dentro una distribuzione Linux tra
  quelle qui sopra (per esempio Ubuntu). Tutto, cioè git, Claude Code,
  Docker oppure PHP con Composer, Python e uv, si installa e si usa *dentro*
  la distribuzione, dal suo terminale, non da PowerShell o da CMD.

macOS, Windows senza WSL 2 (PowerShell, CMD, Git Bash) e WSL 1 non sono
ambienti del corso.

## git

`git --version` deve rispondere. Se manca, si installa con il gestore di
pacchetti della distribuzione.

## Installare Claude Code

Nel terminale (su Windows, quello della distribuzione WSL 2):

    curl -fsSL https://claude.ai/install.sh | bash

È l'installazione nativa, quella consigliata, e si aggiorna da sola in
background. In WSL si usa proprio questo installer per Linux: `claude` si
installa e si avvia dentro il terminale WSL.

Controllo: `claude --version` stampa la versione installata; `claude doctor`
stampa una diagnostica dell'installazione e delle impostazioni, in sola
lettura e senza avviare una sessione.

## Accedere con l'abbonamento Pro

Lanciate `claude` e seguite le istruzioni nel browser, accedendo con il
vostro account claude.ai. Se dopo l'accesso il browser mostra un codice
invece di tornare al terminale, incollatelo nel terminale: in WSL2 succede
spesso.

Dentro Claude Code, `/status` mostra quale metodo di autenticazione è
attivo; `/logout` esce, per poi accedere di nuovo.

## La chiave API non serve

Il piano Pro non include l'uso dell'API, e per il corso la chiave API non
serve. Anzi, non va impostata: se nell'ambiente c'è la variabile
`ANTHROPIC_API_KEY`, Claude Code, una volta che approvate, usa la chiave al
posto dell'abbonamento, e con `claude -p` la usa sempre.

Controllate così (il comando non stampa mai la chiave):

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo impostata; else echo "non impostata"; fi

Se è impostata, toglietela dal file di avvio della shell in cui la
definite (per esempio `~/.bashrc`) e, nel terminale già aperto, date
`unset ANTHROPIC_API_KEY`: Claude Code torna all'abbonamento.

## Docker, oppure PHP e Composer

Gli esercizi sul gestionale in PHP passano da `tools/php.sh`: usa PHP 8.3 o
successivo con Composer se li trova, altrimenti le immagini Docker ufficiali
di PHP e di Composer. Serve una delle due strade, sempre nel terminale
Linux o della distribuzione WSL 2:

- **Docker** con il servizio attivo: `docker version` mostra anche la parte
  «Server». La prima volta `tools/php.sh` scarica le immagini;
- oppure **PHP 8.3 o successivo** con **Composer**: `php --version` e
  `composer --version` devono rispondere.

## Python e uv

Servono Python 3.8 o successivo (`python3 --version`) e uv (`uv --version`),
il gestore di ambienti e pacchetti Python con cui girano gli script Python
del corso. Installateli seguendo le istruzioni ufficiali di ciascuno.

## Il repository delle esercitazioni

Il repository delle esercitazioni è online, su GitHub. Clonatelo ed
entrate nella sua cartella:

    git clone https://github.com/simonescannapieco/claude-code-hands-on-dgroove-tecnodata-trentina esercitazioni
    cd esercitazioni

In WSL 2 clonatelo nella cartella di casa della distribuzione (prima un
`cd ~`), non sotto `/mnt/c`. Tutti i comandi delle esercitazioni partono
dalla cartella `esercitazioni`.

Durante il corso il docente aggiunge al repository le demo e gli esercizi
dei moduli: per averli, `git pull` nella cartella `esercitazioni`. Il
vostro lavoro non ne risente, perché sta negli spazi di lavoro che
`tools/prepara_esercizio.sh` crea fuori dal repository
(`~/corso-claude-code/`).

## Il controllo finale

Dalla cartella `esercitazioni`:

    tools/verifica_ambiente.sh

Controlla il sistema operativo, Claude Code, la variabile
`ANTHROPIC_API_KEY`, git, PHP o Docker, Python e uv; di Claude Code esegue
soltanto `claude --version`, senza nessun prompt. Deve finire con «Tutto
pronto per il corso.». Se no, elenca che cosa sistemare e in quale
paragrafo di questa pagina: sistemate e rilanciatelo.
