<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var \CiaspoLink\Gestionale\Support\Periodo $dal
 * @var \CiaspoLink\Gestionale\Support\Periodo $al
 * @var list<array{zona: string, clienti: int, documenti: int, imponibile: int, iva: int, totale: int}> $righe
 * @var ?string $errore
 */
$totali = ['clienti' => 0, 'documenti' => 0, 'imponibile' => 0, 'iva' => 0, 'totale' => 0];
foreach ($righe as $riga) {
    foreach ($totali as $chiave => $valore) {
        $totali[$chiave] = $valore + $riga[$chiave];
    }
}
?>
<form method="get" action="index.php" class="filtri">
    <input type="hidden" name="pagina" value="report-fatturato">
    <label>Dal mese <input type="month" name="dal" value="<?= $this->e((string) $dal) ?>"></label>
    <label>Al mese <input type="month" name="al" value="<?= $this->e((string) $al) ?>"></label>
    <button type="submit">Calcola</button>
</form>

<?php if ($errore !== null) : ?>
    <p class="errore"><?= $this->e($errore) ?></p>
<?php endif; ?>

<table class="dati">
    <tr><th>Zona</th><th>Clienti</th><th>Documenti</th><th>Imponibile</th><th>IVA</th><th>Totale</th></tr>
    <?php foreach ($righe as $riga) : ?>
        <tr>
            <td><?= $this->e($riga['zona']) ?></td>
            <td class="num"><?= $this->e($riga['clienti']) ?></td>
            <td class="num"><?= $this->e($riga['documenti']) ?></td>
            <td class="num"><?= $this->e($this->euro($riga['imponibile'])) ?></td>
            <td class="num"><?= $this->e($this->euro($riga['iva'])) ?></td>
            <td class="num"><?= $this->e($this->euro($riga['totale'])) ?></td>
        </tr>
    <?php endforeach; ?>
    <tr>
        <th>Totale</th>
        <th class="num"><?= $this->e($totali['clienti']) ?></th>
        <th class="num"><?= $this->e($totali['documenti']) ?></th>
        <th class="num"><?= $this->e($this->euro($totali['imponibile'])) ?></th>
        <th class="num"><?= $this->e($this->euro($totali['iva'])) ?></th>
        <th class="num"><?= $this->e($this->euro($totali['totale'])) ?></th>
    </tr>
</table>
