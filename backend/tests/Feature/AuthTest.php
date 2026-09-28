<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
        ]);

        $response->assertCreated()->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);

        $this->withToken($response->json('token'))
            ->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'mario@example.com');
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
