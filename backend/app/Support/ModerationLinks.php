<?php

namespace App\Support;

use App\Models\Report;
use App\Models\User;
use Illuminate\Support\Facades\URL;

/**
 * Link nelle email all'assistenza: foto da guardare, sospensione dell'account e email già scritte per l'utente.
 * I link sono firmati e scadono dopo VALID_DAYS: chi non ha l'email non può usarli.
 */
class ModerationLinks
{
    public const VALID_DAYS = 30;

    /**
     * Foto in quarantena (rifiutata dal controllo) o foto del messaggio segnalato; null se non c'è.
     */
    public static function image(Report $report): ?string
    {
        if (! $report->image_path && ! $report->listMessage?->image_path) {
            return null;
        }

        return URL::temporarySignedRoute('moderazione.foto', now()->addDays(self::VALID_DAYS), ['report' => $report->id]);
    }

    /**
     * Pagina che chiede conferma e sospende l'account (un GET non sospende: i filtri antispam aprono i link).
     */
    public static function suspend(User $user): string
    {
        return URL::temporarySignedRoute('moderazione.sospendi', now()->addDays(self::VALID_DAYS), ['user' => $user->id]);
    }

    public static function reactivate(User $user): string
    {
        return URL::temporarySignedRoute('moderazione.riattiva', now()->addDays(self::VALID_DAYS), ['user' => $user->id]);
    }

    /**
     * Email già scritta, nella lingua dell'utente, da mandare dal proprio programma di posta: [$kind] è
     * "warning" (avviso) o "suspended" (account sospeso).
     */
    public static function mailto(User $user, string $kind): string
    {
        $locale = $user->preferredLocale();
        $subject = __("app.moderation.{$kind}_subject", [], $locale);
        $body = __("app.moderation.{$kind}_body", ['name' => $user->name], $locale);

        return 'mailto:'.rawurlencode($user->email).'?subject='.rawurlencode($subject).'&body='.rawurlencode($body);
    }
}
