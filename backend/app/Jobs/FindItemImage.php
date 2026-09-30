<?php

namespace App\Jobs;

use App\Events\ListItemSaved;
use App\Models\ListItem;
use App\Support\OpenFoodFacts;
use App\Support\Realtime;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Cerca su Open Food Facts una foto per l'articolo appena aggiunto o rinominato e la mostra a chi guarda la lista.
 * Non tocca le foto caricate dal telefono né i link scelti dall'utente.
 */
class FindItemImage implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public function __construct(public int $itemId, public string $name) {}

    public function handle(): void
    {
        $item = ListItem::with('shoppingList')->find($this->itemId);
        // Rinominato di nuovo nel frattempo: ci pensa il job del nome nuovo.
        if (! $item || $item->name !== $this->name || ! self::wanted($item)) {
            return;
        }

        $url = OpenFoodFacts::imageFor($item->name, $item->shoppingList->country ?? 'IT');
        if ($url === null || $url === $item->image_url) {
            return;
        }
        $item->update(['image_url' => $url, 'image_auto' => true]);
        Realtime::broadcast(new ListItemSaved($item));
    }

    /**
     * Serve una foto automatica: nessuna foto dal telefono e nessun link scelto a mano.
     */
    public static function wanted(ListItem $item): bool
    {
        return $item->image_path === null && ($item->image_url === null || $item->image_auto);
    }
}
