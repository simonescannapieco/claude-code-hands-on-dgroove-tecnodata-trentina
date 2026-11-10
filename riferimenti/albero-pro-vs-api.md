# Piano Pro o API: un albero di decisione

Dove mettere un lavoro: sul piano Pro, sul quale non vedete una fattura ma avete dei limiti, o sull'API, dove pagate ogni token e avete chiavi, tetti e monitoraggio. Quattro domande, in quest'ordine. Le frasi di Anthropic hanno il link: condizioni e cifre cambiano, e il 10 novembre 2026 è la data in cui sono state lette per il corso.

## Le quattro domande

**1. State costruendo un prodotto o uno strumento per altri?**
- Sì: **API**. «If you’re building a product, application, or tool for others, use API key authentication through Claude Console or a supported cloud provider.» ([Log in to your Claude account](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)). I piani in abbonamento non si usano per conto di altri: Anthropic non consente «to route requests through Free, Pro, Max, or Ultra plan credentials on behalf of their users» ([Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)).
- No: domanda 2.

**2. Gira da solo, senza una persona davanti? Una pipeline, un'integrazione, un lavoro notturno?**
- Sì, e fa parte di un servizio: **API**. I Consumer Terms vietano l'accesso «automated or non-human» salvo con una chiave API o dove Anthropic lo permetta esplicitamente ([Consumer Terms](https://www.anthropic.com/legal/consumer-terms)); e il `-p` col vostro login non è un prodotto, è un vostro script: «the Claude Agent SDK and claude -p still draw from your subscription limits» ([Use the Claude Agent SDK with your Claude plan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)).
- Uno script che lanciate voi, ogni tanto: **Pro**, con il login del piano, tenendo presente che i limiti «assume ordinary, individual usage of Claude Code and the Agent SDK» ([Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)).

**3. Lo usa una persona sola?**
- No: il piano è personale, le credenziali non si condividono («You may not share your Account login information, Anthropic API key, or Account credentials with anyone else», [Consumer Terms](https://www.anthropic.com/legal/consumer-terms)). Se serve a un gruppo come strumento comune: **API**, con una chiave di service account e un workspace per ambiente ([Workspaces](https://platform.claude.com/docs/en/manage-claude/workspaces)), oppure i piani Team ed Enterprise, che stanno sotto i Commercial Terms come l'API ([Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)).
- Sì: domanda 4.

**4. I volumi stanno nei limiti del piano?**
- Sul Pro non c'è un numero fisso di messaggi: «there's no fixed message count», e contano modello, lunghezza delle conversazioni e strumenti ([Plans & pricing](https://claude.com/pricing)). Se toccate i limiti spesso: «Consider upgrading to the Max plan» ([Use Claude Code with your Pro, Max, or Ultra plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan)), oppure spostate il lavoro ripetitivo sull'API.
- Sì: **Pro**.

Su un lavoro con dati sensibili, una domanda in più in ogni caso: sul piano Pro «We will train new models using data from Free, Pro, Max, and Ultra accounts when this setting is on» ([Data usage](https://code.claude.com/docs/en/data-usage)): l'impostazione la decidete voi. Sui termini commerciali, API compresa, «Anthropic may not train models on Customer Content from Services» ([Commercial Terms](https://www.anthropic.com/legal/commercial-terms)).

## In sintesi

| | Piano Pro | API |
|---|---|---|
| Che cos'è | l'abbonamento di una persona: chat, Claude Code, Projects | una piattaforma per sviluppatori: chiavi, Console, si paga a consumo |
| Come si paga | fisso: 20 dollari al mese negli Stati Uniti, altrove in valuta locale | per ogni token, in entrata e in uscita; con crediti prepagati |
| Limiti | una finestra di cinque ore e un limite settimanale, condivisi tra chat e Claude Code | rate limit (RPM, ITPM, OTPM) e spend limit mensile per tier |
| Chi lo usa | voi, personalmente | i vostri prodotti e servizi, con chiavi personali o di service account |
| Contratto | Consumer Terms | Commercial Terms: si possono far funzionare prodotti per i propri clienti |
| Si guarda con | `/usage`, `/context`, Settings > Usage | Console: Usage, Cost, spend limit, notifiche per workspace |

Per chi passa all'API: la «Claude Console» dà chiavi e accesso ([Why is Claude API usage billed separately…](https://support.claude.com/en/articles/9876003-why-is-claude-api-usage-billed-separately-from-my-paid-claude-plan)); spend limit e rate limit stanno in [Rate limits](https://platform.claude.com/docs/en/api/rate-limits); i costi per token in [Pricing](https://platform.claude.com/docs/en/about-claude/pricing). La formula del conto è in `cheat-sheet-costi.md`.
