<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ItemsAndImagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_item_can_be_taken_missing_or_back_to_todo(): void
    {
        $list = ShoppingList::factory()->create();
        $list->owner->update(['name' => 'Mario']);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])
            ->assertJsonPath('data.status', 'todo')
            ->json('data.id');

        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'missing'])
            ->assertJsonPath('data.status', 'missing')
            ->assertJsonPath('data.checked', false)
            ->assertJsonPath('data.checked_by', 'Mario');

        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'taken'])
            ->assertJsonPath('data.checked', true);

        // Le app che conoscono solo "checked" continuano a funzionare.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['checked' => false])
            ->assertJsonPath('data.status', 'todo')
            ->assertJsonPath('data.checked_by', null);

        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'boh'])->assertJsonValidationErrors('status');
    }

    public function test_remove_taken_keeps_missing_items(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        foreach (['taken', 'missing', 'todo'] as $status) {
            $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => $status])->json('data.id');
            $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => $status]);
        }

        $this->deleteJson("/api/lists/{$list->id}/items/checked")->assertJsonPath('deleted', 1);
        $this->assertSame(['missing', 'todo'], $list->items()->orderBy('name')->pluck('name')->all());
    }

    public function test_custom_emoji_and_external_image(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $id = $this->postJson("/api/lists/{$list->id}/items", [
            'name' => 'Torta per Anna',
            'custom_icon' => '🎂',
            'image_url' => 'https://example.com/torta.jpg',
        ])->assertJsonPath('data.icon', '🎂')
            ->assertJsonPath('data.custom_icon', '🎂')
            ->assertJsonPath('data.image_url', 'https://example.com/torta.jpg')
            ->json('data.id');

        // Rinominando resta l'emoji scelta; togliendola torna quella riconosciuta.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte'])->assertJsonPath('data.icon', '🎂');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['custom_icon' => null, 'image_url' => null])
            ->assertJsonPath('data.icon', '🥛')
            ->assertJsonPath('data.image_url', null);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'X', 'image_url' => 'javascript:alert(1)'])
            ->assertJsonValidationErrors('image_url');
    }

    public function test_list_photo_upload_download_and_delete(): void
    {
        Storage::fake();
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id, ['can_edit' => false]);

        Sanctum::actingAs($anna);
        $this->post("/api/lists/{$list->id}/image", ['image' => $this->photo('foto.jpg')], ['Accept' => 'application/json'])
            ->assertForbidden();

        Sanctum::actingAs($list->owner);
        $version = $this->post("/api/lists/{$list->id}/image", ['image' => $this->photo('foto.jpg')], ['Accept' => 'application/json'])
            ->assertOk()
            ->json('data.image_version');
        $this->assertNotNull($version);
        $path = $list->fresh()->image_path;
        Storage::assertExists($path);

        // Una nuova foto sostituisce la precedente.
        $newVersion = $this->post("/api/lists/{$list->id}/image", ['image' => $this->photo('b.png')], ['Accept' => 'application/json'])
            ->json('data.image_version');
        $this->assertNotSame($version, $newVersion);
        Storage::assertMissing($path);

        Sanctum::actingAs($anna);
        $this->get("/api/lists/{$list->id}/image")->assertOk()->assertHeader('Cache-Control', 'max-age=31536000, private');

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/lists/{$list->id}/image")->assertForbidden();

        Sanctum::actingAs($list->owner);
        $this->post("/api/lists/{$list->id}/image", ['image' => UploadedFile::fake()->create('doc.pdf', 10, 'application/pdf')], ['Accept' => 'application/json'])
            ->assertJsonValidationErrors('image');

        $current = $list->fresh()->image_path;
        $this->deleteJson("/api/lists/{$list->id}/image")->assertOk()->assertJsonPath('data.image_version', null);
        Storage::assertMissing($current);
        $this->getJson("/api/lists/{$list->id}/image")->assertNotFound();
    }

    public function test_deleting_list_removes_its_photo(): void
    {
        Storage::fake();
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $this->post("/api/lists/{$list->id}/image", ['image' => $this->photo('foto.jpg')], ['Accept' => 'application/json']);
        $path = $list->fresh()->image_path;

        $this->deleteJson("/api/lists/{$list->id}")->assertNoContent();

        Storage::assertMissing($path);
    }
}
