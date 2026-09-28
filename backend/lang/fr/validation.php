<?php

// Messaggi di validazione per le regole usate dall'API (le altre ricadono sull'inglese di Laravel).

return [
    'array' => 'Le champ :attribute doit être une liste.',
    'boolean' => 'Le champ :attribute doit être vrai ou faux.',
    'confirmed' => 'La confirmation de :attribute ne correspond pas.',
    'date' => 'Le champ :attribute n\'est pas une date valide.',
    'digits' => 'Le champ :attribute doit comporter :digits chiffres.',
    'email' => 'Le champ :attribute doit être une adresse e-mail valide.',
    'gt' => [
        'numeric' => 'Le champ :attribute doit être supérieur à :value.',
    ],
    'image' => 'Le champ :attribute doit être une image.',
    'in' => 'La valeur de :attribute n\'est pas valide.',
    'integer' => 'Le champ :attribute doit être un nombre entier.',
    'lowercase' => 'Le champ :attribute doit être en minuscules.',
    'max' => [
        'array' => 'Le champ :attribute ne peut pas avoir plus de :max éléments.',
        'file' => 'Le fichier :attribute ne peut pas dépasser :max kilo-octets.',
        'numeric' => 'Le champ :attribute ne peut pas être supérieur à :max.',
        'string' => 'Le champ :attribute ne peut pas dépasser :max caractères.',
    ],
    'mimes' => 'Le fichier :attribute doit être de type : :values.',
    'min' => [
        'numeric' => 'Le champ :attribute doit être au moins :min.',
        'string' => 'Le champ :attribute doit contenir au moins :min caractères.',
    ],
    'numeric' => 'Le champ :attribute doit être un nombre.',
    'required' => 'Le champ :attribute est obligatoire.',
    'required_with' => 'Le champ :attribute est obligatoire quand :values est présent.',
    'required_without' => 'Le champ :attribute est obligatoire quand :values n\'est pas présent.',
    'string' => 'Le champ :attribute doit être un texte.',
    'unique' => 'Ce :attribute est déjà utilisé.',
    'url' => 'Le champ :attribute doit être un lien valide.',
    'attributes' => [
        'name' => 'nom',
        'email' => 'e-mail',
        'password' => 'mot de passe',
        'code' => 'code',
        'body' => 'message',
        'image' => 'image',
        'quantity' => 'quantité',
        'amount' => 'poids',
        'unit' => 'unité',
        'scheduled_at' => 'date',
        'notes' => 'notes',
        'image_url' => 'lien de l\'image',
    ],
];
