<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * Ultimo messaggio della chat di una lista ricevuto dal telefono di un utente.
 */
#[Fillable(['user_id', 'delivered_up_to'])]
class ChatDelivery extends Model
{
    protected $attributes = ['delivered_up_to' => 0];

    protected function casts(): array
    {
        return ['delivered_up_to' => 'integer'];
    }
}
