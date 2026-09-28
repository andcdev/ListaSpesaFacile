<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\ProductSuggestions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Prodotti da suggerire mentre si scrive: già usati (dal più frequente), poi i più comuni.
 */
class ProductSuggestionController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        return response()->json(['data' => ProductSuggestions::for($request->user())]);
    }
}
