<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            // Chi fa la spesa: solo lui segna i prodotti presi o non trovati (null = chiunque possa modificare).
            $table->foreignId('shopper_id')->nullable()->constrained('users')->nullOnDelete();
            // "Spesa finita": chi, quando e con quale messaggio. Torna vuoto se si riprende a segnare i prodotti.
            $table->timestamp('finished_at')->nullable();
            $table->foreignId('finished_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('finish_message', 500)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shopper_id');
            $table->dropConstrainedForeignId('finished_by');
            $table->dropColumn(['finished_at', 'finish_message']);
        });
    }
};
