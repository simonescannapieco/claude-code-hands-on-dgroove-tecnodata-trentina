<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Integrazione;

use CiaspoLink\Gestionale\Tests\Support\DatabaseDiProva;
use DateTimeImmutable;
use PDO;
use PHPUnit\Framework\TestCase;

/**
 * Test di caratterizzazione di chiusura_mese() (legacy/chiusura_mese.inc.php),
 * scritti prima di proporne il refactoring: fissano il comportamento attuale,
 * così com'è (convenzioni 9.3), senza cambiare il modulo.
 *
 * Il legacy usa la connessione che trova in $GLOBALS['db'] (legacy/inc/db.inc.php):
 * qui un database in memoria con pochi dati scritti dal test. La chiusura vera
 * scrive anche il report in var/report/: ogni test lo rimette com'era.
 */
final class ChiusuraMeseTest extends TestCase
{
    private const OGGI = '2026-09-02';
    private const CARTELLA_VAR = __DIR__ . '/../../var';
    private const REPORT = self::CARTELLA_VAR . '/report/chiusura-2026-08.html';

    private const DATI = <<<'SQL'
        INSERT INTO comuni (id, nome, cap, zona) VALUES (1, 'Pergine Valsugana', '38057', 'Valsugana');
        INSERT INTO offerte VALUES ('CASA_FIBRA_1G', 'Casa Fibra 1 Giga', 'Casa', 'FTTH', 1000, 300, 2500, 3900, 1);
        INSERT INTO offerte VALUES ('BUSINESS_FIBRA_1G', 'Business Fibra 1 Giga', 'Business', 'FTTH', 1000, 1000, 5000,
                                    9900, 1);
        INSERT INTO copertura (id, comune_id, via, civico, tecnologia, velocita_max_mbps, disponibile_dal,
                               aggiornata_il)
        VALUES (1, 1, 'Via dell''Esempio', '12', 'FTTH', 2500, '2017-02-06', '2026-01-10');
        INSERT INTO clienti (id, tipo, nome, cognome, ragione_sociale, email, telefono, via, civico, comune_id,
                             stato, cliente_dal, note)
        VALUES ('CL-009101', 'privato', 'Anna', 'Esempio', NULL, 'anna.esempio@example.org', '+39 000 000 9101',
                'Via dell''Esempio', '12', 1, 'attivo', '2024-03-01', NULL),
               ('CL-009102', 'azienda', NULL, NULL, 'Falegnameria Fittizia S.n.c.', 'ufficio@example.org',
                '+39 000 000 9102', 'Via dell''Esempio', '12', 1, 'attivo', '2023-05-10', NULL),
               ('CL-009103', 'privato', 'Marco', 'Prova', NULL, 'marco.prova@example.org', '+39 000 000 9103',
                'Via dell''Esempio', '12', 1, 'sospeso', '2022-01-15', 'Linea sospesa per morosità il 02/08/2026.'),
               ('CL-009104', 'privato', 'Giulia', 'Campione', NULL, 'giulia.campione@example.org',
                '+39 000 000 9104', 'Via dell''Esempio', '12', 1, 'sospeso', '2021-06-01',
                'Linea sospesa per morosità il 02/08/2026.'),
               ('CL-009105', 'privato', 'Luca', 'Fittizio', NULL, 'luca.fittizio@example.org', '+39 000 000 9105',
                'Via dell''Esempio', '12', 1, 'attivo', '2025-02-01', NULL);
        INSERT INTO linee (id, cliente_id, offerta_codice, copertura_id, accesso, stato, attiva_dal, cessata_il)
        VALUES ('LN-009101', 'CL-009101', 'CASA_FIBRA_1G', 1, 'pppoe', 'attiva', '2024-03-10', NULL),
               ('LN-009106', 'CL-009101', 'CASA_FIBRA_1G', 1, 'pppoe', 'cessata', '2019-01-10', '2024-03-09'),
               ('LN-009102', 'CL-009102', 'BUSINESS_FIBRA_1G', 1, 'dhcp', 'attiva', '2023-05-20', NULL),
               ('LN-009103', 'CL-009103', 'CASA_FIBRA_1G', 1, 'pppoe', 'sospesa', '2022-01-20', NULL),
               ('LN-009104', 'CL-009104', 'CASA_FIBRA_1G', 1, 'pppoe', 'sospesa', '2021-06-10', NULL),
               ('LN-009105', 'CL-009105', 'CASA_FIBRA_1G', 1, 'pppoe', 'attiva', '2025-02-10', NULL);
        INSERT INTO fatture (id, cliente_id, tipo, periodo, emessa_il, scade_il, imponibile_cent, iva_cent,
                             totale_cent, stato, pagata_il)
        VALUES ('FT-2026-000910', 'CL-009102', 'fattura', '2026-08', '2026-09-01', '2026-10-01', 5000, 1100, 6100,
                'emessa', NULL),
               ('FT-2026-000911', 'CL-009103', 'fattura', '2026-07', '2026-08-01', '2026-08-31', 2500, 550, 3050,
                'pagata', '2026-08-25'),
               ('FT-2026-000912', 'CL-009104', 'fattura', '2026-06', '2026-07-01', '2026-07-31', 2500, 550, 3050,
                'scaduta', NULL),
               ('FT-2026-000913', 'CL-009105', 'fattura', '2026-07', '2026-08-01', '2026-08-31', 2500, 550, 3050,
                'pagata', '2026-09-01'),
               ('FT-2026-000914', 'CL-009105', 'fattura', '2026-08', '2026-09-01', '2026-09-30', 2500, 550, 3050,
                'emessa', NULL);
        INSERT INTO ticket (id, cliente_id, linea_id, categoria, priorita, stato, canale, oggetto, descrizione,
                            aperto_il, aggiornato_il, chiuso_il)
        VALUES ('TK-2026-09001', 'CL-009102', 'LN-009102', 'guasto', 'alta', 'chiuso', 'telefono', 'Linea ferma',
                'Nessuna connessione.', '2026-08-03T08:00:00+02:00', '2026-08-04T14:00:00+02:00',
                '2026-08-04T14:00:00+02:00'),
               ('TK-2026-09002', 'CL-009102', 'LN-009102', 'guasto', 'alta', 'chiuso', 'telefono',
                'Linea ferma di nuovo', 'Nessuna connessione.', '2026-08-10T09:00:00+02:00',
                '2026-08-25T09:00:00+02:00', '2026-08-25T09:00:00+02:00'),
               ('TK-2026-09003', 'CL-009102', 'LN-009102', 'guasto', 'media', 'chiuso', 'email',
                'Linea assente al mattino', 'Nessuna connessione.', '2026-08-20T09:00:00+02:00',
                '2026-08-21T07:00:00+02:00', '2026-08-21T07:00:00+02:00'),
               ('TK-2026-09004', 'CL-009102', 'LN-009102', 'guasto', 'alta', 'chiuso', 'telefono',
                'Linea ferma a luglio', 'Nessuna connessione.', '2026-07-01T08:00:00+02:00',
                '2026-07-03T08:00:00+02:00', '2026-07-03T08:00:00+02:00'),
               ('TK-2026-09005', 'CL-009105', 'LN-009105', 'guasto', 'alta', 'chiuso', 'telefono', 'Linea ferma',
                'Nessuna connessione.', '2026-08-05T08:00:00+02:00', '2026-08-08T08:00:00+02:00',
                '2026-08-08T08:00:00+02:00');
        SQL;

