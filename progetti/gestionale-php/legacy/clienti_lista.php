<?php
/*
 * clienti_lista.php - elenco e ricerca dei clienti
 * servita da public/index.php?pagina=clienti
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';
require_once dirname(__FILE__) . '/inc/layout.inc.php';

$q = isset($_GET['q']) ? trim($_GET['q']) : '';
$stato = isset($_GET['stato']) ? $_GET['stato'] : '';
$ordina = isset($_GET['ordina']) ? $_GET['ordina'] : 'c.id';
$p = isset($_GET['p']) ? (int)$_GET['p'] : 1;
if ($p < 1) {
    $p = 1;
}
$per_pagina = 25;

$where = "WHERE 1=1";
if ($q != '') {
    $qq = db_escape($q);
    $where .= " AND (c.id = '$qq' OR c.cognome LIKE '%$qq%' OR c.ragione_sociale LIKE '%$qq%'"
        . " OR c.email LIKE '%$qq%' OR c.via LIKE '%$qq%')";
}
if ($stato != '') {
    $where .= " AND c.stato = '" . db_escape($stato) . "'";
}

$tot = db_value("SELECT COUNT(*) FROM clienti c $where");
$res = db_query("SELECT c.*, co.nome AS comune FROM clienti c JOIN comuni co ON co.id = c.comune_id $where
                 ORDER BY $ordina LIMIT $per_pagina OFFSET " . (($p - 1) * $per_pagina));
$pagine = max(1, (int)ceil($tot / $per_pagina));

pagina_inizio('Clienti');
?>
<form method="get" action="index.php">
  <input type="hidden" name="pagina" value="clienti">
  Cerca (codice, cognome, ragione sociale, e-mail, via):
  <input type="text" name="q" size="30" value="<?php echo $q; ?>">
  Stato:
  <select name="stato">
    <option value="">tutti</option>
    <?php foreach (array('attivo', 'sospeso', 'cessato') as $s) { ?>
      <option value="<?php echo $s; ?>"<?php if ($s == $stato) echo ' selected'; ?>><?php echo $s; ?></option>
    <?php } ?>
  </select>
  <input type="submit" value="Cerca">
</form>

<p><?php echo $tot; ?> clienti trovati<?php if ($q != '') echo " per <b>" . $q . "</b>"; ?></p>

<table border="1" cellpadding="3" cellspacing="0" width="100%">
<tr>
  <th><a href="index.php?pagina=clienti&ordina=c.id&q=<?php echo urlencode($q); ?>">Codice</a></th>
  <th><a href="index.php?pagina=clienti&ordina=c.cognome&q=<?php echo urlencode($q); ?>">Cliente</a></th>
  <th>Tipo</th>
  <th><a href="index.php?pagina=clienti&ordina=co.nome&q=<?php echo urlencode($q); ?>">Comune</a></th>
  <th>Telefono</th>
  <th>Stato</th>
</tr>
<?php
while ($r = db_fetch($res)) {
    // morosita: almeno una fattura scaduta (vedi anche is_moroso)
    $n_scad = db_value("SELECT COUNT(*) FROM fatture WHERE cliente_id = '" . $r['id']
        . "' AND stato = 'scaduta' AND tipo = 'fattura'");
    echo "<tr>";
    echo "<td><a href='index.php?pagina=cliente&id=" . $r['id'] . "'>" . $r['id'] . "</a></td>";
    echo "<td>" . nome_cliente($r) . "</td>";
    echo "<td>" . $r['tipo'] . "</td>";
    echo "<td>" . $r['comune'] . "</td>";
    echo "<td>" . $r['telefono'] . "</td>";
    echo "<td>" . stato_badge($r['stato']);
    if ($n_scad >= 1) {
        echo " <b style='color:red'>MOROSO</b>";
    }
    echo "</td></tr>\n";
}
?>
</table>

<p>Pagina <?php echo $p; ?> di <?php echo $pagine; ?>
<?php if ($p > 1) { ?>
  - <a href="index.php?pagina=clienti&q=<?php echo urlencode($q); ?>&stato=<?php echo $stato; ?>&ordina=<?php echo $ordina; ?>&p=<?php echo $p - 1; ?>">precedente</a>
<?php } ?>
<?php if ($p < $pagine) { ?>
  - <a href="index.php?pagina=clienti&q=<?php echo urlencode($q); ?>&stato=<?php echo $stato; ?>&ordina=<?php echo $ordina; ?>&p=<?php echo $p + 1; ?>">successiva</a>
<?php } ?>
</p>
<?php
pagina_fine();
