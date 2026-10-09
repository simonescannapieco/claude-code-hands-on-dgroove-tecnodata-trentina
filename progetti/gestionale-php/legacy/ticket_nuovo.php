<?php
/*
 * ticket_nuovo.php - apertura di un ticket di assistenza
 * servita da public/index.php?pagina=nuovo-ticket[&cliente=CL-...]
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';
require_once dirname(__FILE__) . '/inc/layout.inc.php';

$categorie = array('guasto', 'lentezza', 'voce', 'wifi', 'amministrativo', 'attivazione');
$priorita = array('bassa', 'media', 'alta', 'critica');
$canali = array('telefono', 'email', 'web', 'rivenditore');
$messaggio = '';
$errore = '';

$cliente = isset($_REQUEST['cliente']) ? strtoupper(trim($_REQUEST['cliente'])) : '';

if (isset($_POST['oggetto'])) {
    $oggetto = trim($_POST['oggetto']);
    $descrizione = trim($_POST['descrizione']);
    $cat = $_POST['categoria'];
    $prio = $_POST['priorita'];
    $canale = $_POST['canale'];
    $linea = isset($_POST['linea']) ? trim($_POST['linea']) : '';

    if ($cliente == '' || $oggetto == '') {
        $errore = 'Cliente e oggetto sono obbligatori';
    } elseif (!db_value("SELECT id FROM clienti WHERE id = '" . db_escape($cliente) . "'")) {
        $errore = 'Cliente inesistente: ' . $cliente;
    } else {
        $id = prossimo_numero_ticket(date('Y'));
        $ora = date('c');
        db_exec("INSERT INTO ticket (id, cliente_id, linea_id, categoria, priorita, stato, canale, oggetto, descrizione,
                                     aperto_il, aggiornato_il, assegnato_a)
                 VALUES ('$id', '" . db_escape($cliente) . "', " . ($linea != '' ? "'" . db_escape($linea) . "'" : "NULL")
                 . ", '$cat', '$prio', 'aperto', '$canale', '" . db_escape($oggetto) . "', '"
                 . db_escape($descrizione) . "', '$ora', '$ora', NULL)");
        log_operazione('ticket', 'aperto ticket ' . $id . ' per ' . $cliente);
        $messaggio = "Ticket <b>" . $id . "</b> aperto: " . $oggetto;
    }
}

$linee = array();
if ($cliente != '') {
    $res = db_query("SELECT id, offerta_codice, stato FROM linee WHERE cliente_id = '" . db_escape($cliente) . "' ORDER BY id");
    while ($l = db_fetch($res)) {
        $linee[] = $l;
    }
}

pagina_inizio('Nuovo ticket');

if ($messaggio != '') {
    echo "<p style='background:#dfd;padding:6px'>" . $messaggio . "</p>";
}
if ($errore != '') {
    echo "<p style='background:#fdd;padding:6px'>" . $errore . "</p>";
}
?>
<form method="post" action="index.php?pagina=nuovo-ticket">
<table>
<tr><td>Cliente</td><td><input type="text" name="cliente" value="<?php echo $cliente; ?>" placeholder="CL-000000"></td></tr>
<tr><td>Linea</td><td>
  <select name="linea">
    <option value="">(nessuna)</option>
    <?php foreach ($linee as $l) { ?>
      <option value="<?php echo $l['id']; ?>"><?php echo $l['id'] . ' - ' . nome_offerta($l['offerta_codice']) . ' (' . $l['stato'] . ')'; ?></option>
    <?php } ?>
  </select>
</td></tr>
<tr><td>Categoria</td><td><select name="categoria"><?php foreach ($categorie as $x) echo "<option>$x</option>"; ?></select></td></tr>
<tr><td>Priorità</td><td><select name="priorita"><?php foreach ($priorita as $x) echo "<option" . ($x == 'media' ? ' selected' : '') . ">$x</option>"; ?></select></td></tr>
<tr><td>Canale</td><td><select name="canale"><?php foreach ($canali as $x) echo "<option>$x</option>"; ?></select></td></tr>
<tr><td>Oggetto</td><td><input type="text" name="oggetto" size="60"></td></tr>
<tr><td>Descrizione</td><td><textarea name="descrizione" rows="5" cols="60"></textarea></td></tr>
<tr><td></td><td><input type="submit" value="Apri ticket"></td></tr>
</table>
</form>
<?php
pagina_fine();