    private PDO $pdo;
    private int $soglia;
    private ?string $reportPrima = null;
    private bool $varPrima = false;
    private bool $cartellaReportPrima = false;

    public static function setUpBeforeClass(): void
    {
        require_once __DIR__ . '/../../legacy/chiusura_mese.inc.php';
    }

    protected function setUp(): void
    {
        $this->pdo = DatabaseDiProva::vuoto();
        $this->pdo->exec(self::DATI);
        // la soglia della sospensione viene dalla configurazione del legacy, non dal test
        $this->soglia = (int) $GLOBALS['SOGLIA_MOROSITA'];
        $this->fattureEmesseGiaScadute('CL-009101', $this->soglia);
        $GLOBALS['db'] = $this->pdo;
        $this->ricordaIlReport();
    }

    protected function tearDown(): void
    {
        $GLOBALS['db'] = null;
        $this->rimettiIlReport();
    }

    public function testSegnaScaduteLeFattureEmesseOltreLaScadenza(): void
    {
        $esito = $this->chiudiAgosto();

        self::assertSame($this->soglia, $esito['scadute']);
        self::assertSame(
            ['scaduta'],
            $this->colonna("SELECT DISTINCT stato FROM fatture WHERE cliente_id = 'CL-009101'"),
        );
        self::assertSame('pagata', $this->valore("SELECT stato FROM fatture WHERE id = 'FT-2026-000913'"));
        self::assertSame('emessa', $this->valore("SELECT stato FROM fatture WHERE id = 'FT-2026-000914'"));
        self::assertSame('emessa', $this->valore("SELECT stato FROM fatture WHERE id = 'FT-2026-000910'"));
    }

