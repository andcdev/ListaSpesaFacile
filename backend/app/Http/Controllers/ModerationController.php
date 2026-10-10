<?php

namespace App\Http\Controllers;

use App\Models\Report;
use App\Models\User;
use App\Support\ModerationLinks;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Pagine aperte dai pulsanti nelle email all'assistenza (link firmati, vedi ModerationLinks).
 */
class ModerationController extends Controller
{
    /**
     * La foto da giudicare: quella rifiutata (in quarantena) o quella del messaggio segnalato.
     */
    public function image(Report $report): StreamedResponse
    {
        $path = $report->image_path ?? $report->listMessage?->image_path;
        abort_unless($path && Storage::exists($path), 404);

        return Storage::response($path, headers: ['Cache-Control' => 'private, no-store', 'X-Robots-Tag' => 'noindex']);
    }

    /**
     * Conferma prima di sospendere.
     */
    public function confirmSuspend(User $user): View
    {
        return $this->page($user, $user->isSuspended() ? 'suspended' : 'confirm-suspend');
    }

    public function suspend(User $user): View
    {
        if (! $user->isSuspended()) {
            $user->suspend();
        }

        return $this->page($user, 'suspended');
    }

    public function confirmReactivate(User $user): View
    {
        return $this->page($user, $user->isSuspended() ? 'confirm-reactivate' : 'active');
    }

    public function reactivate(User $user): View
    {
        $user->forceFill(['suspended_at' => null])->save();

        return $this->page($user, 'active');
    }

    private function page(User $user, string $state): View
    {
        return view('moderazione', [
            'user' => $user,
            'state' => $state,
            'reports' => Report::where('reported_user_id', $user->id)->count(),
            'suspendUrl' => ModerationLinks::suspend($user),
            'reactivateUrl' => ModerationLinks::reactivate($user),
            'warningMailto' => ModerationLinks::mailto($user, 'warning'),
            'suspendedMailto' => ModerationLinks::mailto($user, 'suspended'),
        ]);
    }
}
