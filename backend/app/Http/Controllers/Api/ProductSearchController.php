<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\OpenFoodFacts;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Prodotti di marca mentre si scrive ("latte parm" → Latte intero Parmalat 1 L), da Open Food Facts.
 */
class ProductSearchController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'max:100'],
            'country' => ['sometimes', Rule::in(array_keys(OpenFoodFacts::COUNTRIES))],
        ]);

        return response()->json(['data' => OpenFoodFacts::search($data['q'], $data['country'] ?? 'IT')]);
    }
}
