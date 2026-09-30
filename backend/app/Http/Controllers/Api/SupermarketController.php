<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Support\OpenFoodFacts;
use App\Support\PriceEstimator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupermarketController extends Controller
{
    /**
     * Catene del paese della lista, per suggerire il supermercato mentre si scrive.
     */
    public function index(Request $request): JsonResponse
    {
        $country = $request->validate([
            'country' => ['sometimes', Rule::in(array_keys(OpenFoodFacts::COUNTRIES))],
        ])['country'] ?? 'IT';

        $supermarkets = Supermarket::query()
            ->whereKey(Supermarket::forCountry($country)->modelKeys())
            ->withCount(['reports' => fn ($q) => $q->where('country', $country)->where('status', PriceReport::APPROVED)])
            ->orderBy('name')
            ->get()
            ->map(fn (Supermarket $s) => [
                'id' => $s->id,
                'name' => $s->name,
                'description' => $s->description,
                'has_prices' => $s->reports_count > 0,
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
