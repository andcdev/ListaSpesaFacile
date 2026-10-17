<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Risposte a un singolo messaggio ed eventi della lista nella chat.
 */
class ChatRepliesTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_message_can_reply_to_another_of_the_same_list(): void
    {
        $list = ShoppingList::factory()->create();
        $list->owner->update(['name' => 'Mario']);
        $anna = User::factory()->create(['name' => 'Anna']);
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($list->owner);
        $first = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Prendo anche il caffè?'])->json('data.id');

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Sì, grazie', 'reply_to_id' => $first])
            ->assertCreated()
            ->assertJsonPath('data.reply_to.id', $first)
            ->assertJsonPath('data.reply_to.body', 'Prendo anche il caffè?')
            ->assertJsonPath('data.reply_to.user.name', 'Mario');

        $this->getJson("/api/lists/{$list->id}/messages")->assertJsonPath('data.0.reply_to.id', $first);

        // Eliminato il messaggio citato, la risposta resta senza citazione.
        Sanctum::actingAs($list->owner);
        $this->deleteJson("/api/lists/{$list->id}/messages/{$first}")->assertNoContent();
        $this->getJson("/api/lists/{$list->id}/messages")->assertJsonPath('data.0.reply_to', null);
    }

    public function test_cannot_reply_to_a_message_of_another_list(): void
    {
        $list = ShoppingList::factory()->create();
        $other = ShoppingList::factory()->create();
        $foreign = $other->messages()->create(['body' => 'Altro']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Ciao', 'reply_to_id' => $foreign->id])
            ->assertJsonValidationErrors('reply_to_id');
    }

    public function test_finishing_and_taking_over_appear_as_events_in_the_chat(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create(['name' => 'Spesa']);
        $list->owner->update(['name' => 'Mario']);
        $anna = User::factory()->create(['name' => 'Anna']);
        $list->sharedWith()->attach($anna->id, ['can_edit' => true]);
        $list->items()->create(['name' => 'Latte']);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/finish", ['message' => 'Il latte era finito'])->assertOk();
        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/take-over")->assertOk();
        Sanctum::actingAs($list->owner);
        $this->patchJson("/api/lists/{$list->id}", ['shopper_id' => $list->owner_id])->assertOk();

        $messages = $this->getJson("/api/lists/{$list->id}/messages")->json('data');
        $this->assertSame(
            [['shopper_changed', ['shopper' => 'Mario']], ['took_over', null], [null, null], ['finished', ['missing' => 1]]],
            array_map(fn ($m) => [$m['event'], $m['event_params']], $messages),
        );
        // Le app vecchie, che non conoscono gli eventi, mostrano comunque un testo.
        $this->assertSame('Anna continua la spesa', $messages[1]['body']);
    }
}
