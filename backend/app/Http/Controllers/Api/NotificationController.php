<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\NotificationResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class NotificationController extends Controller
{
    /**
     * Ultime 50 notifiche, dalla più recente, con il numero di non lette.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();

        return NotificationResource::collection($user->notifications()->limit(50)->get())
            ->additional(['unread_count' => $user->unreadNotifications()->count()]);
    }

    /**
     * Segna come lette tutte le notifiche, oppure solo quelle indicate in "ids".
     */
    public function markRead(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['sometimes', 'array', 'max:100'],
            'ids.*' => ['string'],
        ]);

        $request->user()->unreadNotifications()
            ->when(isset($data['ids']), fn ($q) => $q->whereIn('id', $data['ids']))
            ->update(['read_at' => now()]);

        return response()->json(['unread_count' => $request->user()->unreadNotifications()->count()]);
    }

    public function destroyAll(Request $request): JsonResponse
    {
        $request->user()->notifications()->delete();

        return response()->json(status: 204);
    }
}
