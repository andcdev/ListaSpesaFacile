<?php

namespace App\Http\Resources;

use App\Models\ShoppingList;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ShoppingList
 */
class ShoppingListResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $user = $request->user();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'notes' => $this->notes,
            'scheduled_at' => $this->scheduled_at->toIso8601String(),
            // Foto della lista: GET /api/lists/{id}/image?v={image_version}; null se non c'è.
            'image_version' => $this->imageVersion(),
            'reminder_minutes' => $this->reminder_minutes,
            'reminder_target' => $this->reminder_target,
            // Il proprietario consente a chi può modificare anche di cambiare il nome; can_rename vale per l'utente corrente.
            'members_can_rename' => $this->members_can_rename,
            'can_rename' => $user ? $this->canRename($user) : false,
            'owner' => new UserResource($this->whenLoaded('owner')),
            'permission' => $user ? $this->permissionFor($user) : null,
            'items_count' => $this->whenCounted('items'),
            'checked_count' => $this->whenCounted('checked_items'),
            'items' => ListItemResource::collection($this->whenLoaded('items')),
            'shared_with' => UserResource::collection($this->whenLoaded('sharedWith')),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
