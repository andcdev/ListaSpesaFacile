<?php

namespace App\Console\Commands;

use App\Models\PriceReport;
use App\Models\PriceReportVote;
use App\Models\Supermarket;
use App\Support\OpenFoodFacts;
use App\Support\PriceBook;
use App\Support\ProductCatalog;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Throwable;

/**
 * Prezzi di partenza da Open Prices (prices.openfoodfacts.org): prezzi fotografati nei negozi dagli utenti di
 * Open Food Facts, in tutto il mondo (OPEN_PRICES_COUNTRIES li limita ad alcuni paesi). La zona è la città del
 * negozio. Si tiene solo il prezzo più recente per prodotto, catena, stato e comune (dedupe_key): uno più nuovo
 * sostituisce il vecchio e ne azzera le conferme, uno più vecchio si scarta.
 *
 * Ogni prezzo porta con sé il negozio. La catena si riconosce dall'insegna: prima uguale a una catena nota
 * (nome o altro nome), poi, in Italia, contenuta nel nome ("Esselunga Viale Piave"); altrimenti la catena viene
 * creata con il nome dell'insegna (Leclerc, Rema 1000…) e il paese del negozio.
 *
 * L'API non va oltre la pagina 500 (50.000 prezzi) per ricerca: si legge un mese di prezzi per volta (per data di
 * inserimento; un mese con troppi prezzi si divide in due). Gli export giornalieri di Open Prices non servono: non
 * hanno nome e formato dei prodotti.
 *
 * La prima volta si importa tutto (circa 3.200 pagine da 100 prezzi, 35-40 minuti); se si interrompe, la volta dopo
 * riprende dal primo mese non completato. Poi solo i prezzi aggiunti dall'ultima esecuzione riuscita (con un giorno
 * di margine). --all rilegge tutto. Rileggere un prezzo già importato lo aggiorna.
 */
#[Signature('prices:sync-open-prices {--pause=300 : millisecondi tra una richiesta e l\'altra} {--all : rilegge tutti i prezzi, non solo i nuovi} {--from= : data (AAAA-MM-GG) da cui leggere invece dell\'inizio o dell\'ultima esecuzione}')]
#[Description('Importa i prezzi di Open Prices')]
class SyncOpenPrices extends Command
{
    public const API = 'https://prices.openfoodfacts.org/api/v1';

    /** Chiave in cache dell'ultima importazione riuscita. */
    public const LAST_SYNC = 'open-prices:last-sync';

    /** Chiave in cache del primo giorno non ancora importato di un'importazione interrotta (per riprendere). */
    public const RESUME_FROM = 'open-prices:resume-from';

    /** Primo giorno con prezzi su Open Prices. */
    public const START = '2023-11-01';

    /** L'API risponde fino a questa pagina per ricerca. */
    public const MAX_PAGES = 500;

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
        // Da dove leggere: la data indicata, oppure dove si era interrotta l'ultima volta, oppure (con --all o la prima
        // volta) dall'inizio, oppure dall'ultima esecuzione riuscita.
        $from = $this->option('from')
            ?? Cache::get(self::RESUME_FROM)
            ?? ($this->option('all') ? null : Cache::get(self::LAST_SYNC))
            ?? self::START;
        if ($this->option('all') && ! $this->option('from')) {
            $from = self::START;
        }

        $imported = 0;
        try {
            // Un mese per volta: finito un mese, un'interruzione riparte dal successivo.
            for ($day = Carbon::parse($from)->startOfDay(); $day->lte($startedAt); $day = $end->copy()->addDay()->startOfDay()) {
                $end = $day->copy()->endOfMonth()->min($startedAt->copy()->endOfDay());
                $imported += $this->importWindow($day, $end);
                Cache::forever(self::RESUME_FROM, $end->copy()->addDay()->toDateString());
            }
        } catch (Throwable $e) {
            $this->error('Open Prices non raggiungibile: '.$e->getMessage()." (prezzi importati finora: $imported)");

            return self::FAILURE;
        }

        Cache::forget(self::RESUME_FROM);
        Cache::forget('open-prices:next-page');
        Cache::forever(self::LAST_SYNC, $startedAt->copy()->subDay()->toDateString());
        $this->info("Prezzi importati o aggiornati: $imported; catene nuove: {$this->created}.");

