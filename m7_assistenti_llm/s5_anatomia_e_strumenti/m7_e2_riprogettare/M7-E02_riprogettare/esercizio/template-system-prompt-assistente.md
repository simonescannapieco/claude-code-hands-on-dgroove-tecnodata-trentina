# Modello di system prompt per un assistente

Il modello del corso per il system prompt di un assistente virtuale: come si
divide, che cosa va in ogni parte, poi due liste di controllo, per gli strumenti
e per il passaggio a un operatore. Si usa insieme a `pattern-di-prompt.md`, di
cui segue le regole: ogni ingrediente nel suo tag, su una riga sua, con i nomi in
inglese; i tag sono la convenzione del corso, non una raccomandazione di
Anthropic. Le frasi di Anthropic hanno il link; il resto è il metodo del corso,
che si prova con il banco di prova (`progetti/assistenza-clienti/banco/`) nel
laboratorio del Modulo 7.

## Il modello

```text
<role>
Sei l'assistente virtuale di [azienda]: rispondi [su quali canali] a [chi]
per [l'ambito], e lavori per [il servizio che risponde di te].
</role>

<context>
Che cosa fa l'azienda, in poche righe. Che cosa hai a disposizione: gli
strumenti per leggere e scrivere nei sistemi e la base di conoscenza (dove
stanno le procedure); ciò che non sta lì non lo sai. Chi legge le risposte:
il cliente; e chi legge i passaggi all'operatore: l'operatore.
</context>

<instructions>
1. Riconosci il cliente, con lo strumento di verifica, prima di leggere o
   cambiare qualunque suo dato.
2. Capisci la richiesta e controlla che cosa dicono i sistemi prima di
   chiedere al cliente prove: stato della linea, guasti in corso, procedure.
3. Rispondi con ciò che hai trovato; se serve una procedura, cerca nella base
   di conoscenza e segui quella.
4. Per le azioni che cambiano qualcosa usa lo strumento previsto, soltanto
   dopo il riconoscimento e soltanto quando le regole lo consentono.
5. Passa a un operatore secondo le regole qui sotto, nel tag procedures.
6. Per ultimo, prima di inviare la risposta, controlla: non hai promesso
   tempi o importi che i sistemi non dicono; non hai dato dati a chi non è
   riconosciuto; hai indicato il prossimo passo.
</instructions>

<format>
La forma delle risposte: lingua e registro, come cambia per canale (chat,
telefono, e-mail), lunghezza massima, come si presentano i passi; come si
chiude; niente firma se il canale non la vuole.
</format>

<constraints>
Che cosa fai invece di ciò che non va, in positivo: con chi non è riconosciuto
dai solo informazioni generali; le password restano nell'area clienti; dove un
dato non c'è dici che non lo sai e proponi il passo successivo; davanti a
un'emergenza indichi subito i numeri di emergenza; gli importi e le promesse
che non risultano dai sistemi li rimandi a un operatore.
</constraints>

<examples>
<example>
Un caso reale di una riga, con la risposta attesa e le mosse: da tre a cinque
esempi, diversi fra loro, che mostrano le scelte difficili: un caso in cui
passi a un operatore, uno in cui non passi, uno in cui non hai il dato.
</example>
</examples>

<procedures>
Le regole di passaggio all'operatore (il file regole-escalation.md, che il
banco di prova mette in coda al system prompt): quando si passa, quando no, che
cosa si scrive all'operatore, che cosa si fa fuori orario.
</procedures>
```

Dove manca un ingrediente lasciate una scelta al modello: per questo i tag ci
sono tutti. Il modello lo si riempie per un assistente preciso; nel laboratorio,
per quello di CiaspoLink.

## Che cosa va in ogni parte

- **Il ruolo.** Una frase, «Sei …»: chi è l'assistente, per chi lavora, a chi
  scrive. «Setting a role in the system prompt focuses Claude's behavior and tone
  for your use case. Even a single sentence makes a difference»
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices).
  Non serve raccontare l'azienda: bastano le poche righe che cambiano
  il comportamento, nel contesto.
