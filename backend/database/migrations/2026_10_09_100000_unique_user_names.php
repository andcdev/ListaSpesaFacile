<?php

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * Nome utente unico. I doppioni già presenti (senza badare alle maiuscole) tengono il nome il più vecchio,
     * gli altri ricevono 4 caratteri casuali in fondo, come per l'accesso con Google o Amazon.
     */
    public function up(): void
    {
        $seen = [];
        foreach (DB::table('users')->orderBy('id')->get(['id', 'name']) as $user) {
            $key = mb_strtolower(trim($user->name));
            if (! isset($seen[$key])) {
                $seen[$key] = true;

                continue;
            }
            do {
                $name = Str::limit(trim($user->name), 240, '').' '.Str::upper(Str::random(4));
            } while (isset($seen[mb_strtolower($name)]) || User::nameTaken($name));
            $seen[mb_strtolower($name)] = true;
            DB::table('users')->where('id', $user->id)->update(['name' => $name]);
        }

        Schema::table('users', function (Blueprint $table) {
            $table->unique('name');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['name']);
        });
    }
};
