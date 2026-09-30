<?php

namespace App\Events;

use App\Http\Resources\ListItemResource;
use App\Models\ListItem;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Articolo creato o modificato: inviato a chi sta guardando la lista.
 */
class ListItemSaved implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public ListItem $item) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->item->shopping_list_id);
    }

    public function broadcastAs(): string
    {
        return 'item.saved';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        $this->item->loadMissing(['creator', 'checker']);

        return ['item' => (new ListItemResource($this->item))->resolve()];
    }
}
