<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Prezzo indicativo di un prodotto in una catena: a confezione (pz), al kg o al litro.
 */
#[Fillable(['product_key', 'product_name', 'price', 'per'])]
class SupermarketPrice extends Model
{
    /** Il prezzo è per confezione/pezzo, al chilo o al litro. */
    public const PER = ['pz', 'kg', 'l'];

    protected function casts(): array
    {
        return ['price' => 'decimal:2'];
    }

    /**
     * @return BelongsTo<Supermarket, $this>
     */
    public function supermarket(): BelongsTo
    {
        return $this->belongsTo(Supermarket::class);
    }
}
