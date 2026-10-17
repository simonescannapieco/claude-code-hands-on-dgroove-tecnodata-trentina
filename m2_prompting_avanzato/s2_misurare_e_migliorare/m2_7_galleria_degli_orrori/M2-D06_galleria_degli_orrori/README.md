# M2-D06 — La galleria degli orrori

Demo del Modulo 2, nella parte «La galleria degli orrori». In aula la
esegue il docente, e prima di ogni prova indovinate a voce che cosa
succederà; potete rifarla da soli quando volete.

## Obiettivo

Vedere quattro prompt sbagliati all'opera sul messaggio di un cliente, e la
cura di uno di loro: la maggior parte dei «fallimenti dell'AI» sono
fallimenti di specifica.

## Tempo

8 minuti in aula; circa 8 per rifarla da soli.

## Prerequisiti

Claude Code installato e collegato al piano Pro, con
`tools/verifica_ambiente.sh` tutto verde (`PRIMA_DEL_CORSO.md`); Python 3,
che lo stesso controllo verifica.

## Punto di partenza (tools/prepara_esercizio.sh M2-D06)

Lo spazio di lavoro `~/corso-claude-code/M2-D06/` con il messaggio della
Falegnameria Fittizia (`messaggio.md`) e cinque prompt:

- `orrore-1-vaga.md`: «Fammi un documento carino su questo messaggio»;
- `orrore-2-divieto.md`: «Scrivi la risposta al cliente in tre righe. Non
  menzionare l'indennizzo»;
- `cura-2-divieto.md`: lo stesso, ma dicendo che cosa scrivere
  sull'indennizzo invece di vietarlo;
- `orrore-3-cinque.md`: cinque richieste in una (riassunto, categoria,
  risposta, traduzione, tre azioni con una stima dei costi);
- `orrore-4-memoria.md`: «Come ti ho detto ieri, riscrivi la risposta al
  cliente con lo stesso formato che abbiamo concordato»;

più `istruzione.txt` («Rispondi in italiano.») e `leggi_json.py`.

## Passi in Claude Code

1. Preparate lo spazio di lavoro ed entrateci, dalla cartella
   `esercitazioni`:

       tools/prepara_esercizio.sh M2-D06
       cd ~/corso-claude-code/M2-D06

2. Le cinque prove su Sonnet, con le risposte in `orrori.tsv` (le colonne
   del telefono, dell'indennizzo e degli importi in euro le scrive il
   controllo sotto):

       printf 'prova\ttoken_uscita\ttelefono\tindennizzo\timporti\trisposta\n' \
         > orrori.tsv
       for p in orrore-1-vaga orrore-2-divieto cura-2-divieto \
           orrore-3-cinque orrore-4-memoria; do
         r="$(claude -p "$(cat "$p.md")" --model sonnet --effort low \
           --tools "" --system-prompt "$(cat istruzione.txt)" \
           --strict-mcp-config --output-format json)"
         t="$(python3 leggi_json.py result <<< "$r")"
         printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$p" \
           "$(python3 leggi_json.py token_uscita <<< "$r")" \
           "$(grep -Eq '000[ .]?000[ .]?0103' <<< "$t" && echo sì || echo no)" \
           "$(grep -iq 'indennizz' <<< "$t" && echo sì || echo no)" \
           "$(grep -Eo '[0-9][0-9.,]* ?(€|euro)|€ ?[0-9]' <<< "$t" | wc -l | tr -d ' ')" \
           "$t" | tee -a orrori.tsv
       done

## Che cosa osservare

Nella registrazione del corso, su Sonnet:

- **La richiesta vaga**: una «scheda richiesta cliente» che nessuno ha
  chiesto, 1.630 token in uscita, il telefono del cliente dentro. La cura:
  ruolo, destinatario, formato.
- **Il divieto**: rispettato in tre esecuzioni su tre, e proprio per questo
  la domanda del cliente sull'indennizzo resta senza risposta. La cura dice
  che cosa scrivere al suo posto: «la richiesta la valuta l'amministrazione
  e la apriamo noi». La risposta curata però aggiunge da sé una richiamata
  in mattinata: un impegno che il prompt non autorizzava, e che va chiuso
  nel prompt.
- **Cinque richieste in una**: 2.137 token in uscita e sei importi in euro
  inventati per le «stime dei costi». La cura: una richiesta per prompt, o
  più chiamate in fila.
- **La memoria presunta**: in una sessione nuova il modello dice di non
  avere accesso alla conversazione di ieri e chiede il messaggio, la bozza e
  il formato. La cura: il contesto, ogni volta. In claude.ai, sul piano Pro,
  la memoria fra le chat può riportare il contesto di altre conversazioni:
  in `claude -p` ogni chiamata parte da zero.

## Verifica (tools/verifica.sh M2-D06)

In `orrori.tsv`: la risposta al divieto non nomina l'indennizzo, quella
curata sì, e quella alla memoria presunta chiede ciò che le manca. Il
documento «carino» e le cinque richieste li giudicate voi, con le colonne
del telefono e degli importi.

## Se qualcosa va storto

- `claude: command not found`, oppure un errore di accesso: rifate i passi
  di `PRIMA_DEL_CORSO.md` e rilanciate `tools/verifica_ambiente.sh`.
- Una prova senza risposta: rilanciate solo quella.
- Per ricominciare da capo: `tools/reset_esercizio.sh M2-D06`.

## Impronta d'uso sul piano Pro

Cinque chiamate su Sonnet, con effort low, nessuno strumento e nessun
subagent; la vaga e le cinque richieste producono risposte lunghe (tra
mille e duemila token in uscita).

## Per approfondire

- «Di' a Claude cosa fare invece di cosa non fare», nella guida «Prompting
  best practices» (in italiano nella documentazione):
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- La memoria e la cronologia delle chat in claude.ai:
  https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