        return self::SUCCESS;
    }

    /**
     * I prezzi inseriti tra [$from] e [$to] (compresi); se sono più di quanti l'API ne dà per ricerca, a metà.
     */
    private function importWindow(Carbon $from, Carbon $to): int
    {
        $query = [
            'created__gte' => $from->copy()->startOfDay()->format('Y-m-d\\TH:i:s'),
            'created__lte' => $to->copy()->endOfDay()->format('Y-m-d\\TH:i:s.u'),
        ];
        $first = $this->fetch($query, 1);
        $pages = (int) $first->json('pages', 1);
        if ($pages > self::MAX_PAGES && $from->lt($to->copy()->startOfDay())) {
            $middle = $from->copy()->addDays(intdiv((int) $from->diffInDays($to->copy()->startOfDay(), true), 2));

            return $this->importWindow($from, $middle) + $this->importWindow($middle->copy()->addDay(), $to);
        }

        $imported = $this->import((array) $first->json('items', []));
        for ($page = 2; $page <= min($pages, self::MAX_PAGES); $page++) {
            $imported += $this->import((array) $this->fetch($query, $page)->json('items', []));
        }
        $this->line($from->toDateString().' → '.$to->toDateString().": $imported prezzi");

        return $imported;
    }

    /**
     * Una pagina di prezzi, salvata in blocco.
     *
     * @param  array<int, array<string, mixed>>  $prices
     */
    private function import(array $prices): int
    {
        $now = now();
        // Di ogni prodotto, catena, stato e comune si tiene solo il prezzo più recente.
        $latest = [];
        foreach ($prices as $price) {
            $location = $price['location'] ?? null;
            $supermarket = is_array($location) ? $this->chain($location) : null;
            $row = $supermarket ? $this->row($price, $location) : null;
            if ($row === null) {
                continue;
            }
            $row = [...$row, 'supermarket_id' => $supermarket->id, 'created_at' => $now, 'updated_at' => $now];
            $row['dedupe_key'] = sha1(implode('|', [
                $supermarket->id, $row['country'], Supermarket::normalize((string) $row['city']),
                $row['barcode'] ?? 'k:'.($row['product_key'] ?? Supermarket::normalize($row['product_name'])),
            ]));
            if (! isset($latest[$row['dedupe_key']]) || self::newer($row, $latest[$row['dedupe_key']])) {
                $latest[$row['dedupe_key']] = $row;
            }
        }
        if ($latest === []) {
            return 0;
        }

        $existing = PriceReport::whereIn('dedupe_key', array_keys($latest))
            ->get(['id', 'dedupe_key', 'external_id', 'observed_at'])
            ->keyBy('dedupe_key');
        $replaced = [];
        foreach ($latest as $key => $row) {
            $old = $existing[$key] ?? null;
            if ($old === null || $old->external_id === $row['external_id']) {
                continue;
            }
            $current = ['observed_at' => $old->observed_at->toDateTimeString(), 'external_id' => $old->external_id];
            if (self::newer($row, $current)) {
                $replaced[] = $old->id;
            } else {
                unset($latest[$key]);
            }
        }
        if ($latest === []) {
            return 0;
        }

        // Rileggendo lo stesso prezzo si aggiornano i dati, non lo stato: le smentite degli utenti restano.
        $rows = array_values($latest);
        PriceReport::upsert($rows, ['dedupe_key'], array_keys(collect($rows[0])->except(['dedupe_key', 'created_at', 'status'])->all()));
        // Un prezzo più recente sostituisce il vecchio: le conferme erano per il prezzo vecchio.
        if ($replaced !== []) {
            PriceReportVote::whereIn('price_report_id', $replaced)->delete();
            PriceReport::whereKey($replaced)->update(['status' => PriceReport::APPROVED, 'approvals' => 0, 'rejections' => 0]);
        }

        return count($rows);
    }

    /**
     * [$a] è più recente di [$b]: data del prezzo e, a parità, inserito dopo su Open Prices.
     *
     * @param  array<string, mixed>  $a
     * @param  array<string, mixed>  $b
     */
    private static function newer(array $a, array $b): bool
    {
        $id = fn (array $row) => (int) substr((string) $row['external_id'], 3);

        return [(string) $a['observed_at'], $id($a)] > [(string) $b['observed_at'], $id($b)];
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
     * Una pagina di prezzi (100), con una pausa per non pesare sul servizio.
     *
     * @param  array<string, mixed>  $query
     */
    private function fetch(array $query, int $page): Response
    {
        usleep((int) $this->option('pause') * 1000);

        return Http::withUserAgent(OpenFoodFacts::userAgent())
            ->timeout(60)
            ->retry(3, 5000)
            ->get(self::API.'/prices', [...$query, 'size' => 100, 'page' => $page]);
    }
}
