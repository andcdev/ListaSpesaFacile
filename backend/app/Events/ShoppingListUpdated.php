<?php

namespace App\Events;

use App\Models\ShoppingList;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Nome, note, data/ora o promemoria della lista modificati.
 */
class ShoppingListUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public ShoppingList $list) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->list->id);
    }

    public function broadcastAs(): string
    {
        return 'list.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'list' => [
                'id' => $this->list->id,
                'name' => $this->list->name,
                'notes' => $this->list->notes,
                'scheduled_at' => $this->list->scheduled_at->toIso8601String(),
                'reminder_minutes' => $this->list->reminder_minutes,
                'image_version' => $this->list->imageVersion(),
                'reminder_target' => $this->list->reminder_target,
                'members_can_rename' => $this->list->members_can_rename,
            ],
        ];
    }
}
