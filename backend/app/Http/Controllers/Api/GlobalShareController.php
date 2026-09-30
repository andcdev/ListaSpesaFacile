<?php

namespace App\Http\Controllers\Api;

use App\Events\ListsChanged;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Notifications\GlobalShareReceived;
use App\Support\Notifier;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Condivisione globale: tutte le liste dell'utente, anche future, con un altro utente.
 */
class GlobalShareController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            // Utenti con cui condivido tutte le mie liste.
            'shared_with' => UserResource::collection($user->globalShareRecipients()->orderBy('name')->get()),
            // Utenti che condividono tutte le loro liste con me.
            'shared_by' => UserResource::collection($user->globalShareOwners()->orderBy('name')->get()),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $owner = $request->user();

        $data = $request->validate([
            'email' => ['required', 'email'],
            'can_edit' => ['sometimes', 'boolean'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if (! $user) {
            throw ValidationException::withMessages(['email' => [__('app.errors.no_user')]]);
        }
        if ($user->is($owner)) {
            throw ValidationException::withMessages(['email' => [__('app.errors.share_self_all')]]);
        }

        $canEdit = (bool) ($data['can_edit'] ?? true);
        $changes = $owner->globalShareRecipients()->syncWithoutDetaching([$user->id => ['can_edit' => $canEdit]]);

        Realtime::broadcast(new ListsChanged([$owner->id, $user->id]));

        if ($changes['attached'] !== []) {
            Notifier::send([$user], new GlobalShareReceived($owner->name, $canEdit));
        }

        return $this->index($request);
    }

    /**
     * Cambia il permesso su tutte le mie liste per chi le riceve già: sola lettura oppure lettura e modifica.
     */
    public function update(Request $request, User $user): JsonResponse
    {
        $owner = $request->user();
        $data = $request->validate(['can_edit' => ['required', 'boolean']]);

        abort_unless($owner->globalShareRecipients()->whereKey($user->id)->exists(), 404);
        $owner->globalShareRecipients()->updateExistingPivot($user->id, ['can_edit' => (bool) $data['can_edit']]);

        Realtime::broadcast(new ListsChanged([$owner->id, $user->id]));

        return $this->index($request);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $owner = $request->user();

        $owner->globalShareRecipients()->detach($user->id);

        Realtime::broadcast(new ListsChanged([$owner->id, $user->id]));

        return response()->json(status: 204);
    }

    /**
     * Rinuncia a una condivisione globale ricevuta.
     */
    public function leave(Request $request, User $user): JsonResponse
    {
        $me = $request->user();

        $me->globalShareOwners()->detach($user->id);

        Realtime::broadcast(new ListsChanged([$me->id, $user->id]));

        return response()->json(status: 204);
    }
}
