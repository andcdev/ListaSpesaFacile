<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Prezzo che un utente si annota per un prodotto (a confezione, al kg o al litro), di solito in un supermercato.
 * Lo vede solo lui: non compare nelle liste né agli altri utenti.
 */
#[Fillable(['product_name', 'barcode', 'brand', 'supermarket', 'price', 'per', 'note'])]
class UserPrice extends Model
{
    public const PER = ['pz', 'kg', 'l'];

    protected function casts(): array
    {
        return ['price' => 'float'];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'product_name' => $this->product_name,
            'barcode' => $this->barcode,
            'brand' => $this->brand,
            'supermarket' => $this->supermarket,
            'price' => $this->price,
            'per' => $this->per,
            'note' => $this->note,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
