<?php

// Messaggi di validazione per le regole usate dall'API (le altre ricadono sull'inglese di Laravel).

return [
    'array' => 'Il campo :attribute deve essere un elenco.',
    'boolean' => 'Il campo :attribute deve essere vero o falso.',
    'confirmed' => 'La conferma di :attribute non corrisponde.',
    'date' => 'Il campo :attribute non è una data valida.',
    'digits' => 'Il campo :attribute deve avere :digits cifre.',
    'email' => 'Il campo :attribute deve essere un indirizzo email valido.',
    'gt' => [
        'numeric' => 'Il campo :attribute deve essere maggiore di :value.',
    ],
    'image' => 'Il campo :attribute deve essere un\'immagine.',
    'in' => 'Il valore di :attribute non è valido.',
    'integer' => 'Il campo :attribute deve essere un numero intero.',
    'lowercase' => 'Il campo :attribute deve essere in minuscolo.',
    'max' => [
        'array' => 'Il campo :attribute non può avere più di :max elementi.',
        'file' => 'Il file :attribute non può superare :max kilobyte.',
        'numeric' => 'Il campo :attribute non può essere maggiore di :max.',
        'string' => 'Il campo :attribute non può superare :max caratteri.',
    ],
    'mimes' => 'Il file :attribute deve essere di tipo: :values.',
    'min' => [
        'numeric' => 'Il campo :attribute deve essere almeno :min.',
        'string' => 'Il campo :attribute deve avere almeno :min caratteri.',
    ],
    'numeric' => 'Il campo :attribute deve essere un numero.',
    'required' => 'Il campo :attribute è obbligatorio.',
    'required_with' => 'Il campo :attribute è obbligatorio quando è presente :values.',
    'required_without' => 'Il campo :attribute è obbligatorio quando non è presente :values.',
    'string' => 'Il campo :attribute deve essere un testo.',
    'unique' => 'Questo :attribute è già in uso.',
    'url' => 'Il campo :attribute deve essere un link valido.',
    'attributes' => [
        'name' => 'nome',
        'email' => 'email',
        'password' => 'password',
        'code' => 'codice',
        'body' => 'messaggio',
        'image' => 'immagine',
        'quantity' => 'quantità',
        'amount' => 'peso',
        'unit' => 'unità',
        'scheduled_at' => 'data',
        'notes' => 'note',
        'image_url' => 'link dell\'immagine',
    ],
];
