<?php

declare(strict_types=1);

namespace CiaspoLink\Gestionale\Offerte;

use PDO;

final class CatalogoRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function offerta(string $codice): ?Offerta
    {
        $stmt = $this->pdo->prepare('SELECT * FROM offerte WHERE codice = :codice');
        $stmt->execute(['codice' => $codice]);
        $riga = $stmt->fetch();

        return $riga === false ? null : Offerta::daRiga($riga);
    }

    /**
     * Offerte in listino per una tecnologia, entro la velocità disponibile.
     *
     * @return list<Offerta>
     */
    public function vendibili(Tecnologia $tecnologia, int $velocitaMaxMbps): array
    {
        $stmt = $this->pdo->prepare(<<<'SQL'
            SELECT * FROM offerte
             WHERE in_listino = 1 AND tecnologia = :tecnologia AND download_mbps <= :velocita
             ORDER BY famiglia DESC, canone_cent
            SQL);
        $stmt->execute(['tecnologia' => $tecnologia->value, 'velocita' => $velocitaMaxMbps]);

        return array_map(Offerta::daRiga(...), $stmt->fetchAll());
    }
}
