<?php
/**
 * @var \CiaspoLink\Gestionale\Web\Vista $this
 * @var string $titolo
 * @var string $contenuto HTML già pronto della pagina
 */
?>
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="utf-8">
    <title><?= $this->e($titolo) ?> - CiaspoLink</title>
    <link rel="stylesheet" href="stile.css">
</head>
<body>
<header>
    <b>CiaspoLink</b> &middot; gestionale &nbsp;
    <a href="index.php">Cruscotto</a>
    <a href="index.php?pagina=clienti">Clienti</a>
    <a href="index.php?pagina=copertura">Copertura</a>
    <a href="index.php?pagina=attivazioni">Attivazioni</a>
    <a href="index.php?pagina=ticket">Ticket</a>
    <a href="index.php?pagina=nuovo-ticket">Nuovo ticket</a>
    <a href="index.php?pagina=report-fatturato">Fatturato</a>
    <a href="index.php?pagina=provvigioni">Provvigioni</a>
</header>
<main>
    <h1><?= $this->e($titolo) ?></h1>
    <?= $contenuto ?>
</main>
</body>
</html>
