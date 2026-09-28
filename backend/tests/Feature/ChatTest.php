<?php

namespace Tests\Feature;

use App\Events\ListMessageCreated;
use App\Events\ListMessageDeleted;
use App\Models\ListMessage;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use RefreshDatabase;

    public function test_members_chat_and_read_only_users_can_write(): void
    {
        Event::fake([ListMessageCreated::class]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create(['name' => 'Anna']);
        $list->sharedWith()->attach($anna->id, ['can_edit' => false]);

        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => '  Prendi il latte  '])
            ->assertCreated()
            ->assertJsonPath('data.body', 'Prendi il latte')
            ->assertJsonPath('data.user.id', $list->owner->id);

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'Ok!'])->assertCreated();

        $this->getJson("/api/lists/{$list->id}/messages")
            ->assertOk()
            ->assertJsonPath('data.*.body', ['Ok!', 'Prendi il latte'])
            ->assertJsonPath('data.0.user.name', 'Anna')
            ->assertJsonPath('has_more', false);

        Event::assertDispatched(ListMessageCreated::class, 2);
        $this->assertDatabaseCount('notifications', 0); // i messaggi non riempiono l'elenco delle notifiche
    }

    public function test_messages_are_paginated(): void
    {
        $list = ShoppingList::factory()->create();
        foreach (range(1, 60) as $i) {
            $message = new ListMessage(['body' => "m$i"]);
            $message->user()->associate($list->owner);
            $list->messages()->save($message);
        }
        Sanctum::actingAs($list->owner);

        $first = $this->getJson("/api/lists/{$list->id}/messages")
            ->assertJsonCount(50, 'data')
            ->assertJsonPath('data.0.body', 'm60')
            ->assertJsonPath('has_more', true);

        $this->getJson("/api/lists/{$list->id}/messages?before=".$first->json('data.49.id'))
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('data.9.body', 'm1')
            ->assertJsonPath('has_more', false);
    }

    public function test_strangers_cannot_read_or_write(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/lists/{$list->id}/messages")->assertForbidden();
        $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'ciao'])->assertForbidden();
    }

    public function test_author_or_owner_can_delete_a_message(): void
    {
        Event::fake([ListMessageDeleted::class]);
        $list = ShoppingList::factory()->create();
        $anna = User::factory()->create();
        $bruno = User::factory()->create();
        $list->sharedWith()->attach([$anna->id, $bruno->id]);

        Sanctum::actingAs($anna);
        $first = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'uno'])->json('data.id');
        $second = $this->postJson("/api/lists/{$list->id}/messages", ['body' => 'due'])->json('data.id');

        Sanctum::actingAs($bruno);
        $this->deleteJson("/api/lists/{$list->id}/messages/{$first}")->assertForbidden();

        Sanctum::actingAs($anna);
        $this->deleteJson("/api/lists/{$list->id}/messages/{$first}")->assertNoContent();

        Sanctum::actingAs($list->owner);
        $this->deleteJson("/api/lists/{$list->id}/messages/{$second}")->assertNoContent();

        $this->assertDatabaseCount('list_messages', 0);
        Event::assertDispatched(ListMessageDeleted::class, fn (ListMessageDeleted $e) => $e->messageId === $first);
    }

    public function test_message_of_another_list_is_not_reachable(): void
    {
        $list = ShoppingList::factory()->create();
        $other = ShoppingList::factory()->for($list->owner, 'owner')->create();
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$other->id}/messages", ['body' => 'x'])->json('data.id');

        $this->deleteJson("/api/lists/{$list->id}/messages/{$id}")->assertNotFound();
    }
}
