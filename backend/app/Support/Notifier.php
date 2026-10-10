<?php

namespace App\Support;

use App\Models\User;
use App\Notifications\AppNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;

/**
 * Invio delle notifiche senza far fallire l'operazione che le ha generate
 * (la lista è già salvata anche se una notifica non parte).
 */
class Notifier
{
    /**
     * @param  iterable<User>|array<int, int>  $users  utenti o loro id
     * @param  User|null  $from  chi ha fatto l'azione: chi l'ha bloccato non riceve la notifica
     */
    public static function send(iterable $users, AppNotification $notification, ?User $from = null): void
    {
        $users = collect($users);
        if ($users->isEmpty()) {
            return;
        }
        if (! $users->first() instanceof User) {
            $users = User::whereKey($users->all())->get();
        }
        if ($from) {
            $blockers = DB::table('user_blocks')->where('blocked_id', $from->id)->pluck('user_id')->map(fn ($id) => (int) $id);
            $users = $users->reject(fn (User $user) => $blockers->contains($user->id));
            if ($users->isEmpty()) {
                return;
            }
        }

        rescue(fn () => Notification::send($users, $notification));
    }
}
