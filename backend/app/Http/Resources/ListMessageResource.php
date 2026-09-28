<?php

namespace App\Http\Resources;

use App\Models\ListMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ListMessage
 */
class ListMessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'shopping_list_id' => $this->shopping_list_id,
            'body' => $this->body,
            // Foto allegata: GET /api/lists/{list}/messages/{id}/image.
            'has_image' => $this->image_path !== null,
            'user' => $this->user
                ? ['id' => $this->user->id, 'name' => $this->user->name, 'avatar_version' => $this->user->avatarVersion()]
                : null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
