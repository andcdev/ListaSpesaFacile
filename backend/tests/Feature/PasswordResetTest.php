<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private function requestCode(User $user): string
    {
        $code = null;
        $this->postJson('/api/forgot-password', ['email' => strtoupper($user->email)])->assertOk();
        Notification::assertSentTo($user, PasswordResetCode::class, function (PasswordResetCode $n) use (&$code) {
            $code = $n->code;

            return true;
        });

        return $code;
    }

    public function test_code_resets_password_and_signs_in(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'anna@example.com', 'password' => 'vecchia-password']);
        $oldToken = $user->createToken('telefono-vecchio');
        $code = $this->requestCode($user);
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);

        $this->postJson('/api/reset-password', [
            'email' => 'anna@example.com',
            'code' => $code,
            'password' => 'nuova-password',
            'password_confirmation' => 'nuova-password',
        ])->assertOk()->assertJsonStructure(['token', 'user' => ['id', 'email']]);

        $this->assertTrue(Hash::check('nuova-password', $user->fresh()->password));
        // Le altre sessioni vengono chiuse e il codice non si può riusare.
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $oldToken->accessToken->id]);
        $this->postJson('/api/login', ['email' => 'anna@example.com', 'password' => 'nuova-password'])->assertOk();
        $this->postJson('/api/reset-password', [
            'email' => 'anna@example.com',
            'code' => $code,
            'password' => 'altra-password',
            'password_confirmation' => 'altra-password',
        ])->assertJsonValidationErrors('code');
    }

    public function test_unknown_email_gets_the_same_answer(): void
    {
        Notification::fake();

        $this->postJson('/api/forgot-password', ['email' => 'nessuno@example.com'])
            ->assertOk()
            ->assertJsonStructure(['message']);

        Notification::assertNothingSent();
    }

    public function test_wrong_or_expired_code_is_rejected_and_attempts_are_limited(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'bruno@example.com']);
        $code = $this->requestCode($user);
        $wrong = $code === '000000' ? '111111' : '000000';
        $payload = ['email' => 'bruno@example.com', 'password' => 'nuova-password', 'password_confirmation' => 'nuova-password'];

        foreach (range(1, 5) as $_) {
            $this->postJson('/api/reset-password', [...$payload, 'code' => $wrong])->assertJsonValidationErrors('code');
        }
        // Dopo 5 errori anche il codice giusto non vale più.
        $this->postJson('/api/reset-password', [...$payload, 'code' => $code])->assertJsonValidationErrors('code');

        $code = $this->requestCode($user);
        $this->travel(31)->minutes();
        $this->postJson('/api/reset-password', [...$payload, 'code' => $code])->assertJsonValidationErrors('code');
    }

    public function test_social_only_account_can_set_a_password(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'carla@example.com', 'password' => null]);
        $code = $this->requestCode($user);

        $this->postJson('/api/reset-password', [
            'email' => 'carla@example.com',
            'code' => $code,
            'password' => 'password-nuova',
            'password_confirmation' => 'password-nuova',
        ])->assertOk();

        $this->postJson('/api/login', ['email' => 'carla@example.com', 'password' => 'password-nuova'])->assertOk();
    }
}
