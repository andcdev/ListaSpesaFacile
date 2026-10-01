<?php

namespace App\Support;

use App\Models\ListItem;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Suggerimenti mentre si scrive un prodotto: prima quelli già messi in lista dall'utente e da chi condivide
 * le liste con lui (dal più frequente), poi i prodotti più comuni. L'app li filtra mentre si scrive.
 */
class ProductSuggestions
{
    /** Prodotti già usati restituiti al massimo. */
    private const HISTORY_LIMIT = 300;

    /** Prodotti più comuni al supermercato. */
    public const COMMON = [
        'Mele', 'Pere', 'Banane', 'Arance', 'Mandarini', 'Limoni', 'Fragole', 'Uva', 'Kiwi', 'Pesche', 'Albicocche',
        'Ciliegie', 'Anguria', 'Melone', 'Ananas', 'Mirtilli', 'Avocado', 'Frutta secca', 'Noci', 'Mandorle',
        'Insalata', 'Lattuga', 'Rucola', 'Pomodori', 'Pomodorini', 'Zucchine', 'Melanzane', 'Peperoni', 'Carote',
        'Patate', 'Cipolle', 'Aglio', 'Sedano', 'Finocchi', 'Spinaci', 'Broccoli', 'Cavolfiore', 'Funghi',
        'Cetrioli', 'Zucca', 'Basilico', 'Prezzemolo', 'Rosmarino',
        'Pane', 'Pane in cassetta', 'Panini', 'Grissini', 'Crackers', 'Fette biscottate', 'Piadine', 'Pizza',
        'Latte', 'Latte parzialmente scremato', 'Yogurt', 'Yogurt greco', 'Burro', 'Panna da cucina', 'Uova',
        'Mozzarella', 'Parmigiano', 'Grana padano', 'Ricotta', 'Mascarpone', 'Stracchino', 'Gorgonzola',
        'Formaggio a fette', 'Pecorino', 'Scamorza',
        'Prosciutto cotto', 'Prosciutto crudo', 'Salame', 'Mortadella', 'Bresaola', 'Speck', 'Wurstel',
        'Petto di pollo', 'Pollo', 'Carne macinata', 'Bistecca', 'Hamburger', 'Salsiccia', 'Fettine di vitello',
        'Arrosto', 'Tacchino',
        'Salmone', 'Tonno', 'Tonno in scatola', 'Merluzzo', 'Gamberi', 'Orata', 'Branzino', 'Cozze', 'Vongole',
        'Pasta', 'Spaghetti', 'Penne', 'Fusilli', 'Lasagne', 'Tortellini', 'Gnocchi', 'Riso', 'Farina',
        'Cereali', 'Corn flakes', 'Fiocchi d\'avena',
        'Olio extravergine', 'Olio di semi', 'Aceto', 'Sale', 'Zucchero', 'Pepe', 'Passata di pomodoro',
        'Pelati', 'Legumi', 'Ceci', 'Fagioli', 'Lenticchie', 'Piselli', 'Mais', 'Maionese', 'Ketchup', 'Senape',
        'Pesto', 'Sugo pronto', 'Dado', 'Brodo', 'Lievito', 'Miele', 'Marmellata', 'Nutella', 'Caffè', 'Tè',
        'Camomilla', 'Tisane',
        'Biscotti', 'Merendine', 'Cioccolato', 'Patatine', 'Gelato', 'Torta', 'Caramelle', 'Snack',
        'Acqua naturale', 'Acqua frizzante', 'Succo di frutta', 'Coca cola', 'Aranciata', 'Birra', 'Vino rosso',
        'Vino bianco', 'Prosecco', 'Tè freddo',
        'Surgelati', 'Piselli surgelati', 'Spinaci surgelati', 'Bastoncini di pesce', 'Patatine fritte',
        'Minestrone surgelato', 'Pizza surgelata',
        'Carta igienica', 'Fazzoletti', 'Shampoo', 'Balsamo', 'Bagnoschiuma', 'Sapone', 'Dentifricio',
        'Spazzolino', 'Deodorante', 'Assorbenti', 'Pannolini', 'Salviette', 'Cotton fioc', 'Rasoi',
        'Detersivo lavatrice', 'Ammorbidente', 'Detersivo piatti', 'Pastiglie lavastoviglie', 'Candeggina',
        'Sgrassatore', 'Anticalcare', 'Spugne', 'Carta assorbente', 'Carta forno', 'Carta stagnola',
        'Pellicola trasparente', 'Sacchi spazzatura', 'Tovaglioli', 'Piatti di carta', 'Bicchieri di plastica',
        'Pile', 'Lampadine',
        'Cibo per gatti', 'Cibo per cani', 'Lettiera',
    ];

    /**
     * @return array<int, array{name: string, icon: string, category: string, measure: string, times: int}>
     */
    public static function for(User $user): array
    {
        $listIds = ShoppingList::query()->accessibleBy($user)->select('id');

        // Per ogni nome (senza maiuscole) quante volte è stato messo in lista e l'ultima versione.
        $history = ListItem::query()
            ->whereIn('shopping_list_id', $listIds)
            ->groupBy(DB::raw('LOWER(name)'))
            ->selectRaw('MAX(id) as last_id, COUNT(*) as times')
            ->orderByDesc('times')
            ->orderByDesc('last_id')
            ->limit(self::HISTORY_LIMIT)
            ->get();
        $latest = ListItem::query()->whereKey($history->pluck('last_id'))->get()->keyBy('id');

        $suggestions = [];
        foreach ($history as $row) {
            $item = $latest[$row->last_id] ?? null;
            if ($item === null) {
                continue;
            }
            $suggestions[self::key($item->name)] = [
                'name' => $item->name,
                'icon' => $item->custom_icon ?? $item->icon ?? ProductCatalog::categoryIcon($item->category),
                'category' => $item->category,
                'measure' => ProductCatalog::measure($item->name, $item->barcode),
                'times' => (int) $row->times,
            ];
        }

        // Prodotti comuni nella lingua dell'utente; reparto e icona vengono dal nome italiano.
        $translations = app()->getLocale() === 'it' ? [] : (array) trans('products');
        foreach (self::COMMON as $name) {
            $local = $translations[$name] ?? $name;
            $suggestions[self::key($local)] ??= [
                'name' => $local, ...ProductCatalog::detect($name), 'measure' => ProductCatalog::measure($name), 'times' => 0,
            ];
        }

        return array_values($suggestions);
    }

    private static function key(string $name): string
    {
        return Str::lower(Str::ascii(trim($name)));
    }
}
