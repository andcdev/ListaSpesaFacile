<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email con il codice a 6 cifre per confermare l'eliminazione dell'account dal sito.
 */
class AccountDeletionCode extends Notification
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
            ->subject(__('app.mail.deletion_subject'))
            ->greeting(__('app.mail.greeting', ['name' => $notifiable->name]))
            ->line(__('app.mail.deletion_intro'))
            ->line("**{$this->code}**")
            ->line(__('app.mail.reset_validity', ['minutes' => $this->minutes]))
            ->line(__('app.mail.deletion_warning'))
            ->line(__('app.mail.deletion_ignore'))
            ->salutation(__('app.mail.signature'));
    }
}
