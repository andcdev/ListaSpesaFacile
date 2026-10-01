<?php

namespace App\Http\Resources;

use App\Models\ListItem;
use App\Support\ProductCatalog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ListItem
 */
class ListItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'shopping_list_id' => $this->shopping_list_id,
            'name' => $this->name,
            // Prodotto di marca scelto da Open Food Facts (null = scritto a mano).
            'barcode' => $this->barcode,
            'brand' => $this->brand,
            'category' => $this->category,
            // Emoji mostrata: quella scelta dall'utente oppure quella riconosciuta dal nome.
            'icon' => $this->custom_icon ?? $this->icon,
            'custom_icon' => $this->custom_icon,
            'image_url' => $this->image_url,
            // Foto caricata dal telefono: GET /api/lists/{list}/items/{id}/image?v={image_version}; null se non c'è.
            'image_version' => $this->imageVersion(),
            // Come si misura: weight (sfuso a peso), weight_count (sfuso, anche a pezzi), count (confezioni).
            'measure' => ProductCatalog::measure($this->name, $this->barcode),
            'quantity' => $this->quantity,
            'amount' => $this->amount,
            'unit' => $this->unit,
            'checked' => $this->checked,
            'status' => $this->status,
            'position' => $this->position,
            'created_by' => $this->creator?->name,
            // Chi l'ha segnato come preso o non preso.
            'checked_by' => $this->status !== 'todo' ? $this->checker?->name : null,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
