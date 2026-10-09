# KB-01 · Nessuna connessione in fibra: le spie dell'ONT

| | |
|---|---|
| per chi | clienti privati e business con linea in fibra (FTTH) |
| canali | assistenza guidata e operatore |
| vedi anche | KB-11 guasti collettivi · KB-05 router del cliente · KB-13 telefono di casa · KB-16 situazioni delicate |

## Quando si usa

Il cliente in fibra non naviga con nessun dispositivo, né via cavo né in Wi-Fi. Se via cavo funziona e in Wi-Fi no, si passa a KB-03; se naviga ma piano, a KB-02.

## Prima di tutto

1. **Riconosci il cliente** (KB-15): codice cliente o codice linea, più un recapito registrato.
2. **Controlla se in zona c'è un guasto collettivo o una manutenzione** (KB-11). Se c'è, non si fanno fare prove al cliente: si collega la segnalazione al guasto e si segue KB-11.
3. **Controlla lo stato della linea**: segnale ottico, registrazione dell'ONT, sessione di navigazione (privati: sessione PPPoE; aziende: indirizzo ricevuto dalla rete, KB-14).

## Che cosa chiedere

- Da quando non funziona, e se è successo qualcosa: temporale, lavori in casa o in strada, mobili spostati, cavi staccati.
- Le spie dell'**ONT**, la scatoletta bianca dove arriva la fibra (molti la chiamano «modem»):

| spia | se tutto va bene | se è diversa |
|---|---|---|
| POWER | verde fissa | spenta: l'ONT non è alimentato |
| PON | verde fissa | lampeggiante: l'ONT cerca la centrale; spenta: nessun collegamento |
| LOS | spenta | rossa, fissa o lampeggiante: **dalla fibra non arriva luce** |
| LAN | verde, fissa o lampeggiante | spenta: il cavo verso il router è staccato o guasto |

- Le spie del **router** Wi-Fi: alimentazione e «Internet» (su alcuni modelli «WAN»).

## Passi guidati

1. **LOS rossa.** Chiedi di guardare, senza staccarlo, il cavetto sottile della fibra con il connettore verde: non deve essere piegato, schiacciato o tirato. Il connettore non va aperto né pulito. Se la LOS resta rossa e in zona non ci sono guasti, serve un tecnico (passo 6).
2. **POWER spenta.** Verificare presa e alimentatore dell'ONT; provare un'altra presa.
3. **PON lampeggiante da più di 10 minuti, LOS spenta.** Spegnere l'ONT per 30 secondi, riaccenderlo e attendere 5 minuti. Se lampeggia ancora: tecnico.
4. **ONT regolare (POWER e PON verdi, LOS spenta) ma niente internet.** Il problema è tra ONT e router: controllare il cavo di rete tra la porta LAN dell'ONT e la porta WAN del router, poi spegnere il router per 30 secondi e riaccenderlo; attendere 3 minuti.
5. **Ricontrolla lo stato della linea.** Se la sessione è attiva, chiedi una prova di navigazione via cavo. Se il cliente usa un router suo, prosegui con KB-05.
6. **Se non si risolve,** apri la segnalazione con l'esito di ogni passo e proponi un **intervento tecnico** nella prima fascia libera (KB-12): serve una persona maggiorenne in casa.

## Quando passare a un operatore

- LOS rossa senza un guasto collettivo noto e cliente business: subito, priorità alta.
- Sulla linea c'è un telesoccorso o un'altra situazione delicata (KB-16): subito, priorità urgente.
- Dopo i passi 1–5 senza esito, se il cliente chiede di parlare con una persona.
- Il cliente vede un danno alla fibra fuori casa (cavo tranciato, pozzetto aperto durante lavori): l'operatore avvisa i tecnici di rete.

## Che cosa dire

> La spia LOS rossa vuol dire che sulla fibra non arriva la luce dalla nostra centrale. Prima di farle fare prove, controllo se c'è un guasto in zona.

> In zona non risultano guasti. Le chiedo una verifica veloce: guardi il cavetto sottile con il connettore verde che entra nella scatoletta bianca. È piegato o schiacciato? Non lo stacchi.

## Note

- Non si fanno ripetere riavvii già fatti: prima si chiede che cosa il cliente ha già provato.
- Durante un guasto collettivo l'unica prova utile viene **dopo** il ripristino: spegnere e riaccendere il router, se non si ricollega da solo.
