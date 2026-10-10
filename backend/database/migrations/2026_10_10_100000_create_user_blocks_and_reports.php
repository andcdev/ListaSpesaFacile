<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Persone bloccate: user_id non vuole più avere a che fare con blocked_id (condivisioni, chat, notifiche).
        Schema::create('user_blocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('blocked_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'blocked_id']);
        });

        // Segnalazioni dall'app (problema, persona o messaggio) e foto rifiutate dal controllo automatico: partono per
        // email a support@, qui ne resta traccia.
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 20);
            $table->text('body')->nullable();
            $table->foreignId('reported_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('shopping_list_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('list_message_id')->nullable()->constrained()->nullOnDelete();
            // Il messaggio segnalato com'era al momento della segnalazione (l'autore potrebbe eliminarlo).
            $table->text('message_body')->nullable();
            $table->string('app_version', 30)->nullable();
            // Foto rifiutata dal controllo automatico (type "image"): dove l'utente la caricava, i punteggi e la
            // copia in quarantena da guardare (eliminata dopo 30 giorni).
            $table->string('context', 20)->nullable();
            $table->json('scores')->nullable();
            $table->string('image_path')->nullable();
            $table->timestamps();
        });

        // Account sospeso dall'assistenza (dal pulsante nell'email di una segnalazione): non può più accedere.
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('suspended_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('suspended_at');
        });
        Schema::dropIfExists('reports');
        Schema::dropIfExists('user_blocks');
    }
};
