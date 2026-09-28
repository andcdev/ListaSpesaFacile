<?php

use App\Support\ProductCatalog;
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
            // Reparto e icona riconosciuti dal nome (vedi ProductCatalog), modificabili dall'utente.
            $table->string('category', 20)->default(ProductCatalog::DEFAULT_CATEGORY)->after('name');
            $table->string('icon', 16)->nullable()->after('category');
            // Peso o volume, oltre alla quantità: es. 500 g, 1,5 l.
            $table->decimal('amount', 10, 3)->nullable()->after('quantity');
            $table->string('unit', 4)->nullable()->after('amount');
        });

        // Riconosce reparto e icona degli articoli già presenti.
        DB::table('list_items')->select(['id', 'name'])->orderBy('id')->each(function (object $item) {
            DB::table('list_items')->where('id', $item->id)->update(ProductCatalog::detect($item->name));
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('list_items', function (Blueprint $table) {
            $table->dropColumn(['category', 'icon', 'amount', 'unit']);
        });
    }
};
