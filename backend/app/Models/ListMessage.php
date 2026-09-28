<?php

namespace App\Models;

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
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
