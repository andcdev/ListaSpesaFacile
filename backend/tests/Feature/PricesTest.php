<?php

namespace Tests\Feature;

use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Models\User;
use App\Support\PriceBook;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PricesTest extends TestCase
{
    use RefreshDatabase;

    private function prices(string $chain, array $prices): Supermarket
    {
        $supermarket = Supermarket::where('name', $chain)->firstOrFail();
        foreach ($prices as $key => [$price, $per]) {
            $supermarket->prices()->create(['product_key' => $key, 'product_name' => $key, 'price' => $price, 'per' => $per]);
        }

        return $supermarket;
    }

    public function test_supermarket_name_is_matched_to_a_known_chain(): void
    {
        $this->assertSame('Esselunga', Supermarket::match('Esselunga di viale Piave')?->name);
        $this->assertSame('Coop', Supermarket::match('ipercoop')?->name);
        $this->assertSame('Decò', Supermarket::match('Superstore Deco Catania')?->name);
        $this->assertSame("In's Mercato", Supermarket::match("In's")?->name);
        $this->assertNull(Supermarket::match('Alimentari da Mario'));
        $this->assertNull(Supermarket::match(null));
        // Parole intere: "Mdina" non è MD.
        $this->assertNull(Supermarket::match('Mdina market'));
    }

    public function test_quantity_and_measure_multiply_the_price(): void
    {
        $this->prices('Lidl', ['latte' => [1.20, 'l'], 'banan' => [1.50, 'kg'], 'pasta' => [0.90, 'pz']]);
        $list = ShoppingList::factory()->create(['supermarket' => 'Lidl']);
        Sanctum::actingAs($list->owner);

        $add = fn (array $item) => $this->postJson("/api/lists/{$list->id}/items", $item)->json('data.price');

        $this->assertSame(1.2, $add(['name' => 'Latte intero']));
        $this->assertSame(2.4, $add(['name' => 'Latte', 'quantity' => '2', 'amount' => 1, 'unit' => 'l']));
        $this->assertSame(0.6, $add(['name' => 'Latte', 'amount' => 500, 'unit' => 'ml']));
        $this->assertEquals(0.75, $add(['name' => 'Banane', 'amount' => 5, 'unit' => 'hg']));
        $this->assertSame(2.7, $add(['name' => 'Pasta integrale', 'quantity' => '3 pacchi']));
        $this->assertNull($add(['name' => 'Carta igienica']));
    }

    public function test_list_without_known_chain_has_no_prices(): void
    {
        $this->prices('Lidl', ['latte' => [1.20, 'l']]);
        $list = ShoppingList::factory()->create(['supermarket' => 'Bottega sotto casa']);
        Sanctum::actingAs($list->owner);

        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte'])->assertJsonPath('data.price', null);
        $this->getJson("/api/lists/{$list->id}")
            ->assertJsonPath('data.supermarket', 'Bottega sotto casa')
            ->assertJsonPath('data.supermarket_chain', null);
    }

    public function test_changing_supermarket_updates_prices(): void
    {
        $this->prices('Lidl', ['latte' => [1.20, 'l']]);
        $this->prices('Esselunga', ['latte' => [1.50, 'l']]);
        $list = ShoppingList::factory()->create();
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte']);

        $this->getJson("/api/lists/{$list->id}")->assertJsonPath('data.items.0.price', null);

        $this->patchJson("/api/lists/{$list->id}", ['supermarket' => 'Esselunga'])
            ->assertJsonPath('data.supermarket_chain.name', 'Esselunga')
            ->assertJsonPath('data.items.0.price', 1.5);

        $this->patchJson("/api/lists/{$list->id}", ['supermarket' => 'lidl'])
            ->assertJsonPath('data.supermarket_chain.name', 'Lidl')
            ->assertJsonPath('data.items.0.price', 1.2);

        $this->patchJson("/api/lists/{$list->id}", ['supermarket' => ''])
            ->assertJsonPath('data.supermarket', null)
            ->assertJsonPath('data.items.0.price', null);
    }

    public function test_supermarket_can_be_set_when_creating_the_list(): void
    {
        $this->prices('Coop', ['pane' => [2.10, 'pz']]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/lists', ['name' => 'Spesa', 'scheduled_at' => now()->addDay()->toIso8601String(), 'supermarket' => 'Coop'])
            ->assertCreated()
            ->assertJsonPath('data.supermarket', 'Coop')
            ->assertJsonPath('data.supermarket_chain.name', 'Coop')
            ->assertJsonPath('data.supermarket_chain.description', 'Cooperative di consumatori, in tutta Italia');
    }

    public function test_comparison_lists_every_chain_with_prices(): void
    {
        $this->prices('Lidl', ['latte' => [1.20, 'l'], 'pane' => [1.00, 'pz']]);
        $this->prices('Esselunga', ['latte' => [1.50, 'l'], 'pane' => [2.00, 'pz']]);
        $this->prices('Coop', ['latte' => [1.10, 'l']]);
        $list = ShoppingList::factory()->create(['supermarket' => 'Esselunga']);
        Sanctum::actingAs($list->owner);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Latte', 'quantity' => '2']);
        $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane']);
        $id = $this->postJson("/api/lists/{$list->id}/items", ['name' => 'Pane'])->json('data.id');
        // I prodotti non trovati non contano nel totale.
        $this->patchJson("/api/lists/{$list->id}/items/{$id}", ['status' => 'missing']);

        $rows = $this->getJson("/api/lists/{$list->id}/price-comparison")->assertOk()->json('data');

        // Prima chi copre più articoli, a parità il più economico; Coop ha solo il latte.
        $this->assertSame(['Lidl', 'Esselunga', 'Coop'], array_column($rows, 'name'));
        $this->assertEquals([3.4, 5.0, 2.2], array_column($rows, 'total'));
        $this->assertSame([false, true, false], array_column($rows, 'current'));
        $this->assertSame([2, 2, 1], array_column($rows, 'priced_count'));
        $this->assertSame(2, $rows[0]['items_count']);
        $this->assertEquals([2.4, 1.0, 1.0], array_column($rows[0]['items'], 'price'));
        $this->assertSame('Discount, in tutta Italia', $rows[0]['description']);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/lists/{$list->id}/price-comparison")->assertForbidden();
    }

    public function test_supermarkets_endpoint_lists_known_chains(): void
    {
        $this->prices('Lidl', ['latte' => [1.20, 'l']]);
        Sanctum::actingAs(User::factory()->create());

        $rows = collect($this->getJson('/api/supermarkets')->assertOk()->json('data'))->keyBy('name');

        $this->assertTrue($rows['Lidl']['has_prices']);
        $this->assertFalse($rows['Esselunga']['has_prices']);
    }

    public function test_prices_are_imported_from_csv(): void
    {
        $file = tempnam(sys_get_temp_dir(), 'prezzi');
        file_put_contents($file, "\u{FEFF}supermercato;prodotto;prezzo;per\nEsselunga di Milano;Latte;1,29;l\nLidl;Banane;1.49;kg\n"
            ."Lidl;Pasta;0,89;\nLidl;Oggetto misterioso;3;pz\nBottega Rossi;Pane;2,50;pz\nLidl;Latte;abc;l\n");

        $this->artisan('prices:import', ['file' => $file])
            ->expectsOutputToContain('Prezzi importati: 4; righe saltate: 2.')
            ->assertSuccessful();

        $price = fn (string $chain, string $key) => Supermarket::match($chain)?->prices()->where('product_key', $key)->first();
        $this->assertEquals([1.29, 'l'], [(float) $price('Esselunga', 'latte')->price, $price('Esselunga', 'latte')->per]);
        $this->assertEquals([0.89, 'pz'], [(float) $price('Lidl', 'pasta')->price, $price('Lidl', 'pasta')->per]);
        // Catena sconosciuta: viene creata.
        $this->assertNotNull($price('Bottega Rossi', 'pane'));

        // Con --replace i prezzi delle catene nel file vengono sostituiti.
        file_put_contents($file, "Lidl,Latte,1.10,l\n");
        $this->artisan('prices:import', ['file' => $file, '--replace' => true])->assertSuccessful();
        $lidl = Supermarket::match('Lidl');
        $this->assertSame(['latte'], $lidl->prices()->pluck('product_key')->all());
        $this->assertEquals(1.1, $lidl->prices()->value('price'));
        unlink($file);
    }

    public function test_pieces_are_read_from_the_quantity(): void
    {
        $this->assertSame(1.0, PriceBook::pieces(null));
        $this->assertSame(2.0, PriceBook::pieces('2'));
        $this->assertSame(1.5, PriceBook::pieces('1,5 kg'));
        $this->assertSame(1.0, PriceBook::pieces('qualche'));
        $this->assertSame(1.0, PriceBook::pieces('0'));
    }
}
