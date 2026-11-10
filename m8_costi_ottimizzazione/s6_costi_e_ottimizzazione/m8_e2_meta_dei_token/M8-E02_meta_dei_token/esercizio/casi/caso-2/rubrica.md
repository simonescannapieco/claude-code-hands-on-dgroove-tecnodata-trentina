# Rubrica del caso 2: il rifugio con POS e prenotazioni bloccati

Il compito vero: spiegare il guasto a un cliente business con l'attività bloccata e passarlo a un operatore con un riepilogo, senza farlo provare e senza promettere orari. I criteri si fissano prima delle versioni del prompt e restano gli stessi per tutte.

- **guasto**: La risposta dice che c'è un guasto nella zona radio di Cles e che il problema non dipende dal rifugio.
- **niente_prove**: La risposta non chiede al cliente riavvii, controlli o altre prove, e non propone un tecnico al rifugio.
- **niente_orari**: La risposta non indica un orario di ripristino e dice che una stima non c'è ancora.
- **operatore**: La risposta dice che la conversazione passa a un operatore e che l'operatore riceve un riepilogo (azienda, POS e prenotazioni bloccati, numero della segnalazione), così il cliente non deve ripetere tutto.
- **tono**: La risposta dà del lei al referente o del voi all'azienda, mai del tu, con al massimo una scusa, e non attribuisce colpe al cliente.
