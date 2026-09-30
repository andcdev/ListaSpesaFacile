<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Niente più prezzi condivisi (Open Prices, proposte e conferme) né confronto tra catene.
        Schema::dropIfExists('price_report_votes');
        Schema::dropIfExists('price_reports');
        foreach (['open-prices:last-sync', 'open-prices:resume-from', 'open-prices:next-page'] as $key) {
            Cache::forget($key);
        }
        // Restano le catene precaricate (hanno una descrizione), per suggerire il supermercato; via quelle create
        // dall'importazione di Open Prices.
        DB::table('supermarkets')->whereNull('description')->delete();
        Schema::table('supermarkets', function (Blueprint $table) {
            $table->dropIndex(['country']);
            $table->dropColumn('country');
        });
        // La zona serviva solo ai prezzi.
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn(['country', 'province', 'city', 'locality']);
        });

        // Prezzi che ogni utente si annota per i prodotti: li vede solo lui.
        Schema::create('user_prices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('product_name', 150);
            $table->string('barcode', 20)->nullable();
            $table->string('brand', 100)->nullable();
            $table->string('supermarket', 100)->nullable();
            $table->decimal('price', 10, 2);
            $table->string('per', 3)->default('pz');
            $table->string('note', 255)->nullable();
            $table->timestamps();
            $table->index(['user_id', 'product_name']);
        });

        // Consensi dati alla registrazione: informativa privacy (obbligatoria) e newsletter (facoltativa).
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('privacy_accepted_at')->nullable()->after('locale');
            $table->boolean('newsletter')->default(false)->after('privacy_accepted_at');
            $table->timestamp('newsletter_consented_at')->nullable()->after('newsletter');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['privacy_accepted_at', 'newsletter', 'newsletter_consented_at']);
        });
        Schema::dropIfExists('user_prices');
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->string('country', 2)->default('IT')->after('supermarket');
            $table->string('province', 100)->nullable()->after('country');
            $table->string('city', 100)->nullable()->after('province');
            $table->string('locality', 100)->nullable()->after('city');
        });
        Schema::table('supermarkets', function (Blueprint $table) {
            $table->string('country', 2)->nullable()->after('name')->index();
        });
        // I prezzi condivisi non si ricreano: bisognerebbe rieseguire le migrazioni precedenti.
    }
};
