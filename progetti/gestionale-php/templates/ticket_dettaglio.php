<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var \CiaspoLink\Gestionale\Ticket\Ticket $ticket
 * @var ?\CiaspoLink\Gestionale\Ticket\Ticket $padre
 * @var list<\CiaspoLink\Gestionale\Ticket\Ticket> $figli
 * @var list<\CiaspoLink\Gestionale\Ticket\StatoTicket> $stati
 * @var ?string $messaggio
 */
?>
<?php if ($messaggio !== null) : ?>
    <p class="messaggio"><?= $this->e($messaggio) ?></p>
<?php endif; ?>

<table class="dati">
    <tr><th>Oggetto</th><td><?= $this->e($ticket->oggetto) ?></td></tr>
    <tr><th>Descrizione</th><td><?= nl2br($this->e($ticket->descrizione)) ?></td></tr>
    <tr><th>Cliente</th><td>
        <?php if ($ticket->clienteId !== null) : ?>
            <a href="index.php?pagina=cliente&amp;id=<?= $this->e($ticket->clienteId) ?>">
                <?= $this->e($ticket->clienteId . ' ' . $ticket->clienteNome) ?></a>
        <?php else : ?>-<?php endif; ?>
    </td></tr>
    <tr><th>Linea / apparato</th><td><?= $this->e(($ticket->lineaId ?? '-') . ' / ' . ($ticket->apparatoId ?? '-')) ?></td></tr>
    <tr><th>Categoria e priorità</th><td><?= $this->e($ticket->categoria . ', ' . $ticket->priorita->value) ?></td></tr>
    <tr><th>Canale</th><td><?= $this->e($ticket->canale) ?></td></tr>
    <tr><th>Stato</th><td><?= $this->e($ticket->stato->etichetta()) ?></td></tr>
    <tr><th>Aperto / aggiornato / chiuso</th>
        <td><?= $this->e($this->data($ticket->apertoIl) . ' / ' . $this->data($ticket->aggiornatoIl) . ' / '
            . $this->data($ticket->chiusoIl)) ?></td></tr>
    <tr><th>Assegnato a</th><td><?= $this->e($ticket->assegnatoA ?? '-') ?></td></tr>
    <?php if ($padre !== null) : ?>
        <tr><th>Disservizio</th><td><a href="index.php?pagina=ticket-dettaglio&amp;id=<?= $this->e($padre->id) ?>">
            <?= $this->e($padre->id . ' ' . $padre->oggetto) ?></a></td></tr>
    <?php endif; ?>
</table>

<form method="post" action="index.php?pagina=ticket-dettaglio&amp;id=<?= $this->e($ticket->id) ?>" class="filtri">
    <label>Nuovo stato
        <select name="stato">
            <?php foreach ($stati as $stato) : ?>
                <option value="<?= $this->e($stato->value) ?>"<?= $stato === $ticket->stato ? ' selected' : '' ?>>
                    <?= $this->e($stato->etichetta()) ?></option>
            <?php endforeach; ?>
        </select>
    </label>
    <label>Operatore <input type="text" name="operatore" size="18"></label>
    <button type="submit">Aggiorna</button>
</form>

<?php if ($figli !== []) : ?>
    <h2>Ticket collegati (<?= $this->e(count($figli)) ?>)</h2>
    <table class="dati">
        <tr><th>Ticket</th><th>Aperto</th><th>Cliente</th><th>Linea</th><th>Oggetto</th><th>Stato</th></tr>
        <?php foreach ($figli as $figlio) : ?>
            <tr>
                <td><a href="index.php?pagina=ticket-dettaglio&amp;id=<?= $this->e($figlio->id) ?>">
                    <?= $this->e($figlio->id) ?></a></td>
                <td><?= $this->e($this->data($figlio->apertoIl)) ?></td>
                <td><?= $this->e($figlio->clienteNome ?? '-') ?></td>
                <td><?= $this->e($figlio->lineaId ?? '-') ?></td>
                <td><?= $this->e($figlio->oggetto) ?></td>
                <td><?= $this->e($figlio->stato->etichetta()) ?></td>
            </tr>
        <?php endforeach; ?>
    </table>
<?php endif; ?>
