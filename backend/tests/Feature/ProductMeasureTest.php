<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use App\Support\ProductCatalog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductMeasureTest extends TestCase
{
    use RefreshDatabase;

    public function test_measure_follows_how_the_product_is_sold(): void
    {
        $cases = [
            // Frutta e verdura che si contano: peso e pezzi.
            'Mele' => 'weight_count', 'Pere golden' => 'weight_count', 'Pomodori' => 'weight_count',
            'Melanzane' => 'weight_count', 'Zucchine' => 'weight_count', 'Banane' => 'weight_count',
            // Sfusi solo a peso: frutta e verdura che non si contano, salumi e formaggi al banco, carne fresca.
            'Uva' => 'weight', 'Ciliegie' => 'weight', 'Spinaci' => 'weight', 'Funghi' => 'weight',
            'Prosciutto crudo' => 'weight', 'Mortadella' => 'weight', 'Parmigiano' => 'weight', 'Pecorino romano' => 'weight',
            'Carne macinata' => 'weight',
            // Confezionati: solo il numero di confezioni.
            'Mozzarella' => 'count', 'Yogurt greco' => 'count', 'Latte' => 'count', 'Pasta' => 'count', 'Biscotti' => 'count',
            'Uova' => 'count', 'Wurstel' => 'count', 'Acqua naturale' => 'count',
            // Parole di confezione anche per un prodotto di solito sfuso.
            'Pomodori pelati' => 'count', 'Spinaci surgelati' => 'count', 'Prosciutto cotto affettato' => 'count',
            'Piselli' => 'count', 'Frutta secca' => 'count', 'Tonno in scatola' => 'count',
            // Altre lingue: si riconosce il prodotto italiano.
            'Apples' => 'weight_count', 'Tomaten' => 'weight_count',
            // Meno comuni, ma sfusi.
            'Nespole' => 'weight_count', 'Cicoria' => 'weight_count', 'Bietole' => 'weight', 'Taleggio' => 'weight',
            'Guanciale' => 'weight',
            // Non riconosciuto: confezionato.
            'Kinder sorpresa' => 'count', 'Pringles' => 'count',
        ];
        foreach ($cases as $name => $expected) {
            $this->assertSame($expected, ProductCatalog::measure($name), $name);
        }
        // Prodotto di marca (codice a barre): sempre confezione, anche se è un formaggio.
        $this->assertSame('count', ProductCatalog::measure('Parmigiano reggiano', '8001234567890'));
    }

    public function test_measure_reaches_the_app(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->getJson('/api/products/measure?name=Mele')->assertOk()->assertJsonPath('data.measure', 'weight_count');
        $this->getJson('/api/products/measure?name=Kinder%20sorpresa')->assertJsonPath('data.measure', 'count');
        $this->getJson('/api/products/measure')->assertJsonValidationErrors('name');

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Salame'])->assertJsonPath('data.measure', 'weight');
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Nutella', 'barcode' => '3017620422003'])
            ->assertJsonPath('data.measure', 'count');

        $suggestions = collect($this->getJson('/api/products/suggestions')->json('data'))->keyBy('name');
        $this->assertSame('weight', $suggestions['Salame']['measure']);
        $this->assertSame('weight_count', $suggestions['Melanzane']['measure']);
        $this->assertSame('count', $suggestions['Detersivo lavatrice']['measure']);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/products/measure?name=Mele')->assertOk();
    }
}
