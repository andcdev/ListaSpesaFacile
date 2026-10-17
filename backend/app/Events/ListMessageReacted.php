<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Reazioni di un messaggio cambiate: arrivano tutte, così l'app le sostituisce.
 */
class ListMessageReacted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    /**
     * @param  array<int, array{emoji: string, user_id: int, user_name: ?string}>  $reactions
     */
    public function __construct(public int $listId, public int $messageId, public array $reactions) {}

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('list.'.$this->listId);
    }

    public function broadcastAs(): string
    {
        return 'message.reacted';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return ['id' => $this->messageId, 'reactions' => $this->reactions];
    }
}
