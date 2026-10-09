<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var array<string, int> $clienti
 * @var array<string, int> $linee
 * @var int $ticketAperti
 * @var int $attivazioniInCorso
 * @var list<\CiaspoLink\Gestionale\Ticket\Ticket> $disservizi
 */
?>
<div class="riquadri">
    <div class="riquadro"><b><?= $this->e($clienti['attivo'] ?? 0) ?></b>clienti attivi</div>
    <div class="riquadro"><b><?= $this->e($linee['attiva'] ?? 0) ?></b>linee attive</div>
    <div class="riquadro"><b><?= $this->e($linee['sospesa'] ?? 0) ?></b>linee sospese</div>
    <div class="riquadro"><b><?= $this->e($ticketAperti) ?></b>
        <a href="index.php?pagina=ticket&amp;aperti=1">ticket aperti</a></div>
    <div class="riquadro"><b><?= $this->e($attivazioniInCorso) ?></b>
        <a href="index.php?pagina=attivazioni">attivazioni in corso</a></div>
</div>

<h2>Ultimi disservizi</h2>
<table class="dati">
    <tr><th>Ticket</th><th>Aperto</th><th>Apparato</th><th>Oggetto</th><th>Stato</th></tr>
    <?php foreach ($disservizi as $ticket) : ?>
        <tr>
            <td><a href="index.php?pagina=ticket-dettaglio&amp;id=<?= $this->e($ticket->id) ?>">
                <?= $this->e($ticket->id) ?></a></td>
            <td><?= $this->e($this->data($ticket->apertoIl)) ?></td>
            <td><?= $this->e($ticket->apparatoId ?? '-') ?></td>
            <td><?= $this->e($ticket->oggetto) ?></td>
            <td><?= $this->e($ticket->stato->etichetta()) ?></td>
        </tr>
    <?php endforeach; ?>
</table>
