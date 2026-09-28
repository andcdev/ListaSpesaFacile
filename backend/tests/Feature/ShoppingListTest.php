<?php

namespace Tests\Feature;

use App\Events\ListItemDeleted;
use App\Events\ListItemSaved;
use App\Events\ListsChanged;
use App\Events\ShoppingListDeleted;
use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ShoppingListTest extends TestCase
{
    use RefreshDatabase;

    public function test_lists_are_ordered_by_date_and_time(): void
    {
        $user = User::factory()->create();
        ShoppingList::factory()->for($user, 'owner')->create(['name' => 'C', 'scheduled_at' => '2026-10-02 09:00:00']);
        ShoppingList::factory()->for($user, 'owner')->create(['name' => 'A', 'scheduled_at' => '2026-10-01 18:30:00']);
        ShoppingList::factory()->for($user, 'owner')->create(['name' => 'B', 'scheduled_at' => '2026-10-01 20:00:00']);
        ShoppingList::factory()->create(['name' => 'altrui']);

        Sanctum::actingAs($user);

        $this->getJson('/api/lists')
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.*.name', ['A', 'B', 'C']);
    }

    public function test_create_update_delete_list(): void
    {
        Event::fake();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $id = $this->postJson('/api/lists', [
            'name' => 'Spesa sabato',
            'scheduled_at' => '2026-10-03T10:30:00+02:00',
        ])->assertCreated()
            ->assertJsonPath('data.permission', 'owner')
            ->assertJsonPath('data.scheduled_at', '2026-10-03T08:30:00+00:00')
            ->json('data.id');

        $this->patchJson("/api/lists/{$id}", ['name' => 'Spesa domenica'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Spesa domenica');

        $this->deleteJson("/api/lists/{$id}")->assertNoContent();
        $this->assertDatabaseMissing('shopping_lists', ['id' => $id]);

        Event::assertDispatched(ShoppingListDeleted::class);
        Event::assertDispatched(ListsChanged::class, fn (ListsChanged $e) => $e->userIds === [$user->id]);
    }

    public function test_items_crud_broadcasts_events(): void
    {
        Event::fake([ListItemSaved::class, ListItemDeleted::class, ListsChanged::class]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $itemId = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte', 'quantity' => '2 l'])
            ->assertCreated()
            ->assertJsonPath('data.created_by', $list->owner->name)
            ->json('data.id');

        $this->patchJson("/api/lists/{$list->id}/items/{$itemId}", ['checked' => true])
            ->assertOk()
            ->assertJsonPath('data.checked', true)
            ->assertJsonPath('data.checked_by', $list->owner->name);

        $this->deleteJson("/api/lists/{$list->id}/items/checked")->assertOk()->assertJsonPath('deleted', 1);

        Event::assertDispatchedTimes(ListItemSaved::class, 2);
        Event::assertDispatched(ListItemDeleted::class, fn ($e) => $e->itemIds === [$itemId]);
    }

    public function test_item_of_another_list_is_not_reachable(): void
    {
        $list = ShoppingList::factory()->create();
        $foreign = ListItem::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->patchJson("/api/lists/{$list->id}/items/{$foreign->id}", ['checked' => true])->assertNotFound();
    }

    public function test_stranger_cannot_access_list(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/lists/{$list->id}")->assertForbidden();
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'X'])->assertForbidden();
        $this->deleteJson("/api/lists/{$list->id}")->assertForbidden();
    }

    public function test_write_succeeds_even_if_websocket_server_is_down(): void
    {
        config(['broadcasting.default' => 'reverb', 'broadcasting.connections.reverb' => [
            'driver' => 'reverb', 'key' => 'k', 'secret' => 's', 'app_id' => '1',
            'options' => ['host' => '127.0.0.1', 'port' => 1, 'scheme' => 'http'],
        ]]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->assertCreated();
        $this->assertDatabaseHas('list_items', ['shopping_list_id' => $list->id, 'name' => 'Latte']);
    }

    public function test_items_get_category_icon_and_weight(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $id = $this->postJson("/api/lists/{$list->id}/items", [
            'name' => 'Parmigiano',
            'quantity' => '2',
            'amount' => 300,
            'unit' => 'g',
        ])->assertCreated()
            ->assertJsonPath('data.category', 'latticini')
            ->assertJsonPath('data.icon', '🧀')
            ->assertJsonPath('data.quantity', '2')
            ->assertJsonPath('data.amount', 300)
            ->assertJsonPath('data.unit', 'g')
            ->json('data.id');

        // Reparto scelto a mano: icona del reparto.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['category' => 'dispensa'])
            ->assertJsonPath('data.category', 'dispensa')
            ->assertJsonPath('data.icon', '🥫');

        // Nuovo nome: reparto e icona riconosciuti di nuovo. Peso tolto: via anche l'unità.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Birra', 'amount' => null])
            ->assertJsonPath('data.category', 'bevande')
            ->assertJsonPath('data.icon', '🍺')
            ->assertJsonPath('data.amount', null)
            ->assertJsonPath('data.unit', null);

        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['amount' => '1.5', 'unit' => 'l'])
            ->assertJsonPath('data.amount', 1.5)
            ->assertJsonPath('data.unit', 'l');
    }

    public function test_invalid_weight_is_rejected(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Farina', 'amount' => 500])
            ->assertJsonValidationErrors('unit');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Farina', 'amount' => -1, 'unit' => 'kg'])
            ->assertJsonValidationErrors('amount');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Farina', 'amount' => 1, 'unit' => 'etti'])
            ->assertJsonValidationErrors('unit');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Farina', 'category' => 'boh'])
            ->assertJsonValidationErrors('category');
    }

    public function test_config_lists_categories_and_units(): void
    {
        $this->getJson('/api/config')
            ->assertJsonPath('product_categories.0', ['slug' => 'frutta', 'label' => 'Frutta', 'icon' => '🍎'])
            ->assertJsonPath('units', ['g', 'hg', 'kg', 'ml', 'cl', 'l']);
    }
}
