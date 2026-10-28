# M4-D01 — La chiave che scavalca il Pro

Demo del Modulo 4, nella parte «Installare e configurare». In aula il
docente la fa girare, poi la rifate voi: non c'è nessuna chiamata al
modello, quindi potete ripeterla quando volete.

## Obiettivo

Vedere la trappola della chiave API: con `ANTHROPIC_API_KEY`
nell'ambiente, Claude Code smette di usare l'abbonamento e usa la chiave,
anche se avete fatto l'accesso. Due esecuzioni dello stesso comando,
`claude auth status --json`, che mostra lo stato dell'autenticazione
senza mandare nessun prompt: la prima senza la variabile, la seconda con
una chiave finta impostata per quel solo comando. Differiscono soltanto
nella chiave.

## Tempo

4 minuti in aula: 2 per la demo del docente, con la registrazione, e 2
per la vostra prova. Chi non finisce in aula continua da solo, con questo
README: i passi sono gli stessi. Circa 3 minuti per rifarla da soli.

## Prerequisiti

- Claude Code collegato al piano Pro, con `tools/verifica_ambiente.sh`
  tutto verde (`PRIMA_DEL_CORSO.md`).
- Python 3, che lo stesso controllo verifica.
- Nessuna chiave vera: quella della prova è finta,
  `finta-chiave-del-corso`, e non apre niente.

## Punto di partenza (tools/prepara_esercizio.sh M4-D01)

Lo spazio di lavoro `~/corso-claude-code/M4-D01/` con:

- `controlla_accesso.py`: con `--salva <file>` legge l'uscita di
  `claude auth status --json` e ne salva soltanto tre campi,
  `loggedIn`, `authMethod` e `apiKeySource`; senza argomenti confronta
  le due esecuzioni salvate e dice l'esito;
- `.claude/settings.json`: le impostazioni prudenti del repository.

`claude auth status --json` stampa anche l'e-mail, l'organizzazione e
altri dati dell'account. Per questo, nella prova, la sua uscita passa
sempre da `controlla_accesso.py --salva`, che li scarta senza mostrarli:
nessun file della prova li contiene, e nessuna riga a schermo.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M4-D01
       cd ~/corso-claude-code/M4-D01

2. Controllate che nel terminale la chiave non ci sia (il comando non
   stampa mai la chiave):

       if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo impostata; else echo "non impostata"; fi

   Deve dire «non impostata». Se dice «impostata», seguite prima il
   paragrafo «La chiave API non serve» di `PRIMA_DEL_CORSO.md`.

3. Le due esecuzioni. `env -u ANTHROPIC_API_KEY` toglie la variabile per
   il comando che segue; `env ANTHROPIC_API_KEY=…` la imposta per quel
   solo comando, senza esportarla:

       env -u ANTHROPIC_API_KEY claude auth status --json \
         | python3 controlla_accesso.py --salva stato/senza.json
       env ANTHROPIC_API_KEY=finta-chiave-del-corso claude auth status --json \
         | python3 controlla_accesso.py --salva stato/con.json

   Ogni riga «Salvato …» dice i tre campi tenuti.

4. Che cosa dice la prova, e di nuovo il controllo del passo 2:

       python3 controlla_accesso.py
       if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo impostata; else echo "non impostata"; fi

   La seconda riga dice ancora «non impostata»: la chiave finta è esistita
   soltanto per il comando che la nominava.

5. In Claude Code: aprite una sessione nello spazio di lavoro, date
   `/status` e guardate il metodo di accesso, poi `/exit`. Nessun
   messaggio a Claude:

       claude

6. Verificate, dalla cartella `esercitazioni`:

       cd -
       tools/verifica.sh M4-D01

`_docente/live.sh`, la prova del docente, esegue gli stessi due comandi
del passo 3 e poi la verifica.

## Che cosa osservare

### Che cosa dice Anthropic

- Nel riferimento delle variabili d'ambiente di Claude Code, su
  `ANTHROPIC_API_KEY`: «When set, this key is used instead of your Claude
  Pro, Max, Team, or Enterprise subscription even if you are logged in.»
  Quando è impostata, la chiave si usa al posto dell'abbonamento, anche
  se avete fatto l'accesso.
  https://code.claude.com/docs/en/env-vars
- Nella pagina sull'autenticazione, per `claude -p`: «In non-interactive
  mode (-p), the key is always used when present.» In modalità non
  interattiva la chiave, se c'è, si usa sempre. In una sessione
  interattiva Claude Code chiede prima: «If you have an active Claude
  subscription but also have ANTHROPIC_API_KEY set in your environment,
  Claude Code uses the API key once you approve it.» Nella stessa pagina,
  l'ordine con cui sceglie fra più credenziali mette la chiave prima
  dell'abbonamento: «When multiple credentials are present, Claude Code
  chooses one in this order … 3. ANTHROPIC_API_KEY environment variable …
  7. Subscription OAuth credentials from /login.»
  https://code.claude.com/docs/en/authentication
- Che cosa costa, nel centro assistenza: «Claude Code will use this API
  key for authentication instead of your Claude subscription (Pro, Max,
  Team, or Enterprise plans), resulting in API usage charges». L'uso si
  paga come uso dell'API, fuori dal piano.
  https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
