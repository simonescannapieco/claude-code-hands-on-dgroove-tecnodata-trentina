# Dove continuare a imparare

Le risorse ufficiali da tenere a portata di mano, scelte per chi ha seguito il corso con il piano Pro. Titoli e indirizzi sono quelli letti sulle pagine di Anthropic il **10 novembre 2026**, e cambiano spesso: nel dubbio, controllate la pagina ufficiale. Dove una risorsa chiede una chiave API, o tratta funzioni di un altro piano, lo trovate scritto.

## La documentazione

- [Overview di Claude Code](https://code.claude.com/docs/en/overview): installazione, configurazione, skill, subagent, hook, MCP, materiale di riferimento. C'è anche [in italiano](https://code.claude.com/docs/it/overview).
- [Documentazione della piattaforma](https://platform.claude.com/docs/en/home): per integrare Claude nelle proprie applicazioni, dalla prima chiamata API alla produzione, con la [panoramica dei modelli](https://platform.claude.com/docs/en/models/overview).
- [Claude Help Center](https://support.claude.com/en/): i piani Pro, Max e Ultra, l'abbonamento, i limiti d'uso, gli account e la fatturazione.
- [Claude.ai documentation](https://claude.com/docs): collegare Claude ai propri strumenti e insegnargli come lavora il team.

## Da leggere per prime

Per il lavoro con Claude Code:

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices): che cosa dire a Claude di ciò che non può vedere e quale controllo fargli eseguire.
- [Common workflows](https://code.claude.com/docs/en/common-workflows): guide passo per passo per esplorare una codebase, correggere bug, rifattorizzare, testare.
- [Extend Claude Code](https://code.claude.com/docs/en/features-overview): quando usare `CLAUDE.md`, le skill, i subagent, gli hook, MCP e i plugin.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory): le istruzioni persistenti e la memoria automatica.
- [Configure permissions](https://code.claude.com/docs/en/permissions) e [Automate actions with hooks](https://code.claude.com/docs/en/hooks-guide).
- [Run agents in parallel](https://code.claude.com/docs/en/agents): i cinque modi di lavorare su più attività insieme.
- [Prompt library](https://code.claude.com/docs/en/prompt-library): prompt da copiare, classificati per attività e ruolo.

Sui prompt e sugli agenti:

- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices): il riferimento per il prompt engineering con i modelli attuali.
- [Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests): come misurare se un prompt funziona.
- [Building effective agents](https://www.anthropic.com/research/building-effective-agents): con la sua nota in apertura, che dice che gran parte degli strumenti descritti è cambiata da dicembre 2024.
- [Effective context engineering for AI agents](https://www.anthropic.com/research/effective-context-engineering-for-ai-agents).
- [Demystifying evals for AI agents](https://www.anthropic.com/research/demystifying-evals-for-ai-agents).
- [Using Claude Code: Spending your effort](https://claude.dev/blog/spending-your-effort/): che cos'è effort e quale livello usare.
- [Zero Trust for AI Agents](https://claude.com/resources/guides/zero-trust-for-ai-agents): un quadro di sicurezza per gli agenti autonomi in azienda.

## Restare aggiornati

- [Claude Code changelog](https://code.claude.com/docs/en/changelog): le note di rilascio, versione per versione; il 10 novembre 2026 la voce più recente era la 2.1.322, dello stesso giorno. La versione che avete si legge con `claude --version`; in una sessione, `/release-notes` apre il changelog.
- [What's new](https://code.claude.com/docs/en/whats-new) (anche [in italiano](https://code.claude.com/docs/it/whats-new)): un digest settimanale, ma il 10 novembre 2026 si fermava alla settimana dal 7 all'11 settembre. Per il resto, il changelog.
- [Advanced setup](https://code.claude.com/docs/en/setup): le installazioni native si aggiornano da sole; quelle con Homebrew, WinGet e i gestori di pacchetti Linux, per impostazione predefinita, no. `claude update` applica subito un aggiornamento; i canali sono `latest` (il predefinito) e `stable` (in genere una settimana indietro, saltando i rilasci con regressioni gravi).
- [Le note di rilascio delle app Claude](https://support.claude.com/en/articles/12138966-release-notes) e quelle della [piattaforma](https://platform.claude.com/docs/en/release-notes/overview).
- [Model deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations): i modelli in dismissione, con i sostituti; per quelli pubblici, almeno 60 giorni di preavviso a chi li usa.
- [Service status](https://status.claude.com): lo stato dei servizi.
- [Newsroom di Anthropic](https://www.anthropic.com/news).

## Chiedere aiuto

- **A Claude Code stesso:** Claude Code può insegnarvi a usarlo: chiedetegli per esempio come si imposta un hook. Ha accesso integrato alla propria documentazione. `/help` mostra i comandi, `/powerup` fa scoprire le funzioni con brevi lezioni interattive, `/doctor` controlla la configurazione e propone correzioni.
- **Quando qualcosa non va:** [Troubleshooting](https://code.claude.com/docs/en/troubleshooting) e [Debug your configuration](https://code.claude.com/docs/en/debug-your-config); i problemi noti stanno nel [repository di Claude Code](https://github.com/anthropics/claude-code).
- **Segnalare ad Anthropic:** `/feedback`, dentro Claude Code. Attenzione: una copia della conversazione, codice compreso, viene inviata ad Anthropic, e le trascrizioni si conservano per 5 anni ([Data usage](https://code.claude.com/docs/en/data-usage)). Prima dell'invio, una schermata di consenso vi fa scegliere quanta cronologia includere: la sola sessione corrente, il valore predefinito, oppure anche altre sessioni dello stesso progetto delle ultime 24 ore o degli ultimi 7 giorni. Facoltativamente, la segnalazione crea anche una issue nel repository GitHub pubblico. Mai con dati riservati, né nella sessione né in quelle che includete.
- **Il vostro account Pro:** [How to get support](https://support.claude.com/en/articles/9015913-how-to-get-support): il supporto è solo per iscritto, si apre dal menu sotto le vostre iniziali, «Get help». Per Claude Code con il piano: [Use Claude Code with your Pro, Max, or Ultra plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan).
- **Con chi lo usa:** il [Claude Discord](https://discord.com/invite/6PPFFzqPDZ), dalla [pagina della community](https://claude.com/community).

## Claude Academy

[Claude Academy](https://academy.claude.com/) è gratuita: corsi, tutorial e casi d'uso del team education di Anthropic. Il catalogo si consulta senza accedere; per salvare i progressi e ottenere i *completion badge* basta un account Claude, anche gratuito, senza piano a pagamento. Il badge si ottiene superando i quiz del corso e non scade, ma non tutti i corsi lo danno: *Introduction to subagents* e *Introduction to agent skills*, per esempio, no. E **non è una certificazione**. Il vecchio sito `anthropic.skilljar.com` chiude all'inizio di dicembre 2026.

Il corso che viene dopo, modulo per modulo. Dove il catalogo, letto il 10 novembre 2026, non ha un corso dedicato, lo dice l'ultima colonna.

| Modulo | Da seguire | Nota |
|---|---|---|
| 1 | [AI capabilities and limitations](https://academy.claude.com/courses/ai-capabilities-and-limitations), [AI Fluency: Framework and foundations](https://academy.claude.com/courses/ai-fluency-framework-foundations), [AI Fluency for builders](https://academy.claude.com/courses/ai-fluency-for-builders) | — |
| 2 | [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices), [Write a prompt your app can ship](https://academy.claude.com/tutorials/write-a-prompt-your-app-can-ship) | nessun corso dedicato: una pagina della documentazione e un tutorial |
| 3 | [Claude 101](https://academy.claude.com/courses/claude-101) | — |
| 4 | [Claude Code in action](https://academy.claude.com/courses/claude-code-in-action), [Introduction to subagents](https://academy.claude.com/courses/introduction-to-subagents); per chi ha dubbi sulle basi, [Claude Code 101](https://academy.claude.com/courses/claude-code-101) | in *Claude Code in action*, la lezione *GitHub Actions and Code Review* tratta un servizio dei piani Team ed Enterprise e una GitHub Action con la chiave API; quella su *Scheduled tasks and headless*, la modalità bare, che chiede `ANTHROPIC_API_KEY` |
| 5 | [Introduction to agent skills](https://academy.claude.com/courses/introduction-to-agent-skills) | — |
| 6 | [How context affects Claude's performance and cost](https://academy.claude.com/tutorials/parametric-memory-and-context) | nessun corso dedicato: un tutorial |
| 7 | [Tool use with the Messages API](https://academy.claude.com/courses/tool-use-with-the-messages-api), [Introduction to Model Context Protocol](https://academy.claude.com/courses/introduction-to-model-context-protocol), [Model Context Protocol: Advanced topics](https://academy.claude.com/courses/model-context-protocol-advanced-topics), [Introduction to evals](https://academy.claude.com/courses/introduction-to-evals) | per provare da sé le tecniche di *Tool use with the Messages API* e per l'applicazione delle lezioni successive di *Introduction to Model Context Protocol* serve una chiave API; per una propria eval di *Introduction to evals*, un account Console e una chiave; nessun corso sugli assistenti |
| 8 | [Tokens: why some inputs cost more than others](https://academy.claude.com/tutorials/tokens-and-embeddings), [Choosing the right Claude model: Haiku, Sonnet, Opus, or Fable](https://academy.claude.com/tutorials/choosing-the-right-claude-model), [Claude Platform 101](https://academy.claude.com/courses/claude-platform-101) | nessun corso su costi e piani; *Claude Platform 101* chiede una chiave API |

Per chi ottiene una chiave API: [Building with the Claude API](https://academy.claude.com/courses/building-with-the-claude-api). Per i responsabili di engineering, piattaforma e sicurezza di un'organizzazione che già usa Claude Code: [The AI-native SDLC playbook](https://academy.claude.com/courses/ai-native-sdlc-playbook).

Il catalogo dell'Academy si consulta anche da Claude Code, con il suo connettore: un server MCP con tre strumenti in sola lettura, che non chiede un account né un accesso ([le istruzioni](https://academy.claude.com/help/mcp)). Il comando si lancia nel terminale, non dentro una sessione, e per impostazione predefinita vale solo nel progetto della cartella da cui lo lanciate; con `--scope user` vale in tutti i vostri progetti.

```bash
claude mcp add --transport http claude-academy https://academy.claude.com/mcp
```

Poi `/mcp`, dentro Claude Code, lo mostra collegato; `claude mcp remove claude-academy` lo toglie.

## Le certificazioni

Le certificazioni Claude sono un programma separato dai badge dell'Academy: esami a pagamento, con sorveglianza, erogati da Pearson. **Sono aperte solo a chi lavora in un'organizzazione del Claude Partner Network** (l'iscrizione chiede un'email aziendale su un dominio del partner); chi non ne fa parte non può iscriversi. Un'organizzazione che porta Claude ai propri clienti [può candidarsi al Network](https://claude.com/partners), e l'adesione è gratuita. Pagine ufficiali: [chi può sostenere l'esame](https://anthropic-partners.skilljar.com/page/certification-eligibility) e le [FAQ](https://anthropic-partners.skilljar.com/page/faq-certifications).

| Certificazione | Codice | Domande | Minuti | Prezzo di listino (USD) |
|---|---|---|---|---|
| Claude Certified Associate – Foundations | CCAO-F | 60 | 120 | 99 |
| Claude Certified Developer – Foundations | CCDV-F | 53 | 120 | 125 |
| Claude Certified Architect – Foundations | CCAR-F | 60 | 120 | 125 |
| Claude Certified Architect – Professional | CCAR-P | 63 | 120 | 175 |

I prezzi sono di listino, prima degli sconti per i partner. Punteggio da 100 a 1.000, 720 per superarlo; credenziale valida 12 mesi; si sostiene online con sorveglianza o in un test center Pearson; esame e materiali di preparazione in inglese e in giapponese. Non c'è un prerequisito formale fra Foundations e Professional. Le prove Associate, Developer e Architect – Professional hanno contenuti aggiornati **dal 7 dicembre 2026**, e le guide d'esame nuove escono il 17 novembre. La [pagina di Architect – Foundations](https://anthropic-partners.skilljar.com/claude-certified-architect-foundations-certification) elenca i domini e i corsi gratuiti dell'Academy per prepararsi.

## Video, talk ed eventi

I canali YouTube: [Claude](https://www.youtube.com/@claude) e [Anthropic](https://www.youtube.com/@anthropic-ai). Per cominciare, il canale Claude.

- [Claude Code in Action](https://www.youtube.com/playlist?list=PLDM4zut-OsZ0): la playlist sul canale Claude.
- [Beyond the basics with Claude Code](https://www.youtube.com/watch?v=tuY2ChJIx48).
- [Live coding session with Boris Cherny and Jarred Sumner](https://www.youtube.com/watch?v=DlTCu_pNDHE): i flussi di lavoro quotidiani.
- [Picking the right model](https://www.youtube.com/watch?v=P0uMXS6emHA): come confrontare i modelli sul proprio caso d'uso.
- [Running an AI-native engineering org](https://www.youtube.com/watch?v=igO8iyca2_g) e [How Ramp engineers work with AI agents at every step](https://www.youtube.com/watch?v=i4odXOmgMLw): dal singolo al team, e fino agli incidenti in produzione.
- [Code with Claude 2026: San Francisco](https://www.youtube.com/playlist?list=PLmWCw1CzcFim2obQ-w3ohbULOfwp5lApR) e [Londra](https://www.youtube.com/playlist?list=PLmWCw1CzcFilPJdvw6scjHjbBripZWFps): i talk delle conferenze, da riprendere per argomento.
- [Office Hours with Boris Cherny](https://claude.com/office-hours): conversazioni su come i team costruiscono con Claude Code.
- [Claude Code: Advanced](https://claude.com/resources/webinars/claude-code-workshop-advanced): una sessione pratica ricorrente, 90 minuti con gli specialisti di Anthropic.
- [Le sessioni dal vivo dell'Academy](https://academy.claude.com/webinars) e [gli eventi di Anthropic](https://www.anthropic.com/events).

## Articoli e notizie

- [claude.dev](https://claude.dev/): il blog per chi costruisce con Claude, con i consigli degli sviluppatori di Anthropic.
- [Articles](https://claude.com/resources/articles) di claude.com, e la [newsletter per sviluppatori](https://claude.com/resources), mensile.
- [Engineering](https://www.anthropic.com/engineering) di Anthropic: come si costruiscono, valutano e mettono in esercizio gli agenti.

## I repository

- [anthropics/claude-code](https://github.com/anthropics/claude-code): il repository di Claude Code, per il changelog e i problemi noti.
- [anthropics/skills](https://github.com/anthropics/skills): le skill pubbliche di Anthropic, fornite a scopo dimostrativo ed educativo.
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official): la directory dei plugin di Claude Code gestita da Anthropic.
- Con una chiave API, il [Claude Cookbook](https://platform.claude.com/cookbook) e il [tutorial interattivo di prompt engineering](https://github.com/anthropics/prompt-eng-interactive-tutorial), scritto per i modelli Claude 3 (dove differisce, vale *Prompting best practices*). Il repository [`courses`](https://github.com/anthropics/courses) è archiviato, in sola lettura.
