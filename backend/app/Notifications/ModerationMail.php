<?php

namespace App\Notifications;

use App\Models\Report;
use App\Models\User;
use App\Support\ModerationLinks;
use Illuminate\Notifications\Messages\MailMessage;

/**
 * Email all'assistenza (sempre in italiano, a support@ con la copia in cc) con i pulsanti per guardare la foto,
 * sospendere l'account e scrivere all'utente.
 */
trait ModerationMail
{
    /**
     * @param  array<int, string>  $lines  righe in Markdown (i dati degli utenti vengono resi sicuri dal modello)
     * @param  string|null  $quote  testo scritto dall'utente (messaggio della chat, didascalia…), in un riquadro
     * @param  User|null  $person  persona su cui agire: compaiono i pulsanti di sospensione e avviso
     */
    protected function moderationMail(
        Report $report,
        string $subject,
        string $title,
        array $lines,
        ?string $quote = null,
        ?User $person = null,
    ): MailMessage {
        $mail = (new MailMessage)
            ->subject($subject)
            ->markdown('mail.segnalazione', [
                'title' => $title,
                'lines' => $lines,
                'quote' => $quote,
                'imageUrl' => ModerationLinks::image($report),
                'person' => $person,
                'suspendUrl' => $person ? ModerationLinks::suspend($person) : null,
                'warningMailto' => $person ? ModerationLinks::mailto($person, 'warning') : null,
                'validDays' => ModerationLinks::VALID_DAYS,
                'quarantineDays' => Report::QUARANTINE_DAYS,
            ]);
        if ($cc = config('mail.support.cc')) {
            $mail->cc($cc);
        }

        return $mail;
    }

    protected static function describe(User $user): string
    {
        return "{$user->name} <{$user->email}> (utente {$user->id})";
    }
}
