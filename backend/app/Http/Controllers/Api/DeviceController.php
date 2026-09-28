<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Registrazione dei dispositivi per le notifiche push (token Firebase Cloud Messaging).
 */
class DeviceController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:255'],
            'platform' => ['sometimes', 'string', 'in:android,ios'],
        ]);

        // Lo stesso telefono può passare da un account all'altro: il token appartiene all'ultimo utente.
        DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            ['user_id' => $request->user()->id, 'platform' => $data['platform'] ?? 'android'],
        );

        return response()->json(status: 204);
    }

    /**
     * Al logout: il dispositivo non riceve più notifiche per questo utente.
     */
    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['token' => ['required', 'string']]);

        $request->user()->deviceTokens()->where('token', $data['token'])->delete();

        return response()->json(status: 204);
    }
}
