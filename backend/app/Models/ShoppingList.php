<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

#[Fillable(['name', 'notes', 'supermarket', 'scheduled_at', 'reminder_minutes', 'reminder_target', 'members_can_rename'])]
class ShoppingList extends Model
{
    use HasFactory;

    public const PERMISSION_OWNER = 'owner';

    public const PERMISSION_EDIT = 'edit';

    public const PERMISSION_VIEW = 'view';

    /** Destinatari del promemoria: solo il proprietario, solo gli utenti con cui è condivisa, tutti. */
    public const REMINDER_TARGETS = ['owner', 'members', 'all'];

    protected $attributes = ['members_can_rename' => false];

    /** @var array{0: string|null, 1: Supermarket|null}|null supermercato scritto e catena riconosciuta */
    private ?array $chain = null;

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'reminder_minutes' => 'integer',
            'remind_at' => 'datetime',
            'members_can_rename' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        // Ricalcola l'istante del promemoria quando cambiano data/ora o anticipo.
        // Un promemoria che cadrebbe già nel passato non viene inviato.
        // Con la lista se ne vanno anche la sua foto, le foto dei prodotti e quelle della chat
        // (articoli e messaggi sono eliminati dal database a cascata, senza eventi dei modelli).
        static::deleted(function (ShoppingList $list) {
            if ($list->image_path) {
                Storage::delete($list->image_path);
            }
            Storage::deleteDirectory(ListItem::IMAGE_DIR.'/'.$list->id);
            Storage::deleteDirectory(ListMessage::IMAGE_DIR.'/'.$list->id);
        });

        static::saving(function (ShoppingList $list) {
            if (! $list->isDirty(['scheduled_at', 'reminder_minutes'])) {
                return;
            }
            $remindAt = $list->reminder_minutes
                ? $list->scheduled_at->copy()->subMinutes($list->reminder_minutes)
                : null;
            $list->remind_at = $remindAt?->isFuture() ? $remindAt : null;
        });
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * @return HasMany<ListItem, $this>
     */
    public function items(): HasMany
    {
        return $this->hasMany(ListItem::class)->orderBy('position')->orderBy('id');
    }

    /**
     * Versione della foto (cambia a ogni nuova foto): l'app la aggiunge all'URL per aggiornare la cache.
     */
    public function imageVersion(): ?string
    {
        return $this->image_path ? substr(md5($this->image_path), 0, 10) : null;
    }

    /**
     * Catena di supermercati riconosciuta dal supermercato scelto, null se non è una catena nota:
     * in quel caso la lista non ha prezzi.
     */
    public function supermarketChain(): ?Supermarket
    {
        if ($this->chain === null || $this->chain[0] !== $this->supermarket) {
            $this->chain = [$this->supermarket, Supermarket::match($this->supermarket)];
        }

        return $this->chain[1];
    }

    /**
     * @return HasMany<ListMessage, $this>
     */
    public function messages(): HasMany
    {
        return $this->hasMany(ListMessage::class);
    }

    /**
     * Fino a quale messaggio della chat ogni utente ha ricevuto (spunte).
     *
     * @return HasMany<ChatDelivery, $this>
     */
    public function chatDeliveries(): HasMany
    {
        return $this->hasMany(ChatDelivery::class);
    }

    /**
     * Segna come ricevuti dal telefono di [$user] i messaggi fino a [$upTo] (non si torna mai indietro).
     *
     * @return int|null il nuovo valore, oppure null se non è cambiato
     */
    public function markChatDelivered(User $user, int $upTo): ?int
    {
        $upTo = min($upTo, (int) $this->messages()->max('id'));
        if ($upTo <= 0) {
            return null;
        }
        // Atomico: lo stesso telefono può confermare due volte nello stesso istante (app in background e
        // servizio delle notifiche); la riga si crea una sola volta e si aggiorna solo andando avanti.
        $now = now();
        DB::table('chat_deliveries')->insertOrIgnore([
            'shopping_list_id' => $this->id,
            'user_id' => $user->id,
            'delivered_up_to' => 0,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $updated = $this->chatDeliveries()
            ->where('user_id', $user->id)
            ->where('delivered_up_to', '<', $upTo)
            ->update(['delivered_up_to' => $upTo, 'updated_at' => $now]);

        return $updated > 0 ? $upTo : null;
    }

    /**
     * Utenti con cui questa lista è condivisa singolarmente.
     *
     * @return BelongsToMany<User, $this>
     */
    public function sharedWith(): BelongsToMany
    {
        return $this->belongsToMany(User::class)
            ->withPivot('can_edit')
            ->withTimestamps();
    }

    /**
     * Liste visibili all'utente: proprie, condivise singolarmente o tramite condivisione globale.
     *
     * @param  Builder<ShoppingList>  $query
     */
    public function scopeAccessibleBy(Builder $query, User $user): void
    {
        $query->where(function (Builder $q) use ($user) {
            $q->where('owner_id', $user->id)
                ->orWhereHas('sharedWith', fn (Builder $s) => $s->whereKey($user->id))
                ->orWhereIn('owner_id', DB::table('global_shares')
                    ->select('owner_id')
                    ->where('user_id', $user->id));
        });
    }

    /**
     * Permesso dell'utente sulla lista: owner, edit, view oppure null se non ha accesso.
     */
    public function permissionFor(User $user): ?string
    {
        if ($this->owner_id === $user->id) {
            return self::PERMISSION_OWNER;
        }

        $grants = collect([
            $this->sharedWith()->whereKey($user->id)->first()?->pivot->can_edit,
            DB::table('global_shares')
                ->where('owner_id', $this->owner_id)
                ->where('user_id', $user->id)
                ->value('can_edit'),
        ])->reject(fn ($value) => $value === null);

        if ($grants->isEmpty()) {
            return null;
        }

        return $grants->contains(fn ($canEdit) => (bool) $canEdit)
            ? self::PERMISSION_EDIT
            : self::PERMISSION_VIEW;
    }

    /**
     * Può cambiare il nome: il proprietario sempre, chi ha il permesso di modifica solo se il proprietario lo consente.
     */
    public function canRename(User $user): bool
    {
        return match ($this->permissionFor($user)) {
            self::PERMISSION_OWNER => true,
            self::PERMISSION_EDIT => $this->members_can_rename,
            default => false,
        };
    }

    /**
     * Id di tutti gli utenti che possono vedere la lista (per le notifiche in tempo reale).
     *
     * @return array<int, int>
     */
    public function audienceIds(): array
    {
        return collect([$this->owner_id])
            ->merge($this->sharedWith()->pluck('users.id'))
            ->merge(DB::table('global_shares')->where('owner_id', $this->owner_id)->pluck('user_id'))
            ->map(fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();
    }

    /**
     * Id degli utenti che devono ricevere il promemoria, in base a reminder_target.
     *
     * @return array<int, int>
     */
    public function reminderRecipientIds(): array
    {
        $audience = collect($this->audienceIds());

        return match ($this->reminder_target) {
            'owner' => [(int) $this->owner_id],
            'members' => $audience->reject(fn (int $id) => $id === (int) $this->owner_id)->values()->all(),
            default => $audience->all(),
        };
    }
}
