<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Prezzo rilevato in una catena e in una zona: segnalato da un utente (rettifica) o importato da Open Prices.
 * Di chi segnala si mostrano nome e ora; reporter_email resta sul server e non esce mai dalle API.
 */
#[Fillable([
    'supermarket_id', 'product_key', 'barcode', 'product_name', 'price', 'per', 'package_amount', 'package_unit',
    'country', 'city', 'locality', 'source', 'external_id', 'user_id', 'reporter_name', 'reporter_email', 'observed_at',
])]
class PriceReport extends Model
{
    public const SOURCE_USER = 'user';

    public const SOURCE_OPEN_PRICES = 'open_prices';

    protected $hidden = ['reporter_email'];

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'package_amount' => 'float',
            'observed_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Supermarket, $this>
     */
    public function supermarket(): BelongsTo
    {
        return $this->belongsTo(Supermarket::class);
    }

    /**
     * Come viene mostrata nell'app: prezzo, fonte, nome e ora di chi l'ha segnalato, zona. Mai l'email.
     *
     * @return array<string, mixed>
     */
    public function toPublicArray(): array
    {
        return [
            'id' => $this->id,
            'supermarket' => $this->supermarket?->name,
            'product_name' => $this->product_name,
            'barcode' => $this->barcode,
            'price' => $this->price,
            'per' => $this->per,
            'source' => $this->source,
            'reporter' => $this->reporter_name,
            'observed_at' => $this->observed_at->toIso8601String(),
            'country' => $this->country,
            'city' => $this->city,
            'locality' => $this->locality,
        ];
    }
}
