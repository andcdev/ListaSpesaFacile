<?php

use App\Http\Middleware\SetLocale;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // L'app mobile si autentica con token Sanctum anche sul canale WebSocket: POST /api/broadcasting/auth
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['prefix' => 'api', 'middleware' => ['auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // In produzione l'app è dietro Caddy (reverse proxy nel docker-compose).
        $middleware->trustProxies(at: '*');
        // Lingua delle risposte, delle notifiche e delle email (italiano, inglese, francese, tedesco, spagnolo).
        $middleware->appendToGroup('api', SetLocale::class);
        $middleware->appendToGroup('web', SetLocale::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
