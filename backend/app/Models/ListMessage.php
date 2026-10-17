<?php

namespace App\Models;

use App\Events\ListMessageCreated;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

/**
 * Messaggio della chat interna di una lista: testo, foto o entrambi.
 */
#[Fillable(['body'])]
class ListMessage extends Model
{
    /** Cartella delle foto inviate in chat: una sottocartella per lista. */
    public const IMAGE_DIR = 'chat-images';

    /** Eventi della lista che compaiono in chat: spesa finita, "Continuo io", chi fa la spesa scelto. */
    public const EVENTS = ['finished', 'took_over', 'shopper_changed'];

    protected function casts(): array
    {
        return ['event_params' => 'array'];
    }

    /**
     * Mette in chat un evento della lista fatto da [$actor] e lo manda in tempo reale (senza notifiche push: chi
     * deve saperlo ne riceve già una). [$body] è il testo per le versioni dell'app che non conoscono gli eventi.
     *
     * @param  array<string, int|string>  $params
     */
    public static function postEvent(ShoppingList $list, User $actor, string $event, string $body, array $params = []): self
    {
        $message = new self(['body' => $body]);
        $message->event = $event;
        $message->event_params = $params ?: null;
        $message->user()->associate($actor);
        $list->messages()->save($message);
        $list->markChatDelivered($actor, $message->id);
        Realtime::broadcast(new ListMessageCreated($message));

        return $message;
    }

    protected static function booted(): void
    {
        static::deleted(function (ListMessage $message) {
            if ($message->image_path) {
                Storage::delete($message->image_path);
            }
        });
    }

    /**
     * @return BelongsTo<ShoppingList, $this>
     */
    public function shoppingList(): BelongsTo
    {
        return $this->belongsTo(ShoppingList::class);
    }

    /**
     * Messaggio a cui questo risponde.
     *
     * @return BelongsTo<ListMessage, $this>
     */
    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(self::class, 'reply_to_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
