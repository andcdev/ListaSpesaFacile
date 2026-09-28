<?php

namespace App\Notifications;

class ListDeleted extends AppNotification
{
    public function __construct(public string $actorName, public string $listName) {}

    public function kind(): string
    {
        return 'list_deleted';
    }

    public function title(): string
    {
        return __('app.notifications.list_deleted_title', ['actor' => $this->actorName, 'list' => $this->listName]);
    }

    public function body(): string
    {
        return __('app.notifications.list_deleted_body');
    }
}
