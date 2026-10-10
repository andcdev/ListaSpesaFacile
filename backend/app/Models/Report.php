<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Segnalazione inviata dall'app (un problema, una persona o un messaggio della chat) oppure foto rifiutata dal
 * controllo automatico.
 */
#[Fillable(['type', 'body', 'reported_user_id', 'shopping_list_id', 'list_message_id', 'message_body', 'app_version', 'context', 'scores', 'image_path'])]
class Report extends Model
{
    /** Segnalazioni che si possono mandare dall'app. */
    public const TYPES = ['problem', 'user', 'message'];

    /** Foto rifiutata dal controllo automatico (nudità o violenza). */
    public const TYPE_IMAGE = 'image';

    /** Cartella delle foto rifiutate, da guardare dall'email (eliminate dopo QUARANTINE_DAYS). */
    public const QUARANTINE_DIR = 'quarantena';

    public const QUARANTINE_DAYS = 30;

    protected function casts(): array
    {
        return ['scores' => 'array'];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function reportedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    /**
     * @return BelongsTo<ListMessage, $this>
     */
    public function listMessage(): BelongsTo
    {
        return $this->belongsTo(ListMessage::class);
    }

    /**
     * @return BelongsTo<ShoppingList, $this>
     */
    public function shoppingList(): BelongsTo
    {
        return $this->belongsTo(ShoppingList::class);
    }
}
