<?php

namespace App\Support;

/**
 * Valori nutrizionali medi dei prodotti sfusi (frutta, verdura, salumi e formaggi al banco, carne e pesce) dalla
 * tabella CIQUAL 2020 dell'ANSES (licenza CC BY 4.0): resources/data/ciqual.json, una voce per ogni radice del
 * catalogo (ProductCatalog). Niente servizi esterni: il file sta nel server.
 */
class Ciqual
{
    public const SOURCE = 'CIQUAL (ANSES)';

    /** @var array<string, array{code: int, name: string, nutriments: array<string, float|null>}>|null */
    private static ?array $data = null;

    /**
     * Scheda per un prodotto sfuso scritto a mano, null se non è sfuso o non è nella tabella.
     *
     * @return array<string, mixed>|null
     */
    public static function productFor(string $name): ?array
    {
        if (! in_array(ProductCatalog::measure($name), [ProductCatalog::MEASURE_WEIGHT, ProductCatalog::MEASURE_WEIGHT_COUNT], true)) {
            return null;
        }
        $stem = ProductCatalog::productKey($name);
        $food = $stem === null ? null : (self::data()[$stem] ?? null);
        if ($food === null) {
            return null;
        }
        $category = ProductCatalog::detect($name)['category'];
        $plant = in_array($category, ['frutta', 'verdura'], true);
        $animal = in_array($category, ['carne', 'pesce', 'latticini'], true);

        return [
            'barcode' => '',
            'name' => '',
            'brand' => null,
            'quantity' => null,
            'images' => [],
            'nutriments' => $food['nutriments'],
            'kind' => 'food',
            'minerals' => [],
            'ingredients' => null,
            'allergens' => [],
            'traces' => [],
            // Frutta e verdura fresche: senza glutine, vegetariane e vegane. Carne, pesce e formaggi: non vegani.
            'gluten_free' => $plant ? true : null,
            'lactose_free' => null,
            'vegetarian' => $plant ? true : (in_array($category, ['carne', 'pesce'], true) ? false : null),
            'vegan' => $plant ? true : ($animal ? false : null),
            'palm_oil_free' => $plant ? true : null,
            'nutriscore' => null,
            'nova' => null,
            'url' => 'https://ciqual.anses.fr/#/aliments/'.$food['code'],
            'source' => self::SOURCE,
        ];
    }

    /**
     * @return array<string, array{code: int, name: string, nutriments: array<string, float|null>}>
     */
    private static function data(): array
    {
        return self::$data ??= json_decode((string) file_get_contents(resource_path('data/ciqual.json')), true) ?: [];
    }
}
