<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Il proprietario decide se chi può modificare la lista può anche cambiarne il nome.
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->boolean('members_can_rename')->default(false)->after('reminder_target');
        });
        // Le liste già esistenti mantengono il comportamento precedente (nome modificabile da tutti gli editor).
        DB::table('shopping_lists')->update(['members_can_rename' => true]);

        // Foto del prodotto caricata dal telefono (file nel disco "local", servito da GET …/items/{id}/image).
        Schema::table('list_items', function (Blueprint $table) {
            $table->string('image_path')->nullable()->after('image_url');
        });

        // Foto nella chat: il testo diventa facoltativo se c'è l'immagine.
        Schema::table('list_messages', function (Blueprint $table) {
            $table->text('body')->nullable()->change();
            $table->string('image_path')->nullable()->after('body');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('list_messages', function (Blueprint $table) {
            $table->dropColumn('image_path');
        });
        Schema::table('list_items', function (Blueprint $table) {
            $table->dropColumn('image_path');
        });
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('members_can_rename');
        });
    }
};
