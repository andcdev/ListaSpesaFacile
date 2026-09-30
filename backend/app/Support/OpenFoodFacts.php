<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Prodotti di marca da Open Food Facts (search.openfoodfacts.org): suggerimenti mentre si scrive ("latte parm" →
 * Latte intero Parmalat 1 L, con foto) e foto di un articolo scritto a mano.
 *
 * Le risposte restano in cache un giorno: la stessa ricerca fatta da più utenti interroga il servizio una volta.
 * Se il servizio non risponde si torna una lista vuota: la lista della spesa funziona comunque.
 */
class OpenFoodFacts
{
    public const SEARCH_URL = 'https://search.openfoodfacts.org/search';

    /** Paesi (ISO) → tag di Open Food Facts. */
    public const COUNTRIES = [
        'IT' => 'en:italy', 'SM' => 'en:san-marino', 'CH' => 'en:switzerland', 'FR' => 'en:france',
        'DE' => 'en:germany', 'AT' => 'en:austria', 'ES' => 'en:spain', 'GB' => 'en:united-kingdom',
    ];

    /**
     * Prodotti che corrispondono a quanto scritto: tutte le parole, l'ultima anche solo iniziata.
     *
     * @return array<int, array{barcode: string, name: string, brand: string|null, quantity: string|null, amount: float|null, unit: string|null, image_url: string|null}>
     */
    public static function search(string $text, string $country = 'IT', int $limit = 8): array
    {
        $words = self::words($text);
        if ($words === [] || mb_strlen(implode('', $words)) < 3) {
            return [];
        }
        $last = array_pop($words);
        $terms = [...$words, mb_strlen($last) >= 3 ? "($last OR $last*)" : $last];
        if ($tag = self::COUNTRIES[$country] ?? null) {
            $terms[] = "countries_tags:\"$tag\"";
        }
        $query = implode(' AND ', $terms);

        $hits = Cache::remember('off:search:'.md5($query), now()->addDay(), fn () => self::fetch($query));

        $products = [];
        foreach ($hits as $hit) {
            $product = self::product($hit);
            $key = Str::lower($product['name'].'|'.$product['brand'].'|'.$product['quantity']);
            if ($product['name'] !== '' && ! isset($products[$key])) {
                $products[$key] = $product;
            }
        }

        return array_slice(array_values($products), 0, $limit);
    }

    /**
     * Foto per un articolo scritto a mano ("Latte intero" → la foto del primo latte intero trovato), null se non c'è.
     */
    public static function imageFor(string $name, string $country = 'IT'): ?string
    {
        foreach (self::search($name, $country, 20) as $product) {
            if ($product['image_url']) {
                return $product['image_url'];
            }
        }

        return null;
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
    private static function product(array $hit): array
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