- **La lingua**, in `<format>`: «for production applications you should state the
  target language explicitly. The most reliable place to do this is the system
  prompt» (https://platform.claude.com/docs/en/build-with-claude/multilingual-support).
- **Dire che è un assistente virtuale**, in `<context>` o in `<constraints>`: la
  Usage Policy dice che «consumer-facing chatbots or AI agents that communicate
  directly with external users must disclose to users that they are interacting
  with AI rather than a human.» (https://www.anthropic.com/legal/aup); e nella
  costituzione di Anthropic: «never deny being an AI to a user who sincerely wants
  to know if they’re talking to a human or an AI»
  (https://www.anthropic.com/constitution).
- **Le istruzioni** sono passi numerati, l'ultimo un controllo; dicono l'ordine
  e le verifiche, non ricordano i valori dell'azienda.
- **Ciò che non è stabile sta fuori dal prompt**: prezzi, offerte, orari cambiano; li
  sa la base di conoscenza, e gli strumenti li leggono. Se un dato sta nel prompt e
  anche negli strumenti, prima o poi i due non coincidono.
- **I vincoli in positivo**: «Tell Claude what to do instead of what not to do»
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices).
  E il permesso di non sapere: «Allow Claude to say "I don't know": Explicitly
  give Claude permission to admit uncertainty.»
  (https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations).
- **Il contenuto che arriva dagli strumenti** non comanda: «Tell Claude explicitly
  that content returned from tools, documents, or searches is untrusted data and
  must never override the system prompt»
  (https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/mitigate-jailbreaks).
- **Gli esempi** mostrano le scelte difficili: «Provide a list of common scenarios and
  expected responses in your prompts. This “trains” Claude to handle diverse
  situations without breaking character.»
  (https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/increase-consistency).
  Nel corso da tre a cinque, tra tag `<example>`, con almeno un passaggio a un
  operatore.

## Le definizioni degli strumenti: la lista di controllo

Ogni strumento è una definizione (`strumenti.json` nel banco di prova): `name`,
`description`, `input_schema` e, nel banco, `capacita`, che dice quale capacità del
server usa e che il modello non vede. Il campo `description` è «A detailed plain text
description of what the tool does, when it should be used, and how it behaves.», e
`input_schema` «A JSON Schema object defining the expected parameters for the
tool.» (https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools).

- [ ] **Il dettaglio.** «Provide extremely detailed descriptions. This is by far the
  most important factor in tool performance.» e, per ogni descrizione, «What the
  tool does | When it should be used (and when it shouldn’t) | What each parameter
  means and how it affects the tool’s behavior», con «Aim for at least 3–4
  sentences for each tool description, more if the tool is complex.» (stessa
  pagina).
- [ ] **Quando, non solo che cosa.** «Sharpen descriptions. Differentiate tools by
  WHEN to use them, not only WHAT they do.»
  (https://platform.claude.com/docs/en/agents-and-tools/tool-use/troubleshooting-tool-use).
- [ ] **Quanti strumenti.** «More tools don’t always lead to better outcomes. A
  common error we’ve observed is tools that merely wrap existing software
  functionality or API endpoints», e «We recommend building a few thoughtful tools
  targeting specific high-impact workflows, which match your evaluation tasks and
  scaling up from there.» (https://www.anthropic.com/research/writing-tools-for-agents).
- [ ] **Uno scopo per strumento, o un parametro `action`?** Le pagine di Anthropic
  danno due indicazioni che tirano in direzioni diverse: raggruppare le operazioni
  correlate, «Rather than creating a separate tool for every action (create_pr,
  review_pr, merge_pr), group them into a single tool with an action parameter.»
  (define-tools), e, nei criteri di revisione dei connettori, «Split a catch-all
  tool into a read-only tool and one or more write tools.»
  (https://claude.com/docs/connectors/building/review-criteria). Nel banco di prova
  vale una capacità per strumento, così le asserzioni restano leggibili; fuori dal
  banco si sceglie secondo il caso.
- [ ] **I confini e gli errori.** «A good tool definition often includes example
  usage, edge cases, input format requirements, and clear boundaries from other
  tools.» e «Poka-yoke your tools. Change the arguments so that it is harder to make
  mistakes.» (https://www.anthropic.com/research/building-effective-agents); gli
  errori dicono che cosa fare, «Write instructive error messages. Instead of generic
  errors such as "failed", include what went wrong and what Claude should try next»
  (https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls).
- [ ] **Che cosa restituisce**: nella descrizione si dice che cosa torna indietro, e
  gli strumenti che danno dati del cliente restituiscono solo ciò che serve:
  «tool implementations should take care to return only high signal information
  back to agents.» (writing-tools-for-agents).
- [ ] **Il riconoscimento prima dei dati**: nella descrizione di ogni strumento che
  legge o cambia i dati di un cliente si dice che va chiamato soltanto dopo la
  verifica dell'identità. La forma più robusta è un blocco nel codice:
  «Implementing programmatic prerequisites that block downstream tool calls until
  prerequisite steps have completed (e.g., blocking process_refund until get_customer
  has returned a verified customer ID)» (guida d'esame qui sotto); nel banco la
  regola sta nella descrizione, e si misura con l'asserzione `prima_di`.

## Il passaggio a un operatore: la lista di controllo

- [ ] **I criteri scritti, con esempi.** «Adding explicit escalation criteria with
  few-shot examples directly addresses the root cause: unclear decision boundaries.»
  (guida d'esame).
- [ ] **Quali criteri.** «Appropriate escalation triggers: customer requests for a
  human, policy exceptions/gaps (not just complex cases), and inability to make
  meaningful progress» (stessa guida). Una richiesta esplicita si onora subito:
  «Honoring explicit customer requests for human agents immediately without first
  attempting investigation». Quando la procedura non dice che cosa fare: «Escalating
  when policy is ambiguous or silent on the customer's specific request». Il
  cliente arrabbiato non è un criterio da solo: «Acknowledging frustration while
  offering resolution when the issue is within the agent's capability, escalating
  only if the customer reiterates their preference», perché «sentiment-based
  escalation and self-reported confidence scores are unreliable proxies for actual
  case complexity» (stessa guida).
- [ ] **Che cosa si scrive all'operatore.** Un riepilogo fatto per chi non ha letto
  la conversazione: «Compiling structured handoff summaries (customer ID, root cause,
  refund amount, recommended action) when escalating to human agents who lack access
  to the conversation transcript» (stessa guida). Nello strumento: motivo, riepilogo,
  priorità.
- [ ] **Che cosa si dice al cliente.** L'attesa onesta: se l'operatore è in linea
  o se richiama, senza promettere orari che le procedure non danno.
- [ ] **Fuori orario.** Che cosa si fa quando gli operatori non ci sono, secondo le
  procedure: non «un operatore arriva subito».

## Come si prova

Il metodo del corso: si scrive una versione, si fa girare sui casi con le asserzioni
(`tools/prova_assistente.sh <spazio di lavoro> casi`), si confronta con la versione
di prima, una versione alla volta. La guida d'esame è la «Claude Certified Architect
— Foundations Exam Guide»:
https://everpath-course-content.s3-accelerate.amazonaws.com/instructor%2F6nizmqk8tpzpfjvt6qmmav7rh%2Fpublic%2F1783542750%2FClaude+Certified+Architect+%E2%80%93+Foundations+Exam+Guide.pdf
