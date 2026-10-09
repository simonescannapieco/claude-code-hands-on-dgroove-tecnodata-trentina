<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

use CiaspoLink\Gestionale\Legacy\PonteListino;
use CiaspoLink\Gestionale\Linee\Linea;
use CiaspoLink\Gestionale\Linee\LineaRepository;
use CiaspoLink\Gestionale\Support\Periodo;
use DateTimeImmutable;
use PDO;
use Throwable;

/**
 * Fatturazione mensile: una fattura per cliente con tutte le sue linee in
 * servizio nel periodo, emessa il primo giorno del mese successivo. Gli
 * importi delle linee vengono dal listino del vecchio gestionale.
 */
final class GeneratoreFatture
{
    private const GIORNI_SCADENZA = 30;

    public function __construct(
        private readonly PDO $pdo,
        private readonly LineaRepository $linee,
        private readonly PonteListino $listino,
        private readonly CalcoloTotali $calcolo,
        private readonly NumeratoreFatture $numeratore,
        private readonly FatturaRepository $fatture,
    ) {
    }

    /**
     * Emette le fatture del periodo, saltando i clienti già fatturati. In
     * simulazione calcola tutto ma non scrive nulla.
     *
     * @return list<Fattura>
     */
    public function emetti(Periodo $periodo, bool $simulazione = false): array
    {
        $emissione = $periodo->ultimoGiorno()->modify('+1 day');
        $lineePerCliente = [];
        foreach ($this->linee->fatturabiliNelPeriodo($periodo) as $linea) {
            $lineePerCliente[$linea->clienteId][] = $linea;
        }

        $fatture = [];
        if (!$simulazione) {
            $this->pdo->beginTransaction();
        }
        try {
            foreach ($lineePerCliente as $clienteId => $linee) {
                if ($this->fatture->esisteFattura((string) $clienteId, $periodo)) {
                    continue;
                }
                $id = $simulazione
                    ? sprintf('SIMULAZIONE-%04d', count($fatture) + 1)
                    : $this->numeratore->prossimo((int) $emissione->format('Y'));
                $fattura = $this->componi($id, (string) $clienteId, $linee, $periodo, $emissione);
                if (!$simulazione) {
                    $this->fatture->salva($fattura);
                }
                $fatture[] = $fattura;
            }
            if (!$simulazione) {
                $this->pdo->commit();
            }
        } catch (Throwable $errore) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $errore;
        }

        return $fatture;
    }

    /**
     * @param list<Linea> $linee
     */
    private function componi(
        string $id,
        string $clienteId,
        array $linee,
        Periodo $periodo,
        DateTimeImmutable $emissione,
    ): Fattura {
        $righe = [];
        foreach ($linee as $linea) {
            array_push($righe, ...$this->listino->righePerLinea($linea->id, $periodo));
        }

        return new Fattura(
            $id,
            $clienteId,
            'fattura',
            (string) $periodo,
            $emissione->format('Y-m-d'),
            $emissione->modify(sprintf('+%d days', self::GIORNI_SCADENZA))->format('Y-m-d'),
            $this->calcolo->calcola($righe),
            'emessa',
            null,
            $righe,
        );
    }
}
