<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Segnala agli utenti coinvolti che l'elenco delle loro liste va ricaricato
 * (lista creata/modificata/eliminata, condivisione aggiunta o revocata).
 */
class ListsChanged implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets;

    /**
     * @param  array<int, int>  $userIds
     */
    public function __construct(public array $userIds, public ?int $listId = null) {}

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return array_map(
            fn (int $id) => new PrivateChannel('App.Models.User.'.$id),
            array_values(array_unique($this->userIds)),
        );
    }

    public function broadcastAs(): string
    {
        return 'lists.changed';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return ['list_id' => $this->listId];
    }
}
