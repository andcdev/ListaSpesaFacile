<?php

namespace App\Notifications;

use App\Models\Report;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email all'assistenza con una segnalazione dall'app. "Rispondi" scrive a chi ha segnalato.
 */
class ReportReceived extends Notification
{
    use ModerationMail;

    public function __construct(public Report $report) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $report = $this->report;
        $reporter = $report->user;
        $type = ['problem' => 'Problema', 'user' => 'Persona', 'message' => 'Messaggio'][$report->type];

        $lines = [
            '**Da:** '.self::describe($reporter),
            '**Quando:** '.$report->created_at->timezone('Europe/Rome')->format('d/m/Y H:i'),
        ];
        if ($report->app_version) {
            $lines[] = "**Versione dell'app:** {$report->app_version}";
        }
        if ($reported = $report->reportedUser) {
            $lines[] = '**Persona segnalata:** '.self::describe($reported);
        }
        if ($list = $report->shoppingList) {
            $lines[] = "**Lista:** «{$list->name}» (lista {$list->id}, di {$list->owner->name})";
        }
        $lines[] = '**Testo della segnalazione:** '.($report->body ?: '(nessun testo)');
        if ($report->list_message_id) {
            $lines[] = "**Messaggio segnalato** ({$report->list_message_id}):";
        }
        $quote = $report->list_message_id ? ($report->message_body ?? '(solo foto)') : null;

        $mail = $this->moderationMail(
            $report,
            "Segnalazione #{$report->id} · {$type} · {$reporter->name}",
            "Segnalazione #{$report->id}: {$type}",
            $lines,
            $quote,
            $report->reportedUser,
        );

        return $reporter->email ? $mail->replyTo($reporter->email, $reporter->name) : $mail;
    }
}
