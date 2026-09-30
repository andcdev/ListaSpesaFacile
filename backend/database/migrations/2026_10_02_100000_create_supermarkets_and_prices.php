<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** Principali catene italiane: nome, altri nomi con cui vengono scritte, descrizione. */
    private const CHAINS = [
        ['Esselunga', [], 'Supermercati e superstore, soprattutto al Nord e al Centro'],
        ['Coop', ['Ipercoop', 'Coop&Coop', 'Incoop'], 'Cooperative di consumatori, in tutta Italia'],
        ['Conad', ['Conad City', 'Conad Superstore', 'Spazio Conad', 'Sapori & Dintorni'], 'Consorzio di dettaglianti, in tutta Italia'],
        ['Carrefour', ['Carrefour Market', 'Carrefour Express', 'Carrefour Iper'], 'Ipermercati, supermercati e negozi di prossimità'],
        ['Lidl', [], 'Discount, in tutta Italia'],
        ['Eurospin', [], 'Discount, in tutta Italia'],
        ['Aldi', [], 'Discount, soprattutto al Nord'],
        ['MD', ['MD Discount'], 'Discount, in tutta Italia'],
        ['Penny', ['Penny Market'], 'Discount, in tutta Italia'],
        ['Pam', ['Pam Panorama', 'Panorama', 'Pam Local'], 'Supermercati e ipermercati'],
        ['Despar', ['Eurospar', 'Interspar', 'Spar'], 'Supermercati e ipermercati'],
        ['Iper', ['Iper La grande i', 'La grande i'], 'Ipermercati, soprattutto al Nord'],
        ['Bennet', [], 'Ipermercati, soprattutto al Nord'],
        ['Famila', ['Famila Superstore'], 'Supermercati del gruppo Selex'],
        ['Tigros', [], 'Supermercati in Lombardia e Piemonte'],
        ['Crai', [], 'Supermercati di prossimità'],
        ['Sigma', [], 'Supermercati di prossimità'],
        ['Todis', [], 'Discount, soprattutto al Centro-Sud'],
        ["In's Mercato", ["In's"], 'Discount, soprattutto al Nord e al Centro'],
        ['Decò', ['Deco', 'Superstore Decò'], 'Supermercati, soprattutto al Sud'],
    ];

    public function up(): void
    {
        // Catena (distribuzione) a cui si riferiscono i prezzi.
        Schema::create('supermarkets', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100)->unique();
            $table->json('aliases')->nullable();
            $table->string('description')->nullable();
            $table->timestamps();
        });

        // Prezzo indicativo di un prodotto in una catena: a confezione (pz), al kg o al litro.
        // product_key è la radice riconosciuta da ProductCatalog::productKey ("latte", "pomodor"…).
        Schema::create('supermarket_prices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supermarket_id')->constrained()->cascadeOnDelete();
            $table->string('product_key', 100);
            $table->string('product_name', 100);
            $table->decimal('price', 8, 2);
            $table->string('per', 3)->default('pz');
            $table->timestamps();
            $table->unique(['supermarket_id', 'product_key']);
        });

        // Supermercato scelto per la lista, come scritto dall'utente (può anche non essere una catena nota).
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->string('supermarket', 100)->nullable()->after('notes');
        });

        $now = now();
        DB::table('supermarkets')->insert(array_map(fn (array $chain) => [
            'name' => $chain[0],
            'aliases' => json_encode($chain[1]),
            'description' => $chain[2],
            'created_at' => $now,
            'updated_at' => $now,
        ], self::CHAINS));
    }

    public function down(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('supermarket');
        });
        Schema::dropIfExists('supermarket_prices');
        Schema::dropIfExists('supermarkets');
    }
};
