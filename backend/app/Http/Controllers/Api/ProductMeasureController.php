<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\ProductCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Come si misura un prodotto scritto a mano, prima di aggiungerlo: solo peso, peso e pezzi o confezioni
 * (vedi ProductCatalog::measure; non riconosciuto = confezione). L'app lo usa per mostrare nel popup solo i
 * campi che servono.
 */
class ProductMeasureController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:255']]);

        return response()->json(['data' => ['measure' => ProductCatalog::measure($data['name'])]]);
    }
}
