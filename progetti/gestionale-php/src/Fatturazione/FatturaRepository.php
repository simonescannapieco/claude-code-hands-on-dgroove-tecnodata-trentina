<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Fatturazione;

use CiaspoLink\Gestionale\Support\Periodo;
use PDO;

final class FatturaRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function trova(string $id): ?Fattura
    {
        $stmt = $this->pdo->prepare('SELECT * FROM fatture WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Fattura::daRiga($riga, $this->righe($id));
    }

    /**
     * Fatture e note di credito del cliente, dalla più vecchia, con le righe.
     *
     * @return list<Fattura>
     */
    public function perCliente(string $clienteId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM fatture WHERE cliente_id = :cliente ORDER BY emessa_il, id');
        $stmt->execute(['cliente' => $clienteId]);

        $fatture = [];
        foreach ($stmt->fetchAll() as $riga) {
            $fatture[] = Fattura::daRiga($riga, $this->righe((string) $riga['id']));
        }

        return $fatture;
    }

    public function esisteFattura(string $clienteId, Periodo $periodo): bool
    {
        $stmt = $this->pdo->prepare(
            "SELECT 1 FROM fatture WHERE cliente_id = :cliente AND periodo = :periodo AND tipo = 'fattura'",
        );
        $stmt->execute(['cliente' => $clienteId, 'periodo' => (string) $periodo]);

        return $stmt->fetchColumn() !== false;
    }

    /**
     * Salva documento e righe; la transazione la apre chi chiama.
     */
    public function salva(Fattura $fattura): void
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            INSERT INTO fatture (id, cliente_id, tipo, periodo, emessa_il, scade_il, imponibile_cent, iva_cent,
                                 totale_cent, stato, pagata_il)
            VALUES (:id, :cliente, :tipo, :periodo, :emessa, :scade, :imponibile, :iva, :totale, :stato, :pagata)
            SQL);
        $stmt->execute([
            'id' => $fattura->id,
            'cliente' => $fattura->clienteId,
            'tipo' => $fattura->tipo,
            'periodo' => $fattura->periodo,
            'emessa' => $fattura->emessaIl,
            'scade' => $fattura->scadeIl,
            'imponibile' => $fattura->totali->imponibileCent,
            'iva' => $fattura->totali->ivaCent,
            'totale' => $fattura->totali->totaleCent,
            'stato' => $fattura->stato,
            'pagata' => $fattura->pagataIl,
        ]);

        $stmt = $this->pdo->prepare(<<<'SQL'
            INSERT INTO righe_fattura (fattura_id, linea_id, voce, descrizione, quantita, prezzo_unitario_cent,
                                       importo_cent)
            VALUES (:fattura, :linea, :voce, :descrizione, :quantita, :prezzo, :importo)
            SQL);
        foreach ($fattura->righe as $riga) {
            $stmt->execute([
                'fattura' => $fattura->id,
                'linea' => $riga->lineaId,
                'voce' => $riga->voce,
                'descrizione' => $riga->descrizione,
                'quantita' => $riga->quantita,
                'prezzo' => $riga->prezzoUnitarioCent,
                'importo' => $riga->importoCent,
            ]);
        }
    }

    /**
     * @return list<RigaFattura>
     */
    private function righe(string $fatturaId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM righe_fattura WHERE fattura_id = :fattura ORDER BY id');
        $stmt->execute(['fattura' => $fatturaId]);

        return array_map(RigaFattura::daRiga(...), $stmt->fetchAll());
    }
}
