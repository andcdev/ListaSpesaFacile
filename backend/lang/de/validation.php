<?php

// Messaggi di validazione per le regole usate dall'API (le altre ricadono sull'inglese di Laravel).

return [
    'array' => ':attribute muss eine Liste sein.',
    'boolean' => ':attribute muss wahr oder falsch sein.',
    'confirmed' => 'Die Bestätigung von :attribute stimmt nicht überein.',
    'date' => ':attribute ist kein gültiges Datum.',
    'digits' => ':attribute muss :digits Ziffern haben.',
    'email' => ':attribute muss eine gültige E-Mail-Adresse sein.',
    'gt' => [
        'numeric' => ':attribute muss größer als :value sein.',
    ],
    'image' => ':attribute muss ein Bild sein.',
    'in' => 'Der Wert von :attribute ist ungültig.',
    'integer' => ':attribute muss eine ganze Zahl sein.',
    'lowercase' => ':attribute muss kleingeschrieben sein.',
    'max' => [
        'array' => ':attribute darf nicht mehr als :max Elemente haben.',
        'file' => ':attribute darf nicht größer als :max Kilobyte sein.',
        'numeric' => ':attribute darf nicht größer als :max sein.',
        'string' => ':attribute darf nicht länger als :max Zeichen sein.',
    ],
    'mimes' => ':attribute muss vom Typ :values sein.',
    'min' => [
        'numeric' => ':attribute muss mindestens :min sein.',
        'string' => ':attribute muss mindestens :min Zeichen lang sein.',
    ],
    'numeric' => ':attribute muss eine Zahl sein.',
    'required' => ':attribute ist ein Pflichtfeld.',
    'required_with' => ':attribute ist erforderlich, wenn :values angegeben ist.',
    'required_without' => ':attribute ist erforderlich, wenn :values nicht angegeben ist.',
    'string' => ':attribute muss ein Text sein.',
    'unique' => 'Diese :attribute wird bereits verwendet.',
    'url' => ':attribute muss ein gültiger Link sein.',
    'attributes' => [
        'name' => 'Name',
        'email' => 'E-Mail',
        'password' => 'Passwort',
        'code' => 'Code',
        'body' => 'Nachricht',
        'image' => 'Bild',
        'quantity' => 'Menge',
        'amount' => 'Gewicht',
        'unit' => 'Einheit',
        'scheduled_at' => 'Datum',
        'notes' => 'Notizen',
        'image_url' => 'Bildlink',
    ],
];
