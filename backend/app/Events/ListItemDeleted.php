<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Uno o più articoli eliminati da una lista.
 */
class ListItemDeleted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    /**
     * @param  array<int, int>  $itemIds
     */
    public function __construct(public int $listId, public array $itemIds) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->listId);
    }

    public function broadcastAs(): string
    {
        return 'item.deleted';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return ['ids' => array_values($this->itemIds)];
    }
}
