<?php

namespace App\Http\Controllers\Api;

use App\Events\ListItemSaved;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListItemResource;
use App\Models\ListItem;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Support\OpenFoodFacts;
use App\Support\PriceBook;
use App\Support\ProductCatalog;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Prezzi di un articolo nella catena della lista: da dove viene quello mostrato, le segnalazioni precedenti
 * e la rettifica di un utente (prezzo, zona, nome e ora; l'email si conserva ma non si mostra).
 */
class ItemPriceController extends Controller
{
    public function index(ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('view', $list);
        $item->setRelation('shoppingList', $list);

        $chain = $list->supermarketChain();
        $reports = $chain === null ? collect() : $this->reports($list, $item)->limit(30)->get();

        return response()->json([
            'data' => [
                'supermarket' => $chain?->name,
                'zone' => ['country' => $list->country, 'city' => $list->city, 'locality' => $list->locality],
                'current' => $list->quote($item),
                'reports' => $reports->map(fn (PriceReport $r) => $r->setRelation('supermarket', $chain)->toPublicArray())->all(),
            ],
        ]);
    }

    /**
     * Rettifica del prezzo: vale per tutti gli utenti che fanno la spesa in questa catena, prima di tutto nella stessa zona.
     */
    public function store(Request $request, ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('view', $list);

        $data = $request->validate([
            'price' => ['required', 'numeric', 'min:0.01', 'max:10000'],
            'per' => ['sometimes', Rule::in(['pz', 'kg', 'l'])],
            'country' => ['sometimes', Rule::in(array_keys(OpenFoodFacts::COUNTRIES))],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'locality' => ['sometimes', 'nullable', 'string', 'max:100'],
        ]);
        $chain = $list->supermarketChain();
        if ($chain === null) {
            throw ValidationException::withMessages(['price' => [__('app.errors.unknown_supermarket')]]);
        }

        $user = $request->user();
        $per = $data['per'] ?? 'pz';
        // Prezzo a confezione: il contenuto della confezione è il peso o volume dell'articolo, se c'è.
        $package = $per === 'pz' ? PriceBook::package($item->amount, $item->unit) : null;
        PriceReport::create([
            'supermarket_id' => $chain->id,
            'product_key' => ProductCatalog::productKey($item->name),
            'barcode' => $item->barcode,
            'product_name' => mb_substr($item->name, 0, 150),
            'price' => $data['price'],
            'per' => $per,
            'package_amount' => $package[0] ?? null,
            'package_unit' => $package[1] ?? null,
            'country' => $data['country'] ?? $list->country ?? 'IT',
            'city' => array_key_exists('city', $data) ? $data['city'] : $list->city,
            'locality' => array_key_exists('locality', $data) ? $data['locality'] : $list->locality,
            'source' => PriceReport::SOURCE_USER,
            'user_id' => $user->id,
            'reporter_name' => $user->name,
            'reporter_email' => $user->email,
            'observed_at' => now(),
        ]);

        // Il nuovo prezzo può valere anche per gli altri articoli uguali della lista.
        $list->forgetPrices();
        $list->load('items');
        $list->items->each->setRelation('shoppingList', $list);
        $key = ProductCatalog::productKey($item->name);
        foreach ($list->items as $other) {
            if ($other->is($item) || ($key !== null && ProductCatalog::productKey($other->name) === $key)) {
                Realtime::broadcast(new ListItemSaved($other));
            }
        }

        $fresh = $list->items->firstWhere('id', $item->id);

        return (new ListItemResource($fresh->load(['creator', 'checker'])))->response()->setStatusCode(201);
    }

    /**
     * Segnalazioni dello stesso prodotto di marca o, se non ce ne sono, dello stesso tipo di prodotto, dalla più recente.
     */
    private function reports(ShoppingList $list, ListItem $item)
    {
        $query = PriceReport::query()->where('supermarket_id', $list->supermarketChain()->id);
        $key = ProductCatalog::productKey($item->name);
        if ($item->barcode && (clone $query)->where('barcode', $item->barcode)->exists()) {
            $query->where('barcode', $item->barcode);
        } elseif ($key !== null) {
            $query->where('product_key', $key);
        } else {
            $query->whereRaw('1 = 0');
        }

        return $query->orderByDesc('observed_at')->orderByDesc('id');
    }
}
