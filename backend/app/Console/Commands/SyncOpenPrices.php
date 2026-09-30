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
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Throwable;

/**
 * Prezzi di partenza da Open Prices (prices.openfoodfacts.org): prezzi fotografati nei negozi dagli utenti di
 * Open Food Facts, in tutto il mondo (OPEN_PRICES_COUNTRIES li limita ad alcuni paesi). La zona è la città del
 * negozio; le rettifiche degli utenti dell'app, più recenti, hanno la precedenza.
 *
 * Ogni prezzo porta con sé il negozio. La catena si riconosce dall'insegna: prima uguale a una catena nota
 * (nome o altro nome), poi, in Italia, contenuta nel nome ("Esselunga Viale Piave"); altrimenti la catena viene
 * creata con il nome dell'insegna (Leclerc, Rema 1000…) e il paese del negozio.
 *
 * La prima volta si importa tutto (circa 3.200 pagine da 100 prezzi, 35-40 minuti); se si interrompe, la volta dopo
 * riprende dall'ultima pagina completata. Poi solo i prezzi aggiunti dall'ultima esecuzione riuscita (con un giorno
 * di margine). --all rilegge tutto. Rileggere un prezzo già importato lo aggiorna.
 */
#[Signature('prices:sync-open-prices {--pause=300 : millisecondi tra una richiesta e l\'altra} {--all : rilegge tutti i prezzi, non solo i nuovi}')]
#[Description('Importa i prezzi di Open Prices')]
class SyncOpenPrices extends Command
{
    public const API = 'https://prices.openfoodfacts.org/api/v1';

    /** Chiave in cache dell'ultima importazione riuscita. */
    public const LAST_SYNC = 'open-prices:last-sync';

    /** Chiave in cache della prossima pagina da leggere durante l'importazione completa (per riprendere). */
    public const NEXT_PAGE = 'open-prices:next-page';

    /** Unità dei prezzi a peso o volume di Open Prices → unità dell'app. */
    private const PER = ['KILOGRAM' => 'kg', 'LITER' => 'l', 'LITRE' => 'l', 'UNIT' => 'pz'];

    /** @var array<string, Supermarket> nome o altro nome normalizzato → catena */
    private array $byName = [];

    /** @var array<int, Supermarket|null> negozio di Open Prices → catena (null = da saltare) */
    private array $stores = [];

    private int $created = 0;

    public function handle(): int
    {
        if (! config('services.openfoodfacts.enabled')) {
            $this->warn('Open Food Facts disattivato (OPENFOODFACTS_ENABLED=false).');

            return self::SUCCESS;
        }

        foreach (Supermarket::all() as $supermarket) {
            $this->remember($supermarket);
        }
        $startedAt = now();
        $since = $this->option('all') ? null : Cache::get(self::LAST_SYNC);
        // Importazione completa interrotta: si riprende da dove si era arrivati.
        $firstPage = $since === null ? (int) Cache::get(self::NEXT_PAGE, 1) : 1;
        if ($this->option('all')) {
            $firstPage = 1;
        }

        $imported = 0;
        try {
            foreach ($this->pages(array_filter(['created__gte' => $since]), $firstPage) as $page => $prices) {
                $imported += $this->import($prices);
                if ($since === null) {
                    Cache::forever(self::NEXT_PAGE, $page + 1);
                }
            }
        } catch (Throwable $e) {
            $this->error('Open Prices non raggiungibile: '.$e->getMessage()." (prezzi importati finora: $imported)");

            return self::FAILURE;
        }

        Cache::forget(self::NEXT_PAGE);
        Cache::forever(self::LAST_SYNC, $startedAt->copy()->subDay()->toDateString());
        $this->info("Prezzi importati o aggiornati: $imported; catene nuove: {$this->created}.");

        return self::SUCCESS;
    }

