<?php

namespace App\Http\Controllers\Api;

use App\Events\ListItemSaved;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListItemResource;
use App\Models\ListItem;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Models\User;
use App\Support\OpenFoodFacts;
use App\Support\PriceBook;
use App\Support\ProductCatalog;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Prezzi di un articolo nella catena e nella zona della lista. Si mostra quello della zona più vicina con più
 * conferme; toccandolo si vedono gli altri, si conferma quello giusto o se ne propone uno nuovo.
 *
 * Un prezzo proposto da un utente lo vede subito solo lui; gli altri lo vedono dopo la conferma di altri utenti
 * (config prices.approvals_required). Di chi propone si mostrano nome e ora; l'email si conserva ma non si mostra.
 */
class ItemPriceController extends Controller
{
    public function index(Request $request, ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('view', $list);

        return response()->json(['data' => $this->prices($list, $item, $request->user())]);
    }

    /**
     * Prezzo proposto dall'utente. Se nella stessa città c'è già lo stesso prezzo, vale come conferma di quello.
     */
    public function store(Request $request, ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('view', $list);

        $data = $request->validate([
            'price' => ['required', 'numeric', 'min:0.01', 'max:10000'],
            'per' => ['sometimes', Rule::in(['pz', 'kg', 'l'])],
            'country' => ['sometimes', Rule::in(array_keys(OpenFoodFacts::COUNTRIES))],
            'province' => ['sometimes', 'nullable', 'string', 'max:100'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'locality' => ['sometimes', 'nullable', 'string', 'max:100'],
        ]);
        $chain = $this->chain($list);
        $user = $request->user();
        $per = $data['per'] ?? 'pz';
        $zone = [
            $data['country'] ?? $list->country ?? 'IT',
            array_key_exists('province', $data) ? $data['province'] : $list->province,
            array_key_exists('city', $data) ? $data['city'] : $list->city,
            array_key_exists('locality', $data) ? $data['locality'] : $list->locality,
        ];

        $same = $this->reports($chain, $item, $zone[0])
            ->where('per', $per)
            ->where('status', '!=', PriceReport::REJECTED)
            ->get()
            ->first(fn (PriceReport $r) => abs($r->price - $data['price']) < 0.005 && PriceBook::zoneRank($zone, $r) >= 3);

        if ($same && $same->user_id !== $user->id) {
            $same->vote($user, true);
        } elseif (! $same) {
            // Una sola proposta in attesa per utente e prodotto: quella nuova sostituisce la precedente.
            $this->reports($chain, $item, $zone[0])->where('user_id', $user->id)->where('status', PriceReport::PENDING)->delete();
            // Prezzo a confezione: il contenuto della confezione è il peso o volume dell'articolo, se c'è.
            $package = $per === 'pz' ? PriceBook::package($item->amount, $item->unit) : null;
            PriceReport::create([
                'supermarket_id' => $chain->id,
                'product_key' => ProductCatalog::productKey($item->name),
                'barcode' => $item->barcode,
                'product_name' => mb_substr($item->name, 0, 150),
                'price' => $data['price'],
                'currency' => OpenFoodFacts::currency($zone[0]),
                'per' => $per,
                'package_amount' => $package[0] ?? null,
                'package_unit' => $package[1] ?? null,
                'country' => $zone[0],
                'province' => $zone[1],
                'city' => $zone[2],
                'locality' => $zone[3],
                'source' => PriceReport::SOURCE_USER,
                'status' => PriceReport::PENDING,
                'user_id' => $user->id,
                'reporter_name' => $user->name,
                'reporter_email' => $user->email,
                'observed_at' => now(),
            ]);
        }

        $this->broadcast($list, $item);
        $fresh = $list->items->firstWhere('id', $item->id);

        return (new ListItemResource($fresh->load(['creator', 'checker'])))->response()->setStatusCode(201);
    }

    /**
     * Conferma (approve = true) o smentita di un prezzo proposto da altri o importato da Open Prices.
     */
    public function vote(Request $request, ShoppingList $list, ListItem $item, PriceReport $report): JsonResponse
    {
        $this->authorize('view', $list);
        $data = $request->validate(['approve' => ['required', 'boolean']]);
        $chain = $this->chain($list);
        $user = $request->user();

        if ($report->supermarket_id !== $chain->id || $report->country !== ($list->country ?? 'IT')) {
            abort(404);
        }
        if ($report->user_id === $user->id) {
            throw ValidationException::withMessages(['approve' => [__('app.errors.own_price_vote')]]);
        }

        $report->vote($user, (bool) $data['approve']);
        $this->broadcast($list, $item);

        return response()->json(['data' => $this->prices($list, $item, $user)]);
    }

    /**
     * Prezzo mostrato, la propria proposta in attesa e tutti i prezzi della catena per il prodotto nello stesso stato:
     * dalla zona più vicina, poi i confermati, poi con più conferme, poi i più recenti.
     *
     * @return array<string, mixed>
     */
    private function prices(ShoppingList $list, ListItem $item, User $user): array
    {
        $item->setRelation('shoppingList', $list);
        $chain = $list->supermarketChain();
        $zone = $list->zone();
        $reports = $chain === null ? collect() : $this->reports($chain, $item, $zone[0])
            ->where(fn (Builder $q) => $q->where('status', '!=', PriceReport::REJECTED)->orWhere('user_id', $user->id))
            // Le proposte in attesa degli altri si vedono per poterle confermare.
            ->with(['votes' => fn ($q) => $q->where('user_id', $user->id)])
            ->orderByDesc('observed_at')
            ->limit(200)
            ->get()
            ->sortBy([
                fn ($a, $b) => PriceBook::zoneRank($zone, $b) <=> PriceBook::zoneRank($zone, $a),
                fn ($a, $b) => ($b->status === PriceReport::APPROVED) <=> ($a->status === PriceReport::APPROVED),
                fn ($a, $b) => $b->approvals <=> $a->approvals,
                fn ($a, $b) => $b->observed_at <=> $a->observed_at,
            ])
            ->take(30);

        return [
            'supermarket' => $chain?->name,
            'zone' => ['country' => $list->country, 'province' => $list->province, 'city' => $list->city, 'locality' => $list->locality],
            'current' => $list->quote($item),
            'mine' => $list->myPendingPrice($item, $user->id),
            'reports' => $reports->map(fn (PriceReport $r) => [
                ...$r->setRelation('supermarket', $chain)->toPublicArray(),
                'mine' => $r->user_id === $user->id,
                'my_vote' => $r->votes->first()?->approve,
                'nearby' => PriceBook::zoneRank($zone, $r) >= 3,
            ])->values()->all(),
        ];
    }

    private function chain(ShoppingList $list): Supermarket
    {
        return $list->supermarketChain()
            ?? throw ValidationException::withMessages(['price' => [__('app.errors.unknown_supermarket')]]);
    }

    /**
     * Prezzi della catena per il prodotto nello stato: dello stesso prodotto di marca se ce ne sono, altrimenti dello
     * stesso tipo di prodotto.
     *
     * @return Builder<PriceReport>
     */
    private function reports(Supermarket $chain, ListItem $item, string $country): Builder
    {
        $query = PriceReport::query()->where('supermarket_id', $chain->id)->where('country', $country);
        $key = ProductCatalog::productKey($item->name);
        if ($item->barcode && (clone $query)->where('barcode', $item->barcode)->exists()) {
            return $query->where('barcode', $item->barcode);
        }

        return $key !== null ? $query->where('product_key', $key) : $query->whereRaw('1 = 0');
    }

    /**
     * Il prezzo mostrato (o il numero di proposte da confermare) può cambiare per tutti gli articoli uguali della lista.
     */
    private function broadcast(ShoppingList $list, ListItem $item): void
    {
        $list->forgetPrices();
        $list->load('items');
        $list->items->each->setRelation('shoppingList', $list);
        $key = ProductCatalog::productKey($item->name);
        foreach ($list->items as $other) {
            if ($other->id === $item->id || ($key !== null && ProductCatalog::productKey($other->name) === $key)) {
                Realtime::broadcast(new ListItemSaved($other));
            }
        }
    }
}
