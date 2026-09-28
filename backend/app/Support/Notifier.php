<?php

namespace App\Support;

use App\Models\User;
use App\Notifications\AppNotification;
use Illuminate\Support\Facades\Notification;

/**
 * Invio delle notifiche senza far fallire l'operazione che le ha generate
 * (la lista è già salvata anche se una notifica non parte).
 */
class Notifier
{
    /**
     * @param  iterable<User>|array<int, int>  $users  utenti o loro id
     */
    public static function send(iterable $users, AppNotification $notification): void
    {
        $users = collect($users);
        if ($users->isEmpty()) {
            return;
        }
        if (! $users->first() instanceof User) {
            $users = User::whereKey($users->all())->get();
        }

        rescue(fn () => Notification::send($users, $notification));
    }
}
