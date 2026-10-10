<?php

use App\Models\Report;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Storage;

// Eseguiti dal container "scheduler" (php artisan schedule:work).
Schedule::command('lists:send-reminders')->everyMinute()->withoutOverlapping();

// Le notifiche più vecchie di 90 giorni non servono più.
Schedule::call(fn () => DatabaseNotification::where('created_at', '<', now()->subDays(90))->delete())
    ->daily()
    ->name('prune-notifications');

// Le foto rifiutate dal controllo automatico restano in quarantena (da guardare dall'email) solo per qualche giorno.
Schedule::call(function () {
    Report::whereNotNull('image_path')
        ->where('created_at', '<', now()->subDays(Report::QUARANTINE_DAYS))
        ->each(function (Report $report) {
            Storage::delete($report->image_path);
            $report->update(['image_path' => null]);
        });
})->daily()->name('prune-quarantine');
