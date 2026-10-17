<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Reazione (un'emoji) di un utente a un messaggio della chat.
 */
#[Fillable(['user_id', 'emoji'])]
class MessageReaction extends Model
{
    /** Le reazioni che si possono dare, come in WhatsApp. */
    public const EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
