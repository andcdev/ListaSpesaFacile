<?php

namespace App\Notifications;

/**
 * Promemoria inviato reminder_minutes prima della spesa (vedi il comando lists:send-reminders).
 */
class ListReminder extends AppNotification
{
    public function __construct(public int $remindedListId, public string $listName, public int $minutes) {}

    public function kind(): string
    {
        return 'reminder';
    }

    public function title(): string
    {
        return __('app.notifications.reminder_title', ['list' => $this->listName]);
    }

    public function body(): string
    {
        return __('app.notifications.reminder_body', ['time' => self::duration($this->minutes)]);
    }

    public function listId(): ?int
    {
        return $this->remindedListId;
    }

    public function pushTag(): ?string
    {
        return 'reminder-'.$this->remindedListId;
    }

    /**
     * Es. "10 minuti", "1 ora", "1 ora e 30 minuti", "2 giorni".
     */
    public static function duration(int $minutes): string
    {
        $days = intdiv($minutes, 1440);
        $hours = intdiv($minutes % 1440, 60);
        $mins = $minutes % 60;

        $parts = array_filter([
            $days ? trans_choice('app.duration.day', $days) : null,
            $hours ? trans_choice('app.duration.hour', $hours) : null,
            $mins ? trans_choice('app.duration.minute', $mins) : null,
        ]);

        return match (count($parts)) {
            0 => __('app.duration.moments'),
            1 => reset($parts),
            default => implode(', ', array_slice($parts, 0, -1)).' '.__('app.duration.and').' '.end($parts),
        };
    }
}
