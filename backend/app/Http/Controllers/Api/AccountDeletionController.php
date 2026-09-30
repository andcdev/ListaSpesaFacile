<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Notifications\AccountDeletionCode;
use App\Support\AccountDeleter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * Eliminazione dell'account dal sito (listaspesafacile.com/elimina-account), come chiede Google Play:
 * email → codice di 6 cifre via email → codice → account eliminato. Funziona anche per chi è entrato con
 * Google o Amazon e non ha una password, e prova che chi chiede ha accesso a quella casella.
 */
class AccountDeletionController extends Controller
{
    private const CODE_MINUTES = 30;

    /** Tentativi con un codice sbagliato prima che venga annullato. */
    private const MAX_ATTEMPTS = 5;

    public function sendCode(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'string', 'email']]);
        $email = strtolower($data['email']);

        // Stessa risposta anche se l'email non è registrata: non si rivela chi ha un account.
        if ($user = User::firstWhere('email', $email)) {
            $code = str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);
            Cache::put($this->key($email), ['hash' => Hash::make($code), 'attempts' => 0], now()->addMinutes(self::CODE_MINUTES));

            try {
                $user->notify(new AccountDeletionCode($code, self::CODE_MINUTES));
            } catch (Throwable $e) {
                report($e);
                abort(503, __('app.errors.mail_unavailable'));
            }
        }

        return response()->json(['message' => __('app.deletion_sent')]);
    }

    public function confirm(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'string', 'digits:6'],
        ]);
        $email = strtolower($data['email']);
        $record = Cache::get($this->key($email));

        if (! $record || ! Hash::check($data['code'], $record['hash'])) {
            // Troppi tentativi: il codice non vale più, ne serve uno nuovo.
            if ($record) {
                $record['attempts']++;
                $record['attempts'] >= self::MAX_ATTEMPTS
                    ? Cache::forget($this->key($email))
                    : Cache::put($this->key($email), $record, now()->addMinutes(self::CODE_MINUTES));
            }
            throw ValidationException::withMessages(['code' => [__('app.errors.reset_code_invalid')]]);
        }

        Cache::forget($this->key($email));
        if ($user = User::firstWhere('email', $email)) {
            AccountDeleter::delete($user);
        }

        return response()->json(['message' => __('app.account_deleted')]);
    }

    private function key(string $email): string
    {
        return 'account_deletion:'.sha1($email);
    }
}
