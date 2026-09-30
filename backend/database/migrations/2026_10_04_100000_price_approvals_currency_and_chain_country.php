<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Niente più listino da CSV: i prezzi sono solo quelli di Open Prices e quelli segnalati dagli utenti.
        Schema::dropIfExists('supermarket_prices');

        Schema::table('price_reports', function (Blueprint $table) {
            // Open Prices ha prezzi in tutto il mondo, anche in dollari, corone, sterline…
            $table->string('currency', 3)->default('EUR')->after('price');
            // Una rettifica di un utente la vedono gli altri solo dopo la conferma di altri utenti (pending → approved,
            // oppure rejected). I prezzi di Open Prices hanno la foto dello scontrino o dell'etichetta: già approvati.
            $table->string('status', 10)->default('approved')->after('source');
            $table->unsignedSmallInteger('approvals')->default(0)->after('status');
            $table->unsignedSmallInteger('rejections')->default(0)->after('approvals');
            // Provincia: tra la città e il resto del paese per scegliere il prezzo più vicino.
            $table->string('province', 100)->nullable()->after('country');
            $table->index(['supermarket_id', 'country']);
            $table->index('status');
        });
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->string('province', 100)->nullable()->after('country');
        });
        // Le rettifiche già fatte restano visibili: prima non c'era la conferma.

        // Conferme (o smentite) di un prezzo: una per utente, chi l'ha scritto non vota. Si vede il prezzo con più conferme.
        Schema::create('price_report_votes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('price_report_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('approve');
            $table->timestamps();
            $table->unique(['price_report_id', 'user_id']);
        });

        // Paese della catena: si suggeriscono le catene del paese della lista. Quelle già presenti sono italiane;
        // le altre le crea l'importazione di Open Prices dalle insegne dei negozi.
        Schema::table('supermarkets', function (Blueprint $table) {
            $table->string('country', 2)->nullable()->after('name')->index();
        });
        DB::table('supermarkets')->update(['country' => 'IT']);
    }

    public function down(): void
    {
        Schema::table('supermarkets', function (Blueprint $table) {
            $table->dropIndex(['country']);
            $table->dropColumn('country');
        });
        Schema::dropIfExists('price_report_votes');
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('province');
        });
        Schema::table('price_reports', function (Blueprint $table) {
            $table->dropIndex(['supermarket_id', 'country']);
            $table->dropIndex(['status']);
            $table->dropColumn(['currency', 'province', 'status', 'approvals', 'rejections']);
        });
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
    }
};
