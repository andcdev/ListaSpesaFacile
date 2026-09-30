<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Niente più foto cercate in automatico per gli articoli scritti a mano: via quelle già aggiunte. Restano le foto
     * dei prodotti di marca scelti dai suggerimenti, i link scelti a mano e le foto dal telefono.
     */
    public function up(): void
    {
        DB::table('list_items')
            ->where('image_auto', true)
            ->whereNull('barcode')
            ->update(['image_url' => null, 'image_auto' => false]);
    }

    public function down(): void
    {
        // Le foto tolte non si ricreano.
    }
};
