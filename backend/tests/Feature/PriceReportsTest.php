<?php

namespace Tests\Feature;

use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Models\User;
use App\Support\AccountDeleter;
use App\Support\OpenFoodFacts;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PriceReportsTest extends TestCase
{
    use RefreshDatabase;

    private function report(string $chain, array $attributes): PriceReport
    {
        return PriceReport::create([
            'supermarket_id' => Supermarket::where('name', $chain)->firstOrFail()->id,
            'product_name' => $attributes['product_key'] ?? 'prodotto',
            'per' => 'pz',
            'country' => 'IT',
            'source' => 'user',
            'observed_at' => now()->subDay(),
            ...$attributes,
        ]);
    }

    /**
     * Risposte finte di Open Food Facts: i prodotti dati per qualunque ricerca.
     */
    private function fakeOpenFoodFacts(array $hits): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['search.openfoodfacts.org/*' => Http::response(['hits' => $hits])]);
    }

    public function test_user_correction_shows_name_and_time_but_never_the_email(): void
    {
        Supermarket::where('name', 'Lidl')->first()->prices()->create(['product_key' => 'latte', 'product_name' => 'Latte', 'price' => 1.20, 'per' => 'l']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Lidl', 'city' => 'Milano']);
        $mario = User::factory()->create(['name' => 'Mario', 'email' => 'mario.segreto@example.com']);
        $list->sharedWith()->attach($mario->id, ['can_edit' => false]);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])
            ->assertJsonPath('data.price', 1.2)
            ->assertJsonPath('data.price_info.source', 'catalog')
            ->json('data.id');

        // Anche chi ha la sola lettura può correggere un prezzo.
        Sanctum::actingAs($mario);
        $response = $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1.35, 'per' => 'l'])
            ->assertCreated()
            ->assertJsonPath('data.price', 1.35)
            ->assertJsonPath('data.price_info.source', 'user')
            ->assertJsonPath('data.price_info.reporter', 'Mario')
            ->assertJsonPath('data.price_info.city', 'Milano');
        $this->assertNotNull($response->json('data.price_info.observed_at'));

        $history = $this->getJson("/api/lists/{$list->id}/items/{$id}/prices")
            ->assertOk()
            ->assertJsonPath('data.supermarket', 'Lidl')
            ->assertJsonPath('data.reports.0.reporter', 'Mario')
            ->assertJsonPath('data.reports.0.price', 1.35);
        $this->assertSame('mario.segreto@example.com', PriceReport::first()->reporter_email);
        $items = $this->getJson("/api/lists/{$list->id}")->json('data.items');
        foreach ([$response->getContent(), $history->getContent(), json_encode($items)] as $json) {
            $this->assertStringNotContainsString('mario.segreto', $json);
        }

        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1])->assertForbidden();
    }

    public function test_correction_needs_a_known_chain_and_a_valid_price(): void
    {
        $list = ShoppingList::factory()->create(['supermarket' => 'Bottega sotto casa']);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->json('data.id');

        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1.2])
            ->assertJsonValidationErrors(['price' => 'catena conosciuta']);

        $list->update(['supermarket' => 'Coop']);
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 0])->assertJsonValidationErrors('price');
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1, 'per' => 'etto'])->assertJsonValidationErrors('per');
    }

    public function test_closest_zone_wins_then_the_most_recent(): void
    {
        $this->report('Coop', ['product_key' => 'pane', 'price' => 3.00, 'city' => 'Roma', 'observed_at' => now()->subDays(10)]);
        $this->report('Coop', ['product_key' => 'pane', 'price' => 2.00, 'city' => 'Milano', 'observed_at' => now()->subDay()]);
        $this->report('Coop', ['product_key' => 'pane', 'price' => 9.00, 'country' => 'FR', 'city' => 'Roma', 'observed_at' => now()]);
        $list = ShoppingList::factory()->create(['supermarket' => 'Coop', 'city' => 'roma']);
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane']);

        // Roma batte Milano anche se più vecchio; il prezzo francese non conta.
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.price', 3);

        // Stessa località ancora prima della stessa città.
        $this->report('Coop', ['product_key' => 'pane', 'price' => 2.50, 'city' => 'Roma', 'locality' => 'Trastevere', 'observed_at' => now()->subYear()]);
        $this->patchJson("/api/lists/{$list->id}", ['locality' => 'Trastevere'])->assertJsonPath('data.items.0.price', 2.5);

        // Città senza prezzi: vale il più recente del paese.
        $this->patchJson("/api/lists/{$list->id}", ['city' => 'Torino', 'locality' => null])->assertJsonPath('data.items.0.price', 2);
    }

    public function test_branded_product_uses_its_own_price_and_generic_items_scale_the_package(): void
    {
        // Latte Parmalat da 1 l a 1,80 €; un altro latte da 1 l a 1,00 €, più recente.
        $this->report('Esselunga', ['product_key' => 'latte', 'barcode' => '8002580018446', 'price' => 1.80, 'package_amount' => 1, 'package_unit' => 'l', 'observed_at' => now()->subDays(3)]);
        $this->report('Esselunga', ['product_key' => 'latte', 'barcode' => '8000000000001', 'price' => 1.00, 'package_amount' => 1, 'package_unit' => 'l']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Esselunga']);
        Sanctum::actingAs($list->owner);

        $add = fn (array $item) => $this->postJson("/api/lists/{$list->id}/items", $item)->json('data.price');
        $this->assertEquals(3.6, $add(['name' => 'Latte intero Parmalat', 'barcode' => '8002580018446', 'brand' => 'Parmalat', 'quantity' => '2']));
        // Latte generico da mezzo litro: metà del prezzo più recente al litro.
        $this->assertEquals(0.5, $add(['name' => 'Latte', 'amount' => 500, 'unit' => 'ml']));
        // Prodotto di marca senza prezzi suoi: vale quello del tipo di prodotto.
        $this->assertEquals(1.0, $add(['name' => 'Latte Granarolo', 'barcode' => '8000000000999']));
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

    public function test_deleting_the_account_keeps_the_price_without_name_or_email(): void
    {
        $list = ShoppingList::factory()->create(['supermarket' => 'Lidl']);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->json('data.id');
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 2.2])->assertCreated();

        AccountDeleter::delete($list->owner);

        $report = PriceReport::sole();
        $this->assertEquals(2.2, $report->price);
        $this->assertNull($report->user_id);
        $this->assertNull($report->reporter_name);
        $this->assertNull($report->reporter_email);
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

    public function test_items_get_a_photo_from_open_food_facts_unless_the_user_chose_one(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        // Latte con foto (la prima senza); la torta non c'è.
        Http::fake(fn (Request $r) => Http::response(['hits' => str_contains($r['q'], 'torta') ? [] : [
            ['code' => '1', 'product_name' => 'Latte', 'brands' => ['Parmalat']],
            ['code' => '2', 'product_name' => 'Latte', 'brands' => ['Granarolo'], 'image_front_url' => 'https://images.openfoodfacts.org/latte.jpg'],
        ]]));
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->json('data.id');
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.image_url', 'https://images.openfoodfacts.org/latte.jpg');

        // Link scelto a mano: resta anche cambiando il nome.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['image_url' => 'https://example.com/mio.jpg']);
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte intero']);
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.image_url', 'https://example.com/mio.jpg');

        // Senza link, rinominando se ne cerca una di nuovo.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['image_url' => null]);
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Latte scremato']);
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.image_url', 'https://images.openfoodfacts.org/latte.jpg');

        // Nome nuovo senza foto su Open Food Facts: la foto automatica del nome vecchio se ne va.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['name' => 'Torta della nonna']);
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.image_url', null);
    }

    public function test_open_food_facts_down_does_not_break_adding_items(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Http::fake(['search.openfoodfacts.org/*' => Http::response('errore', 500)]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->assertCreated()->assertJsonPath('data.image_url', null);
        $this->getJson('/api/products/search?q=latte')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_open_prices_are_imported_for_known_chains(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        $location = fn (int $id, string $brand, string $country, string $city) => [
            'id' => $id, 'osm_brand' => $brand, 'osm_name' => $brand, 'osm_address_country_code' => $country,
            'osm_address_city' => $city, 'price_count' => 3,
        ];
        $price = fn (int $id, string $code, ?string $name, float $price, array $extra = []) => [
            'id' => $id, 'product_code' => $code, 'price' => $price, 'currency' => 'EUR', 'date' => '2026-09-05',
            'product' => ['product_name' => $name, 'product_quantity' => 1000, 'product_quantity_unit' => 'ml'], ...$extra,
        ];
        Http::fake(function (Request $request) use ($location, $price) {
            if (str_contains($request->url(), '/locations')) {
                return Http::response(['items' => [
                    $location(1, 'Carrefour Market', 'IT', 'Milano'),
                    $location(2, 'Auchan', 'FR', 'Paris'),
                    $location(3, 'Carrefour', 'FR', 'Lyon'),
                    $location(4, 'Bottega Rossi', 'IT', 'Roma'),
                ], 'pages' => 1]);
            }
            // Solo i negozi delle catene note in Italia: Carrefour a Milano (non Auchan, né Carrefour a Lione).
            $store = (int) $request['location_id'];
            $this->assertSame(1, $store);

            return Http::response(['items' => [
                $price($store * 100, '8002580018446', 'latte intero', $store === 1 ? 1.89 : 1.50),
                $price($store * 100 + 1, '8000000000002', 'Pasta', 0.99, ['price_is_discounted' => true, 'price_without_discount' => 1.29]),
                $price($store * 100 + 2, '8000000000003', 'Chips', 2.00, ['currency' => 'USD']),
            ], 'pages' => 1]);
        });

        $this->artisan('prices:sync-open-prices', ['--pause' => 0])
            ->expectsOutputToContain('Negozi delle catene note: 1; prezzi importati o aggiornati: 2.')
            ->assertSuccessful();
        // La volta dopo si chiedono solo i prezzi nuovi (con un giorno di margine); rileggendoli non si duplicano.
        $this->artisan('prices:sync-open-prices', ['--pause' => 0])->assertSuccessful();
        Http::assertSent(fn (Request $r) => str_contains($r->url(), '/prices') && ($r->data()['created__gte'] ?? null) === now()->subDay()->toDateString());

        $this->assertSame(2, PriceReport::count());
        $milk = PriceReport::where('barcode', '8002580018446')->where('city', 'Milano')->sole();
        $this->assertSame(['Carrefour', 'latte', 1.89, 'Milano', 'open_prices', 'Open Prices', 1.0, 'l'], [
            $milk->supermarket->name, $milk->product_key, $milk->price, $milk->city, $milk->source, $milk->reporter_name,
            $milk->package_amount, $milk->package_unit,
        ]);
        // Prezzo in offerta: si tiene quello pieno.
        $this->assertEquals(1.29, PriceReport::where('barcode', '8000000000002')->where('city', 'Milano')->value('price'));

        // Il prezzo importato è la base per le liste in quella catena, anche in un'altra città italiana.
        $list = ShoppingList::factory()->create(['supermarket' => 'Carrefour', 'city' => 'Torino']);
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])
            ->assertJsonPath('data.price', 1.89)
            ->assertJsonPath('data.price_info.source', 'open_prices');
    }
}
