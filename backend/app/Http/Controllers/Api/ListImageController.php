<?php

namespace App\Http\Controllers\Api;

use App\Events\ListsChanged;
use App\Events\ShoppingListUpdated;
use App\Http\Controllers\Controller;
use App\Http\Resources\ShoppingListResource;
use App\Models\ShoppingList;
use App\Notifications\ListActivity;
use App\Support\Realtime;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Foto della lista. Il file non è pubblico: lo scarica solo chi può vedere la lista (con il token).
 */
class ListImageController extends Controller
{
    public function show(ShoppingList $list): StreamedResponse
    {
        $this->authorize('view', $list);
        abort_unless($list->image_path && Storage::exists($list->image_path), 404);

        // L'URL contiene la versione (?v=…): il file può restare in cache a lungo.
        return Storage::response($list->image_path, headers: ['Cache-Control' => 'private, max-age=31536000']);
    }

    public function store(Request $request, ShoppingList $list): ShoppingListResource
    {
        $this->authorize('update', $list);

        $request->validate(['image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192']]);

        $old = $list->image_path;
        $file = $request->file('image');
        $list->image_path = $file->storeAs('list-images', $list->id.'-'.Str::random(12).'.'.$file->extension());
        $list->save();
        if ($old) {
            Storage::delete($old);
        }
        ListActivity::notify($list, $request->user(), 'list_photo');

        return $this->changed($list);
    }

    public function destroy(ShoppingList $list): ShoppingListResource
    {
        $this->authorize('update', $list);

        if ($list->image_path) {
            Storage::delete($list->image_path);
            $list->image_path = null;
            $list->save();
        }

        return $this->changed($list);
    }

    private function changed(ShoppingList $list): ShoppingListResource
    {
        Realtime::broadcast(new ShoppingListUpdated($list));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));

        return new ShoppingListResource($list->load(['owner', 'items.creator', 'items.checker', 'sharedWith']));
    }
}
