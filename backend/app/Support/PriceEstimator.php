<?php

namespace App\Support;

use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Models\Supermarket;

/**
 * Confronto del costo di una lista tra le catene (prezzi scelti da PriceBook, nella zona della lista).
 */
class PriceEstimator
{
    /**
     * Costo della lista in ogni catena che ha il prezzo di almeno un articolo: prima quelle che coprono più
     * articoli, a parità la più economica. Gli articoli non trovati non contano nel totale.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function compare(ShoppingList $list): array
    {
        $items = $list->items;
        $book = PriceBook::forList($list, $items);
        $current = $list->supermarketChain();
        $active = $items->where('status', '!=', 'missing');

        return Supermarket::query()
            ->whereKey($book->supermarketIds())
            ->orderBy('name')
            ->get()
            ->map(function (Supermarket $supermarket) use ($book, $items) {
                $quotes = $items->mapWithKeys(fn (ListItem $item) => [$item->id => $book->quote($supermarket, $item)]);

                return [$supermarket, $quotes];
            })
            ->map(function (array $row) use ($active) {
                [$supermarket, $quotes] = $row;
                // Si sommano solo i prezzi nella valuta più presente (in un paese di solito ce n'è una sola).
                $currency = $active->map(fn (ListItem $item) => $quotes[$item->id]['currency'] ?? null)->filter()->countBy()->sortDesc()->keys()->first();
                $priced = $active->filter(fn (ListItem $item) => $quotes[$item->id] !== null && $quotes[$item->id]['currency'] === $currency);

                return [$supermarket, $quotes, $priced->count(), round($priced->sum(fn (ListItem $item) => $quotes[$item->id]['line']), 2), $currency];
            })
            ->filter(fn (array $row) => $row[2] > 0)
            ->sortBy([fn ($a, $b) => $b[2] <=> $a[2], fn ($a, $b) => $a[3] <=> $b[3]])
            ->values()
            ->map(fn (array $row) => [
                'id' => $row[0]->id,
                'name' => $row[0]->name,
                'description' => $row[0]->description,
                'current' => $current?->is($row[0]) ?? false,
                'total' => $row[3],
                'currency' => $row[4],
                'priced_count' => $row[2],
                'items_count' => $active->count(),
                'items' => $items->map(fn (ListItem $item) => [
                    'id' => $item->id,
                    'name' => $item->name,
                    'icon' => $item->custom_icon ?? $item->icon,
                    'status' => $item->status,
                    'price' => $row[1][$item->id]['line'] ?? null,
                    'currency' => $row[1][$item->id]['currency'] ?? null,
                ])->values()->all(),
            ])
            ->all();
    }
}
