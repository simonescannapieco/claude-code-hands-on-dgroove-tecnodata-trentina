`VerificaCopertura::verifica()` dice se un indirizzo (comune, via, civico, scala) è coperto, e con che cosa.
Normalizza l'indirizzo con `IndirizzoNormalizzato::da()` e legge le righe di copertura del civico da `CoperturaRepository::perIndirizzo()`.
Una riga è disponibile se `disponibile_dal` c'è ed è minore o uguale al giorno della verifica: il giorno stesso conta già.
Il giorno è `$alGiorno` se lo si passa, altrimenti la data di oggi.
Fra le righe disponibili sceglie la migliore: la fibra (FTTH) prima della radio (FWA), poi la velocità più alta.
Se nessuna è disponibile l'esito è «non coperto», con la tecnologia della prima riga non ancora disponibile indicata come pianificata.
Se c'è, l'esito porta tecnologia, velocità, apparato e le offerte vendibili, da `CatalogoRepository::vendibili()`.
`comuni()` elenca i comuni della tabella `comuni`, per il modulo della pagina.
La costruisce `Applicazione::verificaCopertura()`; la chiama `CruscottoController::copertura()`, la pagina `index.php?pagina=copertura`.
La provano i test di integrazione di `tests/Integrazione/VerificaCoperturaTest.php`, sui dati di esempio.
