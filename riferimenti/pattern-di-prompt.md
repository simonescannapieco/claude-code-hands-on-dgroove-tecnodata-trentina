# Pattern di prompt

Il Modulo 2 in poche pagine, da tenere aperto quando scrivete o rivedete un
prompt: il template, gli ingredienti, dove va che cosa, i tag, gli esempi,
il ragionamento sui modelli di oggi, l'output strutturato, la checklist, la
strategia per compito e come si misura. Le fonti sono in fondo, in
«Fonti»; quello che vale per i modelli e per Claude Code può cambiare:
controllate la data delle pagine.

## Il template

```text
Ruolo:      chi è Claude in questo compito, e per chi lavora.
Contesto:   che cosa deve sapere: lo scopo, chi leggerà, come verrà usato
            il risultato.
Istruzione: che cosa deve fare, con un verbo; passi numerati quando
            l'ordine o la completezza contano.
Formato:    in che forma: lunghezza, struttura, tabella, JSON.
Vincoli:    che cosa fare, detto in positivo; che cosa scrivere quando un
            dato manca («non indicato»).
Esempi:     se la forma conta, da tre a cinque, tra tag <example>.

<dati>
... il messaggio, il codice, il log ...
</dati>
```

Ogni ingrediente che manca è una decisione che lasciate al modello: la
lunghezza, il formato, che cosa fare dei dati personali, che cosa si può
promettere. Il prompt è una specifica, non un desiderio.

## Il collega brillante, appena arrivato

La documentazione di Anthropic, nella versione italiana: «Pensa a Claude
come a un dipendente brillante ma nuovo, che non ha contesto sulle tue
norme e sui tuoi flussi di lavoro». Il test chiave: fate leggere il prompt
a un collega con poco contesto sul compito; se resta confuso lui, lo sarà
anche Claude.

## Gli ingredienti, uno per uno

| ingrediente | la domanda | per esempio |
|---|---|---|
| ruolo | chi scrive, e a chi? | «Sei l'assistenza clienti di CiaspoLink e rispondi per e-mail a un cliente business.» |
| contesto | che cosa deve sapere, e perché? | lo scopo, chi legge, le procedure che valgono, tra tag |
| istruzione | che cosa deve fare? | «Rispondi alle due richieste del cliente, con le sole informazioni delle procedure.» |
| formato | in che forma? | «al massimo 120 parole, senza oggetto; firma: L'assistenza clienti di CiaspoLink» |
| vincoli | che cosa fare invece di ciò che non va? | «Dove un dato manca, scrivi “non indicato”.» |
| esempi | quale forma deve copiare? | due o tre segnalazioni già classificate |

Dite a Claude che cosa fare invece di che cosa non fare: per il formato,
la documentazione di Anthropic suggerisce di chiedere una prosa scorrevole,
in paragrafi, invece di vietare il Markdown. Nella galleria degli orrori
del corso (M2-D06) le due frasi di Anthropic sono messe alla prova sullo
stesso riepilogo, accanto a un riepilogo senza indicazioni sul formato.

## Dove va che cosa: system, user, developer

| che cosa | dove |
|---|---|
| il ruolo e le regole che non cambiano da una richiesta all'altra | il system prompt |
| il caso, l'istruzione, il formato, i dati, gli esempi | il messaggio (user) |

- **Claude Code** ha un suo system prompt (l'uso degli strumenti, il
  comportamento sicuro, il formato delle risposte), che non vedete.
  `--append-system-prompt "…"` aggiunge le vostre righe in coda;
  `--system-prompt "…"` lo sostituisce, e con lui toglie le istruzioni
  sugli strumenti e quelle di sicurezza: la documentazione lo indica quando
  superficie, identità o permessi sono diversi da quelli di Claude Code.
  Nella demo del corso, con «Rispondi solo: ok», i token in entrata
  scendono da qualche migliaio a qualche centinaio.
