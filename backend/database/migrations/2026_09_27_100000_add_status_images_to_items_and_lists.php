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
        Schema::table('list_items', function (Blueprint $table) {
            // todo = da prendere, taken = preso, missing = non preso (non trovato/esaurito).
            // "checked" resta come scorciatoia per status = taken.
            $table->string('status', 10)->default('todo')->after('checked');
            // Emoji scelta dall'utente al posto di quella riconosciuta, e immagine esterna (link).
            $table->string('custom_icon', 16)->nullable()->after('icon');
            $table->string('image_url', 2048)->nullable()->after('custom_icon');
        });
        DB::table('list_items')->where('checked', true)->update(['status' => 'taken']);

        // Foto della lista (file nel disco "local", servito da GET /api/lists/{id}/image).
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->string('image_path')->nullable()->after('notes');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('list_items', function (Blueprint $table) {
            $table->dropColumn(['status', 'custom_icon', 'image_url']);
        });
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('image_path');
        });
    }
};
