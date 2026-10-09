-- Schema del gestionale CiaspoLink (SQLite 3).
--
-- Convenzioni dei dati:
--   * importi in centesimi di euro (INTEGER), IVA esclusa salvo dove indicato;
--   * date nel formato YYYY-MM-DD; date e ore in ISO 8601 con l'offset del
--     fuso Europe/Rome (es. 2026-09-08T10:12:00+02:00);
--   * identificativi: CL-000123 cliente, LN-000456 linea, AT-2026-0012
--     attivazione, TK-2026-00123 ticket, FT-2026-000123 fattura, RV-012
--     rivenditore, <ruolo>-<comune>-<nn> apparato.
--
-- I dati di esempio sono nei file di database/dati/, generati da genera.py.
-- Il database si crea con: php bin/inizializza-db.php

PRAGMA foreign_keys = ON;

CREATE TABLE comuni (
    id          INTEGER PRIMARY KEY,
    nome        TEXT    NOT NULL UNIQUE,
    cap         TEXT    NOT NULL CHECK (length(cap) = 5),
    provincia   TEXT    NOT NULL DEFAULT 'TN',
    zona        TEXT    NOT NULL                    -- valle o zona commerciale
);

CREATE TABLE apparati (
    id           TEXT    PRIMARY KEY,               -- <ruolo>-<comune>-<nn>
    ruolo        TEXT    NOT NULL CHECK (ruolo IN ('olt', 'bng', 'ptp', 'bts', 'sbc')),
    descrizione  TEXT    NOT NULL,
    comune_id    INTEGER NOT NULL REFERENCES comuni (id),
    ip_gestione  TEXT    NOT NULL UNIQUE,
    uplink_id    TEXT    REFERENCES apparati (id),  -- apparato a monte
    stato        TEXT    NOT NULL DEFAULT 'in_servizio'
                         CHECK (stato IN ('in_servizio', 'manutenzione', 'dismesso'))
);

-- Copertura per indirizzo: una riga per ogni tecnologia disponibile
-- (o pianificata, se disponibile_dal è NULL) a quell'indirizzo.
CREATE TABLE copertura (
    id                 INTEGER PRIMARY KEY,
    comune_id          INTEGER NOT NULL REFERENCES comuni (id),
    via                TEXT    NOT NULL,
    civico             TEXT    NOT NULL,
    scala              TEXT    NOT NULL DEFAULT '', -- '' se l'edificio ha un solo ingresso
    tecnologia         TEXT    NOT NULL CHECK (tecnologia IN ('FTTH', 'FWA')),
    velocita_max_mbps  INTEGER NOT NULL,
    apparato_id        TEXT    REFERENCES apparati (id),
    disponibile_dal    TEXT,
    aggiornata_il      TEXT    NOT NULL,
    UNIQUE (comune_id, via, civico, scala, tecnologia)
);

CREATE TABLE offerte (
    codice            TEXT    PRIMARY KEY,
    nome              TEXT    NOT NULL,
    famiglia          TEXT    NOT NULL CHECK (famiglia IN ('Casa', 'Business')),
    tecnologia        TEXT    NOT NULL CHECK (tecnologia IN ('FTTH', 'FWA')),
    download_mbps     INTEGER NOT NULL,
    upload_mbps       INTEGER NOT NULL,
    canone_cent       INTEGER NOT NULL,             -- canone mensile, IVA esclusa
    attivazione_cent  INTEGER NOT NULL,             -- contributo una tantum, IVA esclusa
    in_listino        INTEGER NOT NULL DEFAULT 1 CHECK (in_listino IN (0, 1))
);

-- Servizi aggiuntivi, a canone mensile per unità.
CREATE TABLE servizi (
    codice         TEXT    PRIMARY KEY,
    nome           TEXT    NOT NULL,
    unita          TEXT    NOT NULL,                -- linea, indirizzo, interno
    canone_cent    INTEGER NOT NULL,                -- IVA esclusa
    solo_business  INTEGER NOT NULL DEFAULT 0 CHECK (solo_business IN (0, 1))
);

CREATE TABLE rivenditori (
    id                         TEXT    PRIMARY KEY, -- RV-012
    ragione_sociale            TEXT    NOT NULL,
    referente                  TEXT    NOT NULL,
    comune_id                  INTEGER NOT NULL REFERENCES comuni (id),
    email                      TEXT    NOT NULL,
    telefono                   TEXT    NOT NULL,
    partita_iva                TEXT    NOT NULL,
    provvigione_casa_cent      INTEGER NOT NULL,    -- per nuova attivazione Casa completata
    provvigione_business_cent  INTEGER NOT NULL,    -- per nuova attivazione Business completata
    convenzionato_dal          TEXT    NOT NULL,
    attivo                     INTEGER NOT NULL DEFAULT 1 CHECK (attivo IN (0, 1))
);

