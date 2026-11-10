# KB-11 · Guasti collettivi e manutenzioni programmate

| | |
|---|---|
| per chi | tutti i clienti |
| canali | assistenza guidata e operatore |
| vedi anche | KB-01 fibra · KB-04 radio · KB-06 centralino · KB-08 indennizzi · KB-12 orari |

## Quando si usa

Sempre, **prima** di far fare prove a un cliente che non naviga, naviga male o ha il telefono muto: se è in corso un guasto collettivo o una manutenzione, le prove non servono.

## Come funziona, in breve

- Un **guasto collettivo** coinvolge molte linee insieme: una fibra tagliata durante dei lavori, un ponte radio che perde il collegamento, un problema sulla piattaforma voce. I tecnici di rete lo aprono appena il monitoraggio lo vede e lo chiudono al ripristino; compare anche nella pagina dello stato della rete, https://stato-rete.ciaspolink.example.org.
- Le **manutenzioni programmate** si fanno di notte, in finestre brevi. I clienti interessati ricevono un avviso per e-mail **una settimana prima** e la manutenzione compare nella pagina dello stato della rete. Durante la finestra la connessione cade e si riconnette da sola.

## Prima di tutto

1. Riconosci il cliente (KB-15) e controlla lo stato della linea: se la linea è tra quelle coinvolte da un guasto o da una manutenzione, il sistema lo indica.
2. A chi non è cliente o non è riconosciuto si possono dare le informazioni pubbliche sulla zona, le stesse della pagina dello stato della rete.

## Passi guidati: guasto collettivo

1. **Collega** la segnalazione del cliente al guasto: non serve un intervento a domicilio.
2. Spiega che cosa succede in parole semplici, senza sigle né nomi di apparati.
3. **Orari:** si comunica la stima di ripristino solo se i tecnici l'hanno indicata, presentandola come stima; se non c'è, lo si dice e si spiega quando arriverà un aggiornamento.
4. Proponi l'avviso al ripristino, per SMS o e-mail al recapito registrato.
5. **Dopo il ripristino:** se il router non si ricollega da solo entro qualche minuto, spegnerlo per 30 secondi e riaccenderlo.

## Passi guidati: dopo una manutenzione

1. Conferma che c'è stata la manutenzione e che era stata annunciata.
2. Se il router non naviga, nella quasi totalità dei casi basta spegnerlo per 30 secondi e riaccenderlo; poi ricontrolla la sessione.
3. Se la connessione non torna, si segue KB-01 (o KB-04 per la radio).

## Che cosa non fare

- Far riavviare apparati o controllare cavi durante un guasto collettivo.
- Prenotare tecnici a domicilio per un guasto collettivo.
- Inventare cause, orari o indennizzi.
- Dare dettagli tecnici interni: nomi degli apparati, numero esatto delle linee coinvolte.

## Indennizzi

Le richieste di indennizzo per un guasto collettivo si aprono per conto del titolare e le valuta l'amministrazione (KB-08). L'assistenza non promette importi.

## Quando passare a un operatore

- Telesoccorso o situazione delicata su una linea coinvolta nel guasto (KB-16): subito, priorità urgente.
- Cliente business con l'attività bloccata (cassa, prenotazioni, centralino) che chiede di parlare con qualcuno: operatore.
- Il cliente segnala un danno visibile alla rete (cavo tranciato, palo caduto): operatore, che avvisa i tecnici di rete.

## Che cosa dire

> Mi dispiace: c'è un guasto sulla nostra rete nella sua zona e la sua linea è tra quelle ferme. I tecnici sono già sul posto. Non ho ancora un orario di ripristino: le mando un SMS appena la linea torna.

> Stanotte c'è stata una manutenzione programmata sulla nostra rete, annunciata per e-mail la settimana scorsa. A volte il router non si ricollega da solo: lo spenga per 30 secondi e lo riaccenda.

