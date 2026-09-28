<?php

namespace App\Notifications\Channels;

use App\Events\NotificationCreated;
use App\Models\User;
use App\Notifications\AppNotification;
use App\Support\Realtime;

/**
 * Avvisa subito l'app aperta della nuova notifica (dopo il salvataggio nel database, se salvata).
 */
class RealtimeChannel
{
    public function send(User $notifiable, AppNotification $notification): void
    {
        Realtime::broadcast(new NotificationCreated(
            $notifiable->id,
            $notification->payload($notifiable),
            $notifiable->unreadNotifications()->count(),
        ));
    }
}
