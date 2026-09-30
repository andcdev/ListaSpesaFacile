<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Support\PriceEstimator;
use Illuminate\Http\JsonResponse;

class SupermarketController extends Controller
{
    /**
     * Catene note, per suggerire il supermercato mentre si scrive.
     */
    public function index(): JsonResponse
    {
        $supermarkets = Supermarket::query()
            ->withCount('prices')
            ->orderBy('name')
            ->get()
            ->map(fn (Supermarket $s) => [
                'id' => $s->id,
                'name' => $s->name,
                'description' => $s->description,
                'has_prices' => $s->prices_count > 0,
            ]);

        return response()->json(['data' => $supermarkets]);
    }

    /**
     * Quanto costerebbe la lista in ogni catena con dei prezzi, con il dettaglio articolo per articolo.
     */
    public function compare(ShoppingList $list): JsonResponse
    {
        $this->authorize('view', $list);

        $list->load('items');

        return response()->json(['data' => PriceEstimator::compare($list)]);
    }
}
