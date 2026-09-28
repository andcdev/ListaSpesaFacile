<?php

namespace App\Http\Controllers;

use App\Models\SocialAccount;
use App\Models\User;
use App\Support\SocialProviders;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Socialite\Contracts\User as ProviderUser;
use Laravel\Socialite\Facades\Socialite;
use RuntimeException;
use Throwable;

/**
 * Login con Google / Facebook / Amazon per l'app mobile.
 *
 * 1. L'app apre nel browser di sistema /auth/{provider}/redirect?code_challenge=… (PKCE, S256).
 * 2. Il provider riporta l'utente su /auth/{provider}/callback: troviamo o creiamo l'utente.
 * 3. Riapriamo l'app (listaspesafacile://auth?code=…) con un codice monouso di breve durata.
 * 4. L'app scambia codice + code_verifier con un token Sanctum (POST /api/auth/social/exchange).
 *
 * Il token non passa mai dall'URL e il codice è inutile senza il verifier rimasto nell'app.
 */
class SocialAuthController extends Controller
{
    private const STATE_TTL = 600;

    private const CODE_TTL = 120;

    public function redirect(Request $request, string $provider): RedirectResponse
    {
        abort_unless(SocialProviders::isEnabled($provider), 404);

        $data = $request->validate([
            'code_challenge' => ['required', 'string', 'regex:/^[A-Za-z0-9_-]{43}$/'],
        ]);

        $state = Str::random(40);
        Cache::put("social_state:$state", [
            'provider' => $provider,
            'challenge' => $data['code_challenge'],
        ], self::STATE_TTL);

        $driver = Socialite::driver($provider)->stateless()->with(['state' => $state]);
        if ($provider !== 'amazon') {
            $driver->scopes(['email']);
        }

        return $driver->redirect();
    }

    public function callback(Request $request, string $provider): RedirectResponse
    {
        abort_unless(SocialProviders::isEnabled($provider), 404);

        $pending = Cache::pull('social_state:'.$request->string('state'));
        if (! $pending || $pending['provider'] !== $provider) {
            return $this->backToApp(['error' => __('app.errors.social_expired')]);
        }
        if ($request->filled('error')) {
            return $this->backToApp(['error' => __('app.errors.social_cancelled')]);
        }

        try {
            $providerUser = Socialite::driver($provider)->stateless()->user();
        } catch (Throwable $e) {
            report($e);

            return $this->backToApp(['error' => __('app.errors.social_failed', ['provider' => SocialProviders::label($provider)])]);
        }

        try {
            $user = $this->resolveUser($provider, $providerUser);
        } catch (RuntimeException $e) {
            return $this->backToApp(['error' => $e->getMessage()]);
        }

        $code = Str::random(64);
        Cache::put("social_code:$code", [
            'user_id' => $user->id,
            'challenge' => $pending['challenge'],
        ], self::CODE_TTL);

        return $this->backToApp(['code' => $code]);
    }

    /**
     * Account già collegato → quel utente; altrimenti collega per email o crea un nuovo utente.
     */
    private function resolveUser(string $provider, ProviderUser $providerUser): User
    {
        return DB::transaction(function () use ($provider, $providerUser) {
            $account = SocialAccount::where('provider', $provider)
                ->where('provider_user_id', (string) $providerUser->getId())
                ->first();
            if ($account) {
                return $account->user;
            }

            $email = strtolower((string) $providerUser->getEmail());
            if ($email === '') {
                throw new RuntimeException(__('app.errors.social_no_email', ['provider' => SocialProviders::label($provider)]));
            }

            $user = User::firstWhere('email', $email) ?? tap(new User([
                'name' => $providerUser->getName() ?: $providerUser->getNickname() ?: Str::before($email, '@'),
                'email' => $email,
                'locale' => app()->getLocale(),
            ]), function (User $user) {
                // Email già verificata dal provider.
                $user->email_verified_at = now();
                $user->save();
            });

            $user->socialAccounts()->create([
                'provider' => $provider,
                'provider_user_id' => (string) $providerUser->getId(),
            ]);

            return $user;
        });
    }

    /**
     * @param  array<string, string>  $params
     */
    private function backToApp(array $params): RedirectResponse
    {
        return redirect()->away(config('services.social_app_callback').'?'.http_build_query($params));
    }
}