- E come se ne esce, ancora nella pagina sull'autenticazione: «Run unset
  ANTHROPIC_API_KEY to fall back to your subscription, and check /status
  to confirm which method is active.»
  https://code.claude.com/docs/en/authentication

Il comando della prova, nel riferimento della CLI: `claude auth status`
«Show authentication status as JSON. Use --text for human-readable
output. Exits with code 0 if logged in, 1 if not.», e «The JSON's
authMethod field is one of none, claude.ai, oauth_token, api_key,
api_key_helper, or third_party»
(https://code.claude.com/docs/en/cli-reference). Mostra lo stato
dell'autenticazione e non manda prompt: la prova non chiama il modello e
non lancia `claude -p`. La frase su `-p` spiega perché gli script del
corso tolgono `ANTHROPIC_API_KEY` dall'ambiente prima di ogni `claude -p`.

### Che cosa misura il controllo

`controlla_accesso.py` legge `stato/senza.json` e `stato/con.json` e
stampa, per ciascuno, se Claude Code risulta collegato (`loggedIn`), con
quale metodo (`authMethod`) e, quando c'è, da dove viene la chiave
(`apiKeySource`). Poi l'esito: confermata se senza la chiave il metodo è
`claude.ai`, cioè l'abbonamento, e con la chiave è `api_key`, con
`apiKeySource` uguale a `ANTHROPIC_API_KEY`; altrimenti non confermata in
questa esecuzione. È una garanzia del prodotto: deve valere a ogni
esecuzione, e se non vale la verifica esce con 1.

Se già senza la chiave il metodo non è `claude.ai` (nessun accesso, o un
accesso di altro tipo), la prova non ha il suo punto di partenza e il
controllo esce con 2, la precondizione: si parte da un accesso con
l'abbonamento. Un file con campi in più, salvato senza `--salva`, non
vale: il controllo non ne stampa il contenuto e chiede di rifare quel
passo.

Nella registrazione del corso (28 ottobre 2026, Claude Code 2.1.312,
sull'account del docente, nessuna chiamata al modello): senza la chiave,
«collegato sì · metodo claude.ai»; con la chiave finta per quel solo
comando, «collegato sì · metodo api_key · chiave da ANTHROPIC_API_KEY».
«Con ANTHROPIC_API_KEY impostata, Claude Code usa la chiave al posto
dell'abbonamento»: confermata. I due file sono nella cartella
`soluzione/stato/` di questo elemento.

## Verifica (tools/verifica.sh M4-D01)

La verifica fa girare `controlla_accesso.py` dell'elemento sui due file di
`stato/` dello spazio di lavoro, senza chiamare `claude` e senza scrivere
niente. È fatta quando i due file ci sono e la garanzia è confermata;
l'ultima riga è «Fatto: ogni affermazione è stata messa alla prova; gli
esiti sono qui sopra.»

## Se qualcosa va storto

- `--salva` dice che l'ingresso non è il JSON di `claude auth status`: il
  comando prima della pipe non ha risposto. Rifate il passo 3 riga per
  riga; se l'errore resta, `claude auth status --text` mostra lo stato in
  chiaro sul vostro terminale.
- Il controllo esce con 2 e dice che senza la chiave Claude Code non usa
  l'abbonamento: accedete con `claude`, come in `PRIMA_DEL_CORSO.md`
  («Accedere con l'abbonamento Pro»), poi rifate i passi 3 e 4.
- Il controllo dice che un file ha campi in più: è stato salvato con
  l'uscita intera di `claude auth status`, senza `--salva`. Cancellatelo
  e rifate il passo 3 così com'è.
- In una sessione vera, con l'abbonamento attivo, compare «This
  organization has been disabled»: secondo la guida ai problemi di
  installazione è il segno di una chiave nell'ambiente, «"This
  organization has been disabled" despite having an active Claude
  subscription, an ANTHROPIC_API_KEY environment variable is overriding
  your subscription»
  (https://code.claude.com/docs/en/troubleshoot-install): il passo 2
  vi dice se c'è.
- `claude: command not found`: rifate i passi di `PRIMA_DEL_CORSO.md` e
  rilanciate `tools/verifica_ambiente.sh`.
- Per ricominciare da capo: `tools/reset_esercizio.sh M4-D01`.

## Impronta d'uso sul piano Pro

Nessuna chiamata al modello: due esecuzioni di `claude auth status`, che
non mandano prompt, e una sessione aperta soltanto per `/status`, senza
messaggi. Modello, effort, turni e subagent non entrano in gioco. Nella
registrazione del corso (28 ottobre 2026, Claude Code 2.1.312) la prova
del docente non ha chiamato il modello: due esecuzioni di
`claude auth status --json` e la verifica.

## Per approfondire

- Le variabili d'ambiente di Claude Code, `ANTHROPIC_API_KEY` compresa:
  https://code.claude.com/docs/en/env-vars
- L'autenticazione: i metodi, l'ordine con cui Claude Code li sceglie,
  `/status`:
  https://code.claude.com/docs/en/authentication
- Il riferimento della CLI, con `claude auth status`:
  https://code.claude.com/docs/en/cli-reference
- Claude Code con il piano Pro o Max, nel centro assistenza:
  https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
- I problemi di installazione e di accesso:
  https://code.claude.com/docs/en/troubleshoot-install
