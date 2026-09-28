<?php

namespace App\Notifications;

/**
 * Nuova lista di un utente che condivide con te tutte le sue liste.
 */
class ListCreated extends AppNotification
{
    public function __construct(public string $actorName, public int $createdListId, public string $listName) {}

    public function kind(): string
    {
        return 'list_created';
    }

    public function title(): string
    {
        return __('app.notifications.list_created_title', ['actor' => $this->actorName, 'list' => $this->listName]);
    }

    public function body(): string
    {
        return __('app.notifications.list_created_body');
    }

    public function listId(): ?int
    {
        return $this->createdListId;
    }
}
