<?php

namespace App\Http\Controllers\Api;

use App\Events\ListsChanged;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/**
 * Persone bloccate. Bloccando qualcuno si tolgono tutte le condivisioni fra i due (in entrambe le direzioni) e
 * non se ne possono fare di nuove; i suoi messaggi nelle chat in comune non compaiono più e le sue modifiche non
 * arrivano come notifiche. Chi è bloccato non viene avvisato.
 */
class BlockController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return UserResource::collection($request->user()->blockedUsers()->orderBy('name')->get());
    }

    public function store(Request $request): AnonymousResourceCollection
    {
        $me = $request->user();
        $data = $request->validate(['user_id' => ['required', 'integer', 'exists:users,id']]);
        $other = User::findOrFail($data['user_id']);
        abort_if($other->is($me), 422);

        DB::transaction(function () use ($me, $other) {
            $me->blockedUsers()->syncWithoutDetaching([$other->id]);
            // Liste dell'uno condivise singolarmente con l'altro.
            DB::table('shopping_list_user')
                ->where(fn ($q) => $q->where('user_id', $other->id)
                    ->whereIn('shopping_list_id', $me->ownedLists()->select('id')))
                ->orWhere(fn ($q) => $q->where('user_id', $me->id)
                    ->whereIn('shopping_list_id', $other->ownedLists()->select('id')))
                ->delete();
            $me->globalShareRecipients()->detach($other->id);
            $me->globalShareOwners()->detach($other->id);
        });

        Realtime::broadcast(new ListsChanged([$me->id, $other->id]));

        return $this->index($request);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $request->user()->blockedUsers()->detach($user->id);

        return response()->json(status: 204);
    }
}
