<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var list<string> $comuni
 * @var array<string, string> $richiesta
 * @var ?\CiaspoLink\Gestionale\Copertura\EsitoCopertura $esito
 * @var ?string $errore
 */
?>
<form method="get" action="index.php" class="filtri">
    <input type="hidden" name="pagina" value="copertura">
    <label>Comune
        <select name="comune">
            <?php foreach ($comuni as $comune) : ?>
                <option<?= $comune === $richiesta['comune'] ? ' selected' : '' ?>><?= $this->e($comune) ?></option>
            <?php endforeach; ?>
        </select>
    </label>
    <label>Via <input type="text" name="via" size="28" value="<?= $this->e($richiesta['via']) ?>"></label>
    <label>Civico <input type="text" name="civico" size="5" value="<?= $this->e($richiesta['civico']) ?>"></label>
    <label>Scala <input type="text" name="scala" size="3" value="<?= $this->e($richiesta['scala']) ?>"></label>
    <button type="submit">Verifica</button>
</form>

<?php if ($errore !== null) : ?>
    <p class="errore"><?= $this->e($errore) ?></p>
<?php elseif ($esito !== null) : ?>
    <p class="<?= $esito->coperto ? 'messaggio' : 'errore' ?>"><?= $this->e($esito->messaggio()) ?></p>
    <?php if ($esito->offerte !== []) : ?>
        <h2>Offerte attivabili</h2>
        <table class="dati">
            <tr><th>Offerta</th><th>Famiglia</th><th>Velocità</th><th>Canone mensile (IVA esclusa)</th></tr>
            <?php foreach ($esito->offerte as $offerta) : ?>
                <tr>
                    <td><?= $this->e($offerta->nome) ?></td>
                    <td><?= $this->e($offerta->famiglia->value) ?></td>
                    <td><?= $this->e($offerta->downloadMbps . '/' . $offerta->uploadMbps) ?> Mbit/s</td>
                    <td class="num"><?= $this->e($this->euro($offerta->canoneCent)) ?></td>
                </tr>
            <?php endforeach; ?>
        </table>
    <?php endif; ?>
<?php endif; ?>
