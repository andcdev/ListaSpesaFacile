<?php

namespace App\Support;

use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use Illuminate\Support\Collection;

/**
 * Prezzi indicativi degli articoli di una lista nella catena scelta (o nelle altre, per il confronto).
 *
 * Il prezzo di un articolo è quello della catena per il prodotto riconosciuto dal nome, moltiplicato per:
 * - il peso o il volume, se il prezzo è al kg o al litro e l'articolo ha una misura compatibile (500 g → 0,5 kg);
 * - il numero di pezzi o confezioni (quantità "2", "3 confezioni"…; se manca o non è un numero vale 1).
 * Un prezzo al kg o al litro senza misura vale per 1 kg o 1 litro a confezione.
 */
class PriceEstimator
{
    /** Conversione delle unità dell'articolo nell'unità del prezzo. */
    private const TO_PRICE_UNIT = [
        'kg' => ['g' => 0.001, 'hg' => 0.1, 'kg' => 1.0],
        'l' => ['ml' => 0.001, 'cl' => 0.01, 'l' => 1.0],
    ];

    /**
     * Prezzo stimato dell'articolo nella catena, null se la catena non ha il prodotto.
     */
    public static function itemPrice(Supermarket $supermarket, ListItem $item): ?float
    {
        $price = $supermarket->priceFor(ProductCatalog::productKey($item->name));
        if ($price === null) {
            return null;
        }

        $factor = self::TO_PRICE_UNIT[$price['per']][$item->unit] ?? null;
        $units = $factor !== null && $item->amount !== null ? $item->amount * $factor : 1.0;

        return round($price['price'] * $units * self::pieces($item->quantity), 2);
    }

    /**
     * Totale della lista nella catena: gli articoli non trovati non si contano.
     *
     * @param  Collection<int, ListItem>  $items
     * @return array{total: float, priced: int, lines: array<int, float|null>} lines: id articolo => prezzo
     */
    public static function listTotal(Supermarket $supermarket, Collection $items): array
    {
        $lines = [];
        $total = 0.0;
        $priced = 0;
        foreach ($items as $item) {
            $lines[$item->id] = $price = self::itemPrice($supermarket, $item);
            if ($price !== null && $item->status !== 'missing') {
                $total += $price;
                $priced++;
            }
        }

        return ['total' => round($total, 2), 'priced' => $priced, 'lines' => $lines];
    }

    /**
     * Costo della lista in ogni catena che ha il prezzo di almeno un articolo: prima quelle che coprono più
     * articoli, a parità la più economica.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function compare(ShoppingList $list): array
    {
        $items = $list->items;
        $current = $list->supermarketChain();

        return Supermarket::query()
            ->whereHas('prices')
            ->orderBy('name')
            ->get()
            ->map(fn (Supermarket $supermarket) => [$supermarket, self::listTotal($supermarket, $items)])
            ->filter(fn (array $row) => $row[1]['priced'] > 0)
            ->sortBy([fn ($a, $b) => $b[1]['priced'] <=> $a[1]['priced'], fn ($a, $b) => $a[1]['total'] <=> $b[1]['total']])
            ->values()
            ->map(fn (array $row) => [
                'id' => $row[0]->id,
                'name' => $row[0]->name,
                'description' => $row[0]->description,
                'current' => $current?->is($row[0]) ?? false,
                'total' => $row[1]['total'],
                'priced_count' => $row[1]['priced'],
                'items_count' => $items->where('status', '!=', 'missing')->count(),
                'items' => $items->map(fn (ListItem $item) => [
                    'id' => $item->id,
                    'name' => $item->name,
                    'icon' => $item->custom_icon ?? $item->icon,
                    'status' => $item->status,
                    'price' => $row[1]['lines'][$item->id],
                ])->values()->all(),
            ])
            ->all();
    }

    /**
     * Numero di pezzi dalla quantità scritta dall'utente: "2" → 2, "3 confezioni" → 3, "1,5" → 1.5, "qualche" → 1.
     */
    public static function pieces(?string $quantity): float
    {
        if ($quantity === null || ! preg_match('/^\s*(\d+(?:[.,]\d+)?)/', $quantity, $m)) {
            return 1.0;
        }
        $pieces = (float) str_replace(',', '.', $m[1]);

        return $pieces > 0 ? min($pieces, 1000.0) : 1.0;
    }
}
