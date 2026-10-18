<?php

namespace App\Http\Resources;

use App\Models\ShoppingList;
use App\Models\User;
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
            // Supermercato dove si fa la spesa, come scritto dall'utente.
            'supermarket' => $this->supermarket,
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
            'unread_messages' => $this->whenCounted('unread_messages'),
            'items' => ListItemResource::collection($this->whenLoaded('items')),
            'shared_with' => UserResource::collection($this->whenLoaded('sharedWith')),
            ...$this->when($this->relationLoaded('items'), fn () => [
                ...self::shopping($this->resource),
                // Tutte le persone della lista (proprietario compreso), tra cui scegliere chi fa la spesa.
                'people' => User::whereKey($this->audienceIds())->orderBy('name')->get(['id', 'name'])
                    ->map(fn (User $u) => ['id' => $u->id, 'name' => $u->name])->all(),
            ], []),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /**
     * Chi fa la spesa e "Spesa finita" (anche nell'evento list.updated).
     *
     * @return array<string, mixed>
     */
    public static function shopping(ShoppingList $list): array
    {
        $shopperId = $list->activeShopperId();
        $finisher = $list->finished_by ? User::find($list->finished_by, ['id', 'name']) : null;

        return [
            'shopper' => $shopperId === null ? null : ['id' => $shopperId, 'name' => User::find($shopperId)?->name],
            'finished_at' => $list->finished_at?->toIso8601String(),
            'finished_by' => $finisher ? ['id' => $finisher->id, 'name' => $finisher->name] : null,
            'finish_message' => $list->finish_message,
        ];
    }
}