## Note

- Il guasto collettivo non è colpa del cliente: si evita ogni frase che lo faccia pensare.
- Le segnalazioni doppie dello stesso cliente si collegano a quella già aperta.

# KB-04 · Connessione radio (FWA): antenna, segnale e meteo

| | |
|---|---|
| per chi | clienti con Casa Radio o Business Radio (Cles e dintorni) |
| canali | assistenza guidata e operatore |
| vedi anche | KB-11 guasti collettivi · KB-02 speed test · KB-05 router del cliente |

## Quando si usa

Il cliente via radio non naviga, naviga a singhiozzo o molto piano.

## Come funziona, in breve

Sul tetto o sul balcone del cliente c'è una piccola antenna puntata verso la nostra stazione radio. L'antenna riceve corrente e dati con un unico cavo da un **alimentatore** che sta in casa (una scatoletta con una spia), collegato al router. La stazione radio della zona è collegata alla nostra rete con un ponte radio: se il ponte ha un problema, ne risentono tutti i clienti della zona (KB-11).

## Prima di tutto

1. Riconosci il cliente (KB-15).
2. **Controlla se in zona c'è un guasto o un degrado** (KB-11): se c'è, si collega la segnalazione e non si fanno fare prove.
3. Controlla lo stato della linea: **segnale** dell'antenna (meglio di −65 dBm è buono; oltre −75 dBm il collegamento è debole), qualità del collegamento, perdita di pacchetti, sessione di navigazione.

## Che cosa chiedere

- Da quando, e se è successo qualcosa: temporale, vento forte, neve o ghiaccio, lavori sul tetto, alberi cresciuti davanti all'antenna.
- La spia dell'alimentatore dell'antenna: accesa o spenta.
- Se la connessione manca del tutto o va e viene.

## Passi guidati

1. **Spia dell'alimentatore spenta.** Verificare la presa; staccare l'alimentatore dalla corrente per 30 secondi e riattaccarlo.
2. **Cavi.** Controllare che il cavo dall'alimentatore al router sia inserito bene, senza staccare il cavo che sale all'antenna.
3. **Riavvio.** Spegnere il router per 30 secondi e riaccenderlo; attendere 3 minuti.
4. **Ricontrolla il segnale.** Se è debole e in zona non ci sono guasti, l'antenna può essersi spostata (vento) o essere coperta (neve, ghiaccio, rami): serve un tecnico.
5. **Mai** chiedere al cliente di salire sul tetto o di toccare l'antenna: si prenota un intervento (KB-12).

## Il meteo

- Pioggia molto forte, neve bagnata e ghiaccio sull'antenna possono abbassare la velocità per qualche ora; di solito torna normale da sola.
- Il vento forte può spostare l'antenna: se il segnale resta basso anche dopo il maltempo, serve un tecnico.
- Gli alberi che crescono davanti all'antenna peggiorano il segnale soprattutto in primavera e in estate, con le foglie.

## Quando passare a un operatore

- Cliente business senza connessione e nessun guasto noto in zona: subito, priorità alta.
- Segnale debole senza guasti in zona dopo i passi 1–3: intervento tecnico per il riallineamento.
- Più clienti della stessa zona segnalano lo stesso problema e non risulta ancora un guasto collettivo: l'operatore avvisa i tecnici di rete.

## Che cosa dire

> La sua antenna riceve un segnale buono, ma in questo momento c'è un problema sul collegamento radio della zona: i tecnici sono già al lavoro, non serve che faccia prove.

> Il segnale della sua antenna è molto più basso del normale e in zona non ci sono guasti: probabilmente il vento l'ha spostata. Le propongo un tecnico nella prima fascia libera.

## Note

- Non si fa riavviare l'alimentatore più di due volte: poi si passa al tecnico.
- Sulla radio le velocità sono «fino a»: si spiega da che cosa dipendono, senza promettere valori.
