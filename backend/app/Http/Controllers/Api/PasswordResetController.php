<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * Recupero della password dall'app: un codice di 6 cifre via email (più comodo di un link su un telefono),
 * poi codice + nuova password → accesso. Funziona anche per chi si era registrato con Google o Amazon.
 */
class PasswordResetController extends Controller
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
            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $email],
                ['token' => Hash::make($code), 'created_at' => now()],
            );
            Cache::forget($this->attemptsKey($email));

            try {
                $user->notify(new PasswordResetCode($code, self::CODE_MINUTES));
            } catch (Throwable $e) {
                report($e);
                abort(503, __('app.errors.mail_unavailable'));
            }
        }

        return response()->json([
            'message' => __('app.reset_sent'),
        ]);
    }

    public function reset(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'string', 'digits:6'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);
        $email = strtolower($data['email']);

        $record = DB::table('password_reset_tokens')->where('email', $email)->first();
        $valid = $record
            && now()->subMinutes(self::CODE_MINUTES)->lessThan($record->created_at)
            && Hash::check($data['code'], $record->token);

        if (! $valid) {
            // Troppi tentativi: il codice non vale più, ne serve uno nuovo.
            if ($record) {
                Cache::add($this->attemptsKey($email), 0, now()->addMinutes(self::CODE_MINUTES));
                if (Cache::increment($this->attemptsKey($email)) >= self::MAX_ATTEMPTS) {
                    DB::table('password_reset_tokens')->where('email', $email)->delete();
                }
            }
            throw ValidationException::withMessages(['code' => [__('app.errors.reset_code_invalid')]]);
        }

        $user = User::where('email', $email)->firstOrFail();
        abort_if($user->isSuspended(), 403, __('app.errors.account_suspended'));
        $user->password = $data['password'];
        $user->save();

        DB::table('password_reset_tokens')->where('email', $email)->delete();
        Cache::forget($this->attemptsKey($email));
        // Chi conosceva la vecchia password non resta collegato su altri dispositivi.
        $user->tokens()->delete();

        return response()->json([
            'token' => $user->createToken($data['device_name'] ?? 'app')->plainTextToken,
            'user' => new UserResource($user),
        ]);
    }

    private function attemptsKey(string $email): string
    {
        return 'password_reset_attempts:'.sha1($email);
    }
}
