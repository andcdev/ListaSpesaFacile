<?php

use App\Http\Controllers\ModerationController;
use App\Http\Controllers\SocialAuthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Login social dall'app: aperti nel browser di sistema (Custom Tabs / ASWebAuthenticationSession).
Route::middleware('throttle:20,1')->whereIn('provider', ['google', 'amazon'])->group(function () {
    Route::get('/auth/{provider}/redirect', [SocialAuthController::class, 'redirect']);
    Route::get('/auth/{provider}/callback', [SocialAuthController::class, 'callback']);
});

// Pulsanti nelle email all'assistenza (segnalazioni e foto rifiutate): link firmati che scadono, vedi ModerationLinks.
Route::middleware(['signed', 'throttle:30,1'])->prefix('moderazione')->name('moderazione.')->group(function () {
    Route::get('/foto/{report}', [ModerationController::class, 'image'])->name('foto');
    Route::get('/sospendi/{user}', [ModerationController::class, 'confirmSuspend'])->name('sospendi');
    Route::post('/sospendi/{user}', [ModerationController::class, 'suspend']);
    Route::get('/riattiva/{user}', [ModerationController::class, 'confirmReactivate'])->name('riattiva');
    Route::post('/riattiva/{user}', [ModerationController::class, 'reactivate']);
});
