<?php

namespace App\Support;

use App\Models\Report;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ImageRejected;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * Controllo automatico delle foto caricate (chat, prodotti, lista, profilo) con il servizio "moderazione"
 * (modelli open source sul server, le foto non escono). Una foto con nudità, contenuti sessuali o violenza viene
 * rifiutata: ne resta una copia in quarantena e l'assistenza riceve un'email per guardarla e decidere.
 * Se il servizio non risponde la foto passa: meglio un controllo saltato che l'app che non carica più foto.
 */
class ImageModeration
{
    /** Dove l'utente caricava la foto. */
    public const CONTEXTS = ['chat', 'item', 'list', 'avatar'];

    /** Email all'assistenza per le foto rifiutate: al massimo tante all'ora per utente (le altre restano in reports). */
    private const MAILS_PER_HOUR = 3;

    /**
     * Rifiuta la foto (errore di validazione sul campo "image") se il controllo la giudica non ammessa.
     */
    public static function guard(
        UploadedFile $file,
        User $user,
        string $context,
        ?ShoppingList $list = null,
        ?string $caption = null,
    ): void {
        $scores = self::scores($file);
        if ($scores === null || ! self::rejected($scores)) {
            return;
        }

        $report = new Report([
            'type' => Report::TYPE_IMAGE,
            'context' => $context,
            'scores' => $scores,
            'body' => $caption,
            'shopping_list_id' => $list?->id,
            'image_path' => $file->storeAs(Report::QUARANTINE_DIR, Str::random(32).'.'.$file->extension()),
        ]);
        $report->user()->associate($user);
        $report->reported_user_id = $user->id;
        $report->save();
        Log::warning('Foto rifiutata dal controllo automatico', ['report' => $report->id, 'user' => $user->id, 'scores' => $scores]);

        if (RateLimiter::attempt('image-rejected:'.$user->id, self::MAILS_PER_HOUR, fn () => true, 3600)) {
            rescue(fn () => Notification::route('mail', config('mail.support.address'))
                ->notify((new ImageRejected($report->load(['user', 'shoppingList.owner'])))->locale('it')));
        }

        throw ValidationException::withMessages(['image' => [__('app.errors.image_rejected')]]);
    }

    /**
     * Punteggi da 0 a 1 ({sexual, violence}); null se il controllo è spento o il servizio non risponde.
     *
     * @return array{sexual: float, violence: float}|null
     */
    public static function scores(UploadedFile $file): ?array
    {
        $url = config('services.moderation.url');
        if (! $url) {
            return null;
        }
        try {
            $response = Http::timeout(config('services.moderation.timeout'))
                ->attach('image', $file->get(), 'image.'.$file->extension())
                ->post(rtrim($url, '/').'/controlla')
                ->throw();

            return [
                'sexual' => (float) $response->json('sexual'),
                'violence' => (float) $response->json('violence'),
            ];
        } catch (Throwable $e) {
            Log::warning('Controllo delle foto non disponibile: la foto passa senza controllo', ['error' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * @param  array{sexual: float, violence: float}  $scores
     */
    private static function rejected(array $scores): bool
    {
        return $scores['sexual'] >= config('services.moderation.sexual_threshold')
            || $scores['violence'] >= config('services.moderation.violence_threshold');
    }
}
