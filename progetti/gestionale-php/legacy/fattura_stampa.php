<?php
/*
 * fattura_stampa.php - fattura in formato stampabile (anche per l'invio via e-mail)
 * servita da public/index.php?pagina=fattura&id=FT-...
 */

require_once dirname(__FILE__) . '/inc/config.inc.php';
require_once dirname(__FILE__) . '/inc/db.inc.php';
require_once dirname(__FILE__) . '/inc/funzioni.inc.php';

$id = isset($_GET['id']) ? $_GET['id'] : '';
$f = db_fetch(db_query("SELECT * FROM fatture WHERE id = '" . db_escape($id) . "'"));
if (!$f) {
    echo "Fattura non trovata: " . $id;
    return;
}
$c = db_fetch(db_query("SELECT c.*, co.nome AS comune, co.cap, co.provincia FROM clienti c
                         JOIN comuni co ON co.id = c.comune_id WHERE c.id = '" . $f['cliente_id'] . "'"));
$righe = db_fetch_all(db_query("SELECT * FROM righe_fattura WHERE fattura_id = '" . $f['id'] . "' ORDER BY id"));

$titolo = $f['tipo'] == 'nota_credito' ? 'Nota di credito' : 'Fattura';

// totali ricalcolati riga per riga (come sul vecchio modulo cartaceo)
$tot_imponibile = 0;
$tot_iva = 0;
foreach ($righe as $i => $r) {
    $imp = $r['importo_cent'] / 100;
    $iva_riga = calcola_iva($imp);
    $righe[$i]['imponibile'] = $imp;
    $righe[$i]['iva'] = $iva_riga;
    $tot_imponibile += $imp;
    $tot_iva += $iva_riga;
}
$tot_documento = $tot_imponibile + $tot_iva;
?>
<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<title><?php echo $titolo . ' ' . $f['id']; ?></title>
<style>
  body { font-family: Arial, sans-serif; font-size: 13px; margin: 30px; }
  table.righe { border-collapse: collapse; width: 100%; }
  table.righe td, table.righe th { border: 1px solid #999; padding: 4px; }
  .num { text-align: right; }
</style>
</head>
<body>
<table width="100%">
<tr>
  <td valign="top">
    <b style="font-size:18px"><?php echo $NOME_AZIENDA; ?></b><br>
    Via dell'Esempio 1, 38051 Borgo Valsugana (TN)<br>
    P. IVA 00000000001<br>
    amministrazione@example.org - +39 000 000 0001
  </td>
  <td valign="top" align="right">
    <b><?php echo $titolo; ?> n. <?php echo $f['id']; ?></b><br>
    del <?php echo data_it($f['emessa_il']); ?><br>
    <?php if ($f['periodo'] != '') { ?>periodo: <?php echo mese_italiano(substr($f['periodo'], 5, 2)) . ' ' . substr($f['periodo'], 0, 4); ?><br><?php } ?>
    <?php if ($f['tipo'] == 'fattura') { ?>scadenza: <?php echo data_it($f['scade_il']); ?><?php } ?>
  </td>
</tr>
</table>

<p style="margin-top:20px">
  Spett.le<br>
  <b><?php echo nome_cliente($c); ?></b><br>
  <?php echo $c['via'] . ' ' . $c['civico']; ?><br>
  <?php echo $c['cap'] . ' ' . $c['comune'] . ' (' . $c['provincia'] . ')'; ?><br>
  <?php if ($c['partita_iva'] != '') echo 'P. IVA ' . $c['partita_iva'] . '<br>'; ?>
  Codice cliente <?php echo $c['id']; ?>
</p>

<table class="righe">
<tr><th>Descrizione</th><th>Linea</th><th class="num">Q.tà</th><th class="num">Prezzo</th><th class="num">Imponibile</th><th class="num">IVA <?php echo $IVA; ?>%</th></tr>
<?php foreach ($righe as $r) { ?>
<tr>
  <td><?php echo $r['descrizione']; ?></td>
  <td><?php echo $r['linea_id']; ?></td>
  <td class="num"><?php echo $r['quantita']; ?></td>
  <td class="num"><?php echo formatta_euro($r['prezzo_unitario_cent'] / 100); ?></td>
  <td class="num"><?php echo formatta_euro($r['imponibile']); ?></td>
  <td class="num"><?php echo formatta_euro($r['iva']); ?></td>
</tr>
<?php } ?>
</table>

<table width="40%" align="right" style="margin-top:15px">
<tr><td>Imponibile</td><td class="num"><?php echo formatta_euro($tot_imponibile); ?> &euro;</td></tr>
<tr><td>IVA <?php echo $IVA; ?>%</td><td class="num"><?php echo formatta_euro($tot_iva); ?> &euro;</td></tr>
<tr><td><b>Totale</b></td><td class="num"><b><?php echo formatta_euro($tot_documento); ?> &euro;</b></td></tr>
</table>

<p style="clear:both;padding-top:30px">
<?php if ($f['stato'] == 'pagata') { ?>
  Pagata il <?php echo data_it($f['pagata_il']); ?>. Grazie.
<?php } elseif ($f['tipo'] == 'fattura') { ?>
  Pagamento entro il <?php echo data_it($f['scade_il']); ?>, con addebito diretto o bonifico.
<?php } ?>
</p>
</body>
</html>