- **claude.ai** usa un system prompt di Anthropic, aggiornato nel tempo; le
  vostre regole stabili vanno nelle istruzioni per Claude («Instructions
  for Claude»: valgono per tutte le conversazioni dell'account) o nelle
  istruzioni di un progetto (valgono solo nelle chat di quel progetto).
- **«Developer message»** è un termine di OpenAI: nella sua API i messaggi
  developer portano le istruzioni di chi sviluppa l'applicazione. Su Claude
  «developer» compare nel livello di compatibilità con l'SDK di OpenAI,
  dove finisce nel system prompt.

## I tag

- I tag XML aiutano Claude a leggere senza ambiguità un prompt che mescola
  istruzioni, contesto, esempi e dati: un tag per ogni tipo di contenuto,
  per esempio `<istruzioni>`, `<contesto>`, `<messaggio>`.
- Nomi coerenti in tutti i prompt; tag annidati quando il contenuto ha una
  gerarchia (`<documents>`, con dentro un `<document>` per file, come
  negli esempi della documentazione).
- Con i documenti lunghi, i documenti in cima e la domanda in fondo: nei
  test di Anthropic, fino al 30 % di qualità in più.
- Anche la risposta può avere le sue sezioni tra tag: chiedetelo.
- Sui modelli recenti la forma esatta conta probabilmente meno di una
  volta, scrive Anthropic: l'importante è separare istruzioni e dati.

## Gli esempi

- Sono uno dei modi più affidabili per orientare formato, tono e
  struttura: pertinenti (come i casi veri), diversi fra loro, da tre a
  cinque, tra tag `<example>`.
- Orientano la forma della risposta: lo mette alla prova la demo M2-D04.
  Le etichette ammesse si scrivono nel prompt; per classificare, Anthropic
  consiglia un campo `enum` (in uno strumento o negli output strutturati),
  e con `--json-schema` Claude Code restituisce un oggetto convalidato
  sullo schema.
- Per gli strumenti, Anthropic osserva che con i modelli più recenti gli
  esempi d'uso possono restringere lo spazio di esplorazione del modello, e
  preferisce strumenti progettati bene.

## Il ragionamento, sui modelli di oggi

- Il ragionamento è adattivo: Claude decide da sé quando e quanto
  ragionare, in base alla richiesta e all'effort. Sui modelli 5.5 il
  thinking non si può spegnere, né in Claude Code né in claude.ai.
- La leva è l'effort: `--effort` all'avvio di Claude Code, il menu del
  modello in claude.ai. Un effort più alto ragiona di più e consuma di più.
  In Claude Code `ultrathink` nel prompt chiede un ragionamento più
  profondo per quel turno.
- Istruzioni generali («ragiona a fondo») spesso funzionano meglio di passi
  prescrittivi. «Ragiona passo passo» resta un ripiego per quando il
  thinking è spento.
- Chiedete di scrivere il ragionamento solo se dovete leggerlo: su Opus 5.5
  e Sonnet 5.5 la richiesta di scrivere il proprio ragionamento può essere
  rifiutata. Una breve spiegazione della risposta va sempre bene.
- Il ragionamento che vedete non è per forza ciò che accade nel modello:
  Anthropic stessa avverte di non darlo per fedele.

## L'output strutturato

- Quando un programma legge la risposta, non chiedete «solo JSON»: date uno
  schema. In Claude Code:

  ```bash
  claude -p "$(cat richiesta.md)" --output-format json \
    --json-schema "$(cat schema.json)"
  ```

  e l'oggetto arriva, validato, nel campo `structured_output` del JSON.
- Lo schema garantisce la forma, non il contenuto: toglie gli errori di
  sintassi, non quelli di significato. Campi facoltativi, quando la fonte
  può non avere il dato, evitano valori inventati. Nell'output strutturato
  della Claude API, maiuscole e minuscole dei valori `enum` non sono
  garantite.

## La checklist, in otto punti

1. **Ruolo**: chi è Claude, per chi lavora.
2. **Contesto**: lo scopo, chi legge, i dati e le regole che valgono.
3. **Una richiesta sola** per prompt: un compito circoscritto dà risultati
   migliori di tanti obiettivi insieme.
4. **Formato**, o uno schema se il risultato lo legge un programma.
5. **Vincoli in positivo**: che cosa fare, e che cosa scrivere quando un
   dato manca; il permesso di dire «non lo so».
6. **Esempi**, se la forma conta, con le etichette ammesse.
7. **Dati tra tag**, e nessuna memoria presunta: ogni chiamata parte da ciò
   che le date.
8. **Il test del collega**: lo capirebbe chi non sa niente del compito?

## Quale strategia per quale compito

| compito | strategia |
|---|---|
| riassumere, tradurre | zero-shot, con formato e vincoli |
| classificare, estrarre | gli esempi e le etichette ammesse, o uno schema |
| calcolare, decidere | lasciarlo ragionare (effort più alto); leggere il ragionamento quando conta |
| rispondere ai clienti | ruolo, contesto, procedure, esempi di stile |
| alimentare un programma | uno schema JSON |

## Come si misura

- **Prima i criteri di successo**, poi i casi di prova, poi il prompt: il
  ciclo di Anthropic va dai casi di prova a una prima bozza, poi test e
  raffinamento, la validazione finale e il rilascio.
- **Prima il codice**: i controlli scritti in codice (il telefono che non
  deve comparire, la lunghezza, i campi richiesti) sono i più veloci e i più
  affidabili. Poi un giudice: un modello con una rubrica.
- **La rubrica** è fatta di affermazioni verificabili, ciascuna rispettata
  o no, non di una scala da 1 a 5; e il modello giudice non è quello che
  valutate. Negli attrezzi del corso il giudice scrive il motivo prima
  dell'esito.
- **Un cambiamento alla volta**: il testo, oppure il modello, oppure
  l'effort; e un gruppo di esempi tenuto da parte, per scoprire quando il
  prompt si adatta troppo ai casi di prova.
- **I limiti del giudice**: chi cerca lacune ne trova qualcuna anche nel
  lavoro corretto (chiedete solo ciò che tocca la correttezza e i
  requisiti); e, secondo uno studio sui giudici LLM (Zheng e altri, 2023,
  su altri modelli), i giudici tendono a preferire una posizione e le
  risposte più lunghe. Il giudice è uno strumento: quando non siete
  d'accordo, decidete voi.
- **Fatevi fare le domande**: chiedete a Claude di farvi domande sul compito
  prima di scrivere il prompt.
- Gli attrezzi del corso sono nelle esercitazioni M2-E01 e M2-E02:
  `misura.sh` misura una versione (risposta, controlli, giudizio; su v0
  il giudizio due volte, per vedere quali affermazioni cambiano esito) e
  `misura.sh --confronta` ne mette due fianco a fianco e dice l'esito
  della pratica che la nuova versione applica.

## Fonti

- Anthropic, «Prompting best practices», in inglese e in italiano:
  https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  · https://platform.claude.com/docs/it/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Anthropic, i criteri di successo e le valutazioni:
  https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- Anthropic, l'output strutturato:
  https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- Claude Code: `claude -p` e l'output strutturato,
  https://code.claude.com/docs/en/headless; le opzioni del system prompt,
  https://code.claude.com/docs/en/cli-reference; effort e thinking,
  https://code.claude.com/docs/en/model-config; il revisore e i suoi
  limiti, https://code.claude.com/docs/en/best-practices
- claude.ai: effort e thinking nel menu del modello,
  https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings;
  le istruzioni per Claude e dei progetti,
  https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features
- Il livello di compatibilità con l'SDK di OpenAI:
  https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk
- Il blog degli sviluppatori di Anthropic: «Automating eval design and
  hillclimbing with Claude»,
  https://claude.dev/blog/automating-eval-design-and-hillclimbing/; «The new
  rules of context engineering for Claude 5 generation models»,
  https://claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/
- Claude Academy: «Claude 101», https://academy.claude.com/courses/claude-101;
  «Effective prompting techniques» (AI Fluency),
  https://academy.claude.com/courses/ai-fluency-framework-foundations/effective-prompting-techniques
- Il talk «Prompting 101 | Code w/ Claude», sul canale YouTube di Anthropic:
  https://www.youtube.com/watch?v=ysPbXH0LpIE
- Fuori da Anthropic, per contesto: la guida di OpenAI ai messaggi
  developer, https://developers.openai.com/api/docs/guides/text; i limiti
  del giudice LLM (posizione, lunghezza) nello studio di Zheng e altri,
  2023, https://arxiv.org/abs/2306.05685
