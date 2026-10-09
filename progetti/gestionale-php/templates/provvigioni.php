<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var \CiaspoLink\Gestionale\Support\Periodo $periodo
 * @var list<\CiaspoLink\Gestionale\Rivenditori\Provvigione> $provvigioni
 * @var array<string, int> $registrate importi in tabella provvigioni, per rivenditore
 * @var ?string $errore
 */
$calcolate = [];
foreach ($provvigioni as $provvigione) {
    $calcolate[$provvigione->rivenditoreId] = $provvigione;
}
$rivenditori = array_unique(array_merge(array_keys($calcolate), array_keys($registrate)));
sort($rivenditori);
?>
<form method="get" action="index.php" class="filtri">
    <input type="hidden" name="pagina" value="provvigioni">
    <label>Mese <input type="month" name="periodo" value="<?= $this->e((string) $periodo) ?>"></label>
    <button type="submit">Mostra</button>
</form>

<?php if ($errore !== null) : ?>
    <p class="errore"><?= $this->e($errore) ?></p>
<?php endif; ?>

<table class="dati">
    <tr><th>Rivenditore</th><th>Attivazioni Casa</th><th>Attivazioni Business</th><th>Provvigione</th>
        <th>Registrata</th></tr>
    <?php foreach ($rivenditori as $id) : ?>
        <?php $calcolata = $calcolate[$id] ?? null; ?>
        <?php $importo = $calcolata?->importoCent ?? 0; ?>
        <tr>
            <td><?= $this->e($id . ' ' . ($calcolata?->ragioneSociale ?? '')) ?></td>
            <td class="num"><?= $this->e($calcolata?->attivazioniCasa ?? 0) ?></td>
            <td class="num"><?= $this->e($calcolata?->attivazioniBusiness ?? 0) ?></td>
            <td class="num"><?= $this->e($this->euro($importo)) ?></td>
            <td class="num<?= isset($registrate[$id]) && $registrate[$id] !== $importo ? ' diverso' : '' ?>">
                <?= isset($registrate[$id]) ? $this->e($this->euro($registrate[$id])) : '-' ?></td>
        </tr>
    <?php endforeach; ?>
</table>
