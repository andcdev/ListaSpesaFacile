<?php

use App\Http\Controllers\SocialAuthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Login social dall'app: aperti nel browser di sistema (Custom Tabs / ASWebAuthenticationSession).
Route::middleware('throttle:20,1')->whereIn('provider', ['google', 'facebook', 'amazon'])->group(function () {
    Route::get('/auth/{provider}/redirect', [SocialAuthController::class, 'redirect']);
    Route::get('/auth/{provider}/callback', [SocialAuthController::class, 'callback']);
});
