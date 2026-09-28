<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListReminder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RemindersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow('2026-10-01 08:00:00');
    }

    public function test_remind_at_follows_schedule_and_advance(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $id = $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => '2026-10-01T12:00:00+02:00',
            'reminder_minutes' => 10,
        ])->assertCreated()->json('data.id');

        $this->assertSame('2026-10-01 09:50:00', ShoppingList::find($id)->remind_at->toDateTimeString());

        $this->patchJson("/api/lists/{$id}", ['scheduled_at' => '2026-10-01T18:00:00+02:00'])->assertOk();
        $this->assertSame('2026-10-01 15:50:00', ShoppingList::find($id)->remind_at->toDateTimeString());

        $this->patchJson("/api/lists/{$id}", ['reminder_minutes' => 60])->assertOk();
        $this->assertSame('2026-10-01 15:00:00', ShoppingList::find($id)->remind_at->toDateTimeString());

        $this->patchJson("/api/lists/{$id}", ['reminder_minutes' => null])->assertOk();
        $this->assertNull(ShoppingList::find($id)->remind_at);

        // Un promemoria che cadrebbe nel passato non viene programmato.
        $this->patchJson("/api/lists/{$id}", ['scheduled_at' => '2026-10-01T10:05:00+02:00', 'reminder_minutes' => 10])->assertOk();
        $this->assertNull(ShoppingList::find($id)->remind_at);
    }

    public function test_invalid_reminder_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/lists', [
            'name' => 'Spesa',
            'scheduled_at' => '2026-10-02T10:00:00Z',
            'reminder_minutes' => 0,
            'reminder_target' => 'nessuno',
        ])->assertJsonValidationErrors(['reminder_minutes', 'reminder_target']);
    }

    public function test_command_sends_reminder_once_to_the_chosen_users(): void
    {
        Notification::fake();
        $owner = User::factory()->create();
        $anna = User::factory()->create();
        $global = User::factory()->create();
        $owner->globalShareRecipients()->attach($global->id);

        $members = $this->listWithReminder($owner, 'members', [$anna]);
        $onlyOwner = $this->listWithReminder($owner, 'owner', [$anna]);
        $everyone = $this->listWithReminder($owner, 'all', [$anna]);
        $later = ShoppingList::factory()->for($owner, 'owner')->create([
            'scheduled_at' => '2026-10-01 12:00:00', 'reminder_minutes' => 10,
        ]);

        $this->travelTo('2026-10-01 09:50:20');
        $this->artisan('lists:send-reminders')->assertSuccessful();
        $this->artisan('lists:send-reminders')->assertSuccessful();

        $sentFor = fn (User $user) => Notification::sent($user, ListReminder::class)->pluck('remindedListId')->sort()->values()->all();
        $this->assertSame([$members->id, $everyone->id], $sentFor($anna));
        $this->assertSame([$members->id, $everyone->id], $sentFor($global));
        $this->assertSame([$onlyOwner->id, $everyone->id], $sentFor($owner));
        Notification::assertSentTo($anna, ListReminder::class, fn (ListReminder $n) => $n->minutes === 10
            && $n->body() === 'La spesa è tra 10 minuti.');

        $this->assertNull($members->fresh()->remind_at);
        $this->assertNotNull($later->fresh()->remind_at);
    }

    public function test_reminder_is_skipped_if_the_shopping_already_started(): void
    {
        Notification::fake();
        $list = $this->listWithReminder(User::factory()->create(), 'all');

        $this->travelTo('2026-10-01 10:30:00');
        $this->artisan('lists:send-reminders')->assertSuccessful();

        Notification::assertNothingSent();
        $this->assertNull($list->fresh()->remind_at);
    }

    public function test_duration_text(): void
    {
        $this->assertSame('10 minuti', ListReminder::duration(10));
        $this->assertSame('1 ora', ListReminder::duration(60));
        $this->assertSame('1 ora e 30 minuti', ListReminder::duration(90));
        $this->assertSame('1 giorno, 2 ore e 1 minuto', ListReminder::duration(1561));
        $this->assertSame('2 giorni', ListReminder::duration(2880));
    }

    /**
     * Lista alle 10:00 con promemoria 10 minuti prima.
     *
     * @param  array<int, User>  $sharedWith
     */
    private function listWithReminder(User $owner, string $target, array $sharedWith = []): ShoppingList
    {
        $list = ShoppingList::factory()->for($owner, 'owner')->create([
            'scheduled_at' => '2026-10-01 10:00:00',
            'reminder_minutes' => 10,
            'reminder_target' => $target,
        ]);
        $list->sharedWith()->attach(collect($sharedWith)->pluck('id'));

        return $list;
    }
}
