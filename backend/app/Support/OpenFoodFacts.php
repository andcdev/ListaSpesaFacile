<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Prodotti di marca da Open Food Facts (search.openfoodfacts.org): suggerimenti mentre si scrive ("latte parm" →
 * Latte intero Parmalat 1 L, con foto) e scheda del prodotto (menu Info).
 *
 * Le risposte restano in cache un giorno: la stessa ricerca fatta da più utenti interroga il servizio una volta.
 * Se il servizio non risponde si torna una lista vuota: la lista della spesa funziona comunque.
 */
class OpenFoodFacts
{
    public const SEARCH_URL = 'https://search.openfoodfacts.org/search';

    /** Paesi (ISO) → tag di Open Food Facts, per cercare i prodotti venduti nel paese del telefono. */
    public const COUNTRIES = [
        'IT' => 'en:italy', 'SM' => 'en:san-marino', 'VA' => 'en:vatican-city', 'CH' => 'en:switzerland', 'FR' => 'en:france',
        'MC' => 'en:monaco', 'DE' => 'en:germany', 'AT' => 'en:austria', 'ES' => 'en:spain', 'PT' => 'en:portugal',
        'GB' => 'en:united-kingdom', 'IE' => 'en:ireland', 'BE' => 'en:belgium', 'NL' => 'en:netherlands', 'LU' => 'en:luxembourg',
        'DK' => 'en:denmark', 'SE' => 'en:sweden', 'NO' => 'en:norway', 'FI' => 'en:finland', 'IS' => 'en:iceland',
        'PL' => 'en:poland', 'CZ' => 'en:czech-republic', 'SK' => 'en:slovakia', 'HU' => 'en:hungary', 'SI' => 'en:slovenia',
        'HR' => 'en:croatia', 'RO' => 'en:romania', 'BG' => 'en:bulgaria', 'GR' => 'en:greece', 'CY' => 'en:cyprus',
        'MT' => 'en:malta', 'EE' => 'en:estonia', 'LV' => 'en:latvia', 'LT' => 'en:lithuania', 'UA' => 'en:ukraine',
        'RU' => 'en:russia', 'AL' => 'en:albania', 'BA' => 'en:bosnia-and-herzegovina', 'RS' => 'en:serbia', 'TR' => 'en:turkey',
        'IL' => 'en:israel', 'MA' => 'en:morocco', 'TN' => 'en:tunisia', 'US' => 'en:united-states', 'CA' => 'en:canada',
        'MX' => 'en:mexico', 'BR' => 'en:brazil', 'AR' => 'en:argentina', 'JP' => 'en:japan', 'IN' => 'en:india',
        'SG' => 'en:singapore', 'TW' => 'en:taiwan', 'MY' => 'en:malaysia', 'TH' => 'en:thailand', 'AU' => 'en:australia',
        'NZ' => 'en:new-zealand', 'BD' => 'en:bangladesh', 'KZ' => 'en:kazakhstan',
    ];

    /**
     * Paese in cui cercare i prodotti per chi usa l'app in una lingua: italiano → Italia; inglese → ovunque.
     */
    public static function countryForLocale(?string $locale): ?string
    {
        return match ($locale) {
            'fr' => 'FR',
            'de' => 'DE',
            'es' => 'ES',
            'en' => null,
            default => 'IT',
        };
    }

    /**
     * Prodotti che corrispondono a quanto scritto: tutte le parole, l'ultima anche solo iniziata.
     *
     * @return array<int, array{barcode: string, name: string, brand: string|null, quantity: string|null, amount: float|null, unit: string|null, image_url: string|null}>
     */
    public static function search(string $text, ?string $country = 'IT', int $limit = 8): array
    {
        $words = self::words($text);
        if ($words === [] || mb_strlen(implode('', $words)) < 3) {
            return [];
        }
        $last = array_pop($words);
        $terms = [...$words, mb_strlen($last) >= 3 ? "($last OR $last*)" : $last];
        if ($country !== null && ($tag = self::COUNTRIES[$country] ?? null)) {
            $terms[] = "countries_tags:\"$tag\"";
        }
        $query = implode(' AND ', $terms);

        $hits = Cache::remember('off:search:'.md5($query), now()->addDay(), fn () => self::fetch($query));

        $products = [];
        foreach ($hits as $hit) {
            $product = self::fromHit($hit);
            $key = Str::lower($product['name'].'|'.$product['brand'].'|'.$product['quantity']);
            if ($product['name'] !== '' && ! isset($products[$key])) {
                $products[$key] = $product;
            }
        }

        return array_slice(array_values($products), 0, $limit);
    }

    public const PRODUCT_URL = 'https://world.openfoodfacts.org/api/v2/product/';

    /** Valori nutrizionali per 100 g o 100 ml mostrati nell'app. */
    public const NUTRIMENTS = [
        'energy-kcal', 'fat', 'saturated-fat', 'carbohydrates', 'sugars', 'fiber', 'proteins', 'salt',
    ];

