<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\User;
use App\Support\AccountDeleter;
use App\Support\OpenFoodFacts;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductsTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Risposte finte di Open Food Facts: i prodotti dati per qualunque ricerca.
     */
    private function fakeOpenFoodFacts(array $hits): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['search.openfoodfacts.org/*' => Http::response(['hits' => $hits])]);
    }

    public function test_renaming_drops_the_brand_unless_another_product_is_chosen(): void
    {
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte Parmalat', 'barcode' => '8002580018446', 'brand' => 'Parmalat'])
            ->assertJsonPath('data.barcode', '8002580018446')
            ->assertJsonPath('data.brand', 'Parmalat')
            ->json('data.id');

        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['quantity' => '2'])->assertJsonPath('data.barcode', '8002580018446');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte Granarolo', 'barcode' => '8000000000999', 'brand' => 'Granarolo'])
            ->assertJsonPath('data.brand', 'Granarolo');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte di capra'])
            ->assertJsonPath('data.barcode', null)
            ->assertJsonPath('data.brand', null);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'X', 'barcode' => 'abc'])->assertJsonValidationErrors('barcode');
    }

    public function test_product_search_suggests_branded_products(): void
    {
        $this->fakeOpenFoodFacts([
            ['code' => '8002580018446', 'product_name' => 'latte intero', 'brands' => ['Parmalat'], 'quantity' => '1 L', 'product_quantity' => 1000, 'product_quantity_unit' => 'ml', 'image_front_url' => 'https://images.openfoodfacts.org/latte.jpg'],
            ['code' => '8002580018447', 'product_name' => 'latte intero', 'brands' => ['Parmalat'], 'quantity' => '1 L'],
            ['code' => '8002580012444', 'product_name' => 'Latte Zymil Parmalat', 'brands' => ['Parmalat']],
            ['code' => '1', 'product_name' => '', 'brands' => ['Senza nome']],
        ]);
        Sanctum::actingAs(User::factory()->create());

        $rows = $this->getJson('/api/products/search?q='.urlencode('Latte parm"'))->assertOk()->json('data');

        $this->assertSame(['latte intero Parmalat', 'Latte Zymil Parmalat'], array_column($rows, 'name'));
        $this->assertSame(['8002580018446', 'Parmalat', '1 L', 1000, 'ml', 'https://images.openfoodfacts.org/latte.jpg'], [
            $rows[0]['barcode'], $rows[0]['brand'], $rows[0]['quantity'], $rows[0]['amount'], $rows[0]['unit'], $rows[0]['image_url'],
        ]);
        // Le parole dell'utente diventano solo termini di ricerca: tutte richieste, l'ultima anche iniziata, in Italia.
        Http::assertSent(fn (Request $r) => $r['q'] === 'latte AND (parm OR parm*) AND countries_tags:"en:italy"');

        $this->getJson('/api/products/search?q=la')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_package_size_is_read_from_the_label(): void
    {
        $this->assertSame([700.0, 'g'], OpenFoodFacts::parseQuantity('700 g'));
        $this->assertSame([1.0, 'l'], OpenFoodFacts::parseQuantity('1 L'));
        $this->assertSame([1.5, 'l'], OpenFoodFacts::parseQuantity('1,5l'));
        $this->assertSame([null, null], OpenFoodFacts::parseQuantity('6 x 1000 ml'));
        $this->assertSame([null, null], OpenFoodFacts::parseQuantity('43 g (2 x 21,5 g)'));
        $this->assertSame([null, null], OpenFoodFacts::parseQuantity('una confezione'));
    }

    public function test_only_branded_products_get_a_photo_and_it_goes_away_when_renamed(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['*' => Http::response(['hits' => [['code' => '1', 'product_name' => 'Latte', 'image_front_url' => 'https://images.openfoodfacts.org/latte.jpg']]])]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        // Scritto a mano: nessuna foto cercata in automatico.
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->assertJsonPath('data.image_url', null);
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.image_url', null);
        Http::assertNothingSent();

        // Scelto dai suggerimenti: la foto del prodotto; rinominandolo in un altro prodotto se ne va con la marca.
        $id = $this->postJson("/api/lists/{$list->id}/items", [
            'name' => 'Latte intero Parmalat', 'barcode' => '8002580018446', 'brand' => 'Parmalat',
            'image_url' => 'https://images.openfoodfacts.org/parmalat.jpg',
        ])->assertJsonPath('data.image_url', 'https://images.openfoodfacts.org/parmalat.jpg')->json('data.id');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['quantity' => '2', 'image_url' => 'https://images.openfoodfacts.org/parmalat.jpg'])
            ->assertJsonPath('data.image_url', 'https://images.openfoodfacts.org/parmalat.jpg');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte di capra', 'image_url' => 'https://images.openfoodfacts.org/parmalat.jpg'])
            ->assertJsonPath('data.image_url', null)
            ->assertJsonPath('data.barcode', null);

        // Un link scelto a mano resta anche cambiando nome.
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Torta', 'image_url' => 'https://example.com/torta.jpg'])->json('data.id');
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Torta della nonna'])
            ->assertJsonPath('data.image_url', 'https://example.com/torta.jpg');
    }

    public function test_open_food_facts_down_does_not_break_adding_items(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['search.openfoodfacts.org/*' => Http::response('errore', 500)]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->assertCreated();
        $this->getJson('/api/products/search?q=latte')->assertOk()->assertJsonCount(0, 'data');
    }

    /**
     * Un prezzo di Open Prices com'è nell'API, con il negozio dentro.
     */
    public function test_list_keeps_the_supermarket_without_any_price(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $id = $this->postJson('/api/lists', ['name' => 'Spesa', 'scheduled_at' => now()->addDay()->toIso8601String(), 'supermarket' => 'Conad Vomero'])
            ->assertCreated()
            ->assertJsonPath('data.supermarket', 'Conad Vomero')
            ->assertJsonMissingPath('data.supermarket_chain')
            ->json('data.id');
        $this->postJson("/api/lists/$id/items", ['name' => 'Latte'])
            ->assertCreated()
            ->assertJsonMissingPath('data.price')
            ->assertJsonMissingPath('data.price_info');
        $this->getJson("/api/lists/$id/price-comparison")->assertNotFound();

        $names = array_column($this->getJson('/api/supermarkets')->assertOk()->json('data'), 'name');
        $this->assertContains('Esselunga', $names);
        $this->assertContains('Conad', $names);
    }

    public function test_personal_prices_are_seen_and_changed_only_by_their_owner(): void
    {
        $me = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($me);

        $id = $this->postJson('/api/me/prices', [
            'product_name' => 'Latte intero Parmalat', 'barcode' => '8002580018446', 'brand' => 'Parmalat',
            'supermarket' => 'Conad', 'price' => 1.39, 'per' => 'pz',
        ])->assertCreated()->assertJsonPath('data.price', 1.39)->json('data.id');
        $this->postJson('/api/me/prices', ['product_name' => 'Mele', 'price' => 2.2, 'per' => 'kg'])->assertCreated();
        $this->postJson('/api/me/prices', ['product_name' => 'X', 'price' => 0])->assertJsonValidationErrors('price');
        $this->postJson('/api/me/prices', ['product_name' => 'X', 'price' => 1, 'per' => 'etto'])->assertJsonValidationErrors('per');

        $this->assertCount(2, $this->getJson('/api/me/prices')->json('data'));
        $this->assertSame(['Latte intero Parmalat'], array_column($this->getJson('/api/me/prices?q=conad')->json('data'), 'product_name'));
        $this->patchJson("/api/me/prices/$id", ['price' => 1.45, 'supermarket' => 'Coop'])
            ->assertOk()
            ->assertJsonPath('data.price', 1.45)
            ->assertJsonPath('data.supermarket', 'Coop');

        // Un altro utente non li vede e non li tocca.
        Sanctum::actingAs($other);
        $this->assertCount(0, $this->getJson('/api/me/prices')->json('data'));
        $this->patchJson("/api/me/prices/$id", ['price' => 9])->assertNotFound();
        $this->deleteJson("/api/me/prices/$id")->assertNotFound();

        Sanctum::actingAs($me);
        $this->deleteJson("/api/me/prices/$id")->assertNoContent();
        $this->assertCount(1, $this->getJson('/api/me/prices')->json('data'));

        // Eliminando l'account se ne vanno anche i suoi prezzi.
        AccountDeleter::delete($me);
        $this->assertDatabaseCount('user_prices', 0);
    }

    public function test_item_info_comes_from_open_food_facts(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake([
            'world.openfoodfacts.org/*' => Http::response(['status' => 1, 'product' => [
                'code' => '3017620422003', 'product_name' => 'Nutella', 'product_name_it' => 'Nutella', 'brands' => 'Nutella, Ferrero',
                'quantity' => '400 g', 'image_front_url' => 'https://img/front.jpg', 'image_ingredients_url' => 'https://img/ingr.jpg',
                'nutriments' => ['energy-kcal_100g' => 539, 'fat_100g' => 30.9, 'sugars_100g' => 56.3, 'salt_100g' => 0.107],
                'ingredients_text_it' => 'Zucchero, olio di palma, nocciole 13%',
                'allergens_tags' => ['en:milk', 'en:nuts', 'en:soybeans'], 'traces_tags' => [],
                'labels_tags' => ['en:vegetarian', 'en:no-gluten'], 'ingredients_analysis_tags' => ['en:palm-oil', 'en:non-vegan', 'en:vegetarian'],
                'nutriscore_grade' => 'e', 'nova_group' => 4,
            ]]),
            'search.openfoodfacts.org/*' => Http::response(['hits' => [['code' => '3017620422003', 'product_name' => 'Nutella']]]),
        ]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $branded = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Nutella', 'barcode' => '3017620422003'])->json('data.id');
        $typed = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Crema di nocciole'])->json('data.id');

        $this->getJson("/api/lists/{$list->id}/items/{$branded}/info")
            ->assertOk()
            ->assertJsonPath('data.barcode', '3017620422003')
            ->assertJsonPath('data.brand', 'Nutella')
            ->assertJsonPath('data.matched_by', 'barcode')
            ->assertJsonPath('data.images', ['https://img/front.jpg', 'https://img/ingr.jpg'])
            ->assertJsonPath('data.nutriments.energy-kcal', 539)
            ->assertJsonPath('data.nutriments.proteins', null)
            ->assertJsonPath('data.kind', 'food')
            ->assertJsonPath('data.minerals', [])
            ->assertJsonPath('data.ingredients', 'Zucchero, olio di palma, nocciole 13%')
            ->assertJsonPath('data.allergens', ['milk', 'nuts', 'soybeans'])
            ->assertJsonPath('data.gluten_free', true)
            ->assertJsonPath('data.vegetarian', true)
            ->assertJsonPath('data.vegan', false)
            ->assertJsonPath('data.palm_oil_free', false)
            ->assertJsonPath('data.nutriscore', 'e')
            ->assertJsonPath('data.nova', 4);
        // Scritto a mano: il prodotto più simile al nome.
        $this->getJson("/api/lists/{$list->id}/items/{$typed}/info")->assertJsonPath('data.matched_by', 'name');

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/lists/{$list->id}/items/{$branded}/info")->assertForbidden();
    }

    public function test_water_info_has_minerals_in_milligrams_per_litre(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake([
            'world.openfoodfacts.org/*' => Http::response(['status' => 1, 'product' => [
                'code' => '80412021', 'product_name' => 'Acqua minerale naturale frizzante Lete',
                'categories_tags' => ['en:beverages', 'en:waters', 'en:mineral-waters', 'en:natural-mineral-waters'],
                // Open Food Facts: grammi per 100 ml.
                'nutriments' => [
                    'calcium_100g' => 0.0305, 'magnesium_100g' => 0.00133, 'sodium_100g' => 0.0005,
                    'bicarbonate_100g' => 0.094, 'fluoride_100g' => 3e-05, 'energy-kcal_100g' => 0,
                ],
            ]]),
        ]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Lete', 'barcode' => '80412021'])->json('data.id');

        $this->getJson("/api/lists/{$list->id}/items/{$id}/info")
            ->assertOk()
            ->assertJsonPath('data.kind', 'water')
            ->assertJsonPath('data.minerals.calcium', 305)
            ->assertJsonPath('data.minerals.magnesium', 13.3)
            ->assertJsonPath('data.minerals.sodium', 5)
            ->assertJsonPath('data.minerals.bicarbonate', 940)
            ->assertJsonPath('data.minerals.fluoride', 0.3)
            ->assertJsonPath('data.minerals.nitrate', null);
    }

    public function test_flavoured_water_is_food(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake([
            'world.openfoodfacts.org/*' => Http::response(['status' => 1, 'product' => [
                'code' => '8001234567890', 'product_name' => 'Acqua al limone',
                'categories_tags' => ['en:beverages', 'en:waters', 'en:flavoured-waters'],
                'nutriments' => ['energy-kcal_100g' => 20, 'sugars_100g' => 4.8],
            ]]),
        ]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Acqua al limone', 'barcode' => '8001234567890'])->json('data.id');

        $this->getJson("/api/lists/{$list->id}/items/{$id}/info")
            ->assertJsonPath('data.kind', 'food')
            ->assertJsonPath('data.nutriments.sugars', 4.8);
    }

    public function test_item_info_is_null_when_nothing_is_found(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['*' => Http::response(['status' => 0, 'hits' => []])]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Torta della nonna'])->json('data.id');

        $this->getJson("/api/lists/{$list->id}/items/{$id}/info")->assertOk()->assertJsonPath('data', null);
    }

    public function test_loose_items_get_average_values_from_ciqual_without_calling_open_food_facts(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake();
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $apples = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Mele golden'])->json('data.id');
        $ham = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Prosciutto crudo'])->json('data.id');

        $this->getJson("/api/lists/{$list->id}/items/{$apples}/info")
            ->assertOk()
            ->assertJsonPath('data.matched_by', 'generic')
            ->assertJsonPath('data.source', 'CIQUAL (ANSES)')
            ->assertJsonPath('data.kind', 'food')
            ->assertJsonPath('data.nutriments.energy-kcal', 52.4)
            ->assertJsonPath('data.vegan', true)
            ->assertJsonPath('data.gluten_free', true);
        $this->getJson("/api/lists/{$list->id}/items/{$ham}/info")
            ->assertJsonPath('data.nutriments.salt', 5.67)
            ->assertJsonPath('data.vegetarian', false);
        Http::assertNothingSent();
    }

    public function test_hygiene_and_household_products_come_from_the_sister_databases(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake([
            'world.openbeautyfacts.org/cgi/search.pl*' => Http::response(['products' => [
                ['code' => '8001090662231', 'product_name' => 'Shampoo Coconut Milk', 'brands' => 'Herbal Essences, P&G',
                    'quantity' => '400 ml', 'product_quantity' => 400, 'product_quantity_unit' => 'ml', 'image_front_url' => 'https://images.openbeautyfacts.org/s.jpg'],
            ]]),
            'world.openfoodfacts.org/*' => Http::response(['status' => 0]),
            'world.openbeautyfacts.org/api/v2/product/*' => Http::response(['status' => 1, 'product' => [
                'code' => '8001090662231', 'product_name' => 'Shampoo Coconut Milk', 'brands' => 'Herbal Essences',
                'ingredients_text' => 'Aqua, Sodium Laureth Sulfate', 'labels_tags' => ['en:vegan'],
            ]]),
            '*' => Http::response(['hits' => []]),
        ]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->getJson('/api/products/search?q=shampoo')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Shampoo Coconut Milk Herbal Essences')
            ->assertJsonPath('data.0.amount', 400)
            ->assertJsonPath('data.0.image_url', 'https://images.openbeautyfacts.org/s.jpg');

        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Shampoo', 'barcode' => '8001090662231'])->json('data.id');
        $this->getJson("/api/lists/{$list->id}/items/{$id}/info")
            ->assertJsonPath('data.source', 'Open Beauty Facts')
            ->assertJsonPath('data.kind', 'other')
            ->assertJsonPath('data.url', 'https://world.openbeautyfacts.org/product/8001090662231')
            ->assertJsonPath('data.ingredients', 'Aqua, Sodium Laureth Sulfate');
        Http::assertNotSent(fn ($request) => str_contains($request->url(), 'search.openfoodfacts.org'));
    }

    public function test_brand_with_a_generic_word_is_searched_again_by_brand_with_local_products_first(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(function ($request) {
            if (! str_contains($request->url(), 'world.openproductsfacts.org/cgi/search.pl')) {
                return Http::response(['hits' => [], 'products' => []]);
            }

            // Nessun nome contiene "detersivo": si trova solo cercando la marca.
            return Http::response(['products' => $request['search_terms'] === 'calgon' ? [
                ['code' => '1', 'product_name' => 'Calgon Wasmachinereiniger', 'brands' => 'Calgon', 'countries_tags' => ['en:netherlands']],
                ['code' => '2', 'product_name' => 'Calgon Gel 3 in 1', 'brands' => 'Calgon', 'countries_tags' => ['en:italy']],
            ] : []]);
        });
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->getJson('/api/products/search?q=calgon%20detersivo')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.name', 'Calgon Gel 3 in 1');
    }
}
