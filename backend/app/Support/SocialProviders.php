<?php

namespace App\Support;

class SocialProviders
{
    public const ALL = ['google', 'amazon'];

    /**
     * Provider configurati sul server (con client_id e client_secret).
     *
     * @return array<int, string>
     */
    public static function enabled(): array
    {
        return array_values(array_filter(
            self::ALL,
            fn (string $p) => filled(config("services.$p.client_id")) && filled(config("services.$p.client_secret")),
        ));
    }

    public static function isEnabled(string $provider): bool
    {
        return in_array($provider, self::enabled(), true);
    }

    public static function label(string $provider): string
    {
        return ucfirst($provider);
    }
}
