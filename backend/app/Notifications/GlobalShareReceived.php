<?php

namespace App\Notifications;

/**
 * Un utente ha iniziato a condividere con te tutte le sue liste.
 */
class GlobalShareReceived extends AppNotification
{
    public function __construct(public string $actorName, public bool $canEdit) {}

    public function kind(): string
    {
        return 'global_share';
    }

    public function title(): string
    {
        return __('app.notifications.global_share_title', ['actor' => $this->actorName]);
    }

    public function body(): string
    {
        return __($this->canEdit ? 'app.notifications.global_share_edit' : 'app.notifications.global_share_view');
    }
}
