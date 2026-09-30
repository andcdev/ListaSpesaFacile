<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * Catena di supermercati (distribuzione) con i suoi prezzi indicativi.
 */
#[Fillable(['name', 'aliases', 'description'])]
class Supermarket extends Model
{
    /** @var array<string, array{price: float, per: string}>|null prezzi per chiave del prodotto, letti una volta sola */
    private ?array $priceIndex = null;

    protected function casts(): array
    {
        return ['aliases' => 'array'];
    }

    /**
     * @return HasMany<SupermarketPrice, $this>
     */
    public function prices(): HasMany
    {
        return $this->hasMany(SupermarketPrice::class);
    }

    /**
     * Catena corrispondente al supermercato scritto dall'utente: il nome (o uno dei suoi altri nomi) deve comparire
     * come parole intere ("Esselunga di viale Piave" → Esselunga, "Ipercoop" → Coop); vince il nome più lungo
     * ("Carrefour Market" prima di "Carrefour"). Null se non corrisponde a nessuna catena nota.
     */
    public static function match(?string $name): ?self
    {
        $normalized = self::normalize((string) $name);
        if ($normalized === '') {
            return null;
        }

        $best = null;
        $bestLength = 0;
        foreach (self::all() as $supermarket) {
            foreach ([$supermarket->name, ...($supermarket->aliases ?? [])] as $candidate) {
                $key = self::normalize($candidate);
                if ($key !== '' && str_contains(" $normalized ", " $key ") && strlen($key) > $bestLength) {
                    [$best, $bestLength] = [$supermarket, strlen($key)];
                }
            }
        }

        return $best;
    }

    /**
     * "Decò" → "deco", "In's Mercato" → "ins mercato", "Coop&Coop" → "coop coop".
     */
    public static function normalize(string $name): string
    {
        $ascii = str_replace("'", '', Str::lower(Str::ascii($name)));

        return trim((string) preg_replace('/[^a-z0-9]+/', ' ', $ascii));
    }

    /**
     * Prezzo del prodotto con quella chiave, null se la catena non ce l'ha.
     *
     * @return array{price: float, per: string}|null
     */
    public function priceFor(?string $productKey): ?array
    {
        if ($productKey === null) {
            return null;
        }
        $this->priceIndex ??= $this->prices()
            ->get(['product_key', 'price', 'per'])
            ->mapWithKeys(fn (SupermarketPrice $p) => [$p->product_key => ['price' => (float) $p->price, 'per' => $p->per]])
            ->all();

        return $this->priceIndex[$productKey] ?? null;
    }
}
