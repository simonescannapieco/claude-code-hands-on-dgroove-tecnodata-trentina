<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Legacy;

use CiaspoLink\Gestionale\Fatturazione\RigaFattura;
use CiaspoLink\Gestionale\Support\Periodo;
use PDO;

/**
 * Ponte verso il listino del vecchio gestionale (legacy/listino.inc.php), che
 * calcola canoni, ratei, servizi aggiuntivi e promozioni di una linea. Finché
 * quelle regole non vengono portate in src/, la fatturazione passa da qui.
 */
final class PonteListino
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @return list<RigaFattura>
     */
    public function righePerLinea(string $lineaId, Periodo $periodo): array
    {
        require_once __DIR__ . '/../../legacy/listino.inc.php';
        // il listino legge la connessione dalla variabile globale $db
        $GLOBALS['db'] = $this->pdo;

        $righe = [];
        foreach (calcola_importo_linea($lineaId, $periodo->mese, $periodo->anno) as $voce) {
            $righe[] = new RigaFattura(
                (string) $voce['voce'],
                (string) $voce['descrizione'],
                (int) $voce['quantita'],
                (int) $voce['prezzo'],
                (int) $voce['importo'],
                $lineaId,
            );
        }

        return $righe;
    }
}
