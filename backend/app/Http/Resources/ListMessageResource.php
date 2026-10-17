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
            // Messaggio citato nella risposta (null se non è una risposta o se è stato eliminato).
            'reply_to' => $this->replyTo ? [
                'id' => $this->replyTo->id,
                'body' => mb_strimwidth((string) $this->replyTo->body, 0, 160, '…'),
                'has_image' => $this->replyTo->image_path !== null,
                'user' => $this->replyTo->user ? ['id' => $this->replyTo->user->id, 'name' => $this->replyTo->user->name] : null,
            ] : null,
            // Evento della lista (finished, took_over, shopper_changed): testo in grigio composto dall'app.
            'event' => $this->event,
            'event_params' => $this->event_params,
            // Reazioni: una per persona.
            'reactions' => $this->reactionList(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
