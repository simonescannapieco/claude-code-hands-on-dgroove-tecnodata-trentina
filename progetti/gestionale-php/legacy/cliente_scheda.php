<?php
/*
 * cliente_scheda.php - scheda del cliente: anagrafica, linee, fatture, ticket
 * servita da public/index.php?pagina=cliente&id=CL-...
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';
require_once dirname(__FILE__) . '/inc/layout.inc.php';

$id = isset($_GET['id']) ? $_GET['id'] : '';
$res = db_query("SELECT c.*, co.nome AS comune, co.cap, co.zona FROM clienti c JOIN comuni co ON co.id = c.comune_id
                  WHERE c.id = '" . db_escape($id) . "'");
$c = db_fetch($res);
if (!$c) {
    pagina_inizio('Cliente non trovato');
    echo "<p>Nessun cliente con codice " . $id . "</p>";
    pagina_fine();
    return;
}

// salvataggio note
if (isset($_POST['note'])) {
    db_exec("UPDATE clienti SET note = '" . db_escape($_POST['note']) . "' WHERE id = '" . $c['id'] . "'");
    $c['note'] = $_POST['note'];
    log_operazione('clienti', 'note aggiornate per ' . $c['id']);
}

$riv = '';
if ($c['rivenditore_id'] != '') {
    $riv = db_value("SELECT ragione_sociale FROM rivenditori WHERE id = '" . $c['rivenditore_id'] . "'");
}

pagina_inizio(nome_cliente($c) . ' (' . $c['id'] . ')');

if (is_moroso($c['id'])) {
    echo "<p style='background:#fdd;padding:6px'><b>Cliente moroso</b>: ci sono fatture scadute non pagate.</p>";
}
?>
<table border="0" cellpadding="3">
<tr><td><b>Tipo</b></td><td><?php echo $c['tipo']; ?></td></tr>
<?php if ($c['partita_iva'] != '') { ?>
<tr><td><b>Partita IVA</b></td><td><?php echo $c['partita_iva']; ?></td></tr>
<?php } ?>
<tr><td><b>Indirizzo</b></td><td><?php echo $c['via'] . ' ' . $c['civico'] . ', ' . $c['cap'] . ' ' . $c['comune']; ?> (<?php echo $c['zona']; ?>)</td></tr>
<tr><td><b>E-mail</b></td><td><a href="mailto:<?php echo $c['email']; ?>"><?php echo $c['email']; ?></a></td></tr>
<tr><td><b>Telefono</b></td><td><?php echo $c['telefono']; ?></td></tr>
<tr><td><b>Cliente dal</b></td><td><?php echo data_it($c['cliente_dal']); ?></td></tr>
<tr><td><b>Stato</b></td><td><?php echo stato_badge($c['stato']); ?></td></tr>
<tr><td><b>Rivenditore</b></td><td><?php echo $riv != '' ? $riv . ' (' . $c['rivenditore_id'] . ')' : '-'; ?></td></tr>
</table>

<form method="post" action="index.php?pagina=cliente&id=<?php echo $c['id']; ?>">
  <b>Note</b><br>
  <textarea name="note" rows="3" cols="70"><?php echo $c['note']; ?></textarea><br>
  <input type="submit" value="Salva note">
</form>

<h3>Linee</h3>
<?php
$res = db_query("SELECT l.*, o.nome AS offerta FROM linee l JOIN offerte o ON o.codice = l.offerta_codice
                  WHERE l.cliente_id = '" . $c['id'] . "' ORDER BY l.id");
$righe = array();
while ($l = db_fetch($res)) {
    $servizi = array();
    $res2 = db_query("SELECT * FROM linee_servizi WHERE linea_id = '" . $l['id'] . "' AND al IS NULL");
    while ($s = db_fetch($res2)) {
        $servizi[] = nome_servizio($s['servizio_codice']) . ($s['quantita'] > 1 ? ' x' . $s['quantita'] : '');
    }
    $righe[] = array(
        'id' => $l['id'],
        'offerta' => $l['offerta'],
        'apparato' => $l['apparato_id'] . ($l['porta'] != '' ? ' / ' . $l['porta'] : ''),
        'accesso' => $l['accesso'] == 'pppoe' ? 'PPPoE ' . $l['utenza_pppoe'] : 'DHCP',
        'ip' => $l['ipv4_statico'] . ($l['prefisso_ipv6'] != '' ? '<br>' . $l['prefisso_ipv6'] : ''),
        'servizi' => implode(', ', $servizi),
        'stato' => stato_badge($l['stato']) . ($l['attiva_dal'] != '' ? ' dal ' . data_it($l['attiva_dal']) : ''),
    );
}
echo tabella_html($righe, array('id' => 'Linea', 'offerta' => 'Offerta', 'apparato' => 'Apparato',
                                'accesso' => 'Accesso', 'ip' => 'IP statico', 'servizi' => 'Servizi',
                                'stato' => 'Stato'));
?>

<h3>Ultime fatture</h3>
<?php
$res = db_query("SELECT * FROM fatture WHERE cliente_id = '" . $c['id'] . "' ORDER BY emessa_il DESC, id DESC LIMIT 12");
$righe = array();
while ($f = db_fetch($res)) {
    $righe[] = array(
        'id' => "<a href='index.php?pagina=fattura&id=" . $f['id'] . "'>" . $f['id'] . "</a>",
        'tipo' => $f['tipo'] == 'nota_credito' ? 'nota di credito' : 'fattura',
        'periodo' => $f['periodo'],
        'emessa' => data_it($f['emessa_il']),
        'totale' => euro($f['totale_cent']),
        'stato' => stato_badge($f['stato']),
    );
}
echo tabella_html($righe, array('id' => 'Numero', 'tipo' => 'Tipo', 'periodo' => 'Periodo', 'emessa' => 'Emessa',
                                'totale' => 'Totale', 'stato' => 'Stato'));
?>

<h3>Ticket</h3>
<p><a href="index.php?pagina=nuovo-ticket&cliente=<?php echo $c['id']; ?>">Apri un nuovo ticket</a></p>
<?php
$res = db_query("SELECT * FROM ticket WHERE cliente_id = '" . $c['id'] . "' ORDER BY aperto_il DESC LIMIT 20");
$righe = array();
while ($t = db_fetch($res)) {
    $righe[] = array(
        'id' => "<a href='index.php?pagina=ticket-dettaglio&id=" . $t['id'] . "'>" . $t['id'] . "</a>",
        'aperto' => data_ora_it($t['aperto_il']),
        'categoria' => $t['categoria'],
        'oggetto' => $t['oggetto'],
        'stato' => stato_badge($t['stato']),
    );
}
echo tabella_html($righe, array('id' => 'Ticket', 'aperto' => 'Aperto', 'categoria' => 'Categoria',
                                'oggetto' => 'Oggetto', 'stato' => 'Stato'));

pagina_fine();
