<?php

namespace Tests\Feature;

use App\Events\ListMessagesDelivered;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ChatMessageReceived;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatDeliveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_receipts_move_forward_and_are_broadcast(): void
    {
        Event::fake([ListMessagesDelivered::class]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);
        $owner = $list->owner;

        Sanctum::actingAs($owner);
        $first = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Uno'])->json('data.id');
        $second = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Due'])->json('data.id');

        // Chi scrive ha ricevuto i propri messaggi; Anna ancora nulla → una spunta.
        $this->getJson("/api/lists/{$list->id}/messages")
            ->assertJsonPath("delivered.{$owner->id}", $second)
            ->assertJsonPath("delivered.{$anna->id}", 0);

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/messages/delivered", ['up_to' => $first])->assertNoContent();
        // Un valore più vecchio o ripetuto non torna indietro e non genera eventi; uno oltre l'ultimo messaggio si ferma lì.
        $this->postJson("/api/lists/{$list->id}/messages/delivered", ['up_to' => $first])->assertNoContent();
        $this->postJson("/api/lists/{$list->id}/messages/delivered", ['up_to' => 999999])->assertNoContent();

        $this->getJson("/api/lists/{$list->id}/messages")->assertJsonPath("delivered.{$anna->id}", $second);
        Event::assertDispatchedTimes(ListMessagesDelivered::class, 2);
        Event::assertDispatched(ListMessagesDelivered::class, fn ($e) => $e->userId === $anna->id && $e->upTo === $second);

        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/lists/{$list->id}/messages/delivered", ['up_to' => $first])->assertForbidden();
    }

    public function test_simultaneous_receipts_from_the_same_phone_do_not_fail(): void
    {
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);
        $message = $list->messages()->create(['user_id' => $list->owner_id, 'body' => 'Ciao']);

        // Due richieste partite insieme (app in background e servizio delle notifiche): entrambe leggono
        // "nessuna conferma" prima che l'altra la salvi. La seconda non deve fallire né tornare indietro.
        $first = ShoppingList::find($list->id);
        $second = ShoppingList::find($list->id);
        $this->assertSame($message->id, $first->markChatDelivered($anna, $message->id));
        $this->assertNull($second->markChatDelivered($anna, $message->id));
        $this->assertNull($second->markChatDelivered($anna, $message->id - 1));
        $this->assertSame(1, $list->chatDeliveries()->where('user_id', $anna->id)->count());
        $this->assertSame($message->id, $list->chatDeliveries()->where('user_id', $anna->id)->value('delivered_up_to'));
    }

    public function test_chat_notification_carries_the_message_id(): void
    {
        Notification::fake();
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $list->sharedWith()->attach($anna->id);

        Sanctum::actingAs($anna);
        $id = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Ciao'])->json('data.id');

        Notification::assertSentTo($list->owner, ChatMessageReceived::class, fn (ChatMessageReceived $n) => $n->extra() === ['message_id' => $id]);
    }

    public function test_product_suggestions_put_history_first(): void
    {
        $list = ShoppingList::factory()->create();
        $other = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        foreach (['Biscotti al cacao', 'biscotti al cacao', 'Mele', 'Pane'] as $name) {
            $this->postJson("/api/lists/{$list->id}/items", ['name' => $name]);
        }
        $other->items()->create(['name' => 'Segreto di un altro']);

        $data = collect($this->getJson('/api/products/suggestions')->assertOk()->json('data'));

        $this->assertSame(['name' => 'biscotti al cacao', 'icon' => '🍪', 'category' => 'dolci', 'measure' => 'count', 'times' => 2], $data[0]);
        $this->assertSame(1, $data->where('name', 'Mele')->count(), 'i prodotti comuni già usati non si ripetono');
        $this->assertSame('🧻', $data->firstWhere('name', 'Carta igienica')['icon']);
        $this->assertNull($data->firstWhere('name', 'Segreto di un altro'), 'solo liste accessibili');
    }
}
