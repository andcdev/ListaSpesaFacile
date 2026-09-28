<?php

namespace App\Support;

/**
 * Invio degli eventi in tempo reale senza far fallire la richiesta:
 * se Reverb non è raggiungibile il dato è comunque salvato e le app
 * si riallineano ricaricando le liste quando si riconnettono.
 */
class Realtime
{
    public static function broadcast(object ...$events): void
    {
        foreach ($events as $event) {
            rescue(fn () => event($event));
        }
    }
}
