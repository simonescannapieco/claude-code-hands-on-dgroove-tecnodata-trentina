# Esercitazioni — Claude e Claude Code in pratica

Il repository delle demo e delle esercitazioni del corso «Claude e Claude
Code in pratica — Corso base»: per ogni modulo i punti di partenza, le
istruzioni passo passo e le verifiche automatiche; in più i progetti di
esempio su cui lavorano gli esercizi e le dispense di riferimento.

## A chi serve

- A chi segue il corso: per rifare in autonomia, durante e dopo le
  sessioni, ogni demo e ogni esercizio.
- Al docente: per preparare e provare gli elementi prima di ogni sessione.

Prima della prima sessione seguite [`PRIMA_DEL_CORSO.md`](PRIMA_DEL_CORSO.md):
Linux o Windows con WSL 2, installazione di Claude Code, accesso con
l'abbonamento Pro, strumenti e controllo finale.

## Ottenere il repository e aggiornarlo

Il repository è online, su GitHub. Si clona una volta:

    git clone https://github.com/simonescannapieco/claude-code-hands-on-dgroove-tecnodata-trentina esercitazioni
    cd esercitazioni

Quando arrivano le demo e gli esercizi di un modulo, si aggiorna dalla
stessa cartella con

    git pull

Le dispense delle slide, in PDF, di ogni parte di ogni modulo, teoria e
pratica, sono in due posti: allegate all'ultima release del repository,
https://github.com/simonescannapieco/claude-code-hands-on-dgroove-tecnodata-trentina/releases/latest,
e nella cartella `dispense/`, divisa in `theory/` e `practice/`:
https://github.com/simonescannapieco/claude-code-hands-on-dgroove-tecnodata-trentina/tree/master/dispense

Il lavoro degli esercizi sta negli spazi di lavoro, fuori dal repository
(vedi sotto): `git pull` non lo tocca, e lo cancella solo
`tools/reset_esercizio.sh`, quando lo chiedete voi.

## Com'è fatto

