<?php

// Messaggi di validazione per le regole usate dall'API (le altre ricadono sull'inglese di Laravel).

return [
    'array' => 'El campo :attribute debe ser una lista.',
    'boolean' => 'El campo :attribute debe ser verdadero o falso.',
    'confirmed' => 'La confirmación de :attribute no coincide.',
    'date' => 'El campo :attribute no es una fecha válida.',
    'digits' => 'El campo :attribute debe tener :digits dígitos.',
    'email' => 'El campo :attribute debe ser un correo electrónico válido.',
    'gt' => [
        'numeric' => 'El campo :attribute debe ser mayor que :value.',
    ],
    'image' => 'El campo :attribute debe ser una imagen.',
    'in' => 'El valor de :attribute no es válido.',
    'integer' => 'El campo :attribute debe ser un número entero.',
    'lowercase' => 'El campo :attribute debe estar en minúsculas.',
    'max' => [
        'array' => 'El campo :attribute no puede tener más de :max elementos.',
        'file' => 'El archivo :attribute no puede superar :max kilobytes.',
        'numeric' => 'El campo :attribute no puede ser mayor que :max.',
        'string' => 'El campo :attribute no puede superar :max caracteres.',
    ],
    'mimes' => 'El archivo :attribute debe ser de tipo: :values.',
    'min' => [
        'numeric' => 'El campo :attribute debe ser al menos :min.',
        'string' => 'El campo :attribute debe tener al menos :min caracteres.',
    ],
    'numeric' => 'El campo :attribute debe ser un número.',
    'required' => 'El campo :attribute es obligatorio.',
    'required_with' => 'El campo :attribute es obligatorio cuando :values está presente.',
    'required_without' => 'El campo :attribute es obligatorio cuando :values no está presente.',
    'string' => 'El campo :attribute debe ser un texto.',
    'unique' => 'Este :attribute ya está en uso.',
    'url' => 'El campo :attribute debe ser un enlace válido.',
    'attributes' => [
        'name' => 'nombre',
        'email' => 'correo electrónico',
        'password' => 'contraseña',
        'code' => 'código',
        'body' => 'mensaje',
        'image' => 'imagen',
        'quantity' => 'cantidad',
        'amount' => 'peso',
        'unit' => 'unidad',
        'scheduled_at' => 'fecha',
        'notes' => 'notas',
        'image_url' => 'enlace de la imagen',
    ],
];
