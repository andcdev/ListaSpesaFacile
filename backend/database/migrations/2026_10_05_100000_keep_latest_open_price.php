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
        // Di Open Prices si tiene solo l'ultimo prezzo per prodotto, catena, stato e comune: dedupe_key li identifica
        // (null per le proposte degli utenti, che restano tutte).
        Schema::table('price_reports', function (Blueprint $table) {
            $table->string('dedupe_key', 40)->nullable()->unique()->after('external_id');
        });

        // I prezzi di Open Prices importati finora (tutti, anche i vecchi) si rileggono con la nuova regola: la prossima
        // importazione riparte dall'inizio.
        DB::table('price_reports')->where('source', 'open_prices')->delete();
        foreach (['open-prices:last-sync', 'open-prices:resume-from', 'open-prices:next-page'] as $key) {
            Cache::forget($key);
        }
    }

    public function down(): void
    {
        Schema::table('price_reports', function (Blueprint $table) {
            $table->dropUnique(['dedupe_key']);
            $table->dropColumn('dedupe_key');
        });
    }
};
