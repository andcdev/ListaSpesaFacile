<?php

namespace App\Http\Controllers\Api;

use App\Events\ListItemDeleted;
use App\Events\ListItemSaved;
use App\Events\ListsChanged;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListItemResource;
use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Notifications\ListActivity;
use App\Support\ProductCatalog;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ListItemController extends Controller
{
    public function store(Request $request, ShoppingList $list): JsonResponse
    {
        $this->authorize('update', $list);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'quantity' => ['nullable', 'string', 'max:50'],
            ...$this->measureRules(),
        ]);

        $item = new ListItem($data);
        // La foto di un prodotto di marca scelto dai suggerimenti è del prodotto: se ne va se l'articolo cambia nome.
        $item->image_auto = $item->barcode !== null && $item->image_url !== null;
        $item->position = (int) $list->items()->max('position') + 1;
        $item->created_by = $request->user()->id;
        $list->items()->save($item);
        $item->setRelation('shoppingList', $list);

        self::broadcastSaved($list, $item);
        ListActivity::notify($list, $request->user(), 'added', ['item' => self::label($item)]);

        return (new ListItemResource($item->load(['creator', 'checker'])))
            ->response()
            ->setStatusCode(201);
    }

    public function update(Request $request, ShoppingList $list, ListItem $item): ListItemResource
    {
        $this->authorize('update', $list);

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'quantity' => ['sometimes', 'nullable', 'string', 'max:50'],
            'checked' => ['sometimes', 'boolean'],
            'status' => ['sometimes', Rule::in(ListItem::STATUSES)],
            'position' => ['sometimes', 'integer', 'min:0'],
            ...$this->measureRules(),
        ]);

        $item->fill($data);
        $item->setRelation('shoppingList', $list);
        // Rinominato senza scegliere un altro prodotto di marca: non è più quel prodotto.
        if ($item->isDirty('name') && ! array_key_exists('barcode', $data)) {
            $item->barcode = null;
            $item->brand = null;
        }
        // La foto del prodotto di marca se ne va con il prodotto, rinominando; un link scelto a mano resta.
        if ($item->isDirty('image_url')) {
            $item->image_auto = false;
        } elseif ($item->isDirty('name') && $item->image_auto) {
            $item->image_url = null;
            $item->image_auto = false;
        }
        // Le app più vecchie mandano solo "checked".
        if ($item->isDirty('checked') && ! $item->isDirty('status')) {
            $item->status = $item->checked ? 'taken' : 'todo';
        }
        // Chi ha segnato l'articolo come preso o non preso.
        if ($item->isDirty('status')) {
            $item->checked_by = $item->status === 'todo' ? null : $request->user()->id;
        }
        $action = match (true) {
            $item->isDirty('status') => match ($item->status) {
                'taken' => 'taken',
                'missing' => 'missing',
                default => 'todo',
            },
            // Il solo riordino non interessa agli altri.
            $item->isDirty() && array_keys($item->getDirty()) !== ['position'] => 'edited',
            default => null,
        };
        $item->save();

        self::broadcastSaved($list, $item);
        if ($action !== null) {
            ListActivity::notify($list, $request->user(), $action, ['item' => self::label($item)]);
        }

        return new ListItemResource($item->load(['creator', 'checker']));
    }

    public function destroy(Request $request, ShoppingList $list, ListItem $item): JsonResponse
    {
        $this->authorize('update', $list);

        $item->delete();

        $this->broadcastDeleted($list, [$item->id]);
        ListActivity::notify($list, $request->user(), 'deleted', ['item' => self::label($item)]);

        return response()->json(status: 204);
    }

    /**
     * Elimina tutti gli articoli già presi.
     */
    public function destroyChecked(Request $request, ShoppingList $list): JsonResponse
    {
        $this->authorize('update', $list);

        $items = $list->items()->where('checked', true)->get();
        $ids = $items->modelKeys();

        if ($ids !== []) {
            // Uno per uno: con l'articolo se ne va anche la sua foto.
            $items->each->delete();
            $list->touch();
            $this->broadcastDeleted($list, $ids);
            ListActivity::notify($list, $request->user(), 'cleared', ['count' => count($ids)]);
        }

        return response()->json(['deleted' => count($ids)]);
    }

    /**
     * Es. "🥛 Latte", per le notifiche.
     */
    public static function label(ListItem $item): string
    {
        return trim(($item->custom_icon ?? $item->icon).' '.$item->name);
    }

    /**
     * Peso/volume (amount + unit) e reparto scelto a mano (se assente viene riconosciuto dal nome).
     *
     * @return array<string, mixed>
     */
    private function measureRules(): array
    {
        return [
            'amount' => ['sometimes', 'nullable', 'numeric', 'gt:0', 'max:100000'],
            'unit' => ['nullable', 'required_with:amount', Rule::in(ListItem::UNITS)],
            'category' => ['sometimes', Rule::in(array_keys(ProductCatalog::CATEGORIES))],
            // Emoji scelta a mano (null = torna quella riconosciuta) e link a un'immagine esterna.
            'custom_icon' => ['sometimes', 'nullable', 'string', 'max:16'],
            'image_url' => ['sometimes', 'nullable', 'url:http,https', 'max:2048'],
            // Prodotto di marca scelto tra i suggerimenti di Open Food Facts.
            'barcode' => ['sometimes', 'nullable', 'string', 'regex:/^\d{4,20}$/'],
            'brand' => ['sometimes', 'nullable', 'string', 'max:100'],
        ];
    }

    public static function broadcastSaved(ShoppingList $list, ListItem $item): void
    {
        Realtime::broadcast(new ListItemSaved($item));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
    }

    /**
     * @param  array<int, int>  $ids
     */
    private function broadcastDeleted(ShoppingList $list, array $ids): void
    {
        Realtime::broadcast(new ListItemDeleted($list->id, $ids));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
    }
}
