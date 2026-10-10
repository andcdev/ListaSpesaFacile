<?php

namespace App\Notifications;

use App\Models\Report;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email all'assistenza: il controllo automatico ha rifiutato una foto (nudità, contenuti sessuali o violenza).
 * La foto non è stata pubblicata; resta in quarantena per qualche giorno, per guardarla e decidere.
 */
class ImageRejected extends Notification
{
    use ModerationMail;

    private const CONTEXTS = [
        'chat' => 'in chat',
        'item' => 'come foto di un prodotto',
        'list' => 'come foto della lista',
        'avatar' => 'come foto profilo',
    ];

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
        $user = $report->user;
        $scores = $report->scores;
        $where = self::CONTEXTS[$report->context] ?? $report->context;

        $lines = [
            "La foto che **{$user->name}** ha provato a caricare {$where} è stata rifiutata e non l'ha vista nessuno.",
            '**Utente:** '.self::describe($user),
            '**Quando:** '.$report->created_at->timezone('Europe/Rome')->format('d/m/Y H:i'),
            sprintf('**Punteggi:** contenuti sessuali %d%%, violenza %d%%', round($scores['sexual'] * 100), round($scores['violence'] * 100)),
        ];
        if ($list = $report->shoppingList) {
            $lines[] = "**Lista:** «{$list->name}» (lista {$list->id}, di {$list->owner->name})";
        }
        if ($report->body !== null) {
            $lines[] = match ($report->context) {
                'chat' => '**Testo del messaggio:**',
                'item' => '**Prodotto:**',
                default => '**Nome:**',
            };
        }

        return $this->moderationMail(
            $report,
            "Foto rifiutata #{$report->id} · {$user->name}",
            'Foto rifiutata dal controllo automatico',
            $lines,
            $report->body,
            $user,
        );
    }
}
