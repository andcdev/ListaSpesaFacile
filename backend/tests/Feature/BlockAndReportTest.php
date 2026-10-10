<?php

namespace Tests\Feature;

use App\Models\ListMessage;
use App\Models\Report;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ChatMessageReceived;
use App\Notifications\ReportReceived;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Notifications\AnonymousNotifiable;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BlockAndReportTest extends TestCase
{
    use RefreshDatabase;

    public function test_blocking_removes_shares_both_ways_and_prevents_new_ones(): void
    {
        $me = User::factory()->create();
        $other = User::factory()->create(['email' => 'other@example.com']);
        $mine = ShoppingList::factory()->for($me, 'owner')->create();
        $theirs = ShoppingList::factory()->for($other, 'owner')->create();
        $mine->sharedWith()->attach($other->id);
        $theirs->sharedWith()->attach($me->id);
        $other->globalShareRecipients()->attach($me->id);
        Sanctum::actingAs($me);

        $this->postJson('/api/blocks', ['user_id' => $other->id])->assertOk()->assertJsonPath('data.0.id', $other->id);
        $this->getJson('/api/me')->assertJsonPath('data.blocked_ids', [$other->id]);

        $this->assertFalse($mine->sharedWith()->whereKey($other->id)->exists());
        $this->getJson("/api/lists/{$theirs->id}")->assertForbidden();
        $this->postJson("/api/lists/{$mine->id}/shares", ['email' => 'other@example.com'])
            ->assertJsonValidationErrors('email');
        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'shares' => [['email' => 'other@example.com']],
        ])->assertJsonValidationErrors('shares.0.email');

        // Neanche chi è stato bloccato può condividere, e non gli si dice perché.
        Sanctum::actingAs($other);
        $this->postJson('/api/global-shares', ['email' => $me->email])
            ->assertJsonValidationErrors(['email' => __('app.errors.share_blocked')]);

        Sanctum::actingAs($me);
        $this->deleteJson("/api/blocks/{$other->id}")->assertNoContent();
        $this->getJson('/api/blocks')->assertJsonCount(0, 'data');
        $this->postJson("/api/lists/{$mine->id}/shares", ['email' => 'other@example.com'])->assertOk();
    }

    public function test_blocked_user_messages_are_hidden_and_do_not_notify(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create();
        $me = User::factory()->create();
        $other = User::factory()->create();
        $list->sharedWith()->attach([$me->id, $other->id]);
        $me->blockedUsers()->attach($other->id);

        Sanctum::actingAs($other);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'ciao'])->assertCreated();
        Notification::assertSentTo($list->owner, ChatMessageReceived::class);
        Notification::assertNotSentTo($me, ChatMessageReceived::class);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'eccomi'])->assertCreated();

        Sanctum::actingAs($me);
        $this->getJson("/api/lists/{$list->id}/messages")->assertJsonCount(1, 'data')->assertJsonPath('data.0.body', 'eccomi');
    }

    public function test_report_is_emailed_to_support_with_cc(): void
    {
        Notification::fake();
        config(['mail.support.address' => 'support@listaspesafacile.com', 'mail.support.cc' => 'copia@example.com']);
        $list = ShoppingList::factory()->create();
        $me = User::factory()->create();
        $list->sharedWith()->attach($me->id);
        $message = new ListMessage(['body' => 'messaggio brutto']);
        $message->user()->associate($list->owner);
        $list->messages()->save($message);
        Sanctum::actingAs($me);

        $this->postJson('/api/reports', ['type' => 'problem'])->assertJsonValidationErrors('body');
        $this->postJson('/api/reports', [
            'type' => 'message',
            'list_id' => $list->id,
            'message_id' => $message->id,
            'body' => 'Offensivo',
            'app_version' => '1.0.4',
        ])->assertCreated();

        $report = Report::sole();
        $this->assertSame($list->owner_id, $report->reported_user_id);
        $this->assertSame('messaggio brutto', $report->message_body);
        Notification::assertSentOnDemand(ReportReceived::class, function (ReportReceived $n, array $channels, AnonymousNotifiable $to) use ($me) {
            $mail = $n->toMail($to);

            return $to->routes['mail'] === 'support@listaspesafacile.com'
                && $mail->cc === [['copia@example.com', null]]
                && $mail->replyTo === [[$me->email, $me->name]]
                && str_contains((string) $mail->render(), 'messaggio brutto');
        });
    }

    public function test_cannot_report_message_of_a_list_you_cannot_see(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create();
        $message = new ListMessage(['body' => 'x']);
        $message->user()->associate($list->owner);
        $list->messages()->save($message);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/reports', ['type' => 'message', 'list_id' => $list->id, 'message_id' => $message->id])
            ->assertForbidden();
        Notification::assertNothingSent();
    }
}
