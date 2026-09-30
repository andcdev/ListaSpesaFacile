<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\RedirectResponse;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialiteUser;
use Mockery;
use Tests\TestCase;

class SocialAuthTest extends TestCase
{
    use RefreshDatabase;

    private const VERIFIER = 'questo-e-un-code-verifier-lungo-almeno-43-caratteri-ok';

    private ?string $state = null;

    protected function setUp(): void
    {
        parent::setUp();

        foreach (['google', 'amazon'] as $provider) {
            config(["services.$provider.client_id" => 'id', "services.$provider.client_secret" => 'secret']);
        }
    }

    public function test_new_user_signs_up_with_google(): void
    {
        $params = $this->loginVia('google', $this->socialUser('g-1', 'Giulia@Example.com'));

        $response = $this->postJson('/api/auth/social/exchange', [
            'code' => $params['code'],
            'code_verifier' => self::VERIFIER,
        ])->assertOk()->assertJsonPath('user.email', 'giulia@example.com');

        $user = User::firstWhere('email', 'giulia@example.com');
        $this->assertSame('Giulia Verdi', $user->name);
        $this->assertNull($user->password);
        $this->assertDatabaseHas('social_accounts', ['user_id' => $user->id, 'provider' => 'google', 'provider_user_id' => 'g-1']);

        $this->withToken($response->json('token'))->getJson('/api/me')->assertOk();
    }

    public function test_existing_email_is_linked_and_same_user_returned_for_each_provider(): void
    {
        $existing = User::factory()->create(['email' => 'giulia@example.com']);

        foreach (['google' => 'g-9', 'amazon' => 'amzn1.account.X'] as $provider => $id) {
            $params = $this->loginVia($provider, $this->socialUser($id, 'giulia@example.com'));
            $this->postJson('/api/auth/social/exchange', ['code' => $params['code'], 'code_verifier' => self::VERIFIER])
                ->assertOk()
                ->assertJsonPath('user.id', $existing->id);
        }

        // Secondo accesso con Google: riconosciuto dall'id anche se l'email è cambiata.
        $params = $this->loginVia('google', $this->socialUser('g-9', 'nuova@example.com'));
        $this->postJson('/api/auth/social/exchange', ['code' => $params['code'], 'code_verifier' => self::VERIFIER])
            ->assertJsonPath('user.id', $existing->id);

        $this->assertSame(1, User::count());
        $this->assertSame(2, $existing->socialAccounts()->count());
    }

    public function test_code_requires_matching_verifier_and_is_single_use(): void
    {
        $params = $this->loginVia('google', $this->socialUser('g-1', 'a@example.com'));

        $this->postJson('/api/auth/social/exchange', [
            'code' => $params['code'],
            'code_verifier' => str_repeat('x', 43),
        ])->assertJsonValidationErrors('code');

        // Il codice è stato consumato dal tentativo precedente.
        $this->postJson('/api/auth/social/exchange', ['code' => $params['code'], 'code_verifier' => self::VERIFIER])
            ->assertJsonValidationErrors('code');
    }

    public function test_provider_without_email_is_rejected(): void
    {
        $params = $this->loginVia('amazon', $this->socialUser('amzn1.account.1', null));

        $this->assertArrayNotHasKey('code', $params);
        $this->assertStringContainsString('email', $params['error']);
        $this->assertSame(0, User::count());
    }

    public function test_invalid_state_and_cancel_return_error_to_app(): void
    {
        $this->mockProvider('google');

        $this->assertArrayHasKey('error', $this->hitCallback('google', 'stato-inventato'));

        $this->get('/auth/google/redirect?code_challenge='.$this->challenge());
        $this->assertSame('Accesso annullato.', $this->hitCallback('google', $this->state, ['error' => 'access_denied'])['error']);
    }

    public function test_disabled_provider_is_hidden_and_not_found(): void
    {
        config(['services.amazon.client_id' => null]);

        $this->getJson('/api/config')->assertJsonPath('social_providers', ['google']);
        $this->get('/auth/amazon/redirect?code_challenge='.$this->challenge())->assertNotFound();
    }

    public function test_facebook_login_is_no_longer_available(): void
    {
        config(['services.facebook.client_id' => 'id', 'services.facebook.client_secret' => 'secret']);

        $this->getJson('/api/config')->assertJsonPath('social_providers', ['google', 'amazon']);
        $this->get('/auth/facebook/redirect?code_challenge='.$this->challenge())->assertNotFound();
    }

    public function test_password_login_for_social_only_account_explains_how_to_sign_in(): void
    {
        $this->loginVia('google', $this->socialUser('g-1', 'a@example.com'));

        $this->postJson('/api/login', ['email' => 'a@example.com', 'password' => 'qualcosa'])
            ->assertJsonValidationErrors(['email' => 'Google']);
    }

    // ── Helpers ─────────────────────────────────────────────────────

    /**
     * redirect → callback; restituisce i parametri con cui il server riapre l'app.
     *
     * @return array<string, string>
     */
    private function loginVia(string $provider, SocialiteUser $user): array
    {
        $this->mockProvider($provider, $user);

        $this->get("/auth/$provider/redirect?code_challenge=".$this->challenge())
            ->assertRedirect("https://$provider.example/oauth");

        return $this->hitCallback($provider, $this->state);
    }

    /**
     * @param  array<string, string>  $extra
     * @return array<string, string>
     */
    private function hitCallback(string $provider, ?string $state, array $extra = []): array
    {
        $location = $this->get("/auth/$provider/callback?".http_build_query(['state' => $state, 'code' => 'x'] + $extra))
            ->assertRedirect()
            ->headers->get('Location');

        $this->assertStringStartsWith('listaspesafacile://auth?', $location);
        parse_str((string) parse_url($location, PHP_URL_QUERY), $params);

        return $params;
    }

    private function mockProvider(string $name, ?SocialiteUser $user = null): void
    {
        $provider = Mockery::mock();
        $provider->shouldReceive('stateless')->andReturnSelf();
        $provider->shouldReceive('scopes')->andReturnSelf();
        $provider->shouldReceive('with')->andReturnUsing(function (array $params) use ($provider) {
            $this->state = $params['state'];

            return $provider;
        });
        $provider->shouldReceive('redirect')->andReturn(new RedirectResponse("https://$name.example/oauth"));
        if ($user) {
            $provider->shouldReceive('user')->andReturn($user);
        }
        Socialite::shouldReceive('driver')->with($name)->andReturn($provider);
    }

    private function socialUser(string $id, ?string $email): SocialiteUser
    {
        return (new SocialiteUser)->map(['id' => $id, 'email' => $email, 'name' => 'Giulia Verdi']);
    }

    private function challenge(): string
    {
        return rtrim(strtr(base64_encode(hash('sha256', self::VERIFIER, true)), '+/', '-_'), '=');
    }
}
