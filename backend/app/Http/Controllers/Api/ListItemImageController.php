<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ListItemResource;
use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Notifications\ListActivity;
use App\Support\ImageModeration;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Foto di un prodotto scattata o scelta dalla galleria. Come la foto della lista non è pubblica:
 * la scarica solo chi può vedere la lista (con il token).
 */
class ListItemImageController extends Controller
{
    public function show(ShoppingList $list, ListItem $item): StreamedResponse
    {
        $this->authorize('view', $list);
        abort_unless($item->image_path && Storage::exists($item->image_path), 404);

        // L'URL contiene la versione (?v=…): il file può restare in cache a lungo.
        return Storage::response($item->image_path, headers: ['Cache-Control' => 'private, max-age=31536000']);
    }

    public function store(Request $request, ShoppingList $list, ListItem $item): ListItemResource
    {
        $this->authorize('update', $list);

        $request->validate(['image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192']]);

        $file = $request->file('image');
        ImageModeration::guard($file, $request->user(), 'item', $list, $item->name);
        $old = $item->image_path;
        $item->image_path = $file->storeAs(
            ListItem::IMAGE_DIR.'/'.$list->id,
            $item->id.'-'.Str::random(12).'.'.$file->extension(),
        );
        $item->save();
        if ($old) {
            Storage::delete($old);
        }

        ListItemController::broadcastSaved($list, $item);
        ListActivity::notify($list, $request->user(), 'item_photo', ['item' => ListItemController::label($item)]);

        return new ListItemResource($item->load(['creator', 'checker']));
    }

    public function destroy(ShoppingList $list, ListItem $item): ListItemResource
    {
        $this->authorize('update', $list);

        if ($item->image_path) {
            Storage::delete($item->image_path);
            $item->image_path = null;
            $item->save();
            ListItemController::broadcastSaved($list, $item);
        }

        return new ListItemResource($item->load(['creator', 'checker']));
    }
}