    /** Minerali delle acque, in mg/L come sulle etichette (Open Food Facts li tiene in g per 100 ml). */
    public const MINERALS = [
        'calcium', 'magnesium', 'sodium', 'potassium', 'bicarbonate', 'chloride', 'sulphate', 'nitrate', 'fluoride',
        'silica',
    ];

    /** Categorie delle acque (le aromatizzate no: hanno zuccheri e calorie come una bibita). */
    private const WATER_CATEGORIES = ['waters', 'mineral-waters', 'natural-mineral-waters', 'spring-waters'];

    /**
     * Scheda del prodotto: foto, valori nutrizionali, ingredienti, allergeni, tracce e se è adatto a celiaci,
     * vegetariani e vegani (true = sì, false = no, null = non si sa). Null se il prodotto non c'è.
     *
     * @return array<string, mixed>|null
     */
    public static function product(string $barcode): ?array
    {
        if (! config('services.openfoodfacts.enabled') || ! preg_match('/^\d{4,20}$/', $barcode)) {
            return null;
        }
        $data = Cache::remember('off:product:'.$barcode, now()->addDay(), function () use ($barcode) {
            try {
                $response = Http::withUserAgent(self::userAgent())
                    ->timeout(8)
                    ->get(self::PRODUCT_URL.$barcode.'.json', ['fields' => implode(',', [
                        'code', 'product_name', 'product_name_it', 'brands', 'quantity', 'image_front_url',
                        'image_ingredients_url', 'image_nutrition_url', 'image_packaging_url', 'nutriments',
                        'ingredients_text_it', 'ingredients_text', 'allergens_tags', 'traces_tags', 'labels_tags',
                        'ingredients_analysis_tags', 'nutriscore_grade', 'nova_group', 'categories_tags',
                    ])]);

                return $response->successful() && $response->json('status') === 1 ? (array) $response->json('product') : [];
            } catch (Throwable $e) {
                Log::warning('Open Food Facts non raggiungibile: '.$e->getMessage());

                return null;
            }
        });

        return $data ? self::describe($data) : null;
    }