| cartella | che cosa contiene |
|---|---|
| `m1_fondamenti_llm/` … `m9_wrap_up/` | un modulo per cartella: `README.md`, `manifest.tsv` (l'elenco degli elementi) e una cartella per elemento, `<sezione>/<sotto-deck>/<ID>_<nome>/` |
| `progetti/` | i progetti di esempio condivisi: il gestionale in PHP, la rete e l'assistenza clienti di un operatore immaginario |
| `riferimenti/` | le dispense di riferimento: pattern di prompt, modelli di `SKILL.md`, di `CLAUDE.md` e di system prompt, costi |
| `tools/` | gli strumenti: preparare, verificare e ricominciare un elemento; i controlli del docente |
| `tests/` | le prove degli strumenti e dei progetti |

Ogni demo ed esercizio, un **elemento**, ha un identificativo: `M4-E02` è il
secondo esercizio del Modulo 4, `M2-D01` la prima demo del Modulo 2. La sua
cartella contiene:

- `README.md`: obiettivo, tempo, prerequisiti, il punto di partenza, i passi
  in Claude Code con i prompt da incollare, che cosa osservare, come
  verificare, che cosa fare se qualcosa va storto, l'impronta d'uso sul
  piano Pro e le letture per approfondire;
- `esercizio/` o `demo/`: il punto di partenza;
- `verifica.sh`: i controlli automatici del risultato.

## Come si usa un elemento

Gli script di `tools/` sono bash: si lanciano dal terminale di Linux o, su
Windows, da quello della distribuzione WSL 2; sempre dalla cartella del
repository, `esercitazioni`.

1. **Prepara** lo spazio di lavoro:

       tools/prepara_esercizio.sh M4-E02

   Crea `~/corso-claude-code/M4-E02/`, fuori dal repository, con il punto di
   partenza dell'elemento e i progetti che gli servono, e ne fa un
   repository git con un primo commit.

2. **Lavora in Claude Code** dentro lo spazio di lavoro:

       cd ~/corso-claude-code/M4-E02
       claude

   e segui i «Passi in Claude Code» del `README.md` dell'elemento. In ogni
   momento `git status` e `git diff` mostrano che cosa è cambiato rispetto al
   punto di partenza. I checkpoint di Claude Code (`/rewind`) riportano
   indietro dentro una sessione, ma non tracciano le modifiche fatte con
   comandi Bash e non sostituiscono git.

3. **Verifica**:

       tools/verifica.sh M4-E02

   Esce con 0 se il risultato è quello atteso, con 1 se non ancora (e dice
   che cosa manca), con 2 se qualcosa impedisce la verifica, per esempio uno
   spazio di lavoro che non c'è.

4. **Ricomincia** da capo, se serve:

       tools/reset_esercizio.sh M4-E02

   Cancella lo spazio di lavoro, dopo aver chiesto conferma, e lo prepara di
   nuovo.

Lo spazio di lavoro riceve le impostazioni prudenti di
`.claude/settings.json` di questo repository, salvo che l'elemento porti le
sue: regole che negano agli strumenti per i file di Claude Code la lettura
dei file `.env`, delle cartelle `secrets/` e dei file di chiavi. Non coprono
i comandi che leggono file senza nominarli: dati veri, nel corso, non ce ne
sono comunque.

Gli elementi che si svolgono su claude.ai lo dicono nel loro README; quelli
che usano l'API li esegue solo il docente.

## I progetti di esempio

Gli esercizi lavorano su un operatore di connettività **immaginario**,
CiaspoLink S.r.l., con il suo gestionale in PHP, la sua rete in fibra e radio
e la sua assistenza clienti. È tutto inventato: persone, indirizzi, numeri,
apparati e ticket seguono le regole dei dati sintetici di
[`progetti/README.md`](progetti/README.md).

## Il piano Pro: usarlo con misura

Ognuno lavora con il proprio abbonamento Pro. Qualche abitudine tiene i
consumi sotto controllo per tutta la sessione:

- **Guardate `/usage`.** In Claude Code mostra le barre di utilizzo del piano
  e il dettaglio di ciò che pesa sui limiti. I numeri sono approssimati e
  calcolati sul vostro computer: non comprendono l'uso da claude.ai né da
  altri dispositivi. L'orario del prossimo azzeramento si legge su claude.ai,
  in Settings > Usage.
- **I limiti sono condivisi.** Claude sul web, nelle app desktop e mobile, e
  Claude Code attingono agli stessi limiti: un limite di sessione che si
  azzera ogni cinque ore e un limite settimanale. Avvicinandosi a un limite
  compaiono messaggi di avviso; cambiare modello con `/model` non ripristina
  l'accesso.
- **Sonnet per il lavoro di routine.** Opus consuma sensibilmente più quota;
  si cambia modello con `/model`.
- **Effort basso quando basta.** Un effort più basso è più rapido ed
  economico; si regola con `/effort`.
- **`/clear` tra un esercizio e l'altro.** Ripartire da zero non costa
  nulla, mentre una sessione aperta da ore può consumare molto più di quanto
  l'attività faccia pensare.
- **Subagent con misura.** Le richieste di un subagent contano sugli stessi
  limiti della conversazione principale.
- **Niente usage credits e niente Fable.** Gli usage credits si pagano a
  parte, oltre l'uso incluso nel piano; sul piano Pro i modelli Fable
  funzionano solo con gli usage credits. Le esercitazioni del corso non ne
  hanno bisogno.

Ogni elemento dichiara nel suo README l'«Impronta d'uso sul piano Pro»:
modello, effort, turni attesi, subagent.

## Per il docente

    tools/check_handson.sh                  # struttura, manifest, README degli elementi
    tools/run_all.sh [--live] [ID ...]      # ogni elemento: la verifica fallisce sul punto di partenza e passa con la soluzione
    tests/esegui_test.sh                    # le suite di test e shellcheck
    tools/esporta_studenti.sh <cartella>    # una copia senza soluzioni, e il suo bundle

Le soluzioni (`soluzione/`) e il materiale del docente (`_docente/`) stanno
in questo repository, che i partecipanti clonano così com'è da GitHub.
`tools/esporta_studenti.sh` resta disponibile: prepara una copia senza
soluzioni né materiale del docente, come repository git a sé (con un
bundle), se mai servisse distribuirla a parte.
