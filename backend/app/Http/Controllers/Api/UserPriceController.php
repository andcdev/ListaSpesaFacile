<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserPrice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * "I miei prezzi": i prezzi che l'utente si annota per i prodotti. Li vede e li modifica solo lui.
 */
class UserPriceController extends Controller
{
    /**
     * Dal più recente; con ?q= solo quelli del prodotto o del supermercato cercato.
     */
    public function index(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('q', ''));
        $prices = $request->user()->prices()
            ->when($search !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('product_name', 'like', "%$search%")
                ->orWhere('brand', 'like', "%$search%")
                ->orWhere('supermarket', 'like', "%$search%")
                ->orWhere('barcode', $search)))
            ->latest('updated_at')
            ->latest('id')
            ->limit(500)
            ->get();

        return response()->json(['data' => $prices->map->toApi()->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $price = $request->user()->prices()->create($this->validated($request));

        return response()->json(['data' => $price->toApi()], 201);
    }

    public function update(Request $request, UserPrice $price): JsonResponse
    {
        $this->owned($request, $price);
        $price->update($this->validated($request, partial: true));

        return response()->json(['data' => $price->toApi()]);
    }

    public function destroy(Request $request, UserPrice $price): JsonResponse
    {
        $this->owned($request, $price);
        $price->delete();

        return response()->json(status: 204);
    }

    /**
     * Il prezzo di un altro utente non esiste, per chi non è lui.
     */
    private function owned(Request $request, UserPrice $price): void
    {
        abort_unless($price->user_id === $request->user()->id, 404);
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'product_name' => [$required, 'string', 'max:150'],
            'price' => [$required, 'numeric', 'min:0.01', 'max:99999999'],
            'per' => ['sometimes', Rule::in(UserPrice::PER)],
            'barcode' => ['sometimes', 'nullable', 'string', 'regex:/^\d{4,20}$/'],
            'brand' => ['sometimes', 'nullable', 'string', 'max:100'],
            'supermarket' => ['sometimes', 'nullable', 'string', 'max:100'],
            'note' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);
    }
}
