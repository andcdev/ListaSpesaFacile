<?php

namespace App\Models;

use App\Support\ProductCatalog;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

#[Fillable(['name', 'barcode', 'brand', 'category', 'custom_icon', 'image_url', 'image_auto', 'quantity', 'amount', 'unit', 'checked', 'status', 'position'])]
class ListItem extends Model
{
    use HasFactory;

    /** Unità di misura per peso e volume. */
    public const UNITS = ['g', 'hg', 'kg', 'ml', 'cl', 'l'];

    /** Stati: da prendere, preso, non preso (non trovato o esaurito). */
    public const STATUSES = ['todo', 'taken', 'missing'];

    /** Cartella delle foto dei prodotti: una sottocartella per lista. */
    public const IMAGE_DIR = 'item-images';

    protected $attributes = ['status' => 'todo', 'checked' => false];

    protected $touches = ['shoppingList'];

    protected function casts(): array
    {
        return [
            'checked' => 'boolean',
            'position' => 'integer',
            'amount' => 'float',
            'image_auto' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::deleted(function (ListItem $item) {
            if ($item->image_path) {
                Storage::delete($item->image_path);
            }
        });

        // Reparto e icona: riconosciuti dal nome, salvo reparto scelto a mano.
        static::saving(function (ListItem $item) {
            if ($item->isDirty('category') && $item->category !== null) {
                $detected = ProductCatalog::detect($item->name);
                // Se il reparto scelto è quello riconosciuto si tiene l'icona specifica del prodotto.
                $item->icon = $detected['category'] === $item->category
                    ? $detected['icon']
                    : ProductCatalog::categoryIcon($item->category);
            } elseif ($item->isDirty('name') || $item->icon === null) {
                // Nome cambiato: si riconosce di nuovo (una scelta manuale precedente viene sostituita).
                ['category' => $item->category, 'icon' => $item->icon] = ProductCatalog::detect($item->name);
            }
            if ($item->amount === null) {
                $item->unit = null;
            }
            // "checked" e "status" restano allineati, qualunque dei due venga modificato.
            if ($item->isDirty('status')) {
                $item->checked = $item->status === 'taken';
            } elseif ($item->isDirty('checked')) {
                $item->status = $item->checked ? 'taken' : 'todo';
            }
        });
    }

    /**
     * Versione della foto caricata (cambia a ogni nuova foto): l'app la aggiunge all'URL per aggiornare la cache.
     */
    public function imageVersion(): ?string
    {
        return $this->image_path ? substr(md5($this->image_path), 0, 10) : null;
    }

    /**
     * @return BelongsTo<ShoppingList, $this>
     */
    public function shoppingList(): BelongsTo
    {
        return $this->belongsTo(ShoppingList::class);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function checker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'checked_by');
    }
}
