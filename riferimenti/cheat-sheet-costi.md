# Cheat sheet dei costi

Costi e consumi in una pagina. Le cifre sono quelle lette dalle pagine di Anthropic il 10 novembre 2026: prima di un conto che conta, rileggete [Pricing](https://platform.claude.com/docs/en/about-claude/pricing).

## La formula

Anthropic dice di calcolare ognuno dei cinque conteggi del campo `usage` al suo prezzo: «Price each of the five token counts in a response’s usage at its own rate» ([Optimizing for cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)). Il conto di una richiesta:

```text
costo = input non in cache      × prezzo in entrata
      + scritture a 5 minuti    × prezzo di scrittura a 5 minuti
      + scritture a 1 ora       × prezzo di scrittura a 1 ora
      + letture dalla cache     × prezzo di lettura
      + output                  × prezzo in uscita
```

I token in entrata sono la somma di tre campi: «Total input tokens in a request is the summation of input_tokens, cache_creation_input_tokens, and cache_read_input_tokens.» ([Messages API](https://platform.claude.com/docs/en/api/messages/create)).

## Il listino, in dollari per milione di token

| modello | in entrata | in uscita | lettura dalla cache |
|---|---|---|---|
| Haiku 5.5 (prompt fino a 100.000 token) | 0,10 | 0,50 | 0,01 |
| Sonnet 5.5 | 2 | 10 | 0,10 |
| Opus 5.5 | 4 | 20 | 0,20 |
| Fable 5.2 (sul Pro, solo con usage credits) | 8 | 40 | 0,20 |

Oltre i 100.000 token di prompt, Haiku 5.5 costa 0,50 in entrata e 2,50 in uscita ([Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview)). Un token in uscita costa cinque volte uno in entrata sui modelli qui sopra («Output tokens cost five times input tokens», [Optimizing for cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)). Una scrittura in cache: 1,25 volte il prezzo in entrata (durata di 5 minuti), 2 volte (un'ora).

## Le leve

- **Cache del prompt.** Il prefisso che si ripete: «5-minute cache write | 1.25x base input price», «Cache read (hit) | 0.1x base input price» (5 % su Opus 5.5 e Sonnet 5.5, 2,5 % su Fable 5.2); con la durata a 5 minuti la scrittura si ripaga con una lettura, a un'ora con due. Sotto la soglia minima non si applica e non c'è errore ([Pricing](https://platform.claude.com/docs/en/about-claude/pricing); [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)). In Claude Code è automatica ([Prompt caching in Claude Code](https://code.claude.com/docs/en/prompt-caching)).
- **Batch.** «50 percent discount on both input and output tokens» ([Pricing](https://platform.claude.com/docs/en/about-claude/pricing)), per i lavori che possono aspettare fino a 24 ore ([Batch processing](https://platform.claude.com/docs/en/build-with-claude/batch-processing)).
- **Modello.** I modelli piccoli sul lavoro ad alto volume, dove un errore si nota facilmente. Si confronta il «cost per completed task, not per token» ([Optimizing for cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)).
- **Effort.** «Before you move models, try adjusting your effort level.» ([Which Claude model should you build with?](https://claude.dev/blog/which-claude-model-should-you-build-with/)).
- **Meno token.** Tagliare ciò che non cambia la risposta; riassumere (`/compact`); caricare solo quando serve. Si misura prima e dopo.

## Sul piano Pro

- Due limiti, una finestra di cinque ore (dal primo messaggio) e uno settimanale: «Paid plans have two types of usage limits: a session limit that resets every five hours, and weekly limits that reset once every week.» ([How do usage and length limits work?](https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work)). Nessun numero fisso di messaggi.
- Dove si guarda: `/usage` (barre, dettaglio dei consumi), `/context` (che cosa pesa nel contesto), Settings > Usage su claude.ai.
- Un token in più pesa sui limiti, non sulla bolletta: la cifra in dollari di `/usage` è «a guide to how much work you did, not a bill» ([What a task costs on Opus 5.5](https://claude.dev/blog/what-a-task-costs-on-opus-5-5/)).
- Chi supera un limite può attendere il reset, passare a un piano superiore o attivare gli usage credits, che si pagano a tariffe API: in aula non si attivano.

## Sull'API

- Console: pagine Usage (per modello, data e chiave) e Cost ([Cost and usage reporting in the Claude Console](https://support.claude.com/en/articles/9534590-cost-and-usage-reporting-in-the-claude-console)).
- Spend limit dell'organizzazione e dei workspace ([Workspaces](https://platform.claude.com/docs/en/manage-claude/workspaces)), con notifica via email a un importo scelto ([Create and manage Workspaces](https://support.claude.com/en/articles/9796807-create-and-manage-workspaces-in-the-claude-console)).
- Rate limit: richieste, token in entrata e in uscita al minuto ([Rate limits](https://platform.claude.com/docs/en/api/rate-limits)).

Il conto si stima prima: token per listino, non a fattura arrivata.
