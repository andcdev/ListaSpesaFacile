<?php

namespace Tests\Feature;

use App\Events\ListMessageCreated;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ChatMessageReceived;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PhotosTest extends TestCase
{
    use RefreshDatabase;

    public function test_product_photo_upload_download_and_delete(): void
    {
        Storage::fake();
        $list = ShoppingList::factory()->create();
        $viewer = User::factory()->create();
        $list->sharedWith()->attach($viewer->id, ['can_edit' => false]);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Biscotti'])
            ->assertJsonPath('data.image_version', null)
            ->json('data.id');

        $version = $this->post("/api/lists/{$list->id}/items/{$id}/image", [
            'image' => $this->photo('biscotti.jpg'),
        ], ['Accept' => 'application/json'])->assertOk()->json('data.image_version');
        $this->assertNotNull($version);
        $path = $list->items()->first()->image_path;
        $this->assertStringStartsWith("item-images/{$list->id}/", $path);
        Storage::assertExists($path);

        // Chi vede la lista scarica la foto, ma non può cambiarla.
        Sanctum::actingAs($viewer);
        $this->get("/api/lists/{$list->id}/items/{$id}/image?v=$version")->assertOk();
        $this->post("/api/lists/{$list->id}/items/{$id}/image", [
            'image' => $this->photo('x.jpg'),
        ], ['Accept' => 'application/json'])->assertForbidden();

        Sanctum::actingAs(User::factory()->create());
        $this->get("/api/lists/{$list->id}/items/{$id}/image")->assertForbidden();

        Sanctum::actingAs($list->owner);
        $this->deleteJson("/api/lists/{$list->id}/items/{$id}/image")->assertJsonPath('data.image_version', null);
        Storage::assertMissing($path);
    }

    public function test_deleting_items_and_lists_removes_their_photos(): void
    {
        Storage::fake();
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $paths = [];
        foreach (['Pane', 'Latte'] as $name) {
            $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => $name])->json('data.id');
            $this->post("/api/lists/{$list->id}/items/{$id}/image", ['image' => $this->photo('p.jpg')]);
            $paths[$name] = $list->items()->find($id)->image_path;
            if ($name === 'Pane') {
                $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'taken']);
            }
        }
        $this->post("/api/lists/{$list->id}/messages", ['image' => $this->photo('chat.jpg')]);
        $chatPath = $list->messages()->first()->image_path;

        // "Rimuovi articoli presi" elimina anche la foto dell'articolo preso.
        $this->deleteJson("/api/lists/{$list->id}/items/checked")->assertJsonPath('deleted', 1);
        Storage::assertMissing($paths['Pane']);
        Storage::assertExists($paths['Latte']);

        $this->deleteJson("/api/lists/{$list->id}")->assertNoContent();
        Storage::assertMissing($paths['Latte']);
        Storage::assertMissing($chatPath);
    }

    public function test_chat_photo_with_or_without_text(): void
    {
        Storage::fake();
        Notification::fake();
        Event::fake([ListMessageCreated::class]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id, ['can_edit' => false]);

        // Anche chi ha la sola lettura può mandare foto in chat.
        Sanctum::actingAs($anna);
        $message = $this->post("/api/lists/{$list->id}/messages", [
            'image' => $this->photo('scaffale.jpg'),
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.body', null)
            ->assertJsonPath('data.has_image', true)
            ->json('data');
        $this->post("/api/lists/{$list->id}/messages", [
            'body' => 'Questo?',
            'image' => $this->photo('b.jpg'),
        ], ['Accept' => 'application/json'])->assertCreated();

        $this->get("/api/lists/{$list->id}/messages/{$message['id']}/image")->assertOk();
        $this->postJson("/api/lists/{$list->id}/messages", [])->assertJsonValidationErrors('body');
        $this->post("/api/lists/{$list->id}/messages", [
            'image' => UploadedFile::fake()->create('virus.exe', 10),
        ], ['Accept' => 'application/json'])->assertJsonValidationErrors('image');

        $previews = [];
        Notification::assertSentTo($list->owner, ChatMessageReceived::class, function (ChatMessageReceived $n) use (&$previews) {
            $previews[] = $n->body();

            return true;
        });
        $this->assertSame(['📷 Foto', '📷 Questo?'], $previews);

        Sanctum::actingAs(User::factory()->create());
        $this->get("/api/lists/{$list->id}/messages/{$message['id']}/image")->assertForbidden();

        Sanctum::actingAs($anna);
        $path = $list->messages()->find($message['id'])->image_path;
        $this->deleteJson("/api/lists/{$list->id}/messages/{$message['id']}")->assertNoContent();
        Storage::assertMissing($path);
    }
}
