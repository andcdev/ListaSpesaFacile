<?php

namespace App\Notifications;

/**
 * L'utente è stato scelto per fare la spesa di una lista.
 */
class ShoppingAssigned extends AppNotification
{
    public function __construct(
        public string $actorName,
        public int $assignedListId,
        public string $assignedListName,
    ) {}

    public function kind(): string
    {
        return 'shopping_assigned';
    }

    public function title(): string
    {
        return __('app.notifications.shopping_assigned_title', ['list' => $this->assignedListName]);
    }

    public function body(): string
    {
        return __('app.notifications.shopping_assigned_body', ['actor' => $this->actorName]);
    }

    public function listId(): ?int
    {
        return $this->assignedListId;
    }
}
