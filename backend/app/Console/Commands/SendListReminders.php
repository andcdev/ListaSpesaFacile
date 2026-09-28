<?php

namespace App\Console\Commands;

use App\Models\ShoppingList;
use App\Notifications\ListReminder;
use App\Support\Notifier;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Invia i promemoria arrivati a scadenza. Eseguito ogni minuto dallo scheduler (routes/console.php).
 */
#[Signature('lists:send-reminders')]
#[Description('Invia i promemoria delle liste della spesa')]
class SendListReminders extends Command
{
    public function handle(): int
    {
        $sent = 0;

        ShoppingList::query()
            ->whereNotNull('remind_at')
            ->where('remind_at', '<=', now())
            ->each(function (ShoppingList $list) use (&$sent) {
                // Lo "prenotiamo" azzerando remind_at: se due scheduler girano insieme, lo invia uno solo.
                $claimed = ShoppingList::whereKey($list->id)->whereNotNull('remind_at')->toBase()->update(['remind_at' => null]);

                // Se il server era fermo e la spesa è già iniziata, il promemoria non serve più.
                if (! $claimed || $list->scheduled_at->isPast()) {
                    return;
                }

                // Minuti effettivamente mancanti (lo scheduler può partire con qualche secondo di ritardo).
                $minutes = min($list->reminder_minutes, (int) ceil(now()->diffInMinutes($list->scheduled_at, true)));

                Notifier::send($list->reminderRecipientIds(), new ListReminder($list->id, $list->name, max(1, $minutes)));
                $sent++;
            });

        $this->info("Promemoria inviati: $sent");

        return self::SUCCESS;
    }
}
