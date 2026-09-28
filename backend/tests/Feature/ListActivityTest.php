<?php

namespace Tests\Feature;

use App\Events\NotificationCreated;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListActivity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ListActivityTest extends TestCase
{
    use RefreshDatabase;

    public function test_changes_notify_the_other_members_only(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $list->owner->update(['name' => 'Mario']);
        $anna = User::factory()->create(['name' => 'Anna']);
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->json('data.id');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'taken']);
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['position' => 5]); // solo riordino: nessun avviso
        $this->deleteJson("/api/lists/{$list->id}/items/{$id}");

        $actions = [];
        Notification::assertSentTo($anna, ListActivity::class, function (ListActivity $n) use (&$actions, $list) {
            $actions[] = $n->body();

            return $n->listId() === $list->id && $n->title() === 'Spesa' && $n->sender() === 'Mario';
        });
        $this->assertSame(['Mario ha aggiunto 🥛 Latte', 'Mario ha preso 🥛 Latte', 'Mario ha eliminato 🥛 Latte'], $actions);
        Notification::assertNotSentTo($list->owner, ListActivity::class);
    }

    public function test_activity_reaches_the_open_app_but_not_the_notification_list(): void
    {
        Event::fake([NotificationCreated::class]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertCreated();

        Event::assertDispatched(NotificationCreated::class, fn (NotificationCreated $e) => $e->userId === $anna->id
            && $e->notification['kind'] === 'list_activity'
            && $e->notification['stored'] === false
            && $e->notification['list_id'] === $list->id);
        $this->assertDatabaseCount('notifications', 0);
    }

    public function test_rename_needs_the_owner_permission(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id, ['can_edit' => true]);
        $when = now()->addDay()->toIso8601String();

        Sanctum::actingAs($anna);
        $this->getJson("/api/lists/{$list->id}")
            ->assertJsonPath('data.members_can_rename', false)
            ->assertJsonPath('data.can_rename', false);
        $this->patchJson("/api/lists/{$list->id}", ['name' => 'Altro', 'scheduled_at' => $when])
            ->assertJsonValidationErrors('name');
        // Le altre modifiche sono permesse (anche rimandando lo stesso nome).
        $this->patchJson("/api/lists/{$list->id}", ['name' => 'Spesa', 'notes' => 'Coop'])->assertOk();
        $this->patchJson("/api/lists/{$list->id}", ['members_can_rename' => true])->assertForbidden();

        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}", ['members_can_rename' => true])
            ->assertJsonPath('data.members_can_rename', true);

        Sanctum::actingAs($anna);
        $this->patchJson("/api/lists/{$list->id}", ['name' => 'Spesa grande'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Spesa grande')
            ->assertJsonPath('data.can_rename', true);

        Notification::assertSentTo($list->owner, ListActivity::class, fn (ListActivity $n) => str_contains($n->body(), 'ha rinominato «Spesa» in «Spesa grande»'));
    }

    public function test_owner_can_allow_renaming_at_creation(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/lists', [
            'name' => 'Festa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'members_can_rename' => true,
        ])->assertCreated()->assertJsonPath('data.members_can_rename', true);

        $this->postJson('/api/lists', ['name' => 'Spesa', 'scheduled_at' => now()->addDay()->toIso8601String()])
            ->assertJsonPath('data.members_can_rename', false);
    }
}