CREATE TABLE clienti (
    id               TEXT    PRIMARY KEY,           -- CL-000123
    tipo             TEXT    NOT NULL CHECK (tipo IN ('privato', 'azienda', 'associazione')),
    nome             TEXT,                          -- solo privati
    cognome          TEXT,                          -- solo privati
    ragione_sociale  TEXT,                          -- aziende e associazioni
    partita_iva      TEXT,                          -- aziende
    email            TEXT    NOT NULL,
    telefono         TEXT    NOT NULL,
    via              TEXT    NOT NULL,
    civico           TEXT    NOT NULL,
    comune_id        INTEGER NOT NULL REFERENCES comuni (id),
    rivenditore_id   TEXT    REFERENCES rivenditori (id),
    stato            TEXT    NOT NULL DEFAULT 'attivo'
                             CHECK (stato IN ('attivo', 'sospeso', 'cessato')),
    cliente_dal      TEXT    NOT NULL,
    note             TEXT
);

CREATE TABLE linee (
    id              TEXT    PRIMARY KEY,            -- LN-000456
    cliente_id      TEXT    NOT NULL REFERENCES clienti (id),
    offerta_codice  TEXT    NOT NULL REFERENCES offerte (codice),
    copertura_id    INTEGER NOT NULL REFERENCES copertura (id),
    apparato_id     TEXT    REFERENCES apparati (id),
    porta           TEXT,                           -- porta PON (0/1/3) o settore radio (S2)
    accesso         TEXT    NOT NULL CHECK (accesso IN ('pppoe', 'dhcp')),
    utenza_pppoe    TEXT    UNIQUE,                 -- ln000456@ciaspolink.example.org
    mac_cpe         TEXT    UNIQUE,
    ipv4_statico    TEXT    UNIQUE,
    prefisso_ipv6   TEXT    UNIQUE,
    stato           TEXT    NOT NULL
                            CHECK (stato IN ('in_attivazione', 'attiva', 'sospesa', 'cessata')),
    attiva_dal      TEXT,
    cessata_il      TEXT
);

CREATE TABLE linee_servizi (
    linea_id         TEXT    NOT NULL REFERENCES linee (id),
    servizio_codice  TEXT    NOT NULL REFERENCES servizi (codice),
    quantita         INTEGER NOT NULL DEFAULT 1 CHECK (quantita > 0),
    dal              TEXT    NOT NULL,
    al               TEXT,
    PRIMARY KEY (linea_id, servizio_codice, dal)
);

CREATE TABLE attivazioni (
    id               TEXT    PRIMARY KEY,           -- AT-2026-0012
    linea_id         TEXT    NOT NULL REFERENCES linee (id),
    tipo             TEXT    NOT NULL CHECK (tipo IN ('nuova', 'cambio_offerta', 'trasloco')),
    offerta_codice   TEXT    NOT NULL REFERENCES offerte (codice), -- offerta richiesta
    rivenditore_id   TEXT    REFERENCES rivenditori (id),
    stato            TEXT    NOT NULL CHECK (stato IN ('richiesta', 'verifica_tecnica', 'pianificata',
                                                       'installazione', 'completata', 'annullata')),
    richiesta_il     TEXT    NOT NULL,
    pianificata_per  TEXT,
    completata_il    TEXT,
    aggiornata_il    TEXT    NOT NULL,
    tecnico          TEXT,
    note             TEXT
);

-- Storico dei passaggi di stato (registrato dal settembre 2025).
CREATE TABLE attivazioni_eventi (
    id              INTEGER PRIMARY KEY,
    attivazione_id  TEXT    NOT NULL REFERENCES attivazioni (id),
    da_stato        TEXT,
    a_stato         TEXT    NOT NULL,
    avvenuto_il     TEXT    NOT NULL,
    operatore       TEXT    NOT NULL
);

