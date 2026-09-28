<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Promemoria: reminder_minutes prima di scheduled_at, per il proprietario, i destinatari o tutti.
        // remind_at è l'istante di invio già calcolato; torna null quando il promemoria è stato inviato.
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->unsignedInteger('reminder_minutes')->nullable()->after('scheduled_at');
            $table->string('reminder_target', 10)->default('all')->after('reminder_minutes');
            $table->dateTime('remind_at')->nullable()->index()->after('reminder_target');
        });

        // Chat interna di ogni lista.
        Schema::create('list_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->text('body');
            $table->timestamps();
            $table->index(['shopping_list_id', 'id']);
        });

        // Notifiche mostrate nell'app (tabella standard delle notifiche di Laravel).
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type');
            $table->morphs('notifiable');
            $table->text('data');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });

        // Token Firebase Cloud Messaging dei dispositivi (notifiche push).
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token')->unique();
            $table->string('platform', 20)->default('android');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('list_messages');

        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropIndex(['remind_at']);
            $table->dropColumn(['reminder_minutes', 'reminder_target', 'remind_at']);
        });
    }
};
