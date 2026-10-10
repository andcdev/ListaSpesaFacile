<?php

namespace Tests\Feature;

use App\Models\ListMessage;
use App\Models\Report;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ImageRejected;
use App\Notifications\ReportReceived;
use App\Support\ModerationLinks;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Notifications\AnonymousNotifiable;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ModerationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake();
        Notification::fake();
        config([
            'services.moderation.url' => 'http://moderazione:8000',
            'mail.support.address' => 'support@listaspesafacile.com',
            'mail.support.cc' => 'andcecere@gmail.com',
        ]);
    }

    private function scores(float $sexual, float $violence): void
    {
        Http::fake(['moderazione:8000/controlla' => Http::response(['sexual' => $sexual, 'violence' => $violence])]);
    }

    public function test_rejected_chat_photo_is_quarantined_and_emailed_with_buttons(): void
    {
        $this->scores(0.97, 0.01);
        $list = ShoppingList::factory()->create();
        $user = User::factory()->create(['locale' => 'en']);
        $list->sharedWith()->attach($user->id);
        Sanctum::actingAs($user);

        $this->post("/api/lists/{$list->id}/messages", [
            'body' => 'guarda qui',
            'image' => $this->photo('foto.jpg'),
        ], ['Accept' => 'application/json'])->assertJsonValidationErrors('image');

        $this->assertSame(0, ListMessage::count());
        $report = Report::sole();
        $this->assertSame(['image', 'chat', 'guarda qui', $user->id], [$report->type, $report->context, $report->body, $report->reported_user_id]);
        Storage::assertExists($report->image_path);

        Notification::assertSentOnDemand(ImageRejected::class, function (ImageRejected $n, array $channels, AnonymousNotifiable $to) use ($report, $user) {
            $mail = $n->toMail($to);
            $html = (string) $mail->render();

            return $to->routes['mail'] === 'support@listaspesafacile.com'
                && $mail->cc === [['andcecere@gmail.com', null]]
                && str_contains($html, 'guarda qui')
                && str_contains($html, 'Guarda la foto')
                && str_contains($html, 'moderazione/foto/'.$report->id)
                && str_contains($html, 'moderazione/sospendi/'.$user->id)
                // Avviso già scritto nella lingua dell'utente.
                && str_contains($html, 'mailto:'.rawurlencode($user->email).'?subject='.rawurlencode('Notice from Lista Spesa Facile'));
        });
    }

    public function test_photos_below_thresholds_or_without_service_are_accepted(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->scores(0.1, 0.2);
        $this->post("/api/lists/{$list->id}/image", ['image' => $this->photo('a.jpg')], ['Accept' => 'application/json'])
            ->assertOk();

        // Servizio giù: la foto passa.
        Http::fake(['moderazione:8000/*' => Http::response(status: 500)]);
        $this->post('/api/me/avatar', ['image' => $this->photo('b.jpg')], ['Accept' => 'application/json'])
            ->assertOk();

        $this->assertSame(0, Report::count());
        Notification::assertNothingSent();
    }

    public function test_violent_product_photo_is_rejected(): void
    {
        $this->scores(0.02, 0.9);
        $list = ShoppingList::factory()->create();
        $item = $list->items()->create(['name' => 'Latte']);
        Sanctum::actingAs($list->owner);

        $this->post("/api/lists/{$list->id}/items/{$item->id}/image", ['image' => $this->photo('c.jpg')], ['Accept' => 'application/json'])
            ->assertJsonValidationErrors('image');
        $this->assertNull($item->fresh()->image_path);
        $this->assertSame('item', Report::sole()->context);
    }

    public function test_quarantined_image_needs_a_valid_signed_link(): void
    {
        $user = User::factory()->create();
        Storage::put('quarantena/x.jpg', 'foto');
        $report = new Report(['type' => 'image', 'context' => 'avatar', 'scores' => ['sexual' => 1, 'violence' => 0], 'image_path' => 'quarantena/x.jpg']);
        $report->user()->associate($user);
        $report->save();

        $this->get(ModerationLinks::image($report))->assertOk();
        $this->get("/moderazione/foto/{$report->id}")->assertForbidden();
    }

    public function test_suspend_asks_confirmation_then_blocks_every_login(): void
    {
        $user = User::factory()->create(['email' => 'mario@example.com', 'password' => 'password123']);
        $user->createToken('app');
        $url = ModerationLinks::suspend($user);

        // Aprire il link (come fanno i filtri antispam) non sospende.
        $this->get($url)->assertOk()->assertSee('Sospendi account');
        $this->assertFalse($user->fresh()->isSuspended());

        $this->withoutMiddleware(ValidateCsrfToken::class)
            ->post($url)->assertOk()->assertSee('Account sospeso');
        $this->assertTrue($user->fresh()->isSuspended());
        $this->assertSame(0, $user->tokens()->count());

        $this->postJson('/api/login', ['email' => 'mario@example.com', 'password' => 'password123'])
            ->assertForbidden()
            ->assertJsonPath('message', __('app.errors.account_suspended'));

        $this->withoutMiddleware(ValidateCsrfToken::class)
            ->post(ModerationLinks::reactivate($user))->assertOk();
        $this->postJson('/api/login', ['email' => 'mario@example.com', 'password' => 'password123'])->assertOk();
    }

    public function test_report_email_has_message_photo_and_suspend_button(): void
    {
        $list = ShoppingList::factory()->create();
        $me = User::factory()->create();
        $list->sharedWith()->attach($me->id);
        $message = new ListMessage(['body' => 'insulto']);
        $message->user()->associate($list->owner);
        $message->image_path = 'chat-images/'.$list->id.'/m.jpg';
        $list->messages()->save($message);
        Sanctum::actingAs($me);

        $this->postJson('/api/reports', ['type' => 'message', 'list_id' => $list->id, 'message_id' => $message->id])
            ->assertCreated();

        Notification::assertSentOnDemand(ReportReceived::class, function (ReportReceived $n, array $channels, AnonymousNotifiable $to) use ($list) {
            $html = (string) $n->toMail($to)->render();

            return str_contains($html, 'insulto')
                && str_contains($html, 'Guarda la foto')
                && str_contains($html, 'moderazione/sospendi/'.$list->owner_id)
                && str_contains($html, 'mailto:');
        });
    }
}
