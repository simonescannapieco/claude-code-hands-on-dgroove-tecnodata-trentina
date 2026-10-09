-- Dati di esempio del gestionale CiaspoLink: offerte e servizi aggiuntivi.
-- Generato da genera.py (seme 20260907): non modificare a mano, rigenerare.

INSERT INTO offerte (codice, nome, famiglia, tecnologia, download_mbps, upload_mbps, canone_cent, attivazione_cent, in_listino) VALUES
('CASA_FIBRA_300', 'Casa Fibra 300', 'Casa', 'FTTH', 300, 100, 1990, 3900, 0),
('CASA_FIBRA_1G', 'Casa Fibra 1 Giga', 'Casa', 'FTTH', 1000, 300, 2290, 3900, 1),
('CASA_FIBRA_25G', 'Casa Fibra 2,5 Giga', 'Casa', 'FTTH', 2500, 500, 3190, 3900, 1),
('CASA_RADIO', 'Casa Radio', 'Casa', 'FWA', 100, 20, 2150, 7900, 1),
('BIZ_FIBRA_1G', 'Business Fibra 1 Giga', 'Business', 'FTTH', 1000, 1000, 4900, 9900, 1),
('BIZ_FIBRA_25G', 'Business Fibra 2,5 Giga', 'Business', 'FTTH', 2500, 1000, 7900, 9900, 1),
('BIZ_RADIO', 'Business Radio', 'Business', 'FWA', 200, 50, 4400, 14900, 1);

INSERT INTO servizi (codice, nome, unita, canone_cent, solo_business) VALUES
('HOTSPOT_WIFI', 'Hotspot Wi-Fi', 'linea', 1900, 1),
('IP_STATICO', 'IP statico', 'indirizzo', 500, 0),
('LINEA_VOCE', 'Linea voce di casa', 'linea', 300, 0),
('VOIP_INTERNO', 'Centralino Cloud - interno VoIP', 'interno', 390, 1);
