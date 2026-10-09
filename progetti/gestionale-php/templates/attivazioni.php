<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var list<\CiaspoLink\Gestionale\Attivazioni\Attivazione> $attivazioni
 * @var ?string $messaggio
 * @var ?string $errore
 */
?>
<?php if ($messaggio !== null) : ?>
    <p class="messaggio"><?= $this->e($messaggio) ?></p>
<?php endif; ?>
<?php if ($errore !== null) : ?>
    <p class="errore"><?= $this->e($errore) ?></p>
<?php endif; ?>

<p><?= $this->e(count($attivazioni)) ?> attivazioni non ancora concluse, dalla richiesta più vecchia.</p>
<table class="dati">
    <tr><th>Attivazione</th><th>Cliente</th><th>Comune</th><th>Tipo</th><th>Offerta</th><th>Richiesta</th>
        <th>Pianificata</th><th>Stato</th><th>Passa a</th></tr>
    <?php foreach ($attivazioni as $attivazione) : ?>
        <tr>
            <td><?= $this->e($attivazione->id) ?><br><small><?= $this->e($attivazione->lineaId) ?></small></td>
            <td><a href="index.php?pagina=cliente&amp;id=<?= $this->e($attivazione->clienteId) ?>">
                <?= $this->e($attivazione->clienteNome) ?></a></td>
            <td><?= $this->e($attivazione->comune) ?></td>
            <td><?= $this->e($attivazione->tipo) ?></td>
            <td><?= $this->e($attivazione->offertaCodice) ?></td>
            <td><?= $this->e($this->data($attivazione->richiestaIl)) ?></td>
            <td><?= $this->e($this->data($attivazione->pianificataPer)) ?></td>
            <td><?= $this->e($attivazione->stato->etichetta()) ?></td>
            <td>
                <form method="post" action="index.php?pagina=attivazioni">
                    <input type="hidden" name="id" value="<?= $this->e($attivazione->id) ?>">
                    <select name="stato">
                        <?php foreach ($attivazione->stato->successivi() as $stato) : ?>
                            <option value="<?= $this->e($stato->value) ?>"><?= $this->e($stato->etichetta()) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <input type="text" name="operatore" size="12" placeholder="operatore">
                    <button type="submit">OK</button>
                </form>
            </td>
        </tr>
    <?php endforeach; ?>
</table>
