    $canone = (int)$l['canone_cent'];
    $gg_mese = 30; // mese commerciale
    $gg = $gg_mese;
    $tipo = 'canone';
    $descr = $l['nome_offerta'] . ' - canone ' . $MESI[(int)$mese] . ' ' . $anno;

    // attivata nel mese: rateo dal giorno di attivazione
    if ($l['attiva_dal'] != '' && substr($l['attiva_dal'], 0, 7) == $periodo) {
        $g = (int)substr($l['attiva_dal'], 8, 2);
        $gg = $gg_mese - $g + 1;
        $tipo = 'rateo';
        $descr = $l['nome_offerta'] . ' - canone dal ' . data_it($l['attiva_dal']) . ' (' . $gg . ' gg)';
    }
    // cessata nel mese: rateo fino al giorno di cessazione
    if ($l['cessata_il'] != '' && substr($l['cessata_il'], 0, 7) == $periodo) {
        $g = (int)substr($l['cessata_il'], 8, 2);
        $gg = $g;
        $tipo = 'rateo';
        $descr = $l['nome_offerta'] . ' - canone fino al ' . data_it($l['cessata_il']) . ' (' . $gg . ' gg)';
    }
    $importo = intdiv($canone * $gg, $gg_mese);
