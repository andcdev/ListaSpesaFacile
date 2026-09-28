<?php

namespace App\Notifications;

/**
 * Una lista è stata condivisa con l'utente.
 */
class ListShared extends AppNotification
{
    public function __construct(
        public string $actorName,
        public int $sharedListId,
        public string $listName,
        public bool $canEdit,
    ) {}

    public function kind(): string
    {
        return 'list_shared';
    }

    public function title(): string
    {
        return __('app.notifications.list_shared_title', ['actor' => $this->actorName, 'list' => $this->listName]);
    }

    public function body(): string
    {
        return __($this->canEdit ? 'app.notifications.list_shared_edit' : 'app.notifications.list_shared_view');
    }

    public function listId(): ?int
    {
        return $this->sharedListId;
    }
}