    public function testSospendeIClientiAttiviConTanteFattureScaduteQuantoLaSoglia(): void
    {
        $esito = $this->chiudiAgosto();

        self::assertSame(['CL-009101'], $esito['sospesi']);
        self::assertSame(
            ['stato' => 'sospeso', 'note' => 'Linea sospesa per morosità il 02/09/2026.'],
            $this->riga("SELECT stato, note FROM clienti WHERE id = 'CL-009101'"),
        );
        self::assertSame('sospesa', $this->valore("SELECT stato FROM linee WHERE id = 'LN-009101'"));
        self::assertSame('cessata', $this->valore("SELECT stato FROM linee WHERE id = 'LN-009106'"));
        self::assertSame('attivo', $this->valore("SELECT stato FROM clienti WHERE id = 'CL-009105'"));
    }

    public function testRiattivaISospesiSenzaFattureScadute(): void
    {
        $esito = $this->chiudiAgosto();

        self::assertSame(['CL-009103'], $esito['riattivati']);
        self::assertSame(
            ['stato' => 'attivo', 'note' => null],
            $this->riga("SELECT stato, note FROM clienti WHERE id = 'CL-009103'"),
        );
        self::assertSame('attiva', $this->valore("SELECT stato FROM linee WHERE id = 'LN-009103'"));
        self::assertSame('sospeso', $this->valore("SELECT stato FROM clienti WHERE id = 'CL-009104'"));
        self::assertSame('sospesa', $this->valore("SELECT stato FROM linee WHERE id = 'LN-009104'"));
    }

    public function testEmetteUnaNotaDiCreditoPerIGuastiBusinessDiPiuDi24Ore(): void
    {
        $esito = $this->chiudiAgosto();

        self::assertSame(['FT-2026-000915'], $esito['note_credito']);
        self::assertSame(
            [
                'id' => 'FT-2026-000915',
                'cliente_id' => 'CL-009102',
                'periodo' => '2026-08',
                'emessa_il' => self::OGGI,
                'scade_il' => '2026-10-02',
                'imponibile_cent' => -11000,
                'iva_cent' => -2420,
                'totale_cent' => -13420,
                'stato' => 'emessa',
                'rif_fattura_id' => 'FT-2026-000910',
            ],
            $this->riga(
                "SELECT id, cliente_id, periodo, emessa_il, scade_il, imponibile_cent, iva_cent, totale_cent, stato,
                        rif_fattura_id
                   FROM fatture WHERE tipo = 'nota_credito'",
            ),
        );
    }

