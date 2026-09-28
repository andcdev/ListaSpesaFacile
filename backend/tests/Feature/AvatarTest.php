<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AvatarTest extends TestCase
{
    use RefreshDatabase;

    public function test_avatar_upload_is_visible_to_list_members_only(): void
    {
        Storage::fake();
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($anna);
        $this->getJson('/api/me')->assertJsonPath('data.avatar_version', null);
        $version = $this->post('/api/me/avatar', ['image' => $this->photo('io.jpg')], ['Accept' => 'application/json'])
            ->assertOk()
            ->json('data.avatar_version');
        $this->assertNotNull($version);
        $path = $anna->fresh()->avatar_path;
        Storage::assertExists($path);

        // In chat il messaggio porta la versione della foto di chi scrive.
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Ciao'])
            ->assertJsonPath('data.user.avatar_version', $version);

        Sanctum::actingAs($list->owner);
        $this->get("/api/users/{$anna->id}/avatar?v=$version")->assertOk();

        // Chi non ha liste in comune non la vede.
        Sanctum::actingAs(User::factory()->create());
        $this->get("/api/users/{$anna->id}/avatar")->assertForbidden();

        Sanctum::actingAs($anna);
        $this->deleteJson('/api/me/avatar')->assertJsonPath('data.avatar_version', null);
        Storage::assertMissing($path);
        $this->get("/api/users/{$anna->id}/avatar")->assertNotFound();
        $this->post('/api/me/avatar', ['image' => UploadedFile::fake()->create('x.pdf', 10, 'application/pdf')], ['Accept' => 'application/json'])
            ->assertJsonValidationErrors('image');
    }
}