    /**
     * Scheda di un articolo: il suo prodotto di marca, oppure il prodotto più simile al nome (matched_by = "name").
     *
     * @return array<string, mixed>|null
     */
    public static function productFor(?string $barcode, string $name, ?string $country): ?array
    {
        if ($barcode && ($product = self::product($barcode))) {
            return [...$product, 'matched_by' => 'barcode'];
        }
        foreach (self::search($name, $country, 5) as $hit) {
            if ($hit['barcode'] !== '' && ($product = self::product($hit['barcode']))) {
                return [...$product, 'matched_by' => 'name'];
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $p
     * @return array<string, mixed>
     */
    private static function describe(array $p): array
    {
        $tags = fn (string $key) => array_values(array_map(
            fn ($t) => Str::after((string) $t, ':'),
            array_filter((array) ($p[$key] ?? []), fn ($t) => is_string($t)),
        ));
        $allergens = $tags('allergens_tags');
        $labels = $tags('labels_tags');
        $analysis = $tags('ingredients_analysis_tags');
        $status = fn (string $yes, string $no) => in_array($yes, $analysis, true) || in_array($yes, $labels, true)
            ? true
            : (in_array($no, $analysis, true) ? false : null);
        $nutriments = (array) ($p['nutriments'] ?? []);
        $categories = $tags('categories_tags');
        $water = array_intersect(self::WATER_CATEGORIES, $categories) !== []
            && array_intersect(['flavoured-waters', 'flavored-waters'], $categories) === [];

        return [
            'barcode' => (string) ($p['code'] ?? ''),
            'name' => trim((string) ($p['product_name_it'] ?? '') ?: (string) ($p['product_name'] ?? '')),
            'brand' => trim(Str::before((string) ($p['brands'] ?? ''), ',')) ?: null,
            'quantity' => $p['quantity'] ?? null,
            // Prima la confezione, poi ingredienti, tabella nutrizionale e imballaggio.
            'images' => array_values(array_filter([
                $p['image_front_url'] ?? null, $p['image_ingredients_url'] ?? null,
                $p['image_nutrition_url'] ?? null, $p['image_packaging_url'] ?? null,
            ])),
            'nutriments' => collect(self::NUTRIMENTS)
                ->mapWithKeys(fn (string $n) => [$n => is_numeric($nutriments[$n.'_100g'] ?? null) ? round((float) $nutriments[$n.'_100g'], 2) : null])
                ->all(),
            // Acqua: minerali al posto dei valori nutrizionali (g per 100 ml × 10.000 = mg/L).
            'kind' => $water ? 'water' : 'food',
            'minerals' => $water
                ? collect(self::MINERALS)
                    ->mapWithKeys(fn (string $m) => [$m => is_numeric($nutriments[$m.'_100g'] ?? null) ? round((float) $nutriments[$m.'_100g'] * 10000, 2) : null])
                    ->all()
                : [],
            'ingredients' => trim((string) ($p['ingredients_text_it'] ?? '') ?: (string) ($p['ingredients_text'] ?? '')) ?: null,
            'allergens' => $allergens,
            'traces' => $tags('traces_tags'),
            // Celiaci: senza glutine se lo dice l'etichetta, no se il glutine è tra gli allergeni.
            'gluten_free' => in_array('no-gluten', $labels, true) || in_array('gluten-free', $labels, true)
                ? true
                : (in_array('gluten', $allergens, true) ? false : null),
            'lactose_free' => in_array('no-lactose', $labels, true) || in_array('lactose-free', $labels, true) ? true : null,
            'vegetarian' => $status('vegetarian', 'non-vegetarian'),
            'vegan' => $status('vegan', 'non-vegan'),
            'palm_oil_free' => in_array('palm-oil-free', $analysis, true) ? true : (in_array('palm-oil', $analysis, true) ? false : null),
            'nutriscore' => in_array($p['nutriscore_grade'] ?? null, ['a', 'b', 'c', 'd', 'e'], true) ? $p['nutriscore_grade'] : null,
            'nova' => is_numeric($p['nova_group'] ?? null) ? (int) $p['nova_group'] : null,
            'url' => 'https://world.openfoodfacts.org/product/'.($p['code'] ?? ''),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private static function fetch(string $query): array
    {
        if (! config('services.openfoodfacts.enabled')) {
            return [];
        }
        try {
            $response = Http::withUserAgent(self::userAgent())
                ->timeout(6)
                ->get(self::SEARCH_URL, [
                    'q' => $query,
                    'page_size' => 20,
                    'langs' => 'it',
                    'fields' => 'code,product_name,product_name_it,brands,quantity,product_quantity,product_quantity_unit,image_front_url',
                ]);

            return $response->successful() ? (array) $response->json('hits', []) : [];
        } catch (Throwable $e) {
            Log::warning('Open Food Facts non raggiungibile: '.$e->getMessage());

            return [];
        }
    }

    /**
     * @param  array<string, mixed>  $hit
     * @return array{barcode: string, name: string, brand: string|null, quantity: string|null, amount: float|null, unit: string|null, image_url: string|null}
     */
    private static function fromHit(array $hit): array
    {
        $brands = array_values(array_filter(array_map('trim', (array) ($hit['brands'] ?? []))));
        $brand = $brands[0] ?? null;
        $name = trim((string) ($hit['product_name_it'] ?? $hit['product_name'] ?? ''));
        // "Latte intero" di Parmalat → "Latte intero Parmalat"; il nome che contiene già la marca resta com'è.
        if ($brand && $name !== '' && ! Str::contains(Str::lower($name), Str::lower($brand))) {
            $name .= ' '.$brand;
        }
        [$amount, $unit] = self::measure($hit['product_quantity'] ?? null, $hit['product_quantity_unit'] ?? null);
        if ($amount === null) {
            [$amount, $unit] = self::parseQuantity((string) ($hit['quantity'] ?? ''));
        }

        return [
            'barcode' => (string) ($hit['code'] ?? ''),
            'name' => Str::limit($name, 150, ''),
            'brand' => $brand ? Str::limit($brand, 100, '') : null,
            'quantity' => isset($hit['quantity']) ? Str::limit(trim((string) $hit['quantity']), 50, '') : null,
            'amount' => $amount,
            'unit' => $unit,
            'image_url' => $hit['image_front_url'] ?? null,
        ];
    }

    /**
     * Contenuto della confezione in un'unità dell'app: 1000 + "ml" → [1000, "ml"], 500 + "g" → [500, "g"].
     *
     * @return array{0: float|null, 1: string|null}
     */
    public static function measure(mixed $amount, mixed $unit): array
    {
        $unit = Str::lower((string) $unit);
        if (! is_numeric($amount) || $amount <= 0 || ! in_array($unit, ['g', 'kg', 'ml', 'cl', 'l'], true)) {
            return [null, null];
        }

        return [(float) $amount, $unit];
    }

    /**
     * Contenuto scritto sulla confezione: "700 g" → [700, "g"], "1 L" → [1, "l"], "1,5l" → [1.5, "l"];
     * le confezioni multiple ("6 x 1000 ml") e i testi non riconosciuti → [null, null].
     *
     * @return array{0: float|null, 1: string|null}
     */
    public static function parseQuantity(string $text): array
    {
        if (preg_match('/\d\s*x\s*\d/i', $text) || ! preg_match('/^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|l)\b/i', $text, $m)) {
            return [null, null];
        }

        return self::measure((float) str_replace(',', '.', $m[1]), $m[2]);
    }

    /**
     * Parole semplici (lettere e numeri): quello che scrive l'utente non diventa sintassi di ricerca.
     *
     * @return array<int, string>
     */
    private static function words(string $text): array
    {
        $clean = (string) preg_replace('/[^\p{L}\p{N}]+/u', ' ', Str::lower($text));

        return array_values(array_filter(explode(' ', $clean), fn ($w) => $w !== '' && ! in_array($w, ['and', 'or', 'not'], true)));
    }

    public static function userAgent(): string
    {
        return config('app.name').'/1.0 ('.config('app.url').')';
    }
}
