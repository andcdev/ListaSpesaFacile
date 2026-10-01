<?php

use App\Http\Controllers\Api\AccountDeletionController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AvatarController;
use App\Http\Controllers\Api\ConfigController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\GlobalShareController;
use App\Http\Controllers\Api\ListImageController;
use App\Http\Controllers\Api\ListItemController;
use App\Http\Controllers\Api\ListItemImageController;
use App\Http\Controllers\Api\ListMessageController;
use App\Http\Controllers\Api\ListShareController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\ProductInfoController;
use App\Http\Controllers\Api\ProductMeasureController;
use App\Http\Controllers\Api\ProductSearchController;
use App\Http\Controllers\Api\ProductSuggestionController;
use App\Http\Controllers\Api\ShoppingListController;
use App\Http\Controllers\Api\SupermarketController;
use App\Http\Controllers\Api\UserPriceController;
use Illuminate\Support\Facades\Route;

Route::get('/config', ConfigController::class);

Route::middleware('throttle:10,1')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/auth/social/exchange', [AuthController::class, 'exchangeSocialCode']);
    Route::post('/forgot-password', [PasswordResetController::class, 'sendCode']);
    Route::post('/reset-password', [PasswordResetController::class, 'reset']);
    // Eliminazione dell'account dalla pagina listaspesafacile.com/elimina-account (anche senza l'app).
    Route::post('/account-deletion/code', [AccountDeletionController::class, 'sendCode']);
    Route::post('/account-deletion/confirm', [AccountDeletionController::class, 'confirm']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::patch('/me', [AuthController::class, 'update']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::delete('/me', [AuthController::class, 'destroy']);
    Route::post('/me/avatar', [AvatarController::class, 'store']);
    Route::delete('/me/avatar', [AvatarController::class, 'destroy']);
    Route::get('/users/{user}/avatar', [AvatarController::class, 'show']);

    Route::apiResource('lists', ShoppingListController::class)->parameters(['lists' => 'list']);
    Route::get('/products/suggestions', ProductSuggestionController::class);
    Route::get('/products/search', ProductSearchController::class)->middleware('throttle:60,1');
    Route::get('/products/measure', ProductMeasureController::class);
    Route::get('/supermarkets', [SupermarketController::class, 'index']);

    // I miei prezzi: li vede solo chi li ha scritti.
    Route::get('/me/prices', [UserPriceController::class, 'index']);
    Route::post('/me/prices', [UserPriceController::class, 'store']);
    Route::patch('/me/prices/{price}', [UserPriceController::class, 'update']);
    Route::delete('/me/prices/{price}', [UserPriceController::class, 'destroy']);

    Route::scopeBindings()->group(function () {
        Route::delete('/lists/{list}/items/checked', [ListItemController::class, 'destroyChecked']);
        Route::post('/lists/{list}/items', [ListItemController::class, 'store']);
        Route::patch('/lists/{list}/items/{item}', [ListItemController::class, 'update']);
        Route::delete('/lists/{list}/items/{item}', [ListItemController::class, 'destroy']);

        Route::get('/lists/{list}/items/{item}/image', [ListItemImageController::class, 'show']);
        Route::post('/lists/{list}/items/{item}/image', [ListItemImageController::class, 'store']);
        Route::delete('/lists/{list}/items/{item}/image', [ListItemImageController::class, 'destroy']);
        Route::get('/lists/{list}/items/{item}/info', ProductInfoController::class)->middleware('throttle:60,1');

    });

    Route::get('/lists/{list}/shares', [ListShareController::class, 'index']);
    Route::post('/lists/{list}/shares', [ListShareController::class, 'store']);
    Route::patch('/lists/{list}/shares/{user}', [ListShareController::class, 'update']);
    Route::delete('/lists/{list}/shares/{user}', [ListShareController::class, 'destroy']);

    Route::get('/lists/{list}/image', [ListImageController::class, 'show']);
    Route::post('/lists/{list}/image', [ListImageController::class, 'store']);
    Route::delete('/lists/{list}/image', [ListImageController::class, 'destroy']);

    Route::get('/lists/{list}/messages', [ListMessageController::class, 'index']);
    Route::post('/lists/{list}/messages', [ListMessageController::class, 'store'])->middleware('throttle:30,1');
    Route::post('/lists/{list}/messages/delivered', [ListMessageController::class, 'delivered']);
    Route::get('/lists/{list}/messages/{message}/image', [ListMessageController::class, 'image'])->scopeBindings();
    Route::delete('/lists/{list}/messages/{message}', [ListMessageController::class, 'destroy'])->scopeBindings();

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/read', [NotificationController::class, 'markRead']);
    Route::delete('/notifications', [NotificationController::class, 'destroyAll']);

    Route::post('/devices', [DeviceController::class, 'store']);
    Route::delete('/devices', [DeviceController::class, 'destroy']);

    Route::get('/global-shares', [GlobalShareController::class, 'index']);
    Route::post('/global-shares', [GlobalShareController::class, 'store']);
    Route::patch('/global-shares/{user}', [GlobalShareController::class, 'update']);
    Route::delete('/global-shares/{user}', [GlobalShareController::class, 'destroy']);
    Route::delete('/global-shares/received/{user}', [GlobalShareController::class, 'leave']);
});
