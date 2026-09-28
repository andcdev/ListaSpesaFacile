<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email con il codice a 6 cifre per scegliere una nuova password dall'app.
 */
class PasswordResetCode extends Notification
{
    public function __construct(public string $code, public int $minutes) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject(__('app.mail.reset_subject'))
            ->greeting(__('app.mail.greeting', ['name' => $notifiable->name]))
            ->line(__('app.mail.reset_intro'))
            ->line("**{$this->code}**")
            ->line(__('app.mail.reset_validity', ['minutes' => $this->minutes]))
            ->line(__('app.mail.reset_ignore'))
            ->salutation(__('app.mail.signature'));
    }
}
