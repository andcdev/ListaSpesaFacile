<?php

namespace App\Console\Commands;

use App\Models\Supermarket;
use App\Models\SupermarketPrice;
use App\Support\ProductCatalog;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Carica i prezzi indicativi delle catene da un file CSV (separato da virgole o punti e virgola):
 *
 *   supermercato;prodotto;prezzo;per
 *   Esselunga;Latte;1,29;l
 *   Lidl;Banane;1,49;kg
 *   Coop;Pasta;0,89;pz
 *
 * "per" è pz (a confezione), kg o l; se manca vale pz. La prima riga può essere l'intestazione.
 * Il prodotto viene riconosciuto come negli articoli delle liste ("Pomodorini" vale per tutti i pomodori);
 * le righe con un prodotto non riconosciuto vengono saltate. Una catena che non esiste viene creata.
 */
#[Signature('prices:import {file : percorso del file CSV} {--replace : elimina prima i prezzi delle catene presenti nel file}')]
#[Description('Importa i prezzi indicativi delle catene di supermercati da un CSV')]
class ImportPrices extends Command
{
    public function handle(): int
    {
        $path = (string) $this->argument('file');
        $lines = is_readable($path) ? file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) : false;
        if ($lines === false) {
            $this->error("File non leggibile: $path");

            return self::FAILURE;
        }

        $rows = [];
        $skipped = 0;
        foreach ($lines as $n => $line) {
            $line = trim($n === 0 ? (string) preg_replace('/^\xEF\xBB\xBF/', '', $line) : $line);
            $cells = array_map('trim', str_getcsv($line, str_contains($line, ';') ? ';' : ',', '"', ''));
            [$chain, $product, $price, $per] = array_pad($cells, 4, '');
            $per = strtolower($per ?: 'pz');
            $price = str_replace(',', '.', $price);

            if ($n === 0 && ! is_numeric($price)) {
                continue; // intestazione
            }
            $key = ProductCatalog::productKey($product);
            if ($chain === '' || $key === null || ! is_numeric($price) || $price <= 0 || ! in_array($per, SupermarketPrice::PER, true)) {
                $this->warn('Riga '.($n + 1)." saltata: $line");
                $skipped++;

                continue;
            }
            $rows[] = compact('chain', 'product', 'key', 'price', 'per');
        }

        $imported = DB::transaction(function () use ($rows) {
            $chains = [];
            $cleared = [];
            foreach ($rows as $row) {
                $supermarket = $chains[$row['chain']] ??= Supermarket::match($row['chain'])
                    ?? Supermarket::create(['name' => $row['chain'], 'aliases' => []]);
                if ($this->option('replace') && ! isset($cleared[$supermarket->id])) {
                    $supermarket->prices()->delete();
                    $cleared[$supermarket->id] = true;
                }
                $supermarket->prices()->updateOrCreate(
                    ['product_key' => $row['key']],
                    ['product_name' => $row['product'], 'price' => $row['price'], 'per' => $row['per']],
                );
            }

            return count($rows);
        });

        $this->info("Prezzi importati: $imported; righe saltate: $skipped.");

        return self::SUCCESS;
    }
}
