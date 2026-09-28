<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Il telefono di un utente ha ricevuto i messaggi della chat fino a [upTo]: le spunte diventano blu.
 */
class ListMessagesDelivered implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public int $listId, public int $userId, public int $upTo) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->listId);
    }

    public function broadcastAs(): string
    {
        return 'messages.delivered';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return ['user_id' => $this->userId, 'up_to' => $this->upTo];
    }
}
