<?php

namespace Tests\Feature;

use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CopyListTest extends TestCase
{
    use RefreshDatabase;

    public function test_copy_gets_items_and_photos_with_new_date_and_name(): void
    {
        Storage::fake();
        $source = ShoppingList::factory()->create(['name' => 'Spesa sabato']);
        $source->image_path = 'list-images/'.$source->id.'-abc.jpg';
        $source->save();
        Storage::put($source->image_path, 'lista');
        $member = User::factory()->create();
        $source->sharedWith()->attach($member->id, ['can_edit' => false]);

        $milk = new ListItem(['name' => 'Latte', 'quantity' => '2', 'amount' => 1, 'unit' => 'l', 'custom_icon' => '🐄']);
        $milk->status = 'taken';
        $milk->image_path = ListItem::IMAGE_DIR.'/'.$source->id.'/latte.jpg';
        $source->items()->save($milk);
        Storage::put($milk->image_path, 'foto');
        $source->items()->save(new ListItem(['name' => 'Pane', 'category' => 'altro']));

        // Anche chi ha la lista in sola lettura può copiarla: la copia è sua.
        Sanctum::actingAs($member);
        $response = $this->postJson('/api/lists', [
            'copy_from' => $source->id,
            'name' => 'Spesa domenica',
            'scheduled_at' => now()->addDays(2)->toIso8601String(),
            'supermarket' => 'Coop',
        ])->assertCreated()
            ->assertJsonPath('data.name', 'Spesa domenica')
            ->assertJsonPath('data.permission', 'owner')
            ->assertJsonCount(2, 'data.items');

        $copy = ShoppingList::findOrFail($response->json('data.id'));
        $this->assertSame('Coop', $copy->supermarket);
        $this->assertNotSame($source->image_path, $copy->image_path);
        Storage::assertExists($copy->image_path);

        $copiedMilk = $copy->items()->where('name', 'Latte')->sole();
        $this->assertSame('todo', $copiedMilk->status);
        $this->assertSame('2', $copiedMilk->quantity);
        $this->assertSame('l', $copiedMilk->unit);
        $this->assertSame('🐄', $copiedMilk->custom_icon);
        $this->assertSame($member->id, $copiedMilk->created_by);
        $this->assertStringStartsWith(ListItem::IMAGE_DIR.'/'.$copy->id.'/', $copiedMilk->image_path);
        Storage::assertExists($copiedMilk->image_path);
        $this->assertSame('altro', $copy->items()->where('name', 'Pane')->sole()->category);

        // L'originale resta com'era; eliminando la copia le sue foto se ne vanno, quelle dell'originale no.
        $this->assertSame(2, $source->items()->count());
        $this->deleteJson("/api/lists/{$copy->id}")->assertNoContent();
        Storage::assertMissing($copiedMilk->image_path);
        Storage::assertExists($milk->image_path);
        Storage::assertExists($source->image_path);
    }

    public function test_cannot_copy_a_list_you_cannot_see(): void
    {
        $source = ShoppingList::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/lists', [
            'copy_from' => $source->id,
            'name' => 'Mia',
            'scheduled_at' => now()->addDay()->toIso8601String(),
        ])->assertForbidden();
        $this->assertSame(1, ShoppingList::count());
    }
}
