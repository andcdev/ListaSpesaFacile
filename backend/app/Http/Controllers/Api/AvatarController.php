<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Foto profilo, mostrata accanto ai messaggi della chat. La vede solo chi ha almeno una lista in comune.
 */
class AvatarController extends Controller
{
    public function show(Request $request, User $user): StreamedResponse
    {
        $me = $request->user();
        abort_unless(
            $me->is($user) || ShoppingList::query()->accessibleBy($me)->accessibleBy($user)->exists(),
            403,
        );
        abort_unless($user->avatar_path && Storage::exists($user->avatar_path), 404);

        // L'URL contiene la versione (?v=…): il file può restare in cache a lungo.
        return Storage::response($user->avatar_path, headers: ['Cache-Control' => 'private, max-age=31536000']);
    }

    public function store(Request $request): UserResource
    {
        $request->validate(['image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096']]);

        $user = $request->user();
        $old = $user->avatar_path;
        $file = $request->file('image');
        $user->avatar_path = $file->storeAs(User::AVATAR_DIR, $user->id.'-'.Str::random(12).'.'.$file->extension());
        $user->save();
        if ($old) {
            Storage::delete($old);
        }

        return new UserResource($user);
    }

    public function destroy(Request $request): UserResource
    {
        $user = $request->user();
        if ($user->avatar_path) {
            Storage::delete($user->avatar_path);
            $user->avatar_path = null;
            $user->save();
        }

        return new UserResource($user);
    }
}
