<?php

namespace Tests\Unit;

use App\Support\ProductCatalog;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class ProductCatalogTest extends TestCase
{
    /**
     * @return array<string, array{string, string, string}>
     */
    public static function products(): array
    {
        return [
            'singolare' => ['Mela', 'frutta', '🍎'],
            'plurale e maiuscole' => ['MELE golden', 'frutta', '🍎'],
            'radice' => ['pomodorini', 'verdura', '🍅'],
            'accento' => ['Caffè macinato', 'dispensa', '☕'],
            'prodotto prima del gusto' => ['Yogurt alla fragola', 'latticini', '🥛'],
            'succo di frutta' => ['succo di mela', 'bevande', '🧃'],
            'espressione' => ['Carta igienica 12 rotoli', 'igiene', '🧻'],
            'latte vegetale' => ['latte di soia', 'bevande', '🥛'],
            'radice più specifica' => ['patatine', 'dolci', '🥔'],
            'patate' => ['patate', 'verdura', '🥔'],
            'peperoncino non è pepe' => ['peperoncino', 'verdura', '🌶️'],
            'panna non è pane' => ['panna da cucina', 'latticini', '🥛'],
            'panettone' => ['panettone', 'dolci', '🍰'],
            'pane' => ['pane integrale', 'pane', '🍞'],
            'numero davanti' => ['2 bottiglie di vino rosso', 'bevande', '🍷'],
            'carne' => ['petto di pollo', 'carne', '🍗'],
            'pesce' => ['Salmone affumicato', 'pesce', '🐟'],
            'parola corta intera' => ['tè verde', 'dispensa', '🍵'],
            'parola corta non come prefisso' => ['tegame', 'altro', '🛒'],
            'casa' => ['Detersivo piatti', 'casa', '🧴'],
            'animali' => ['crocchette gatto', 'animali', '🐾'],
            'surgelati' => ['gelato al cioccolato', 'surgelati', '🍨'],
            'sconosciuto' => ['regalo per Anna', 'altro', '🛒'],
        ];
    }

    #[DataProvider('products')]
    public function test_detects_category_and_icon(string $name, string $category, string $icon): void
    {
        $this->assertSame(['category' => $category, 'icon' => $icon], ProductCatalog::detect($name));
    }

    public function test_every_product_points_to_an_existing_category(): void
    {
        $reflection = new \ReflectionClass(ProductCatalog::class);
        foreach (['PRODUCTS', 'PHRASES'] as $constant) {
            foreach ($reflection->getConstant($constant) as $stem => [$category]) {
                $this->assertArrayHasKey($category, ProductCatalog::CATEGORIES, "$constant: $stem");
            }
        }
    }
}
