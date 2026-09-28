<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'lowercase', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::create([...$data, 'locale' => app()->getLocale()]);

        return $this->tokenResponse($user, $data['device_name'] ?? 'app', 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if ($user && $user->password === null) {
            throw ValidationException::withMessages([
                'email' => [__('app.errors.social_only', ['providers' => $user->socialAccounts()->pluck('provider')->map(ucfirst(...))->join(', ')])],
            ]);
        }

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => [__('app.errors.invalid_credentials')],
            ]);
        }

        return $this->tokenResponse($user, $data['device_name'] ?? 'app');
    }

    /**
     * Ultimo passo del login social: codice monouso + code_verifier (PKCE) → token.
     */
    public function exchangeSocialCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string'],
            'code_verifier' => ['required', 'string', 'min:43', 'max:128'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $pending = Cache::pull('social_code:'.$data['code']);
        $challenge = rtrim(strtr(base64_encode(hash('sha256', $data['code_verifier'], true)), '+/', '-_'), '=');

        if (! $pending || ! hash_equals($pending['challenge'], $challenge)) {
            throw ValidationException::withMessages(['code' => [__('app.errors.social_code_invalid')]]);
        }

        return $this->tokenResponse(User::findOrFail($pending['user_id']), $data['device_name'] ?? 'app');
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(status: 204);
    }

    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    private function tokenResponse(User $user, string $deviceName, int $status = 200): JsonResponse
    {
        return response()->json([
            'token' => $user->createToken($deviceName)->plainTextToken,
            'user' => new UserResource($user),
        ], $status);
    }
}
