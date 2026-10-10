<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\AccountDeleter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            // Ogni nome è unico (senza badare alle maiuscole): è quello che gli altri vedono nelle liste.
            'name' => ['required', 'string', 'max:255', function (string $attribute, mixed $value, \Closure $fail) {
                if (is_string($value) && User::nameTaken($value)) {
                    $fail(__('app.errors.name_taken'));
                }
            }],
            // Indirizzo valido secondo lo standard, senza forme strane (es. "mario@localhost", spazi, punti doppi).
            'email' => ['required', 'string', 'lowercase', 'email:rfc,strict', 'regex:/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'device_name' => ['nullable', 'string', 'max:255'],
            // Informativa privacy e condizioni d'uso da accettare; newsletter facoltativa.
            'privacy' => ['accepted'],
            'terms' => ['sometimes', 'accepted'],
            'newsletter' => ['sometimes', 'boolean'],
        ]);

        // Le versioni dell'app precedenti alle condizioni d'uso non mandano "terms" e mostrano gli errori solo sotto
        // i campi che conoscono: l'invito ad aggiornare va sotto la casella della privacy.
        if (! array_key_exists('terms', $data)) {
            throw ValidationException::withMessages(['privacy' => [__('app.errors.update_app_for_terms')]]);
        }

        $newsletter = (bool) ($data['newsletter'] ?? false);
        $user = User::create([
            ...collect($data)->only(['email', 'password'])->all(),
            'name' => trim($data['name']),
            'locale' => app()->getLocale(),
            'privacy_accepted_at' => now(),
            'terms_accepted_at' => now(),
            'newsletter' => $newsletter,
            'newsletter_consented_at' => $newsletter ? now() : null,
        ]);

        return $this->tokenResponse($user, $data['device_name'] ?? 'app', 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if ($user && $user->password === null) {
            throw ValidationException::withMessages([
                'email' => [__('app.errors.social_only', ['providers' => $user->socialAccounts()->pluck('provider')->map(ucfirst(...))->join(', ')])],
            ]);
        }

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => [__('app.errors.invalid_credentials')],
            ]);
        }

        return $this->tokenResponse($user, $data['device_name'] ?? 'app');
    }

    /**
     * Ultimo passo del login social: codice monouso + code_verifier (PKCE) → token.
     */
    public function exchangeSocialCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string'],
            'code_verifier' => ['required', 'string', 'min:43', 'max:128'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $pending = Cache::pull('social_code:'.$data['code']);
        $challenge = rtrim(strtr(base64_encode(hash('sha256', $data['code_verifier'], true)), '+/', '-_'), '=');

        if (! $pending || ! hash_equals($pending['challenge'], $challenge)) {
            throw ValidationException::withMessages(['code' => [__('app.errors.social_code_invalid')]]);
        }

        return $this->tokenResponse(User::findOrFail($pending['user_id']), $data['device_name'] ?? 'app');
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(status: 204);
    }

    /**
     * Eliminazione dell'account dall'app (Google Play la chiede sia nell'app sia sul sito): stessa pulizia della
     * pagina listaspesafacile.com/elimina-account. Il token dell'app basta come prova d'identità, e chi è entrato
     * con Google o Amazon non ha una password da chiedere.
     */
    public function destroy(Request $request): JsonResponse
    {
        AccountDeleter::delete($request->user());

        return response()->json(status: 204);
    }

    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    /**
     * Consenso alla newsletter, dal menu del profilo.
     */
    public function update(Request $request): UserResource
    {
        $data = $request->validate(['newsletter' => ['required', 'boolean']]);
        $user = $request->user();
        $user->newsletter = (bool) $data['newsletter'];
        $user->newsletter_consented_at = $user->newsletter ? now() : null;
        $user->save();

        return new UserResource($user);
    }

    private function tokenResponse(User $user, string $deviceName, int $status = 200): JsonResponse
    {
        // Account sospeso dall'assistenza: nessun accesso, con nessun metodo.
        abort_if($user->isSuspended(), 403, __('app.errors.account_suspended'));

        return response()->json([
            'token' => $user->createToken($deviceName)->plainTextToken,
            'user' => new UserResource($user),
        ], $status);
    }
}
