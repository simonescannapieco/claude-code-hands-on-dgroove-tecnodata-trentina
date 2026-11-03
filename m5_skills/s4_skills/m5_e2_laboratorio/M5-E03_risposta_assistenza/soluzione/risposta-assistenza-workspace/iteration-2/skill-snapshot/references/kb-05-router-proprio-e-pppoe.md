# KB-05 · Router del cliente e credenziali PPPoE

| | |
|---|---|
| per chi | clienti privati che usano un router proprio, in fibra o via radio |
| canali | assistenza guidata e operatore |
| vedi anche | KB-01 nessuna connessione · KB-14 linee business · KB-15 identificazione |

## Quando si usa

Il cliente vuole usare un router suo al posto di quello di CiaspoLink, oppure l'ha appena installato e non naviga; chiede «i parametri» o «la password della linea».

## Prima di tutto

1. Riconosci il cliente (KB-15).
2. Verifica il tipo di linea: le linee **private** usano una sessione **PPPoE** con nome utente e password; le linee **business** ricevono l'indirizzo dalla rete senza password (KB-14).

## I parametri delle linee private

| parametro | valore |
|---|---|
| porta del router | WAN, collegata alla porta LAN dell'ONT (fibra) o all'alimentatore dell'antenna (radio) |
| VLAN | 120, con tag |
| protocollo | PPPoE |
| nome utente | il codice della linea in minuscolo, senza trattino, seguito da @ciaspolink.example.org (esempio: ln000201@ciaspolink.example.org) |
| password | **nell'area clienti**, in «La mia linea» → «Credenziali» |
| MTU | 1492 |
| IPv4 | dinamico, assegnato dalla sessione |
| IPv6 | prefisso /56 assegnato in automatico (delega del prefisso) |
| DNS | automatici |

## Che cosa chiedere

- Marca e modello del router, solo se serve a indicare dove si trova un'impostazione.
- Se la sessione si è mai collegata con il router nuovo.

## Passi guidati

1. Spiega dove trovare la password: area clienti → «La mia linea» → «Credenziali». **La password non si scrive mai in chat, non si detta al telefono e non si manda per e-mail**, nemmeno al titolare.
2. Se il cliente non riesce ad accedere all'area clienti, si usa il recupero dell'accesso dalla pagina di login: il codice arriva all'e-mail o al cellulare registrati.
3. Fai inserire i parametri della tabella. Il nome utente si può confermare (non è segreto), la password no.
4. Dopo il salvataggio attendere 2 minuti e **controllare la sessione**: se è attiva, il router è configurato bene.
5. Se la sessione non si attiva: ricontrollare VLAN e nome utente; far riscrivere la password copiandola dall'area clienti (attenzione a spazi all'inizio o alla fine).

## La linea voce

Chi ha la **Linea voce di casa** usa la porta telefono del router CiaspoLink. Con un router proprio servono anche le credenziali della linea voce (anche queste nell'area clienti) e un router con porta telefono compatibile; altrimenti conviene lasciare il router CiaspoLink per il telefono.

## Quando passare a un operatore

- La sessione non si attiva dopo i passi 1–5: un operatore verifica i tentativi di accesso dalla rete.
- Il cliente vuole cambiare la password della linea e non riesce ad accedere all'area clienti.
- Richieste su configurazioni avanzate del router del cliente (porte, VPN, firewall): l'assistenza dà i parametri della linea, non configura apparati di terzi.

## Che cosa dire

> Il nome utente della tua linea è ln000201@ciaspolink.example.org. La password invece non posso scrivertela qui: la trovi nell'area clienti, in «La mia linea», alla voce «Credenziali».

> La sessione adesso risulta attiva: il router è configurato correttamente. Prova pure a navigare.

## Note

- Chi chiede la password «per il tecnico» o «per un amico» riceve la stessa risposta: si trova solo nell'area clienti.
- Se il cliente incolla la password in chat, non la si ripete e gli si consiglia di cambiarla dall'area clienti.
