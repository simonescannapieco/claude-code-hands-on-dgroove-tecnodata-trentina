<?php
/*
 * layout.inc.php - testata e piede delle pagine del vecchio gestionale
 */

require_once dirname(__FILE__) . '/config.inc.php';

function pagina_inizio($titolo)
{
    global $NOME_AZIENDA;
    echo "<!DOCTYPE html>\n<html lang='it'><head><meta charset='utf-8'>";
    echo "<title>" . $titolo . " - " . $NOME_AZIENDA . "</title>";
    echo "<link rel='stylesheet' href='stile.css'></head>\n<body class='legacy'>\n";
    echo "<div style='background:#335;color:white;padding:6px'><b>" . $NOME_AZIENDA . "</b> - gestionale";
    echo " | <a style='color:white' href='index.php'>Cruscotto</a>";
    echo " | <a style='color:white' href='index.php?pagina=clienti'>Clienti</a>";
    echo " | <a style='color:white' href='index.php?pagina=copertura'>Copertura</a>";
    echo " | <a style='color:white' href='index.php?pagina=attivazioni'>Attivazioni</a>";
    echo " | <a style='color:white' href='index.php?pagina=ticket'>Ticket</a>";
    echo " | <a style='color:white' href='index.php?pagina=nuovo-ticket'>Nuovo ticket</a>";
    echo " | <a style='color:white' href='index.php?pagina=report-fatturato'>Fatturato</a>";
    echo " | <a style='color:white' href='index.php?pagina=provvigioni'>Provvigioni</a>";
    echo "</div>\n<h2>" . $titolo . "</h2>\n";
}

function pagina_fine()
{
    echo "\n<hr><small>gestionale v3 - pagina generata il " . date('d/m/Y H:i') . "</small>\n</body></html>\n";
}
