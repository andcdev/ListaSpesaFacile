<?php

namespace App\Console\Commands;

use App\Models\PriceReport;
use App\Models\Supermarket;
use App\Support\OpenFoodFacts;
use App\Support\PriceBook;
use App\Support\ProductCatalog;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Prezzi di partenza da Open Prices (prices.openfoodfacts.org): prezzi di prodotti di marca fotografati dagli utenti
 * di Open Food Facts nei negozi. Si tengono quelli dei negozi delle catene note nei paesi configurati
 * (OPEN_PRICES_COUNTRIES, di norma solo IT), con la città del negozio come zona. Le rettifiche degli utenti
 * dell'app, più recenti, hanno la precedenza.
 *
 * L'API non filtra per paese: si leggono tutti i negozi e poi i prezzi di quelli giusti, con una pausa tra le
 * richieste. La prima volta si importa tutto, poi solo i prezzi aggiunti dall'ultima esecuzione riuscita (con un
 * giorno di margine); --all rilegge tutto. Rileggere un prezzo già importato lo aggiorna.
 */
#[Signature('prices:sync-open-prices {--pause=300 : millisecondi tra una richiesta e l\'altra} {--all : rilegge tutti i prezzi, non solo i nuovi}')]
#[Description('Importa da Open Prices i prezzi dei negozi delle catene note')]
class SyncOpenPrices extends Command
{
    public const API = 'https://prices.openfoodfacts.org/api/v1';

    /** Chiave in cache dell'ultima importazione riuscita. */
    public const LAST_SYNC = 'open-prices:last-sync';

    public function handle(): int
    {
        if (! config('services.openfoodfacts.enabled')) {
            $this->warn('Open Food Facts disattivato (OPENFOODFACTS_ENABLED=false).');

            return self::SUCCESS;
        }

        $chains = Supermarket::all();
        $startedAt = now();
        $since = $this->option('all') ? null : Cache::get(self::LAST_SYNC);
        try {
            $stores = $this->stores($chains);
            $imported = 0;
            foreach ($stores as $locationId => [$supermarket, $location]) {
                $imported += $this->importStore($locationId, $supermarket, $location, $since);
            }
        } catch (Throwable $e) {
            $this->error('Open Prices non raggiungibile: '.$e->getMessage());

            return self::FAILURE;
        }

        Cache::forever(self::LAST_SYNC, $startedAt->copy()->subDay()->toDateString());
        $this->info('Negozi delle catene note: '.count($stores)."; prezzi importati o aggiornati: $imported.");

        return self::SUCCESS;
    }

    /**
     * Negozi di Open Prices che appartengono a una catena nota, nei paesi supportati.
     *
     * @param  Collection<int, Supermarket>  $chains
     * @return array<int, array{0: Supermarket, 1: array<string, mixed>}> id del negozio => [catena, negozio]
     */
    private function stores(Collection $chains): array
    {
        $stores = [];
        foreach ($this->pages('/locations') as $location) {
            $country = $location['osm_address_country_code'] ?? null;
            if (! in_array($country, config('services.openfoodfacts.price_countries'), true)) {
                continue;
            }
            $supermarket = Supermarket::match($location['osm_brand'] ?? null, $chains)
                ?? Supermarket::match($location['osm_name'] ?? null, $chains);
            if ($supermarket && ($location['price_count'] ?? 0) > 0) {
                $stores[$location['id']] = [$supermarket, $location];
            }
        }

        return $stores;
    }

    /**
     * @param  array<string, mixed>  $location
     */
    private function importStore(int $locationId, Supermarket $supermarket, array $location, ?string $since): int
    {
        $count = 0;
        $query = ['location_id' => $locationId, 'type' => 'PRODUCT', 'created__gte' => $since];
        foreach ($this->pages('/prices', array_filter($query)) as $price) {
            // Solo euro e solo prodotti con un nome riconoscibile o un codice a barre.
            $product = $price['product'] ?? [];
            $name = trim((string) ($product['product_name'] ?? ''));
            $code = $price['product_code'] ?? null;
            $amount = $price['price_without_discount'] ?? $price['price'] ?? null;
            if (($price['currency'] ?? null) !== 'EUR' || ! is_numeric($amount) || $amount <= 0 || ($name === '' && ! $code)) {
                continue;
            }
            [$quantity, $unit] = OpenFoodFacts::measure($product['product_quantity'] ?? null, $product['product_quantity_unit'] ?? null);
            $package = PriceBook::package($quantity, $unit);

            PriceReport::updateOrCreate(['external_id' => 'op:'.$price['id']], [
                'supermarket_id' => $supermarket->id,
                'product_key' => $name === '' ? null : ProductCatalog::productKey($name),
                'barcode' => $code && preg_match('/^\d{4,20}$/', $code) ? $code : null,
                'product_name' => mb_substr($name !== '' ? $name : (string) $code, 0, 150),
                'price' => round((float) $amount, 2),
                'per' => 'pz',
                'package_amount' => $package[0] ?? null,
                'package_unit' => $package[1] ?? null,
                'country' => $location['osm_address_country_code'],
                'city' => isset($location['osm_address_city']) ? mb_substr($location['osm_address_city'], 0, 100) : null,
                'locality' => null,
                'source' => PriceReport::SOURCE_OPEN_PRICES,
                'reporter_name' => 'Open Prices',
                'observed_at' => Carbon::parse($price['date'] ?? $price['created'] ?? now()),
            ]);
            $count++;
        }

        return $count;
    }

    /**
     * Tutte le pagine di un elenco dell'API.
     *
     * @param  array<string, mixed>  $query
     * @return iterable<int, array<string, mixed>>
     */
    private function pages(string $path, array $query = []): iterable
    {
        for ($page = 1; ; $page++) {
            usleep((int) $this->option('pause') * 1000);
            $response = Http::withUserAgent(OpenFoodFacts::userAgent())
                ->timeout(30)
                ->retry(3, 2000, throw: false)
                ->get(self::API.$path, [...$query, 'size' => 100, 'page' => $page]);
            // Oltre l'ultima pagina l'API risponde 404.
            if ($response->status() === 404) {
                return;
            }
            $response->throw();
            $items = (array) $response->json('items', []);
            yield from $items;
            if (count($items) < 100 || $page >= (int) $response->json('pages', $page)) {
                return;
            }
        }
    }
}
