<?php

return [

    // Conferme di altri utenti necessarie perché la rettifica di un prezzo sia mostrata a tutti (e smentite perché
    // venga scartata). Chi l'ha scritta la vede subito.
    'approvals_required' => max(1, (int) env('PRICE_APPROVALS_REQUIRED', 1)),

];
