<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListActivity;
use App\Notifications\ListReminder;
use App\Notifications\PasswordResetCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LocalizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_messages_follow_the_app_language_and_it_is_remembered(): void
    {
        $this->withHeader('Accept-Language', 'en')
            ->postJson('/api/login', ['email' => 'nessuno@example.com', 'password' => 'x'])
            ->assertJsonValidationErrors(['email' => 'Invalid email or password.']);
        $this->withHeader('Accept-Language', 'fr-FR,fr;q=0.9')
            ->postJson('/api/register', [])
            ->assertJsonValidationErrors(['email' => 'Le champ e-mail est obligatoire.']);
        // Lingua non gestita: italiano.
        $this->withHeader('Accept-Language', 'pt-BR')
            ->postJson('/api/login', ['email' => 'nessuno@example.com', 'password' => 'x'])
            ->assertJsonValidationErrors(['email' => 'Credenziali non valide.']);

        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->withHeader('Accept-Language', 'de')->getJson('/api/me')->assertOk();
        $this->assertSame('de', $user->fresh()->locale);
    }

    public function test_notifications_are_written_in_the_recipient_language(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $list->owner->update(['name' => 'Mario']);
        $anna = User::factory()->create(['locale' => 'de']);
        $list->sharedWith()->attach($anna->id);

        // Mario usa l'app in italiano, Anna in tedesco: ognuno legge nella propria lingua.
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte']);

        Notification::assertSentTo($anna, ListActivity::class, function (ListActivity $n, array $channels, object $notifiable, string $locale) {
            $this->assertSame('de', $locale);
            app()->setLocale($locale);

            return $n->body() === 'Mario hat 🥛 Latte hinzugefügt';
        });
    }

    public function test_reminder_duration_and_mail_are_translated(): void
    {
        app()->setLocale('en');
        $this->assertSame('1 hour and 30 minutes', ListReminder::duration(90));
        $this->assertSame('Shopping starts in 2 days.', (new ListReminder(1, 'Party', 2880))->body());

        app()->setLocale('es');
        $mail = (new PasswordResetCode('123456', 30))->toMail(User::factory()->make(['name' => 'Ana']));
        $this->assertSame('Código para restablecer la contraseña', $mail->subject);
        $this->assertSame('Hola Ana:', $mail->greeting);
    }

    public function test_categories_suggestions_and_recognition_in_other_languages(): void
    {
        $this->withHeader('Accept-Language', 'es')->getJson('/api/config')
            ->assertJsonPath('product_categories.0.label', 'Fruta');

        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $suggestions = collect($this->withHeader('Accept-Language', 'fr')->getJson('/api/products/suggestions')->json('data'));
        $this->assertSame('🧻', $suggestions->firstWhere('name', 'Papier toilette')['icon']);
        $this->assertNull($suggestions->firstWhere('name', 'Carta igienica'));

        // Prodotti comuni scritti in un'altra lingua: reparto e icona come in italiano.
        foreach (['Milk' => '🥛', 'Pommes de terre' => '🥔', 'Hähnchenbrust 500g' => '🍗', 'Papel higiénico' => '🧻'] as $name => $icon) {
            $this->postJson("/api/lists/{$list->id}/items", ['name' => $name])->assertJsonPath('data.icon', $icon);
        }
    }
}
