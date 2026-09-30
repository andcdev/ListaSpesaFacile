<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * Conferma (approve = true) o smentita di una rettifica di prezzo da parte di un utente.
 */
#[Fillable(['price_report_id', 'user_id', 'approve'])]
class PriceReportVote extends Model
{
    protected function casts(): array
    {
        return ['approve' => 'boolean'];
    }
}
