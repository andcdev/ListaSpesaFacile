<?php

namespace App\Http\Resources;

use App\Models\ListItem;
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
            'category' => $this->category,
            // Emoji mostrata: quella scelta dall'utente oppure quella riconosciuta dal nome.
            'icon' => $this->custom_icon ?? $this->icon,
            'custom_icon' => $this->custom_icon,
            'image_url' => $this->image_url,
            // Foto caricata dal telefono: GET /api/lists/{list}/items/{id}/image?v={image_version}; null se non c'è.
            'image_version' => $this->imageVersion(),
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
