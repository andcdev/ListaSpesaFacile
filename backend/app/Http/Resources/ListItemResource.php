<?php

namespace App\Http\Resources;

use App\Models\ListItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ListItem
 */
class ListItemResource extends JsonResource
{
    /** Per gli eventi in tempo reale: niente di personale (la rettifica in attesa la vede solo chi l'ha scritta). */
    private bool $forEveryone = false;

    public function forEveryone(): static
    {
        $this->forEveryone = true;

        return $this;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $viewer = $this->forEveryone ? null : $request->user()?->id;
        $list = $this->shoppingList;

        return [
            'id' => $this->id,
            'shopping_list_id' => $this->shopping_list_id,
            'name' => $this->name,
            // Prodotto di marca scelto da Open Food Facts (null = scritto a mano).
            'barcode' => $this->barcode,
            'brand' => $this->brand,
            'category' => $this->category,
            // Emoji mostrata: quella scelta dall'utente oppure quella riconosciuta dal nome.
            'icon' => $this->custom_icon ?? $this->icon,
            'custom_icon' => $this->custom_icon,
            'image_url' => $this->image_url,
            // Foto caricata dal telefono: GET /api/lists/{list}/items/{id}/image?v={image_version}; null se non c'è.
            'image_version' => $this->imageVersion(),
            'quantity' => $this->quantity,
            'amount' => $this->amount,
            'unit' => $this->unit,
            // Prezzo indicativo nella catena e nella zona della lista (null se non si conosce) e da dove viene:
            // fonte (user, open_prices, catalog), nome e ora di chi l'ha segnalato, zona. Mai l'email.
            // Solo prezzi approvati: di Open Prices o rettifiche confermate da altri utenti.
            'price' => ($quote = $list?->quote($this->resource))['line'] ?? null,
            'price_info' => $quote ? collect($quote)->except('line')->all() : null,
            // La propria rettifica in attesa di conferma (solo nelle risposte a chi l'ha scritta, mai negli eventi).
            'my_price' => $this->when($viewer !== null, fn () => $list?->myPendingPrice($this->resource, $viewer)),
            // Rettifiche di altri in attesa di conferma: chi guarda la lista può confermarle.
            'pending_prices' => $list?->pendingPrices($this->resource, $viewer) ?? 0,
            'checked' => $this->checked,
            'status' => $this->status,
            'position' => $this->position,
            'created_by' => $this->creator?->name,
            // Chi l'ha segnato come preso o non preso.
            'checked_by' => $this->status !== 'todo' ? $this->checker?->name : null,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
