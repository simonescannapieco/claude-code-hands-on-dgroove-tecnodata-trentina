# Prima del corso

Circa un quarto d'ora di preparazione se avete già Docker (o PHP 8.3 o
successivo con Composer) e, su Windows, WSL 2 con una distribuzione Linux;
di più se dovete installarli: installare WSL 2 richiede anche un riavvio
del computer. Da
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
  quelle qui sopra: la guida dà i comandi per Ubuntu e per Debian. Tutto,
  cioè git, Claude Code,
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
  riavviate il computer: il comando installa WSL 2 con Ubuntu. Poi create
  il vostro utente Linux (il paragrafo «Il primo avvio: utente e
  password»).
- **WSL c'è, ma non una distribuzione Linux**, oppure preferite Debian a
  Ubuntu: `wsl --list --online` (in breve `wsl -l -o`) elenca i nomi delle
  distribuzioni disponibili, e `wsl --install -d Ubuntu`, oppure
  `wsl --install -d Debian`, installa quella che scegliete. Si fa così
  anche quando `wsl --install` mostra soltanto l'aiuto di WSL. Ubuntu e
  Debian vanno ugualmente bene: da qui in poi i comandi sono gli stessi, e
  dove la guida scrive `<distribuzione>` va il nome che avete scelto.
- **La distribuzione è in WSL 1** (`1` nella colonna della versione):
  convertitela con `wsl --set-version <distribuzione> 2`, con il nome che
  mostra `wsl -l -v`, per esempio `wsl --set-version Ubuntu 2`.

Su Windows non serve installare altro per Claude Code, nemmeno Git for
Windows: si lavora tutto dentro la distribuzione. I dettagli
dell'installazione di WSL sono nella pagina di Microsoft
[How to install Linux on Windows with WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

Per impostazione predefinita WSL 2 assegna alla distribuzione il 50% della
memoria di Windows, e Claude Code chiede almeno 4 GB di RAM: su un computer
con 8 GB o più la distribuzione ne riceve almeno 4. Il limite si cambia con
l'impostazione `memory` di `.wslconfig`, descritta nella pagina di Microsoft
[Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

### Il primo avvio: utente e password

Alla prima apertura di una distribuzione appena installata (si apre da sola
alla fine di `wsl --install`; poi dal menu Start, scrivendone il nome, o da
Windows Terminal) la finestra impiega un po' a decomprimere i file, e poi
vi chiede un nome utente e una password per Linux. Valgono soltanto per
quella distribuzione e non hanno a che fare con il vostro account Windows.
Mentre scrivete la password non compare nulla sullo schermo: è normale.
Quell'account è l'amministratore Linux, e può usare `sudo`. Da qui in poi
ogni comando si dà nel terminale della distribuzione, salvo dove la guida
dice PowerShell.

Controllate che `sudo` funzioni:

    sudo whoami

Chiede la vostra password e risponde `root`. Se invece `sudo` non risponde
(`command not found`) o dice che il vostro utente non può usarlo, si
rimedia da PowerShell, entrando nella distribuzione come `root`:

    wsl -d <distribuzione> -u root
    apt-get update && apt-get install -y sudo
    gpasswd -a <nome_utente> sudo
    exit
    wsl --terminate <distribuzione>

`<nome_utente>` è quello scelto al primo avvio; la riga di `apt-get`
serve soltanto se `sudo` non è installato. Poi riaprite la distribuzione e
ripetete `sudo whoami`.

### Aggiornare la distribuzione e installare gli strumenti di base

Windows non aggiorna da solo le distribuzioni Linux. Nel terminale della
distribuzione (su Linux, nel vostro):

    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get autoremove -y && sudo apt-get autoclean
    sudo apt-get install -y curl git

`update` aggiorna l'elenco dei pacchetti, `upgrade` porta i pacchetti
installati all'ultima versione, `autoremove` e `autoclean` tolgono ciò che
non serve più. `curl` serve agli installer di Claude Code e di uv, e una
distribuzione appena installata può non averlo; git serve al repository
delle esercitazioni. I comandi `apt-get` di questa pagina valgono per
Ubuntu e Debian, in WSL come su Linux.

### Entrare, uscire, ricominciare da capo

- **Entrare** nella distribuzione: dal menu Start, da Windows Terminal,
  oppure da PowerShell con `wsl -d <distribuzione>`. Si esce con `exit`.
- **Vedere che cosa è installato**, e con quale versione di WSL: `wsl -l -v`.
- **Ricominciare da capo**, soltanto se serve:
  `wsl --unregister <distribuzione>` toglie la distribuzione da WSL e
  cancella in modo definitivo tutti i suoi dati, le impostazioni e i
  programmi: anche Claude Code, il repository delle esercitazioni e gli
  spazi di lavoro che stanno al suo interno. Poi si reinstalla con
  `wsl --install -d <distribuzione>` e si rifà questa pagina dall'inizio.

## L'editor: Visual Studio Code

L'editor consigliato è Visual Studio Code. Su Windows 10 o 11 con WSL 2 si
consigliano due estensioni:

- **WSL**, di Microsoft: apre le cartelle della distribuzione WSL 2 in
  Visual Studio Code, in modo che i file si modifichino dove stanno, dentro
  la distribuzione;
- **XLSX, CSV, TSV & Markdown Editor**: per aprire e modificare i file
  `.xlsx`, `.csv`, `.tsv` e Markdown.

## git

`git --version` deve rispondere. Se manca, si installa con il gestore di
pacchetti della distribuzione: su Ubuntu e Debian
`sudo apt-get install -y git`.

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
lo mette, `~/.local/bin`, non è ancora nel PATH. In quel caso l'installer
stesso, alla fine, stampa il comando da dare:

    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

Gli altri casi li tratta la pagina ufficiale
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

Per PHP e Composer, su Ubuntu e Debian:

    sudo apt-get install -y php-cli php-sqlite3 php-xml php-mbstring php-zip unzip composer

Sono l'interprete, le estensioni che servono al gestionale e ai suoi test,
`unzip` (che Composer usa per scompattare i pacchetti) e Composer. Non
installate il pacchetto `php`: porta con sé anche il server web Apache.
Controllate le tre estensioni principali con:

    php -m | grep -E '^(dom|mbstring|pdo_sqlite)$'

che deve stampare tre righe. Ubuntu 24.04 o successiva e Debian 13 hanno
PHP 8.3 o successivo nei loro pacchetti; se `php --version` mostra una
versione precedente, o il gestore di pacchetti della vostra distribuzione
non offre PHP 8.3 o successivo, scegliete Docker. Per Docker:

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
Se `python3` manca, si installa con il gestore di pacchetti della
distribuzione: su Ubuntu e Debian `sudo apt-get install -y python3`. Per uv
c'è l'installer ufficiale:

    curl -LsSf https://astral.sh/uv/install.sh | sh

Poi aprite un nuovo terminale e date `uv --version`; senza aprirlo, basta
`source $HOME/.local/bin/env`. Gli altri metodi sono nella pagina
[Installing uv](https://docs.astral.sh/uv/getting-started/installation/).
Non usate `pip install uv`: su Ubuntu e Debian recenti il sistema rifiuta
(`externally-managed-environment`) di installare pacchetti con pip fuori da
un ambiente virtuale, e forzarlo con `--break-system-packages` rischia di
guastare il Python della distribuzione.

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
