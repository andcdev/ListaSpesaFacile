<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Broadcast;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SharingTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_shares_list_with_multiple_users(): void
    {
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $luca = User::factory()->create(['email' => 'luca@example.com']);
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'anna@example.com'])->assertOk();
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'LUCA@example.com', 'can_edit' => false])
            ->assertOk()
            ->assertJsonCount(2, 'data');

        Sanctum::actingAs($anna);
        $this->getJson('/api/lists')->assertJsonPath('data.0.permission', 'edit');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertCreated();
        $this->deleteJson("/api/lists/{$list->id}")->assertForbidden();

        Sanctum::actingAs($luca);
        $this->getJson("/api/lists/{$list->id}")->assertOk()->assertJsonPath('data.permission', 'view');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertForbidden();
    }

    public function test_share_with_unknown_email_fails(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/shares", ['email' => 'nessuno@example.com'])
            ->assertJsonValidationErrors('email');
    }

    public function test_only_owner_can_share_but_member_can_leave(): void
    {
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $other = User::factory()->create();
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/shares", ['email' => $other->email])->assertForbidden();
        $this->deleteJson("/api/lists/{$list->id}/shares/{$anna->id}")->assertNoContent();
        $this->getJson("/api/lists/{$list->id}")->assertForbidden();
    }

    public function test_global_share_gives_access_to_all_current_and_future_lists(): void
    {
        $owner = User::factory()->create();
        $anna = User::factory()->create(['email' => 'anna@example.com']);
        ShoppingList::factory()->for($owner, 'owner')->create();

        Sanctum::actingAs($owner);
        $this->postJson('/api/global-shares', ['email' => 'anna@example.com', 'can_edit' => false])
            ->assertOk()
            ->assertJsonPath('shared_with.0.email', 'anna@example.com')
            ->assertJsonPath('shared_with.0.can_edit', false);
        ShoppingList::factory()->for($owner, 'owner')->create();

        Sanctum::actingAs($anna);
        $this->getJson('/api/lists')->assertJsonCount(2, 'data')->assertJsonPath('data.0.permission', 'view');
        $this->getJson('/api/global-shares')->assertJsonPath('shared_by.0.id', $owner->id);

        Sanctum::actingAs($owner);
        $this->deleteJson("/api/global-shares/{$anna->id}")->assertNoContent();

        Sanctum::actingAs($anna);
        $this->getJson('/api/lists')->assertJsonCount(0, 'data');
    }

    public function test_owner_changes_the_permission_of_a_list_share(): void
    {
        $list = ShoppingList::factory()->create();
        $mario = User::factory()->create();
        $list->sharedWith()->attach($mario->id, ['can_edit' => true]);
        Sanctum::actingAs($list->owner);

        $this->patchJson("/api/lists/{$list->id}/shares/{$mario->id}", ['can_edit' => false])
            ->assertOk()
            ->assertJsonPath('data.0.can_edit', false);

        // Ora Mario legge ma non modifica.
        Sanctum::actingAs($mario);
        $this->getJson("/api/lists/{$list->id}")->assertOk()->assertJsonPath('data.permission', 'view');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertForbidden();
        // E non può cambiarsi il permesso da solo.
        $this->patchJson("/api/lists/{$list->id}/shares/{$mario->id}", ['can_edit' => true])->assertForbidden();

        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}/shares/{$mario->id}", ['can_edit' => true])->assertJsonPath('data.0.can_edit', true);
        $this->patchJson("/api/lists/{$list->id}/shares/{$mario->id}", [])->assertJsonValidationErrors('can_edit');
        // Chi non ha la lista non si può modificare.
        $this->patchJson("/api/lists/{$list->id}/shares/".User::factory()->create()->id, ['can_edit' => true])->assertNotFound();
    }

    public function test_owner_changes_the_permission_of_a_global_share(): void
    {
        $owner = User::factory()->create();
        $anna = User::factory()->create();
        $list = ShoppingList::factory()->for($owner, 'owner')->create();
        $owner->globalShareRecipients()->attach($anna->id, ['can_edit' => true]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/global-shares/{$anna->id}", ['can_edit' => false])
            ->assertOk()
            ->assertJsonPath('shared_with.0.can_edit', false);

        Sanctum::actingAs($anna);
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.permission', 'view');

        Sanctum::actingAs($owner);
        $this->patchJson('/api/global-shares/'.User::factory()->create()->id, ['can_edit' => true])->assertNotFound();
    }

    public function test_presence_channel_authorization(): void
    {
        config(['broadcasting.default' => 'reverb', 'broadcasting.connections.reverb' => [
            'driver' => 'reverb', 'key' => 'k', 'secret' => 's', 'app_id' => '1',
            'options' => ['host' => 'localhost', 'port' => 8080, 'scheme' => 'http'],
        ]]);
        // I canali sono registrati sul broadcaster attivo al boot ("null" nei test): li ricarichiamo su reverb.
        Broadcast::purge();
        require base_path('routes/channels.php');
        $list = ShoppingList::factory()->create();

        Sanctum::actingAs($list->owner);
        $this->postJson('/api/broadcasting/auth', ['socket_id' => '1.1', 'channel_name' => "presence-list.{$list->id}"])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data']);

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/broadcasting/auth', ['socket_id' => '1.1', 'channel_name' => "presence-list.{$list->id}"])
            ->assertForbidden();
    }
}
