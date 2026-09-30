<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Zona del supermercato della lista: i prezzi segnalati nella stessa zona hanno la precedenza.
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->string('country', 2)->default('IT')->after('supermarket');
            $table->string('city', 100)->nullable()->after('country');
            $table->string('locality', 100)->nullable()->after('city');
        });

        // Prodotto di marca scelto da Open Food Facts (codice a barre) e foto trovata in automatico dal nome.
        Schema::table('list_items', function (Blueprint $table) {
            $table->string('barcode', 20)->nullable()->after('name');
            $table->string('brand', 100)->nullable()->after('barcode');
            $table->boolean('image_auto')->default(false)->after('image_url');
        });

        // Prezzo rilevato in una catena e in una zona: dagli utenti (rettifiche) o da Open Prices (base di partenza).
        // Di chi segnala si mostrano nome e ora; l'email si conserva ma non viene mai mostrata.
        Schema::create('price_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supermarket_id')->constrained()->cascadeOnDelete();
            $table->string('product_key', 100)->nullable()->index();
            $table->string('barcode', 20)->nullable()->index();
            $table->string('product_name', 150);
            $table->decimal('price', 8, 2);
            $table->string('per', 3)->default('pz');
            // Contenuto della confezione in kg o litri (0.5 = 500 g), se noto: serve a stimare altre quantità.
            $table->decimal('package_amount', 10, 3)->nullable();
            $table->string('package_unit', 2)->nullable();
            $table->string('country', 2)->default('IT');
            $table->string('city', 100)->nullable();
            $table->string('locality', 100)->nullable();
            $table->string('source', 12)->default('user');
            $table->string('external_id', 40)->nullable()->unique();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('reporter_name')->nullable();
            $table->string('reporter_email')->nullable();
            $table->dateTime('observed_at')->index();
            $table->timestamps();
            $table->index(['supermarket_id', 'product_key']);
            $table->index(['supermarket_id', 'barcode']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('price_reports');
        Schema::table('list_items', function (Blueprint $table) {
            $table->dropColumn(['barcode', 'brand', 'image_auto']);
        });
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn(['country', 'city', 'locality']);
        });
    }
};
