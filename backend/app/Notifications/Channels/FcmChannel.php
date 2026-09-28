<?php

namespace App\Notifications\Channels;

use App\Models\User;
use App\Notifications\AppNotification;
use App\Support\Fcm;
use Throwable;

/**
 * Notifica push su tutti i dispositivi dell'utente. Un errore su un dispositivo non blocca gli altri;
 * i token non più validi vengono eliminati.
 */
class FcmChannel
{
    public function __construct(private Fcm $fcm) {}

    public function send(User $notifiable, AppNotification $notification): void
    {
        if (! $this->fcm->enabled()) {
            return;
        }

        $payload = $notification->payload($notifiable);
        $data = [
            'id' => $payload['id'],
            'kind' => $payload['kind'],
            'list_id' => $payload['list_id'],
            'sender' => $payload['sender'],
            'list_name' => $payload['list_name'],
            ...$notification->extra(),
        ];

        foreach ($notifiable->deviceTokens as $device) {
            try {
                if (! $this->fcm->send($device->token, $payload['title'], $payload['body'], $data, $notification->pushTag())) {
                    $device->delete();
                }
            } catch (Throwable $e) {
                report($e);
            }
        }
    }
}
