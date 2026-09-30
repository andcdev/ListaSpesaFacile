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
use Illuminate\Support\Sleep;
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

    public function test_proposed_price_is_seen_by_its_author_until_others_confirm_it(): void
    {
        $this->report('Lidl', ['product_key' => 'latte', 'price' => 1.20, 'per' => 'l', 'source' => 'open_prices']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Lidl', 'city' => 'Milano']);
        $owner = $list->owner;
        $mario = User::factory()->create(['name' => 'Mario', 'email' => 'mario.segreto@example.com']);
        $list->sharedWith()->attach($mario->id, ['can_edit' => false]);
        Sanctum::actingAs($owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])
            ->assertJsonPath('data.price', 1.2)
            ->assertJsonPath('data.price_info.source', 'open_prices')
            ->json('data.id');

        // Anche chi ha la sola lettura propone un prezzo: lo vede subito solo lui.
        Sanctum::actingAs($mario);
        $proposed = $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1.35, 'per' => 'l'])
            ->assertCreated()
            ->assertJsonPath('data.price', 1.2)
            ->assertJsonPath('data.my_price.price', 1.35)
            ->assertJsonPath('data.my_price.status', 'pending')
            ->assertJsonPath('data.my_price.reporter', 'Mario')
            ->assertJsonPath('data.my_price.city', 'Milano');
        $reportId = $proposed->json('data.my_price.report_id');
        // Non si conferma da solo.
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => true])
            ->assertJsonValidationErrors('approve');

        // Gli altri vedono ancora il prezzo confermato, e che ce n'è uno da confermare.
        Sanctum::actingAs($owner);
        $this->getJson("/api/lists/{$list->id}")
            ->assertJsonPath('data.items.0.price', 1.2)
            ->assertJsonPath('data.items.0.my_price', null)
            ->assertJsonPath('data.items.0.pending_prices', 1);
        $history = $this->getJson("/api/lists/{$list->id}/items/{$id}/prices")
            ->assertOk()
            ->assertJsonPath('data.supermarket', 'Lidl')
            ->assertJsonPath('data.reports.0.reporter', 'Mario')
            ->assertJsonPath('data.reports.0.status', 'pending')
            ->assertJsonPath('data.reports.0.mine', false)
            ->assertJsonPath('data.reports.0.my_vote', null);

        // Confermato da un altro utente: lo vedono tutti (è anche della stessa città).
        $voted = $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => true])
            ->assertOk()
            ->assertJsonPath('data.current.price', 1.35)
            ->assertJsonPath('data.current.reporter', 'Mario')
            ->assertJsonPath('data.reports.0.status', 'approved')
            ->assertJsonPath('data.reports.0.approvals', 1)
            ->assertJsonPath('data.reports.0.my_vote', true);
        $this->getJson("/api/lists/{$list->id}")
            ->assertJsonPath('data.items.0.price', 1.35)
            ->assertJsonPath('data.items.0.pending_prices', 0);

        $this->assertSame('mario.segreto@example.com', PriceReport::find($reportId)->reporter_email);
        $items = $this->getJson("/api/lists/{$list->id}")->json('data.items');
        foreach ([$proposed->getContent(), $history->getContent(), $voted->getContent(), json_encode($items)] as $json) {
            $this->assertStringNotContainsString('mario.segreto', $json);
        }

        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1])->assertForbidden();
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => true])->assertForbidden();
    }

    public function test_the_most_confirmed_price_of_the_zone_is_shown(): void
    {
        // Il prezzo più vecchio ha una conferma, quello più recente nessuna: si vede il più confermato.
        $a = $this->report('Coop', ['product_key' => 'pane', 'price' => 2.00, 'city' => 'Roma', 'approvals' => 1, 'observed_at' => now()->subDays(20)]);
        $b = $this->report('Coop', ['product_key' => 'pane', 'price' => 2.50, 'city' => 'Roma']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Coop', 'city' => 'Roma']);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertJsonPath('data.price', 2)->json('data.id');

        // Due utenti confermano l'altro prezzo: ora ha più conferme.
        foreach (User::factory()->count(2)->create() as $user) {
            $list->sharedWith()->attach($user->id);
            Sanctum::actingAs($user);
            $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$b->id}/vote", ['approve' => true])->assertOk();
        }
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.price', 2.5);
        $this->assertSame(2, $b->fresh()->approvals);
        $this->assertSame(1, $a->fresh()->approvals);
    }

    public function test_proposing_a_price_already_there_confirms_it(): void
    {
        $report = $this->report('Coop', ['product_key' => 'pane', 'price' => 2.00, 'city' => 'Roma', 'source' => 'open_prices']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Coop', 'city' => 'roma']);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->json('data.id');

        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 2.0])->assertCreated();

        $this->assertSame(1, PriceReport::count());
        $this->assertSame(1, $report->fresh()->approvals);
    }

    public function test_rejected_proposal_disappears_for_everyone_but_its_author(): void
    {
        $list = ShoppingList::factory()->create(['supermarket' => 'Coop', 'city' => 'Roma']);
        $other = User::factory()->create();
        $list->sharedWith()->attach($other->id);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->json('data.id');
        $reportId = $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 99])->json('data.my_price.report_id');

        Sanctum::actingAs($other);
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => false])
            ->assertOk()
            ->assertJsonCount(0, 'data.reports');
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.pending_prices', 0);

        Sanctum::actingAs($list->owner);
        $this->getJson("/api/lists/{$list->id}/items/{$id}/prices")->assertJsonPath('data.reports.0.status', 'rejected');
        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.my_price', null);
    }

    public function test_more_confirmations_can_be_required(): void
    {
        config(['prices.approvals_required' => 2]);
        $list = ShoppingList::factory()->create(['supermarket' => 'Coop']);
        [$anna, $luca] = User::factory()->count(2)->create();
        $list->sharedWith()->attach([$anna->id, $luca->id]);
        Sanctum::actingAs($list->owner);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->json('data.id');
        $reportId = $this->postJson("/api/lists/{$list->id}/items/{$id}/prices", ['price' => 1.8])->json('data.my_price.report_id');

        Sanctum::actingAs($anna);
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => true]);
        $this->assertSame('pending', PriceReport::find($reportId)->status);
        Sanctum::actingAs($luca);
        $this->postJson("/api/lists/{$list->id}/items/{$id}/prices/{$reportId}/vote", ['approve' => true])
            ->assertJsonPath('data.current.price', 1.8);
    }

    public function test_province_comes_between_city_and_country(): void
    {
        $this->report('Esselunga', ['product_key' => 'pane', 'price' => 2.20, 'city' => 'Monza', 'province' => 'MB', 'observed_at' => now()->subMonth()]);
        $this->report('Esselunga', ['product_key' => 'pane', 'price' => 3.10, 'city' => 'Firenze', 'province' => 'FI']);
        $list = ShoppingList::factory()->create(['supermarket' => 'Esselunga', 'city' => 'Lissone', 'province' => 'mb']);
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->assertJsonPath('data.price', 2.2);
        $this->patchJson("/api/lists/{$list->id}", ['province' => null])->assertJsonPath('data.items.0.price', 3.1);
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

    /**
     * Un prezzo di Open Prices com'è nell'API, con il negozio dentro.
     */
    private function openPrice(int $id, ?array $store, string $name, float $price, array $extra = []): array
    {
        [$storeId, $brand, $osmName, $country, $city] = $store ?? [null, null, null, null, null];

        return [
            'id' => $id, 'type' => 'PRODUCT', 'product_code' => (string) (8000000000000 + $id), 'price' => $price,
            'currency' => 'EUR', 'date' => '2026-09-05',
            'product' => ['product_name' => $name, 'product_quantity' => 1000, 'product_quantity_unit' => 'ml'],
            'location' => $store === null ? null : [
                'id' => $storeId, 'osm_brand' => $brand, 'osm_name' => $osmName, 'osm_address_country_code' => $country,
                'osm_address_city' => $city,
            ],
            ...$extra,
        ];
    }

    public function test_all_open_prices_are_imported_with_their_chain_and_currency(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        $milano = [1, 'Carrefour Market', 'Carrefour Market', 'IT', 'Milano'];
        $esselunga = [2, null, 'Esselunga Viale Piave', 'IT', 'Milano'];
        $prices = [
            $this->openPrice(10, $milano, 'latte intero', 1.89, ['product_code' => '8002580018446']),
            $this->openPrice(11, $milano, 'Pasta', 0.99, ['price_is_discounted' => true, 'price_without_discount' => 1.29]),
            $this->openPrice(12, [3, 'Carrefour', 'Carrefour', 'FR', 'Lyon'], 'lait', 1.50, ['product_code' => '8002580018446']),
            $this->openPrice(13, [4, 'E.Leclerc', 'E.Leclerc Drive', 'FR', 'Paris'], 'Lait demi-écrémé', 0.99),
            $this->openPrice(14, [5, 'Rema 1000', 'Rema 1000', 'NO', 'Oslo'], 'Milk', 25.9, ['currency' => 'NOK']),
            $this->openPrice(15, $esselunga, 'Latte', 1.39),
            ['id' => 16, 'type' => 'CATEGORY', 'category_tag' => 'en:bananas', 'price_per' => 'KILOGRAM', 'price' => 1.99,
                'currency' => 'EUR', 'date' => '2026-09-06', 'location' => $this->openPrice(0, $esselunga, '', 0)['location']],
            $this->openPrice(17, null, 'Senza negozio', 1),
            $this->openPrice(18, [6, 'Les 400 Coop', 'Les 400 Coop', 'FR', 'Paris'], 'Pain', 2.1),
        ];
        Http::fake(fn () => Http::response(['items' => $prices, 'pages' => 1]));

        $this->artisan('prices:sync-open-prices', ['--pause' => 0])
            ->expectsOutputToContain('Prezzi importati o aggiornati: 8; catene nuove: 3.')
            ->assertSuccessful();
        // La volta dopo si chiedono solo i prezzi nuovi (con un giorno di margine); rileggendoli non si duplicano.
        $this->artisan('prices:sync-open-prices', ['--pause' => 0])->assertSuccessful();
        Http::assertSent(fn (Request $r) => ($r->data()['created__gte'] ?? null) === now()->subDay()->toDateString());
        $this->assertSame(8, PriceReport::count());

        $report = fn (int $id) => PriceReport::where('external_id', "op:$id")->with('supermarket')->sole();
        $this->assertSame(['Carrefour', 'latte', 1.89, 'EUR', 'Milano', 1.0, 'l'], [
            $report(10)->supermarket->name, $report(10)->product_key, $report(10)->price, $report(10)->currency,
            $report(10)->city, $report(10)->package_amount, $report(10)->package_unit,
        ]);
        // Prezzo in offerta: si tiene quello pieno.
        $this->assertEquals(1.29, $report(11)->price);
        // Stessa catena in Francia; insegne sconosciute diventano catene nuove del loro paese ("Les 400 Coop" non è Coop).
        $this->assertSame('Carrefour', $report(12)->supermarket->name);
        $this->assertSame(['E.Leclerc', 'FR'], [$report(13)->supermarket->name, $report(13)->supermarket->country]);
        $this->assertSame(['Rema 1000', 'NO', 'NOK', 25.9], [$report(14)->supermarket->name, $report(14)->country, $report(14)->currency, $report(14)->price]);
        $this->assertSame('Les 400 Coop', $report(18)->supermarket->name);
        // Insegna italiana scritta con l'indirizzo; frutta sfusa al kg riconosciuta dal nome inglese.
        $this->assertSame('Esselunga', $report(15)->supermarket->name);
        $this->assertSame(['Esselunga', 'banan', 'kg', 1.99], [$report(16)->supermarket->name, $report(16)->product_key, $report(16)->per, $report(16)->price]);

        // In Italia vale il prezzo italiano, anche in un'altra città; quello francese, più basso, no.
        $list = ShoppingList::factory()->create(['supermarket' => 'Carrefour', 'city' => 'Torino']);
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])
            ->assertJsonPath('data.price', 1.89)
            ->assertJsonPath('data.price_info.source', 'open_prices')
            ->assertJsonPath('data.price_info.currency', 'EUR');

        // In Norvegia il prezzo è in corone.
        $oslo = ShoppingList::factory()->for($list->owner, 'owner')->create(['supermarket' => 'Rema 1000', 'country' => 'NO']);
        $this->postJson("/api/lists/{$oslo->id}/items", ['name' => 'Latte'])
            ->assertJsonPath('data.price', 25.9)
            ->assertJsonPath('data.price_info.currency', 'NOK');
        $this->getJson("/api/lists/{$oslo->id}/price-comparison")->assertJsonPath('data.0.currency', 'NOK');

        // Le catene suggerite sono quelle del paese della lista.
        $names = fn (string $country) => array_column($this->getJson("/api/supermarkets?country=$country")->json('data'), 'name');
        $this->assertContains('E.Leclerc', $names('FR'));
        $this->assertContains('Carrefour', $names('FR'));
        $this->assertNotContains('Esselunga', $names('FR'));
        $this->assertContains('Esselunga', $names('IT'));
        $this->assertNotContains('E.Leclerc', $names('IT'));
        // Una catena straniera non viene scambiata per quella scritta in una lista italiana.
        $rome = ShoppingList::factory()->for($list->owner, 'owner')->create(['supermarket' => 'Rema 1000']);
        $this->getJson("/api/lists/{$rome->id}")->assertJsonPath('data.supermarket_chain', null);
    }

    public function test_interrupted_full_import_resumes_from_the_last_page(): void
    {
        config(['services.openfoodfacts.enabled' => true]);
        Sleep::fake();
        $store = [1, 'Lidl', 'Lidl', 'IT', 'Roma'];
        $page = fn (int $n) => Http::response([
            'items' => array_map(fn (int $i) => $this->openPrice($n * 1000 + $i, $store, 'Latte', 1), range(1, 100)),
            'pages' => 3,
        ]);
        $fail = true;
        Http::fake(function (Request $r) use ($page, &$fail) {
            $n = (int) $r['page'];

            return $n === 2 && $fail ? Http::response('errore', 500) : $page($n);
        });

        $this->artisan('prices:sync-open-prices', ['--pause' => 0])->assertFailed();
        $this->assertSame(100, PriceReport::count());

        $fail = false;
        $this->artisan('prices:sync-open-prices', ['--pause' => 0])
            ->expectsOutputToContain('Prezzi importati o aggiornati: 200;')
            ->assertSuccessful();
        $this->assertSame(300, PriceReport::count());
        // La prima pagina si è letta una volta sola.
        $this->assertCount(1, Http::recorded(fn (Request $r) => (int) $r['page'] === 1));
    }
}
