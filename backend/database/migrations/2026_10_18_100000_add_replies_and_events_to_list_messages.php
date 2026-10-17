<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('list_messages', function (Blueprint $table) {
            // Risposta a un messaggio della stessa chat (se quello viene eliminato la risposta resta, senza citazione).
            $table->foreignId('reply_to_id')->nullable()->constrained('list_messages')->nullOnDelete();
            // Evento della lista mostrato in grigio tra i messaggi (es. "finished"): l'app compone il testo nella
            // lingua di chi legge da event + event_params; body resta come testo per le versioni vecchie dell'app.
            $table->string('event', 40)->nullable();
            $table->json('event_params')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('list_messages', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reply_to_id');
            $table->dropColumn(['event', 'event_params']);
        });
    }
};
