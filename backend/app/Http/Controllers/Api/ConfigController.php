<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ListItem;
use App\Support\Fcm;
use App\Support\ProductCatalog;
use App\Support\SocialProviders;
use Illuminate\Http\JsonResponse;

/**
 * Parametri pubblici per l'app: server WebSocket (Reverb), provider di login social attivi e notifiche push.
 */
class ConfigController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'realtime' => config('services.realtime'),
            'social_providers' => SocialProviders::enabled(),
            // Il server invia notifiche push (Firebase configurato): altrimenti l'app programma i promemoria sul telefono.
            'push' => app(Fcm::class)->enabled(),
            // Reparti degli articoli (nome e icona), per la scelta manuale nell'app.
            'product_categories' => ProductCatalog::categories(),
            'units' => ListItem::UNITS,
        ]);
    }
}
