# Prima del corso

Circa un quarto d'ora di preparazione se avete già Docker (o PHP 8.3 o
successivo con Composer) e, su Windows, WSL 2; di più se dovete
installarli: installare WSL 2 richiede anche un riavvio del computer. Da
fare prima della prima sessione, in ordine, dall'inizio alla fine. Si
finisce con `tools/verifica_ambiente.sh` che risponde «Tutto pronto per il
corso.».

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
  Docker oppure PHP con Composer, Python e uv, si usa *dentro* la
  distribuzione, dal suo terminale, non da PowerShell o da CMD, e lì si
  installa; soltanto Docker Desktop, se lo scegliete, si installa in
  Windows e si collega alla distribuzione (il paragrafo «Docker, oppure
  PHP e Composer»).

macOS, Windows senza WSL 2 (PowerShell, CMD, Git Bash) e WSL 1 non sono
ambienti del corso.

Su Windows, controllate WSL 2 da PowerShell con `wsl -l -v`: elenca le
distribuzioni installate, e quella che userete deve avere `2` nella
colonna della versione. Conta una distribuzione Linux come
Ubuntu, non `docker-desktop`, che è quella di Docker Desktop.

- **WSL non c'è**: serve Windows 10 versione 2004 (build 19041) o
  successiva, oppure Windows 11. Aprite PowerShell come amministratore
  (tasto destro, «Esegui come amministratore»), date `wsl --install` e
  riavviate il computer: il comando installa WSL 2 con Ubuntu. Poi, in
  Ubuntu, create un nome utente e una password per Linux.
- **La distribuzione è in WSL 1** (`1` nella colonna della versione):
  convertitela con `wsl --set-version <distribuzione> 2`, con il nome che
  mostra `wsl -l -v`, per esempio `wsl --set-version Ubuntu 2`.

I dettagli, e che cosa fare se `wsl --install` mostra soltanto l'aiuto di
WSL, sono nella pagina di Microsoft
[How to install Linux on Windows with WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## git

`git --version` deve rispondere. Se manca, si installa con il gestore di
pacchetti della distribuzione.

## Installare Claude Code

Nel terminale (su Windows, quello della distribuzione WSL 2):

    curl -fsSL https://claude.ai/install.sh | bash

È l'installazione nativa, quella consigliata, e si aggiorna da sola in
background. In WSL si usa proprio questo installer per Linux: `claude` si
installa e si avvia dentro il terminale WSL.

Il comando non mostra l'avanzamento mentre scarica Claude Code. Quando ha
finito, aprite un nuovo terminale e date `claude --version`: stampa la
versione installata. Se invece il terminale risponde che `claude` non si
trova (`bash: claude: command not found`), la cartella in cui l'installer
lo mette, `~/.local/bin`, non è ancora nel PATH: che cosa fare lo dice la
pagina ufficiale
[`command not found: claude` after installation](https://code.claude.com/docs/en/troubleshoot-install#command-not-found-claude-after-installation).

`claude doctor` stampa una diagnostica dell'installazione e delle
impostazioni, in sola lettura e senza avviare una sessione.

## La chiave API non serve

Il piano Pro non include l'uso dell'API, e per il corso la chiave API non
serve. Anzi, non va impostata, e conviene controllarlo prima di accedere:
se nell'ambiente c'è la variabile `ANTHROPIC_API_KEY`, al primo avvio
Claude Code chiede se usare la chiave e, se approvate, può saltare
l'accesso; da lì usa la chiave al posto dell'abbonamento, e con
`claude -p` la usa sempre.

Controllate così (il comando non stampa mai la chiave):

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo impostata; else echo "non impostata"; fi

Se è impostata, toglietela dal file di avvio della shell in cui la
definite (per esempio `~/.bashrc`) e, nel terminale già aperto, date
`unset ANTHROPIC_API_KEY`: Claude Code torna all'abbonamento.

## Accedere con l'abbonamento Pro

Lanciate `claude` e seguite le istruzioni nel browser, accedendo con il
vostro account claude.ai. Se dopo l'accesso il browser mostra un codice
invece di tornare al terminale, incollatelo nel terminale: in WSL2 succede
spesso.

Dentro Claude Code, `/status` mostra quale metodo di autenticazione è
attivo; `/logout` esce, per poi accedere di nuovo.

## Docker, oppure PHP e Composer

Gli esercizi sul gestionale in PHP passano da `tools/php.sh`: usa PHP 8.3 o
successivo con Composer se li trova, altrimenti le immagini Docker ufficiali
di PHP e di Composer. Serve una delle due strade, sempre nel terminale
Linux o della distribuzione WSL 2:

- **Docker** con il servizio attivo: `docker version` mostra anche la parte
  «Server». La prima volta `tools/php.sh` scarica le immagini;
- oppure **PHP 8.3 o successivo** con **Composer**: `php --version` e
  `composer --version` devono rispondere.

Se il gestore di pacchetti della vostra distribuzione non offre PHP 8.3 o
successivo, scegliete Docker. Per Docker:

- **su Linux, con Docker Engine**, il vostro utente deve stare nel gruppo
  `docker`, altrimenti `docker` funziona soltanto con `sudo`: date
  `sudo usermod -aG docker $USER`, poi uscite dalla sessione e rientrate.
  Il gruppo `docker` dà privilegi pari a quelli di root: i dettagli sono
  nella pagina di Docker
  [Linux post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user);
- **su Windows, con Docker Desktop**, in *Settings > Resources > WSL
  Integration* attivate l'integrazione per la vostra distribuzione e
  confermate con *Apply*: così `docker` risponde nel suo terminale. Docker
  Desktop non va affiancato a un Docker Engine installato dentro la
  distribuzione; i dettagli sono nella pagina di Docker
  [Docker Desktop WSL 2 backend on Windows](https://docs.docker.com/desktop/features/wsl/#enable-docker-in-a-wsl-2-distribution).

## Python e uv

Servono Python 3.8 o successivo con il comando `python3`
(`python3 --version`), quello con cui si lanciano gli script Python delle
esercitazioni, e uv, il gestore di pacchetti e di progetti Python: il
corso lo chiede, e il controllo finale lo cerca con `uv --version`.
Python si installa con il gestore di pacchetti della distribuzione; uv
seguendo la sua pagina ufficiale,
[Installing uv](https://docs.astral.sh/uv/getting-started/installation/).

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

Controlla il sistema operativo, Claude Code e il vostro accesso, la
variabile `ANTHROPIC_API_KEY`, git, PHP o Docker, Python e uv. Di Claude
Code esegue soltanto `claude --version` e `claude auth status`, che mostra
lo stato dell'autenticazione, senza nessun prompt; dell'accesso considera
soltanto se c'è e con quale metodo, e non stampa né l'e-mail né
l'organizzazione dell'account. La riga dell'accesso è in ordine quando
dice «accesso: con l'abbonamento (claude.ai)». Il controllo deve finire
con «Tutto pronto per il corso.». Se no, elenca che cosa sistemare e in
quale paragrafo di questa pagina: sistemate e rilanciatelo.
