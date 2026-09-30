<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Endpoint WebSocket pubblico (raggiunto dall'app, di solito tramite il reverse proxy).
    'realtime' => [
        'key' => env('REVERB_APP_KEY'),
        'host' => env('REVERB_PUBLIC_HOST', env('REVERB_HOST', 'localhost')),
        'port' => (int) env('REVERB_PUBLIC_PORT', env('REVERB_PORT', 8080)),
        'scheme' => env('REVERB_PUBLIC_SCHEME', env('REVERB_SCHEME', 'http')),
    ],

    // Accesso con Google e Amazon (flusso OAuth gestito dal server, vedi SocialAuthController).
    // Un provider è attivo solo se ha client_id e client_secret.
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('APP_URL').'/auth/google/callback',
    ],

    'amazon' => [
        'client_id' => env('AMAZON_CLIENT_ID'),
        'client_secret' => env('AMAZON_CLIENT_SECRET'),
        'redirect' => env('APP_URL').'/auth/amazon/callback',
    ],

    // Notifiche push con Firebase Cloud Messaging: file JSON del service account
    // (Console Firebase → Impostazioni progetto → Account di servizio → Genera nuova chiave privata).
    // Se il file non esiste le notifiche push sono disattivate.
    'fcm' => [
        'credentials' => env('FCM_CREDENTIALS', base_path('secrets/firebase-service-account.json')),
    ],

    // Indirizzo con cui il server riapre l'app al termine del login social (schema registrato nell'app).
    'social_app_callback' => env('SOCIAL_APP_CALLBACK', 'listaspesafacile://auth'),

    // Open Food Facts (prodotti di marca, foto e informazioni). Spento nei test, che lo riaccendono con le risposte
    // finte.
    'openfoodfacts' => [
        'enabled' => (bool) env('OPENFOODFACTS_ENABLED', true),
    ],

];
