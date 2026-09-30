<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * Catena di supermercati: si suggerisce mentre si scrive il supermercato della lista.
 */
#[Fillable(['name', 'aliases', 'description'])]
class Supermarket extends Model
{
    protected function casts(): array
    {
        return ['aliases' => 'array'];
    }
}
