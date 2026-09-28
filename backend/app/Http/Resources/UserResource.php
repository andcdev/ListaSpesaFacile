<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            // Foto profilo: GET /api/users/{id}/avatar?v={avatar_version}; null = nessuna (l'app mostra le iniziali).
            'avatar_version' => $this->avatarVersion(),
            'can_edit' => $this->whenPivotLoaded('shopping_list_user', fn () => (bool) $this->pivot->can_edit,
                $this->whenPivotLoaded('global_shares', fn () => (bool) $this->pivot->can_edit)),
        ];
    }
}
