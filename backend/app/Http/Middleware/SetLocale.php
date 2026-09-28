<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Lingua della risposta: quella scelta nell'app (header Accept-Language), altrimenti quella salvata
 * per l'utente, altrimenti l'italiano. La lingua dell'app viene ricordata per l'utente, così notifiche,
 * promemoria ed email (inviati senza una richiesta dell'utente) arrivano nella sua lingua.
 */
class SetLocale
{
    public const SUPPORTED = ['it', 'en', 'fr', 'de', 'es'];

    public function handle(Request $request, Closure $next): Response
    {
        $fromHeader = $request->hasHeader('Accept-Language') ? $request->getPreferredLanguage(self::SUPPORTED) : null;
        app()->setLocale($fromHeader ?? $request->user()?->locale ?? config('app.locale'));

        $response = $next($request);

        // Dopo la richiesta: sulle rotte protette l'utente è ormai autenticato.
        $user = $request->user();
        if ($fromHeader !== null && $user !== null && $user->locale !== $fromHeader) {
            $user->forceFill(['locale' => $fromHeader])->saveQuietly();
        }

        return $response;
    }
}
