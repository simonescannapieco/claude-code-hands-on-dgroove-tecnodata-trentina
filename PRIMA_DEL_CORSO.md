# Prima del corso

Questa pagina prepara il vostro computer per le esercitazioni di «Claude e
Claude Code in pratica — Corso base». Alla fine `tools/verifica_ambiente.sh`
controlla che non manchi niente.

## Che cosa serve

- **Un abbonamento Claude Pro.** Claude Code richiede un account Pro, Max,
  Team, Enterprise o Console: il piano gratuito di claude.ai non lo include.
- **Un computer** con macOS 13.0 o successivo, Windows 10 1809 o successivo
  (oppure Windows Server 2019 o successivo), Ubuntu 20.04 o successivo,
  Debian 10 o successivo, oppure Alpine Linux 3.19 o successivo; almeno 4 GB
  di RAM, un processore x64 o ARM64 e una connessione a internet.
- **git**, **Docker** (oppure PHP 8.3 o successivo con Composer), **Python 3
  con uv**: i paragrafi qui sotto.

## Installare Claude Code

**macOS, Linux, WSL** — da un terminale:

    curl -fsSL https://claude.ai/install.sh | bash

È l'installazione nativa, quella consigliata, e si aggiorna da sola in
background.

### Windows

Su Windows Claude Code gira in modo nativo oppure dentro WSL.

- **Windows nativo**, da PowerShell:

      irm https://claude.ai/install.ps1 | iex

  oppure dal Prompt dei comandi (CMD):

      curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd

  Non servono diritti di amministratore. Git for Windows è facoltativo per
  Claude Code: porta Git Bash, che il Bash tool di Claude Code usa; senza,
  Claude Code esegue i comandi con il PowerShell tool.
- **WSL**: si usa l'installer per Linux (il comando `curl` del paragrafo
  sopra), e `claude` si installa e si avvia dentro il terminale WSL, non da
  PowerShell o da CMD.

Gli script del corso (`tools/*.sh` e i `verifica.sh` degli elementi) sono
bash: su Windows lanciateli da WSL 2 oppure da Git Bash.

### Altri modi di installare

Con Homebrew (`brew install --cask claude-code`) o con WinGet
(`winget install Anthropic.ClaudeCode`): queste due installazioni non si
aggiornano da sole. Su Debian, Fedora, RHEL e Alpine anche dai repository
apt, dnf o apk. Oppure il pacchetto npm globale `@anthropic-ai/claude-code`,
che richiede Node.js 22 o successivo: mai con `sudo npm install -g`.

### Controllo

`claude --version` stampa la versione installata. `claude doctor` stampa
una diagnostica dell'installazione e delle impostazioni, in sola lettura e
senza avviare una sessione.

## Accedere con l'abbonamento Pro

Lanciate `claude` in un terminale e seguite le istruzioni nel browser,
accedendo con il vostro account claude.ai. Se dopo l'accesso il browser
mostra un codice invece di tornare al terminale, incollatelo nel terminale:
succede spesso in WSL2, nelle sessioni SSH e nei container.

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
definite (per esempio `~/.bashrc` o `~/.zshrc`) e, nel terminale già aperto,
date `unset ANTHROPIC_API_KEY`: Claude Code torna all'abbonamento.

## git

Serve git: `git --version` deve rispondere. Si installa con il gestore di
pacchetti del sistema o dal sito di git; su Windows con Git for Windows, che
porta anche Git Bash.

## Docker, oppure PHP e Composer

Gli esercizi sul gestionale in PHP passano da `tools/php.sh`: usa PHP 8.3 o
successivo con Composer se li trova sul computer, altrimenti le immagini
Docker ufficiali di PHP e di Composer. Serve quindi una delle due strade:

- **Docker** con il servizio attivo: `docker version` mostra anche la parte
  «Server». La prima volta `tools/php.sh` scarica le immagini;
- oppure **PHP 8.3 o successivo** con **Composer**: `php --version` e
  `composer --version` devono rispondere.

## Python e uv

Servono Python 3.8 o successivo (`python3 --version`) e uv (`uv --version`),
il gestore di ambienti e pacchetti Python con cui girano gli script Python
del corso. Installateli seguendo le istruzioni ufficiali di ciascuno.

## Il repository delle esercitazioni

Il docente vi consegna il repository: una cartella pronta, oppure un file
`.bundle` da clonare con

    git clone <file>.bundle esercitazioni

Aprite un terminale nella cartella del repository: i comandi delle
esercitazioni partono tutti da lì.

## Il controllo finale

    tools/verifica_ambiente.sh

Su Windows lanciatelo da WSL 2 o da Git Bash. Controlla il sistema
operativo, Claude Code, la variabile `ANTHROPIC_API_KEY`, git, PHP o Docker,
Python e uv; di Claude Code esegue soltanto `claude --version`, senza nessun
prompt. Esce con 0 se c'è tutto; altrimenti elenca che cosa sistemare e in
quale paragrafo di questa pagina.
