<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Invio di notifiche push con Firebase Cloud Messaging (API HTTP v1).
 *
 * Attivo solo se esiste il file JSON del service account indicato in services.fcm.credentials:
 * senza, l'app riceve comunque le notifiche in tempo reale quando è aperta.
 */
class Fcm
{
    /** Canale Android creato dall'app per tutte le notifiche. */
    public const ANDROID_CHANNEL = 'lista_spesa';

    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /** @var array<string, string>|null */
    private ?array $credentials = null;

    public function enabled(): bool
    {
        return $this->credentials() !== null;
    }

    /**
     * Invia una notifica a un dispositivo.
     *
     * Su Android il messaggio contiene solo dati (priorità alta): lo riceve l'app anche chiusa o in background
     * e disegna lei la notifica, raggruppando chat e modifiche nella conversazione della lista come WhatsApp.
     * Su iOS il sistema mostra direttamente titolo e testo.
     *
     * @param  array<string, scalar|null>  $data  dati letti dall'app all'apertura della notifica
     * @return bool false se il token non è più valido (app disinstallata o token rinnovato)
     */
    public function send(string $token, string $title, string $body, array $data = [], ?string $tag = null): bool
    {
        $credentials = $this->credentials() ?? throw new RuntimeException('FCM non configurato.');

        $data = ['title' => $title, 'body' => $body, 'tag' => $tag, 'channel_id' => self::ANDROID_CHANNEL, ...$data];

        $response = Http::withToken($this->accessToken())
            ->timeout(10)
            ->post("https://fcm.googleapis.com/v1/projects/{$credentials['project_id']}/messages:send", [
                'message' => [
                    'token' => $token,
                    // FCM accetta solo stringhe nei dati.
                    'data' => array_map(fn ($value) => (string) $value, array_filter($data, fn ($v) => $v !== null)),
                    'android' => ['priority' => 'high'],
                    'apns' => [
                        'headers' => ['apns-priority' => '10'],
                        'payload' => [
                            'aps' => array_filter([
                                'alert' => ['title' => $title, 'body' => $body],
                                'sound' => 'default',
                                // Stesso thread = notifiche raggruppate (es. chat e modifiche della stessa lista).
                                'thread-id' => $tag,
                            ]),
                        ],
                    ],
                ],
            ]);

        if ($response->successful()) {
            return true;
        }

        $errorCode = collect($response->json('error.details', []))->pluck('errorCode')->filter()->first();
        if ($response->status() === 404 || $errorCode === 'UNREGISTERED') {
            return false;
        }

        $response->throw();

        return true;
    }

    /**
     * Token OAuth2 del service account (JWT firmato RS256), valido un'ora: lo teniamo in cache 50 minuti.
     */
    private function accessToken(): string
    {
        $credentials = $this->credentials();

        return Cache::remember('fcm_access_token:'.$credentials['client_email'], now()->addMinutes(50), function () use ($credentials) {
            $now = time();
            $segments = [
                self::base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
                self::base64Url(json_encode([
                    'iss' => $credentials['client_email'],
                    'scope' => self::SCOPE,
                    'aud' => $credentials['token_uri'],
                    'iat' => $now,
                    'exp' => $now + 3600,
                ])),
            ];
            if (! openssl_sign(implode('.', $segments), $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
                throw new RuntimeException('Chiave privata FCM non valida.');
            }
            $segments[] = self::base64Url($signature);

            return Http::asForm()
                ->timeout(10)
                ->post($credentials['token_uri'], [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => implode('.', $segments),
                ])
                ->throw()
                ->json('access_token');
        });
    }

    /**
     * @return array<string, string>|null
     */
    private function credentials(): ?array
    {
        if ($this->credentials !== null) {
            return $this->credentials;
        }

        $path = config('services.fcm.credentials');
        if (! $path || ! is_readable($path)) {
            return null;
        }

        $json = json_decode((string) file_get_contents($path), true);
        if (! is_array($json) || ! isset($json['project_id'], $json['client_email'], $json['private_key'])) {
            return null;
        }
        $json['token_uri'] ??= 'https://oauth2.googleapis.com/token';

        return $this->credentials = $json;
    }

    private static function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
