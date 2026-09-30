<?php

use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\Schedule;

// Eseguiti dal container "scheduler" (php artisan schedule:work).
Schedule::command('lists:send-reminders')->everyMinute()->withoutOverlapping();

// Le notifiche più vecchie di 90 giorni non servono più.
Schedule::call(fn () => DatabaseNotification::where('created_at', '<', now()->subDays(90))->delete())
    ->daily()
    ->name('prune-notifications');
