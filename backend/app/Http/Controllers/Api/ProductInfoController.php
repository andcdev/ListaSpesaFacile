<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Support\OpenFoodFacts;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Info di un articolo (menu ⋮ → Info): codice a barre, foto, calorie e valori nutrizionali, ingredienti, allergeni e
 * se è adatto a celiaci, vegetariani e vegani, da Open Food Facts. Per un articolo scritto a mano si usa il prodotto
 * più simile al nome (matched_by = "name"); data = null se non si trova niente.
 */
class ProductInfoController extends Controller
{
    public function __invoke(Request $request, ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('view', $list);

        $country = OpenFoodFacts::countryForLocale($request->user()->locale);

        return response()->json(['data' => OpenFoodFacts::productFor($item->barcode, $item->name, $country)]);
    }
}
