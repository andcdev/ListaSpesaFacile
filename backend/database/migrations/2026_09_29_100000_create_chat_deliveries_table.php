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
        // Spunte della chat: per ogni utente, fino a quale messaggio della lista il suo telefono ha ricevuto.
        // I messaggi sono in ordine di id, quindi basta l'ultimo (come le conferme di WhatsApp).
        Schema::create('chat_deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('delivered_up_to')->default(0);
            $table->timestamps();
            $table->unique(['shopping_list_id', 'user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chat_deliveries');
    }
};
