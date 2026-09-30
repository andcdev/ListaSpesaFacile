<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Prezzo rilevato in una catena e in una zona: segnalato da un utente (rettifica) o importato da Open Prices.
 * Di chi segnala si mostrano nome e ora; reporter_email resta sul server e non esce mai dalle API.
 */
#[Fillable([
    'supermarket_id', 'product_key', 'barcode', 'product_name', 'price', 'currency', 'per', 'package_amount', 'package_unit',
    'country', 'province', 'city', 'locality', 'source', 'status', 'approvals', 'rejections', 'external_id', 'dedupe_key', 'user_id', 'reporter_name', 'reporter_email', 'observed_at',
])]
class PriceReport extends Model
{
    public const SOURCE_USER = 'user';

    public const SOURCE_OPEN_PRICES = 'open_prices';

    /** Rettifica di un utente in attesa della conferma di altri utenti: la vede solo chi l'ha scritta. */
    public const PENDING = 'pending';

    /** Visibile a tutti: di Open Prices, oppure confermata da abbastanza utenti (config prices.approvals_required). */
    public const APPROVED = 'approved';

    /** Smentita da abbastanza utenti: non conta più. */
    public const REJECTED = 'rejected';

    protected $hidden = ['reporter_email'];

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'package_amount' => 'float',
            'observed_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Supermarket, $this>
     */
    public function supermarket(): BelongsTo
    {
        return $this->belongsTo(Supermarket::class);
    }

    /**
     * @return HasMany<PriceReportVote, $this>
     */
    public function votes(): HasMany
    {
        return $this->hasMany(PriceReportVote::class);
    }

    /**
     * Conferma o smentita di un altro utente (si può cambiare il proprio voto). Tra i prezzi della stessa zona si
     * mostra quello con più conferme. Una rettifica in attesa diventa visibile a tutti con abbastanza conferme
     * (config prices.approvals_required); un prezzo con abbastanza smentite, più delle conferme, viene scartato.
     */
    public function vote(User $user, bool $approve): void
    {
        $this->votes()->updateOrCreate(['user_id' => $user->id], ['approve' => $approve]);
        $this->approvals = $this->votes()->where('approve', true)->count();
        $this->rejections = $this->votes()->where('approve', false)->count();
        $required = config('prices.approvals_required');
        $this->status = match (true) {
            $this->rejections >= $required && $this->rejections > $this->approvals => self::REJECTED,
            $this->approvals >= $required || $this->source !== self::SOURCE_USER => self::APPROVED,
            default => self::PENDING,
        };
        $this->save();
    }

    /**
     * Come viene mostrata nell'app: prezzo, fonte, nome e ora di chi l'ha segnalato, zona. Mai l'email.
     *
     * @return array<string, mixed>
     */
    public function toPublicArray(): array
    {
        return [
            'id' => $this->id,
            'supermarket' => $this->supermarket?->name,
            'product_name' => $this->product_name,
            'barcode' => $this->barcode,
            'price' => $this->price,
            'currency' => $this->currency,
            'per' => $this->per,
            'source' => $this->source,
            'status' => $this->status,
            'approvals' => $this->approvals,
            'rejections' => $this->rejections,
            'reporter' => $this->reporter_name,
            'observed_at' => $this->observed_at->toIso8601String(),
            'country' => $this->country,
            'province' => $this->province,
            'city' => $this->city,
            'locality' => $this->locality,
        ];
    }
}
