<?php

namespace Tests\Feature;

use App\Events\ShoppingListDeleted;
use App\Models\ListMessage;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\AccountDeletionCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    private function requestCode(User $user): string
    {
        $code = null;
        $this->postJson('/api/account-deletion/code', ['email' => strtoupper($user->email)])->assertOk();
        Notification::assertSentTo($user, AccountDeletionCode::class, function (AccountDeletionCode $n) use (&$code) {
            $code = $n->code;

            return true;
        });

        return $code;
    }

    public function test_unknown_email_gets_the_same_answer_and_no_email(): void
    {
        Notification::fake();
        $known = $this->postJson('/api/account-deletion/code', ['email' => User::factory()->create()->email])
            ->assertOk()->json('message');

        $this->postJson('/api/account-deletion/code', ['email' => 'nessuno@example.com'])
            ->assertOk()->assertJsonPath('message', $known);
        Notification::assertSentTimes(AccountDeletionCode::class, 1);
    }

    public function test_code_deletes_the_account_with_its_lists_messages_and_photos(): void
    {
        Storage::fake();
        Event::fake([ShoppingListDeleted::class]);
        Notification::fake();

        $anna = User::factory()->create(['email' => 'anna@example.com']);
        $marco = User::factory()->create();

        // Una lista di Anna, condivisa con Marco, con una foto.
        Sanctum::actingAs($anna);
        $this->post('/api/me/avatar', ['image' => $this->photo('io.jpg')], ['Accept' => 'application/json'])->assertOk();
        $own = ShoppingList::factory()->for($anna, 'owner')->create();
        $own->sharedWith()->attach($marco->id, ['can_edit' => true]);
        $this->post("/api/lists/{$own->id}/image", ['image' => $this->photo('lista.jpg')], ['Accept' => 'application/json'])
            ->assertOk();

        // Una lista di Marco condivisa con Anna, dove Anna ha scritto un messaggio con foto.
        $theirs = ShoppingList::factory()->for($marco, 'owner')->create();
        $theirs->sharedWith()->attach($anna->id, ['can_edit' => true]);
        $this->post("/api/lists/{$theirs->id}/messages", ['image' => $this->photo('chat.jpg')], ['Accept' => 'application/json'])
            ->assertCreated();
        $anna->createToken('telefono');

        $files = [$anna->fresh()->avatar_path, $own->fresh()->image_path, ListMessage::first()->image_path];
        foreach ($files as $path) {
            Storage::assertExists($path);
        }

        $code = $this->requestCode($anna);
        $this->postJson('/api/account-deletion/confirm', ['email' => 'anna@example.com', 'code' => $code])->assertOk();

        $this->assertModelMissing($anna);
        $this->assertModelMissing($own);
        $this->assertModelExists($theirs);
        $this->assertDatabaseCount('list_messages', 0);
        $this->assertDatabaseCount('shopping_list_user', 0);
        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $anna->id]);
        foreach ($files as $path) {
            Storage::assertMissing($path);
        }
        Event::assertDispatched(ShoppingListDeleted::class, fn ($e) => $e->listId === $own->id);

        // Il codice vale una volta sola.
        $this->postJson('/api/account-deletion/confirm', ['email' => 'anna@example.com', 'code' => $code])
            ->assertJsonValidationErrors('code');
    }

    public function test_wrong_codes_do_not_delete_and_five_mistakes_burn_the_code(): void
    {
        Notification::fake();
        $anna = User::factory()->create();
        $code = $this->requestCode($anna);
        $wrong = $code === '000000' ? '111111' : '000000';

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/account-deletion/confirm', ['email' => $anna->email, 'code' => $wrong])
                ->assertJsonValidationErrors('code');
        }
        $this->postJson('/api/account-deletion/confirm', ['email' => $anna->email, 'code' => $code])
            ->assertJsonValidationErrors('code');
        $this->assertModelExists($anna);
    }
}