    public function testLaNotaDiCreditoHaUnaRigaPerGuastoConIlTettoDi100Euro(): void
    {
        $this->chiudiAgosto();

        self::assertSame(
            [
                ['LN-009102', 'indennizzo', 'Indennizzo disservizio TK-2026-09001 (1 gg)', 1, -1000, -1000],
                ['LN-009102', 'indennizzo', 'Indennizzo disservizio TK-2026-09002 (14 gg)', 1, -10000, -10000],
            ],
            $this->pdo->query(
                "SELECT linea_id, voce, descrizione, quantita, prezzo_unitario_cent, importo_cent
                   FROM righe_fattura WHERE fattura_id = 'FT-2026-000915' ORDER BY id",
            )->fetchAll(PDO::FETCH_NUM),
        );
    }

    public function testRestituisceIlRiepilogoDelleOperazioni(): void
    {
        $esito = $this->chiudiAgosto();

        self::assertSame(
            ['periodo', 'scadute', 'sospesi', 'riattivati', 'note_credito', 'provvigioni', 'operazioni'],
            array_keys($esito),
        );
        self::assertSame('2026-08', $esito['periodo']);
        self::assertSame($this->soglia + 3, $esito['operazioni']);
    }

    public function testRegistraLaChiusuraNelRegistroOperazioni(): void
    {
        $this->chiudiAgosto();

        self::assertSame(
            [sprintf('chiusura 2026-08: %d scadute, 1 sospesi, 1 riattivati, 1 note di credito', $this->soglia)],
            $this->colonna("SELECT messaggio FROM registro_operazioni WHERE modulo = 'chiusura'"),
        );
    }

    public function testScriveIlReportDelMeseInVarReport(): void
    {
        $this->chiudiAgosto();

        self::assertFileExists(self::REPORT);
        $report = (string) file_get_contents(self::REPORT);
        self::assertStringContainsString('<h1>CiaspoLink S.r.l. - chiusura di agosto 2026</h1>', $report);
        self::assertStringContainsString(sprintf('<tr><th>Fatture scadute</th><td>%d</td>', $this->soglia), $report);
        self::assertStringContainsString('<tr><th>Clienti sospesi</th><td>1</td><td>CL-009101</td></tr>', $report);
        self::assertStringContainsString('<tr><th>Clienti riattivati</th><td>1</td><td>CL-009103</td></tr>', $report);
        self::assertStringContainsString('<tr><th>Note di credito</th><td>1</td><td>-134,20 &euro;</td></tr>', $report);
        self::assertStringContainsString(sprintf('Dettaglio (%d operazioni)', $this->soglia + 3), $report);
    }

    public function testInSimulazioneCalcolaMaNonScriveNiente(): void
    {
        $prima = $this->fotografia();

        $esito = $this->chiudiAgosto(true);

        self::assertSame($prima, $this->fotografia());
        self::assertSame(0, (int) $this->valore('SELECT COUNT(*) FROM registro_operazioni'));
        self::assertSame($this->reportPrima !== null, is_file(self::REPORT));
        self::assertSame($this->soglia, $esito['scadute']);
        // in simulazione le fatture appena scadute non contano ancora per la sospensione
        self::assertSame([], $esito['sospesi']);
        self::assertSame(['CL-009103'], $esito['riattivati']);
        self::assertSame(['(simulazione)'], $esito['note_credito']);
        self::assertSame($this->soglia + 2, $esito['operazioni']);
    }

    public function testUnaSecondaChiusuraDelloStessoMeseNonRipeteLaNotaDiCredito(): void
    {
        $this->chiudiAgosto();

        $esito = $this->chiudiAgosto();

        self::assertSame(0, $esito['scadute']);
        self::assertSame([], $esito['sospesi']);
        self::assertSame([], $esito['riattivati']);
        self::assertSame([], $esito['note_credito']);
        self::assertSame(0, $esito['operazioni']);
        self::assertSame(1, (int) $this->valore("SELECT COUNT(*) FROM fatture WHERE tipo = 'nota_credito'"));
    }

