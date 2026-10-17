<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListActivity;
use App\Notifications\ShoppingAssigned;
use App\Notifications\ShoppingFinished;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Chi fa la spesa, "Spesa finita" e "Continuo io".
 */
class ShoppingRunTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array{0: ShoppingList, 1: User}
     */
    private function sharedList(): array
    {
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $list->owner->update(['name' => 'Mario']);
        $giulia = User::factory()->create(['name' => 'Giulia']);
        $list->sharedWith()->attach($giulia->id, ['can_edit' => true]);

        return [$list, $giulia];
    }

    public function test_the_shopper_is_chosen_at_creation_and_notified(): void
    {
        Notification::fake();
        $owner = User::factory()->create(['name' => 'Mario']);
        $giulia = User::factory()->create(['name' => 'Giulia', 'email' => 'giulia@example.com']);

        Sanctum::actingAs($owner);
        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'shares' => [['email' => 'giulia@example.com']],
            'shopper_email' => 'Giulia@example.com',
        ])->assertCreated()
            ->assertJsonPath('data.shopper.id', $giulia->id)
            ->assertJsonPath('data.shopper.name', 'Giulia')
            ->assertJsonCount(2, 'data.people');

        Notification::assertSentTo($giulia, ShoppingAssigned::class);
    }

    public function test_the_shopper_must_be_on_the_list(): void
    {
        $owner = User::factory()->create();
        User::factory()->create(['email' => 'altro@example.com']);

        Sanctum::actingAs($owner);
        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => now()->addDay()->toIso8601String(),
            'shopper_email' => 'altro@example.com',
        ])->assertJsonValidationErrors('shopper_email');
        $this->assertDatabaseCount('shopping_lists', 0);
    }

    public function test_only_the_shopper_marks_products_but_others_can_still_edit(): void
    {
        [$list, $giulia] = $this->sharedList();
        $item = $list->items()->create(['name' => 'Latte']);

        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}", ['shopper_id' => $giulia->id])
            ->assertOk()->assertJsonPath('data.shopper.id', $giulia->id);

        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'taken'])
            ->assertForbidden()->assertJsonPath('message', fn ($m) => str_contains($m, 'Giulia'));
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['name' => 'Latte intero'])->assertOk();

        Sanctum::actingAs($giulia);
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'taken'])->assertOk();

        // Senza nessuno scelto torna a segnare chiunque possa modificare.
        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}", ['shopper_id' => null])->assertOk()->assertJsonPath('data.shopper', null);
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'todo'])->assertOk();
    }

    public function test_a_shopper_removed_from_the_list_no_longer_blocks_the_others(): void
    {
        [$list, $giulia] = $this->sharedList();
        $list->forceFill(['shopper_id' => $giulia->id])->save();
        $item = $list->items()->create(['name' => 'Pane']);
        $list->sharedWith()->detach($giulia->id);

        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'taken'])->assertOk();
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.shopper', null);
    }

    public function test_finishing_with_missing_products_notifies_the_others_and_puts_them_back_to_buy(): void
    {
        Notification::fake();
        [$list, $giulia] = $this->sharedList();
        $list->forceFill(['shopper_id' => $giulia->id])->save();
        $list->items()->create(['name' => 'Mele', 'status' => 'taken', 'checked' => true]);
        $pane = $list->items()->create(['name' => 'Pane', 'status' => 'missing', 'checked_by' => $giulia->id]);
        $list->items()->create(['name' => 'Latte']);

        Sanctum::actingAs($giulia);
        $this->postJson("/api/lists/{$list->id}/finish", ['message' => 'Il pane era finito'])
            ->assertOk()
            ->assertJsonPath('data.finished_by.name', 'Giulia')
            ->assertJsonPath('data.finish_message', 'Il pane era finito');

        $this->assertSame('todo', $pane->fresh()->status);
        $this->assertNull($pane->fresh()->checked_by);
        $this->assertDatabaseHas('list_messages', ['shopping_list_id' => $list->id, 'body' => 'Il pane era finito']);
        Notification::assertSentTo($list->owner, ShoppingFinished::class, fn (ShoppingFinished $n) => $n->title() === 'Giulia ha finito la spesa «Spesa»'
            && $n->body() === 'Mancano 2 prodotti: 🍞 Pane, 🥛 Latte. «Il pane era finito»');
        Notification::assertNotSentTo($giulia, ShoppingFinished::class);
    }

    public function test_finishing_everything_says_so(): void
    {
        Notification::fake();
        [$list] = $this->sharedList();
        $list->items()->create(['name' => 'Mele', 'status' => 'taken', 'checked' => true]);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/finish")->assertOk();

        Notification::assertSentTo(User::firstWhere('name', 'Giulia'), ShoppingFinished::class, fn (ShoppingFinished $n) => $n->body() === 'È stato preso tutto.');
    }

    public function test_alone_on_the_list_nobody_is_notified(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create();
        $list->items()->create(['name' => 'Mele']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/finish")->assertOk();

        Notification::assertNothingSent();
    }

    public function test_only_the_shopper_can_finish(): void
    {
        [$list, $giulia] = $this->sharedList();
        $list->forceFill(['shopper_id' => $giulia->id])->save();
        $list->items()->create(['name' => 'Mele']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/finish")->assertForbidden();
    }

    public function test_taking_over_moves_the_shopping_and_clears_the_finish(): void
    {
        Notification::fake();
        [$list, $giulia] = $this->sharedList();
        $list->forceFill(['shopper_id' => $giulia->id, 'finished_at' => now(), 'finished_by' => $giulia->id])->save();
        $item = $list->items()->create(['name' => 'Latte']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/take-over")
            ->assertOk()
            ->assertJsonPath('data.shopper.id', $list->owner_id)
            ->assertJsonPath('data.finished_at', null);
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'taken'])->assertOk();

        Notification::assertSentTo($giulia, ListActivity::class, fn (ListActivity $n) => $n->body() === 'Mario continua la spesa');
    }

    public function test_marking_again_after_finishing_clears_the_finish(): void
    {
        [$list] = $this->sharedList();
        $list->forceFill(['finished_at' => now(), 'finished_by' => $list->owner_id])->save();
        $item = $list->items()->create(['name' => 'Latte']);

        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}/items/{$item->id}", ['status' => 'taken'])->assertOk();

        $this->assertNull($list->fresh()->finished_at);
    }

    public function test_viewers_cannot_finish_or_take_over(): void
    {
        [$list] = $this->sharedList();
        $viewer = User::factory()->create();
        $list->sharedWith()->attach($viewer->id, ['can_edit' => false]);
        $list->items()->create(['name' => 'Mele']);

        Sanctum::actingAs($viewer);
        $this->postJson("/api/lists/{$list->id}/finish")->assertForbidden();
        $this->postJson("/api/lists/{$list->id}/take-over")->assertForbidden();
    }
}
