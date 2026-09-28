<?php

namespace Tests\Feature;

use App\Events\NotificationCreated;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\GlobalShareReceived;
use App\Notifications\ListCreated;
use App\Notifications\ListDeleted;
use App\Notifications\ListShared;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationsTest extends TestCase
{
    use RefreshDatabase;

    public function test_list_created_with_shares_and_reminder(): void
    {
        Notification::fake();
        $owner = User::factory()->create(['name' => 'Mario']);
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $luca = User::factory()->create(['email' => 'luca@example.com']);
        $family = User::factory()->create();
        $owner->globalShareRecipients()->attach([$family->id, $anna->id]);
        Sanctum::actingAs($owner);

        $id = $this->postJson('/api/lists', [
            'name' => 'Spesa sabato',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'reminder_minutes' => 60,
            'reminder_target' => 'members',
            'shares' => [
                ['email' => 'anna@example.com'],
                ['email' => 'LUCA@example.com', 'can_edit' => false],
            ],
        ])->assertCreated()
            ->assertJsonPath('data.reminder_minutes', 60)
            ->assertJsonPath('data.reminder_target', 'members')
            ->assertJsonCount(2, 'data.shared_with')
            ->json('data.id');

        Notification::assertSentTo($anna, ListShared::class, fn (ListShared $n) => $n->canEdit && $n->sharedListId === $id);
        Notification::assertSentTo($luca, ListShared::class, fn (ListShared $n) => ! $n->canEdit);
        // Chi riceve tutte le liste viene avvisato della nuova lista, ma Anna una volta sola.
        Notification::assertSentTo($family, ListCreated::class);
        Notification::assertNotSentTo($anna, ListCreated::class);
        Notification::assertNothingSentTo($owner);
    }

    public function test_unknown_recipient_blocks_creation(): void
    {
        $owner = User::factory()->create();
        Sanctum::actingAs($owner);

        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'shares' => [['email' => 'nessuno@example.com']],
        ])->assertJsonValidationErrors('shares.0.email');

        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'shares' => [['email' => $owner->email]],
        ])->assertJsonValidationErrors('shares.0.email');

        $this->assertDatabaseCount('shopping_lists', 0);
    }

    public function test_share_notifies_only_the_first_time(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com', 'can_edit' => false])->assertOk();
        $this->postJson('/api/global-shares', ['email' => 'anna@example.com'])->assertOk();
        $this->postJson('/api/global-shares', ['email' => 'anna@example.com', 'can_edit' => false])->assertOk();

        Notification::assertSentToTimes($anna, ListShared::class, 1);
        Notification::assertSentToTimes($anna, GlobalShareReceived::class, 1);
    }

    public function test_delete_notifies_members_but_not_owner(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);
        Sanctum::actingAs($list->owner);

        $this->deleteJson("/api/lists/{$list->id}")->assertNoContent();

        Notification::assertSentTo($anna, ListDeleted::class, fn (ListDeleted $n) => $n->listName === 'Spesa');
        Notification::assertNothingSentTo($list->owner);
    }

    public function test_notifications_are_stored_broadcast_and_marked_read(): void
    {
        Event::fake([NotificationCreated::class]);
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $list->owner->update(['name' => 'Mario']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();
        $this->travel(1)->seconds(); // l'elenco è ordinato per data di creazione
        $this->postJson('/api/global-shares', ['email' => 'anna@example.com'])->assertOk();

        Event::assertDispatched(
            NotificationCreated::class,
            fn (NotificationCreated $e) => $e->userId === $anna->id
                && $e->notification['kind'] === 'list_shared'
                && $e->notification['list_id'] === $list->id
                && $e->unreadCount === 1,
        );

        Sanctum::actingAs($anna);
        $response = $this->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonPath('unread_count', 2)
            ->assertJsonPath('data.0.kind', 'global_share')
            ->assertJsonPath('data.1.kind', 'list_shared')
            ->assertJsonPath('data.1.title', 'Mario ha condiviso con te «Spesa»')
            ->assertJsonPath('data.1.read', false);

        $this->postJson('/api/notifications/read', ['ids' => [$response->json('data.1.id')]])
            ->assertJsonPath('unread_count', 1);
        $this->postJson('/api/notifications/read')->assertJsonPath('unread_count', 0);
        $this->getJson('/api/notifications')->assertJsonPath('data.0.read', true);

        $this->deleteJson('/api/notifications')->assertNoContent();
        $this->getJson('/api/notifications')->assertJsonCount(0, 'data');
    }

    public function test_notifications_are_private(): void
    {
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/notifications')->assertJsonCount(0, 'data')->assertJsonPath('unread_count', 0);
        $this->postJson('/api/notifications/read')->assertOk();

        Sanctum::actingAs($anna);
        $this->getJson('/api/notifications')->assertJsonPath('unread_count', 1);
    }
}