    public function testUnMeseNonValidoStampaUnMessaggioENonFaNiente(): void
    {
        $prima = $this->fotografia();
        $this->expectOutputString("Mese non valido: 13\n");

        $esito = chiusura_mese(2026, 13, ['oggi' => self::OGGI, 'verbose' => false]);

        self::assertFalse($esito);
        self::assertSame($prima, $this->fotografia());
    }

    /**
     * @return array<string, mixed>|false
     */
    private function chiudiAgosto(bool $simula = false): array|false
    {
        return chiusura_mese(2026, 8, ['oggi' => self::OGGI, 'verbose' => false, 'simula' => $simula]);
    }

    /**
     * Tante fatture emesse e già scadute quante ne servono, una per mese a
     * ritroso da luglio 2026.
     */
    private function fattureEmesseGiaScadute(string $clienteId, int $quante): void
    {
        $inserisci = $this->pdo->prepare(
            "INSERT INTO fatture (id, cliente_id, tipo, periodo, emessa_il, scade_il, imponibile_cent, iva_cent,
                                  totale_cent, stato)
             VALUES (:id, :cliente, 'fattura', :periodo, :emessa, :scade, 2500, 550, 3050, 'emessa')",
        );
        $luglio = new DateTimeImmutable('2026-07-01');
        for ($n = 0; $n < $quante; $n++) {
            $periodo = $luglio->modify(sprintf('-%d month', $n));
            $emessa = $periodo->modify('+1 month');
            $inserisci->execute([
                'id' => sprintf('FT-%s-%06d', $emessa->format('Y'), 801 + $n),
                'cliente' => $clienteId,
                'periodo' => $periodo->format('Y-m'),
                'emessa' => $emessa->format('Y-m-d'),
                'scade' => $emessa->modify('+30 days')->format('Y-m-d'),
            ]);
        }
    }

    /**
     * Gli stati di fatture, clienti e linee, per confrontare prima e dopo.
     *
     * @return array<string, list<array<string, mixed>>>
     */
    private function fotografia(): array
    {
        return [
            'fatture' => $this->pdo->query('SELECT id, tipo, stato FROM fatture ORDER BY id')->fetchAll(),
            'clienti' => $this->pdo->query('SELECT id, stato, note FROM clienti ORDER BY id')->fetchAll(),
            'linee' => $this->pdo->query('SELECT id, stato FROM linee ORDER BY id')->fetchAll(),
            'righe' => $this->pdo->query('SELECT fattura_id FROM righe_fattura ORDER BY id')->fetchAll(),
        ];
    }

    private function valore(string $sql): mixed
    {
        return $this->pdo->query($sql)->fetchColumn();
    }

    /**
     * @return list<mixed>
     */
    private function colonna(string $sql): array
    {
        return $this->pdo->query($sql)->fetchAll(PDO::FETCH_COLUMN);
    }

    /**
     * @return array<string, mixed>
     */
    private function riga(string $sql): array
    {
        $riga = $this->pdo->query($sql)->fetch();
        self::assertIsArray($riga);

        return $riga;
    }

    private function ricordaIlReport(): void
    {
        $this->varPrima = is_dir(self::CARTELLA_VAR);
        $this->cartellaReportPrima = is_dir(dirname(self::REPORT));
        $this->reportPrima = is_file(self::REPORT) ? (string) file_get_contents(self::REPORT) : null;
    }

    private function rimettiIlReport(): void
    {
        if ($this->reportPrima !== null) {
            file_put_contents(self::REPORT, $this->reportPrima);
            return;
        }
        if (is_file(self::REPORT)) {
            unlink(self::REPORT);
        }
        if (!$this->cartellaReportPrima && is_dir(dirname(self::REPORT))) {
            rmdir(dirname(self::REPORT));
        }
        if (!$this->varPrima && is_dir(self::CARTELLA_VAR)) {
            rmdir(self::CARTELLA_VAR);
        }
    }
}
