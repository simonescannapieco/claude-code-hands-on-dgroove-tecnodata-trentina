<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var \CiaspoLink\Gestionale\Ticket\FiltroTicket $filtro
 * @var list<\CiaspoLink\Gestionale\Ticket\Ticket> $ticket
 * @var list<\CiaspoLink\Gestionale\Ticket\StatoTicket> $stati
 * @var list<\CiaspoLink\Gestionale\Ticket\PrioritaTicket> $priorita
 * @var list<string> $categorie
 */
?>
<form method="get" action="index.php" class="filtri">
    <input type="hidden" name="pagina" value="ticket">
    <label>Stato
        <select name="stato">
            <option value="">tutti</option>
            <?php foreach ($stati as $stato) : ?>
                <option value="<?= $this->e($stato->value) ?>"<?= $filtro->stato === $stato ? ' selected' : '' ?>>
                    <?= $this->e($stato->etichetta()) ?></option>
            <?php endforeach; ?>
        </select>
    </label>
    <label>Priorità
        <select name="priorita">
            <option value="">tutte</option>
            <?php foreach ($priorita as $voce) : ?>
                <option<?= $filtro->priorita === $voce ? ' selected' : '' ?>><?= $this->e($voce->value) ?></option>
            <?php endforeach; ?>
        </select>
    </label>
    <label>Categoria
        <select name="categoria">
            <option value="">tutte</option>
            <?php foreach ($categorie as $categoria) : ?>
                <option<?= $filtro->categoria === $categoria ? ' selected' : '' ?>><?= $this->e($categoria) ?></option>
            <?php endforeach; ?>
        </select>
    </label>
    <label>Cliente <input type="text" name="cliente" size="10" placeholder="CL-000000"
                          value="<?= $this->e($filtro->clienteId ?? '') ?>"></label>
    <label>Apparato <input type="text" name="apparato" size="16" placeholder="olt-pergine-01"
                           value="<?= $this->e($filtro->apparatoId ?? '') ?>"></label>
    <label>Dal <input type="date" name="dal" value="<?= $this->e($filtro->dal?->format('Y-m-d') ?? '') ?>"></label>
    <label>Al <input type="date" name="al" value="<?= $this->e($filtro->al?->format('Y-m-d') ?? '') ?>"></label>
    <label><input type="checkbox" name="aperti" value="1"<?= $filtro->soloAperti ? ' checked' : '' ?>>
        solo aperti</label>
    <button type="submit">Filtra</button>
</form>

<p><?= $this->e(count($ticket)) ?> ticket (al massimo 100, dal più recente)</p>
<table class="dati">
    <tr><th>Ticket</th><th>Aperto</th><th>Cliente</th><th>Categoria</th><th>Priorità</th><th>Stato</th>
        <th>Oggetto</th></tr>
    <?php foreach ($ticket as $voce) : ?>
        <tr>
            <td><a href="index.php?pagina=ticket-dettaglio&amp;id=<?= $this->e($voce->id) ?>"><?= $this->e($voce->id) ?></a></td>
            <td><?= $this->e($this->data($voce->apertoIl)) ?></td>
            <td><?= $this->e($voce->clienteNome ?? ($voce->apparatoId ?? '-')) ?></td>
            <td><?= $this->e($voce->categoria) ?></td>
            <td><?= $this->e($voce->priorita->value) ?></td>
            <td><?= $this->e($voce->stato->etichetta()) ?></td>
            <td><?= $this->e($voce->oggetto) ?></td>
        </tr>
    <?php endforeach; ?>
</table>