CREATE TABLE ticket (
    id             TEXT    PRIMARY KEY,             -- TK-2026-00123
    cliente_id     TEXT    REFERENCES clienti (id), -- NULL per i ticket aperti dal monitoraggio
    linea_id       TEXT    REFERENCES linee (id),
    apparato_id    TEXT    REFERENCES apparati (id),
    padre_id       TEXT    REFERENCES ticket (id),  -- ticket del disservizio a cui è collegato
    categoria      TEXT    NOT NULL CHECK (categoria IN ('guasto', 'lentezza', 'voce', 'wifi',
                                                         'amministrativo', 'attivazione',
                                                         'disservizio', 'manutenzione')),
    priorita       TEXT    NOT NULL CHECK (priorita IN ('bassa', 'media', 'alta', 'critica')),
    stato          TEXT    NOT NULL CHECK (stato IN ('aperto', 'in_lavorazione', 'in_attesa_cliente',
                                                     'risolto', 'chiuso')),
    canale         TEXT    NOT NULL CHECK (canale IN ('telefono', 'email', 'web', 'rivenditore',
                                                      'monitoraggio')),
    oggetto        TEXT    NOT NULL,
    descrizione    TEXT    NOT NULL,
    aperto_il      TEXT    NOT NULL,
    aggiornato_il  TEXT    NOT NULL,
    chiuso_il      TEXT,
    assegnato_a    TEXT
);

-- Fatture e note di credito (queste ultime con importi negativi).
-- L'IVA è il 22 % del totale imponibile, arrotondato al centesimo.
CREATE TABLE fatture (
    id               TEXT    PRIMARY KEY,           -- FT-2026-000123
    cliente_id       TEXT    NOT NULL REFERENCES clienti (id),
    tipo             TEXT    NOT NULL CHECK (tipo IN ('fattura', 'nota_credito')),
    periodo          TEXT,                          -- YYYY-MM del servizio fatturato
    emessa_il        TEXT    NOT NULL,
    scade_il         TEXT    NOT NULL,
    imponibile_cent  INTEGER NOT NULL,
    iva_cent         INTEGER NOT NULL,
    totale_cent      INTEGER NOT NULL,
    stato            TEXT    NOT NULL CHECK (stato IN ('emessa', 'pagata', 'scaduta', 'annullata')),
    pagata_il        TEXT,
    rif_fattura_id   TEXT    REFERENCES fatture (id) -- per le note di credito
);

-- Voci di fattura. Il rateo è la quota del canone per i giorni di servizio
-- nel mese: canone × giorni di servizio / giorni del mese.
CREATE TABLE righe_fattura (
    id                    INTEGER PRIMARY KEY,
    fattura_id            TEXT    NOT NULL REFERENCES fatture (id),
    linea_id              TEXT    REFERENCES linee (id),
    voce                  TEXT    NOT NULL CHECK (voce IN ('canone', 'rateo', 'servizio', 'attivazione',
                                                           'sconto', 'indennizzo', 'storno')),
    descrizione           TEXT    NOT NULL,
    quantita              INTEGER NOT NULL DEFAULT 1,
    prezzo_unitario_cent  INTEGER NOT NULL,
    importo_cent          INTEGER NOT NULL
);

CREATE TABLE provvigioni (
    id                    INTEGER PRIMARY KEY,
    rivenditore_id        TEXT    NOT NULL REFERENCES rivenditori (id),
    periodo               TEXT    NOT NULL,         -- YYYY-MM
    attivazioni_casa      INTEGER NOT NULL,
    attivazioni_business  INTEGER NOT NULL,
    importo_cent          INTEGER NOT NULL,
    calcolata_il          TEXT    NOT NULL,
    stato                 TEXT    NOT NULL CHECK (stato IN ('calcolata', 'liquidata')),
    UNIQUE (rivenditore_id, periodo)
);

-- Registro scritto dai moduli della cartella legacy/.
CREATE TABLE registro_operazioni (
    id         INTEGER PRIMARY KEY,
    quando     TEXT    NOT NULL,
    modulo     TEXT    NOT NULL,
    messaggio  TEXT    NOT NULL
);

CREATE INDEX idx_clienti_comune ON clienti (comune_id);
CREATE INDEX idx_linee_cliente ON linee (cliente_id);
CREATE INDEX idx_linee_apparato ON linee (apparato_id, porta);
CREATE INDEX idx_copertura_indirizzo ON copertura (comune_id, via, civico);
CREATE INDEX idx_attivazioni_linea ON attivazioni (linea_id);
CREATE INDEX idx_attivazioni_stato ON attivazioni (stato);
CREATE INDEX idx_eventi_attivazione ON attivazioni_eventi (attivazione_id);
CREATE INDEX idx_ticket_cliente ON ticket (cliente_id);
CREATE INDEX idx_ticket_stato ON ticket (stato, priorita);
CREATE INDEX idx_fatture_cliente ON fatture (cliente_id, periodo);
CREATE UNIQUE INDEX ux_fatture_periodo ON fatture (cliente_id, periodo) WHERE tipo = 'fattura';
CREATE INDEX idx_righe_fattura ON righe_fattura (fattura_id);
