<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Tests\Integrazione;

use CiaspoLink\Gestionale\Attivazioni\AttivazioneRepository;
use CiaspoLink\Gestionale\Attivazioni\StatoAttivazione;
use CiaspoLink\Gestionale\Attivazioni\TransizioneNonConsentita;
use CiaspoLink\Gestionale\Attivazioni\WorkflowAttivazioni;
use CiaspoLink\Gestionale\Linee\LineaRepository;
use CiaspoLink\Gestionale\Linee\StatoLinea;
use CiaspoLink\Gestionale\Tests\Support\DatabaseDiProva;
use DateTimeImmutable;
use DomainException;
use PDO;
use PHPUnit\Framework\TestCase;

final class WorkflowAttivazioniTest extends TestCase
{
    private PDO $pdo;
    private AttivazioneRepository $attivazioni;
    private WorkflowAttivazioni $workflow;

    protected function setUp(): void
    {
        $this->pdo = DatabaseDiProva::vuoto();
        $this->pdo->exec(<<<'SQL'
            INSERT INTO comuni (id, nome, cap, zona) VALUES (1, 'Rovereto', '38068', 'Vallagarina');
            INSERT INTO offerte VALUES ('CASA_FIBRA_1G', 'Casa Fibra 1 Giga', 'Casa', 'FTTH', 1000, 300, 2290, 3900, 1);
            INSERT INTO copertura (id, comune_id, via, civico, tecnologia, velocita_max_mbps, disponibile_dal,
                                   aggiornata_il)
            VALUES (1, 1, 'Via dei Modelli', '5', 'FTTH', 2500, '2017-02-06', '2026-01-10');
            INSERT INTO clienti (id, tipo, nome, cognome, email, telefono, via, civico, comune_id, cliente_dal)
            VALUES ('CL-009001', 'privato', 'Anna', 'Simulato', 'anna.simulato@example.org', '+39 001 234 5678',
                    'Via dei Modelli', '5', 1, '2026-09-01');
            INSERT INTO linee (id, cliente_id, offerta_codice, copertura_id, accesso, stato)
            VALUES ('LN-009001', 'CL-009001', 'CASA_FIBRA_1G', 1, 'pppoe', 'in_attivazione');
            INSERT INTO attivazioni (id, linea_id, tipo, offerta_codice, stato, richiesta_il, aggiornata_il)
            VALUES ('AT-2026-9001', 'LN-009001', 'nuova', 'CASA_FIBRA_1G', 'richiesta',
                    '2026-09-01T10:00:00+02:00', '2026-09-01T10:00:00+02:00');
            SQL);
        $this->attivazioni = new AttivazioneRepository($this->pdo);
        $this->workflow = new WorkflowAttivazioni($this->pdo, $this->attivazioni, new LineaRepository($this->pdo));
    }

    public function testAvanzaERegistraIlPassaggio(): void
    {
        $attivazione = $this->workflow->avanza(
            'AT-2026-9001',
            StatoAttivazione::VerificaTecnica,
            'Sara Inventato',
            new DateTimeImmutable('2026-09-02T09:15:00+02:00'),
        );

        self::assertSame(StatoAttivazione::VerificaTecnica, $attivazione->stato);
        self::assertSame('2026-09-02T09:15:00+02:00', $attivazione->aggiornataIl);
        $eventi = $this->attivazioni->eventi('AT-2026-9001');
        self::assertCount(1, $eventi);
        self::assertSame('richiesta', $eventi[0]['da_stato']);
        self::assertSame('verifica_tecnica', $eventi[0]['a_stato']);
    }

    public function testRifiutaUnPassaggioNonPrevisto(): void
    {
        $this->expectException(TransizioneNonConsentita::class);

        $this->workflow->avanza(
            'AT-2026-9001',
            StatoAttivazione::Completata,
            'Sara Inventato',
            new DateTimeImmutable(),
        );
    }

    public function testIlCompletamentoMetteInServizioLaLinea(): void
    {
        $passi = [
            StatoAttivazione::VerificaTecnica,
            StatoAttivazione::Pianificata,
            StatoAttivazione::Installazione,
            StatoAttivazione::Completata,
        ];
        foreach ($passi as $giorno => $stato) {
            $this->workflow->avanza(
                'AT-2026-9001',
                $stato,
                'Walter Campione',
                new DateTimeImmutable(sprintf('2026-09-%02dT11:00:00+02:00', 2 + $giorno)),
            );
        }

        $linea = (new LineaRepository($this->pdo))->trova('LN-009001');
        self::assertNotNull($linea);
        self::assertSame(StatoLinea::Attiva, $linea->stato);
        self::assertSame('2026-09-05', $linea->attivaDal);
        self::assertSame('2026-09-05T11:00:00+02:00', $this->attivazioni->trova('AT-2026-9001')?->completataIl);
    }

    public function testAttivazioneInesistente(): void
    {
        $this->expectException(DomainException::class);

        $this->workflow->avanza('AT-2026-0000', StatoAttivazione::Annullata, 'Sara Inventato', new DateTimeImmutable());
    }
}
