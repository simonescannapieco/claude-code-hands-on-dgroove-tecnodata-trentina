# KB-06 · Centralino Cloud: interni «non registrato»

| | |
|---|---|
| per chi | aziende con il Centralino Cloud |
| canali | assistenza guidata e operatore (team voce) |
| vedi anche | KB-11 guasti collettivi · KB-14 linee business · KB-12 orari |

## Quando si usa

I telefoni dell'ufficio mostrano «non registrato» (o «no service»), non entrano chiamate, non si riesce a chiamare fuori, oppure il risponditore non parte.

## Come funziona, in breve

Gli interni sono telefoni IP collegati alla rete dell'ufficio e si registrano, attraverso internet, sulla piattaforma voce di CiaspoLink. Se in ufficio manca internet, o se la piattaforma voce ha un problema, i telefoni non si registrano. L'amministratore del centralino dell'azienda gestisce interni, orari e deviazioni dal portale https://centralino.ciaspolink.example.org.

## Prima di tutto

1. Riconosci il cliente (KB-15): per i clienti business serve uno dei referenti registrati.
2. **Controlla se c'è un guasto sulla piattaforma voce** (KB-11). Se c'è: si collega la segnalazione, si spiega la deviazione d'emergenza (sotto) e non si fanno fare prove sui telefoni.
3. Controlla lo stato della linea dati dell'ufficio.

## Che cosa chiedere

- Quanti interni non funzionano: tutti o solo alcuni.
- Se in ufficio internet funziona.
- Se è cambiato qualcosa in rete: nuovo router o firewall, nuovo switch, lavori elettrici.

## Passi guidati

1. **Tutti gli interni giù, internet funziona:** quasi sempre è un problema centrale. Se non risulta ancora un guasto, si passa subito al team voce.
2. **Tutti gli interni giù, internet non funziona:** è un problema di linea; si segue KB-01 o KB-14.
3. **Solo alcuni interni:** riavviare uno dei telefoni staccandolo dalla corrente (o dal cavo di rete, se è alimentato dal cavo) per 10 secondi; verificare che lo switch dell'ufficio sia acceso.
4. **Dopo un cambio di router o firewall:** sul nuovo apparato va **disattivata la funzione «SIP ALG»** e vanno aperte verso l'esterno le porte indicate nella guida del centralino (nell'area clienti). L'assistenza indica le impostazioni; non configura apparati di terzi.

## La deviazione d'emergenza

Finché gli interni non si registrano, l'amministratore del centralino può deviare le chiamate in arrivo su un cellulare: portale del centralino → «Instradamento» → «Deviazione d'emergenza», inserire il numero e salvare. Si disattiva dallo stesso punto quando il servizio torna. Se l'amministratore non riesce ad accedere al portale, un operatore del team voce può attivarla su richiesta di un referente registrato.

## Quando passare a un operatore

- Tutti gli interni giù senza un guasto noto: subito al team voce, priorità alta.
- Guasto noto, ma il cliente non riesce ad attivare la deviazione: team voce.
- Fuori orario (KB-12): segnalazione con priorità alta e richiamata all'apertura; per chi ha l'Assistenza Prioritaria, il numero dedicato.

## Che cosa dire

> In questo momento c'è un problema sulla nostra piattaforma voce che impedisce ai telefoni di registrarsi: non dipende dai vostri apparecchi. Nel frattempo potete deviare le chiamate in arrivo su un cellulare dal portale del centralino: le spiego come.

> Ho collegato la vostra segnalazione al guasto in corso: la richiamiamo noi al numero che mi ha indicato appena il servizio torna regolare.

## Note

- Durante un guasto della piattaforma non si fanno riavviare tutti i telefoni: non serve.
- Le credenziali degli interni non si comunicano per chat, telefono o e-mail: le gestisce l'amministratore dal portale.
