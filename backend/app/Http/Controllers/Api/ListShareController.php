<?php

namespace App\Http\Controllers\Api;

use App\Events\ListsChanged;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListShared;
use App\Support\Notifier;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * Condivisione di una singola lista con uno o più utenti.
 */
class ListShareController extends Controller
{
    public function index(ShoppingList $list): AnonymousResourceCollection
    {
        $this->authorize('view', $list);

        return UserResource::collection($list->sharedWith()->orderBy('name')->get());
    }

    public function store(Request $request, ShoppingList $list): AnonymousResourceCollection
    {
        $this->authorize('share', $list);

        $data = $request->validate([
            'email' => ['required', 'email'],
            'can_edit' => ['sometimes', 'boolean'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if (! $user) {
            throw ValidationException::withMessages(['email' => [__('app.errors.no_user')]]);
        }
        if ($user->id === $list->owner_id) {
            throw ValidationException::withMessages(['email' => [__('app.errors.already_owner')]]);
        }

        $canEdit = (bool) ($data['can_edit'] ?? true);
        $changes = $list->sharedWith()->syncWithoutDetaching([$user->id => ['can_edit' => $canEdit]]);

        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));

        // Solo alla prima condivisione, non quando cambia il permesso.
        if ($changes['attached'] !== []) {
            Notifier::send([$user], new ListShared($request->user()->name, $list->id, $list->name, $canEdit));
        }

        return $this->index($list);
    }

    /**
     * Revoca la condivisione (proprietario) oppure abbandona la lista (utente condiviso).
     */
    public function destroy(Request $request, ShoppingList $list, User $user): JsonResponse
    {
        if (! $user->is($request->user())) {
            $this->authorize('share', $list);
        }

        $audience = $list->audienceIds();
        $list->sharedWith()->detach($user->id);

        Realtime::broadcast(new ListsChanged($audience, $list->id));

        return response()->json(status: 204);
    }
}
