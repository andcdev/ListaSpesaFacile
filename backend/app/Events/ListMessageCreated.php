<?php

namespace App\Events;

use App\Http\Resources\ListMessageResource;
use App\Models\ListMessage;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Nuovo messaggio nella chat della lista.
 */
class ListMessageCreated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public ListMessage $message) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->message->shopping_list_id);
    }

    public function broadcastAs(): string
    {
        return 'message.created';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        $this->message->loadMissing('user');

        return ['message' => (new ListMessageResource($this->message))->resolve()];
    }
}
