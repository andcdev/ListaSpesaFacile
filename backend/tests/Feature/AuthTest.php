<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_receives_token(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Mario',
            'email' => 'mario@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'privacy' => true,
        ]);

        $response->assertCreated()->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);

        $this->withToken($response->json('token'))
            ->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'mario@example.com')
            ->assertJsonPath('data.newsletter', false);
        $user = User::firstWhere('email', 'mario@example.com');
        $this->assertNotNull($user->privacy_accepted_at);
        $this->assertNull($user->newsletter_consented_at);
    }

    public function test_registration_requires_privacy_and_a_valid_email(): void
    {
        $data = ['name' => 'Mario', 'password' => 'password123', 'password_confirmation' => 'password123'];

        $this->postJson('/api/register', [...$data, 'email' => 'mario@example.com'])->assertJsonValidationErrors('privacy');
        $this->postJson('/api/register', [...$data, 'email' => 'mario@example.com', 'privacy' => false])->assertJsonValidationErrors('privacy');
        foreach (['mario', 'mario@', 'mario@localhost', 'mario@@example.com', 'ma rio@example.com', 'mario@example.c', 'mario..rossi@example.com'] as $email) {
            $this->postJson('/api/register', [...$data, 'email' => $email, 'privacy' => true])->assertJsonValidationErrors('email');
        }
        $this->assertDatabaseCount('users', 0);
    }

    public function test_newsletter_consent_at_registration_and_from_the_profile(): void
    {
        $token = $this->postJson('/api/register', [
            'name' => 'Anna', 'email' => 'anna@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123', 'privacy' => true, 'newsletter' => true,
        ])->assertCreated()->json('token');
        $anna = User::firstWhere('email', 'anna@example.com');
        $this->assertTrue($anna->newsletter);
        $this->assertNotNull($anna->newsletter_consented_at);

        $this->withToken($token)->patchJson('/api/me', ['newsletter' => false])->assertOk()->assertJsonPath('data.newsletter', false);
        $this->assertNull($anna->fresh()->newsletter_consented_at);
        $this->withToken($token)->patchJson('/api/me', ['newsletter' => true])->assertJsonPath('data.newsletter', true);

        // Il consenso degli altri non si vede.
        $list = ShoppingList::factory()->for($anna, 'owner')->create();
        $this->withToken($token)->getJson("/api/lists/{$list->id}")->assertJsonPath('data.owner.newsletter', true);
        $mario = User::factory()->create();
        $list->sharedWith()->attach($mario->id);
        $this->app['auth']->forgetGuards();
        Sanctum::actingAs($mario);
        $this->getJson("/api/lists/{$list->id}")->assertJsonMissingPath('data.owner.newsletter');
    }

    public function test_login_with_wrong_password_fails(): void
    {
        User::factory()->create(['email' => 'mario@example.com']);

        $this->postJson('/api/login', ['email' => 'mario@example.com', 'password' => 'sbagliata'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_login_and_logout(): void
    {
        User::factory()->create(['email' => 'mario@example.com']);

        $token = $this->postJson('/api/login', ['email' => 'mario@example.com', 'password' => 'password'])
            ->assertOk()
            ->json('token');

        $this->withToken($token)->postJson('/api/logout')->assertNoContent();
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }

    public function test_config_exposes_realtime_settings(): void
    {
        $this->getJson('/api/config')->assertOk()->assertJsonStructure(['realtime' => ['key', 'host', 'port', 'scheme']]);
    }
}
