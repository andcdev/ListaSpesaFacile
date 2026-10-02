<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Contracts\Translation\HasLocalePreference;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'locale', 'privacy_accepted_at', 'terms_accepted_at', 'newsletter', 'newsletter_consented_at'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable implements HasLocalePreference
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /** Cartella delle foto profilo. */
    public const AVATAR_DIR = 'avatars';

    protected static function booted(): void
    {
        static::deleted(function (User $user) {
            if ($user->avatar_path) {
                Storage::delete($user->avatar_path);
            }
        });
    }

    /**
     * Lingua di notifiche ed email: quella usata nell'app, altrimenti la predefinita (italiano).
     */
    public function preferredLocale(): string
    {
        return $this->locale ?? config('app.locale');
    }

    /**
     * Versione della foto profilo (cambia a ogni nuova foto): l'app la aggiunge all'URL per aggiornare la cache.
     */
    public function avatarVersion(): ?string
    {
        return $this->avatar_path ? substr(md5($this->avatar_path), 0, 10) : null;
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'privacy_accepted_at' => 'datetime',
            'terms_accepted_at' => 'datetime',
            'newsletter' => 'boolean',
            'newsletter_consented_at' => 'datetime',
        ];
    }

    /**
     * I prezzi che l'utente si è annotato (li vede solo lui).
     *
     * @return HasMany<UserPrice, $this>
     */
    public function prices(): HasMany
    {
        return $this->hasMany(UserPrice::class);
    }

    /**
     * Liste create dall'utente.
     *
     * @return HasMany<ShoppingList, $this>
     */
    public function ownedLists(): HasMany
    {
        return $this->hasMany(ShoppingList::class, 'owner_id');
    }

    /**
     * Dispositivi registrati per le notifiche push.
     *
     * @return HasMany<DeviceToken, $this>
     */
    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }

    /**
     * Account Google / Amazon collegati (anche Facebook, per chi lo usava prima).
     *
     * @return HasMany<SocialAccount, $this>
     */
    public function socialAccounts(): HasMany
    {
        return $this->hasMany(SocialAccount::class);
    }

    /**
     * Utenti con cui l'utente condivide tutte le proprie liste.
     *
     * @return BelongsToMany<User, $this>
     */
    public function globalShareRecipients(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'global_shares', 'owner_id', 'user_id')
            ->withPivot('can_edit')
            ->withTimestamps();
    }

    /**
     * Utenti che condividono tutte le proprie liste con questo utente.
     *
     * @return BelongsToMany<User, $this>
     */
    public function globalShareOwners(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'global_shares', 'user_id', 'owner_id')
            ->withPivot('can_edit')
            ->withTimestamps();
    }

    /**
     * Il nome è già di un altro utente? Senza badare a maiuscole e spazi ai lati: ogni nome è unico, perché è
     * quello che gli altri vedono nelle liste condivise e nella chat.
     */
    public static function nameTaken(string $name): bool
    {
        return static::query()->whereRaw('LOWER(name) = ?', [mb_strtolower(trim($name))])->exists();
    }

    /**
     * [name] se è libero, altrimenti "name XXXX" con 4 caratteri alfanumerici casuali, finché non ce n'è uno
     * libero (accesso con Google o Amazon, dove il nome arriva dal provider e non si può chiedere di cambiarlo).
     */
    public static function uniqueName(string $name): string
    {
        $base = Str::limit(trim($name), 240, '');
        $candidate = $base;
        while (static::nameTaken($candidate)) {
            $candidate = $base.' '.Str::upper(Str::random(4));
        }

        return $candidate;
    }
}