    /**
     * Una pagina di prezzi, salvata in blocco.
     *
     * @param  array<int, array<string, mixed>>  $prices
     */
    private function import(array $prices): int
    {
        $now = now();
        $rows = [];
        foreach ($prices as $price) {
            $location = $price['location'] ?? null;
            $supermarket = is_array($location) ? $this->chain($location) : null;
            $row = $supermarket ? $this->row($price, $location) : null;
            if ($row !== null) {
                $rows[] = [...$row, 'supermarket_id' => $supermarket->id, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        if ($rows !== []) {
            // Rileggendo un prezzo si aggiornano i dati, non lo stato: le smentite degli utenti restano.
            PriceReport::upsert($rows, ['external_id'], array_keys(collect($rows[0])->except(['external_id', 'created_at', 'status'])->all()));
        }

        return count($rows);
    }

    /**
     * Dati del prezzo, null se non è utilizzabile (senza importo o senza un prodotto riconoscibile).
     *
     * @param  array<string, mixed>  $price
     * @param  array<string, mixed>  $location
     * @return array<string, mixed>|null
     */
    private function row(array $price, array $location): ?array
    {
        $amount = $price['price_without_discount'] ?? $price['price'] ?? null;
        $currency = strtoupper((string) ($price['currency'] ?? ''));
        if (! is_numeric($amount) || $amount <= 0 || strlen($currency) !== 3) {
            return null;
        }

        if (($price['type'] ?? 'PRODUCT') === 'CATEGORY') {
            // Frutta, verdura e sfusi: "en:bananas" al kg → Banane (riconosciute anche dal nome inglese).
            $name = Str::of((string) ($price['category_tag'] ?? ''))->after(':')->replace('-', ' ')->ucfirst()->toString();
            $key = $name === '' ? null : ProductCatalog::productKey($name);
            if ($key === null) {
                return null;
            }
            [$code, $per, $package] = [null, self::PER[$price['price_per'] ?? 'UNIT'] ?? 'pz', null];
        } else {
            $product = $price['product'] ?? [];
            $name = trim((string) ($product['product_name'] ?? ''));
            $code = $price['product_code'] ?? null;
            $code = is_string($code) && preg_match('/^\d{4,20}$/', $code) ? $code : null;
            if ($name === '' && $code === null) {
                return null;
            }
            $key = $name === '' ? null : ProductCatalog::productKey($name);
            [$quantity, $unit] = OpenFoodFacts::measure($product['product_quantity'] ?? null, $product['product_quantity_unit'] ?? null);
            [$per, $package] = ['pz', PriceBook::package($quantity, $unit)];
        }

        return [
            'external_id' => 'op:'.$price['id'],
            'product_key' => $key,
            'barcode' => $code,
            'product_name' => mb_substr($name !== '' ? $name : (string) $code, 0, 150),
            'price' => round((float) $amount, 2),
            'currency' => $currency,
            'per' => $per,
            'package_amount' => $package[0] ?? null,
            'package_unit' => $package[1] ?? null,
            'country' => $location['osm_address_country_code'],
            'province' => null,
            'city' => isset($location['osm_address_city']) ? mb_substr((string) $location['osm_address_city'], 0, 100) : null,
            'locality' => null,
            'source' => PriceReport::SOURCE_OPEN_PRICES,
            'status' => PriceReport::APPROVED,
            'user_id' => null,
            'reporter_name' => 'Open Prices',
            'reporter_email' => null,
            'observed_at' => Carbon::parse($price['date'] ?? $price['created'] ?? now())->toDateTimeString(),
        ];
    }

    /**
     * Catena del negozio (letta una volta per negozio); null se il paese è escluso o il negozio non ha nome.
     *
     * @param  array<string, mixed>  $location
     */
    private function chain(array $location): ?Supermarket
    {
        $id = (int) ($location['id'] ?? 0);
        if (array_key_exists($id, $this->stores)) {
            return $this->stores[$id];
        }

        $country = $location['osm_address_country_code'] ?? null;
        $allowed = config('services.openfoodfacts.price_countries');
        if (! is_string($country) || strlen($country) !== 2 || ($allowed !== [] && ! in_array($country, $allowed, true))) {
            return $this->stores[$id] = null;
        }

        $brand = trim((string) ($location['osm_brand'] ?? ''));
        $name = trim((string) ($location['osm_name'] ?? ''));
        $supermarket = $this->byName[Supermarket::normalize($brand)] ?? $this->byName[Supermarket::normalize($name)] ?? null;

        // In Italia le insegne sono spesso scritte con l'indirizzo: "Esselunga Viale Piave", "Conad City Brera".
        if ($supermarket === null && in_array($country, ['IT', 'SM', 'VA'], true)) {
            $italian = collect($this->byName)->unique('id')->where('country', 'IT')->values();
            $supermarket = Supermarket::match($brand ?: $name, $italian) ?? ($brand ? Supermarket::match($name, $italian) : null);
        }

        $label = mb_substr($brand ?: $name, 0, 100);
        if ($supermarket === null && Supermarket::normalize($label) !== '') {
            $supermarket = Supermarket::create(['name' => $label, 'country' => $country, 'aliases' => []]);
            $this->remember($supermarket);
            $this->created++;
        }

        return $this->stores[$id] = $supermarket;
    }

    private function remember(Supermarket $supermarket): void
    {
        foreach ([$supermarket->name, ...($supermarket->aliases ?? [])] as $name) {
            $this->byName[Supermarket::normalize($name)] ??= $supermarket;
        }
    }

    /**
     * Le pagine di prezzi, dalla prima indicata, in ordine di id.
     *
     * @param  array<string, mixed>  $query
     * @return iterable<int, array<int, array<string, mixed>>> numero di pagina → prezzi
     */
    private function pages(array $query, int $page): iterable
    {
        for (; ; $page++) {
            usleep((int) $this->option('pause') * 1000);
            $response = Http::withUserAgent(OpenFoodFacts::userAgent())
                ->timeout(60)
                ->retry(3, 5000, throw: false)
                ->get(self::API.'/prices', [...$query, 'size' => 100, 'page' => $page]);
            // Oltre l'ultima pagina l'API risponde 404.
            if ($response->status() === 404) {
                return;
            }
            $response->throw();
            $items = (array) $response->json('items', []);
            yield $page => $items;
            if ($page % 100 === 0) {
                $this->line("Pagina $page di ".$response->json('pages', '?'));
            }
            if (count($items) < 100 || $page >= (int) $response->json('pages', $page)) {
                return;
            }
        }
    }
}
