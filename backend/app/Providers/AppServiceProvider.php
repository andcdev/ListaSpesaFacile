<?php

namespace App\Providers;

use App\Support\Fcm;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use SocialiteProviders\Amazon\AmazonExtendSocialite;
use SocialiteProviders\Manager\SocialiteWasCalled;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Una sola istanza: credenziali Firebase lette una volta per processo.
        $this->app->singleton(Fcm::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Event::listen(SocialiteWasCalled::class, [AmazonExtendSocialite::class, 'handle']);
    }
}
