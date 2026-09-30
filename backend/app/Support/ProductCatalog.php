<?php

namespace App\Support;

use Illuminate\Support\Str;

/**
 * Riconosce il tipo di prodotto dal nome dell'articolo e sceglie reparto e icona (emoji).
 *
 * Regole:
 * - prima si cercano le espressioni di più parole ("carta igienica", "olio di semi"…);
 * - poi si guarda la prima parola del nome che corrisponde a un prodotto noto
 *   (in italiano il prodotto viene prima: "succo di mela" è un succo, "yogurt alla fragola" uno yogurt);
 * - le chiavi sono radici: "pomodor" riconosce pomodoro, pomodori, pomodorini.
 *   Le chiavi di meno di 4 lettere devono corrispondere alla parola intera ("te", "the", "uva").
 */
class ProductCatalog
{
    public const DEFAULT_CATEGORY = 'altro';

    /** Reparti in ordine di giro al supermercato: slug => [nome, icona]. */
    public const CATEGORIES = [
        'frutta' => ['Frutta', '🍎'],
        'verdura' => ['Verdura', '🥦'],
        'pane' => ['Pane e forno', '🍞'],
        'latticini' => ['Latte, formaggi e uova', '🧀'],
        'carne' => ['Carne e salumi', '🥩'],
        'pesce' => ['Pesce', '🐟'],
        'pasta' => ['Pasta, riso e cereali', '🍝'],
        'dispensa' => ['Dispensa', '🥫'],
        'dolci' => ['Dolci e snack', '🍪'],
        'bevande' => ['Bevande', '🥤'],
        'surgelati' => ['Surgelati', '🧊'],
        'igiene' => ['Igiene personale', '🧴'],
        'casa' => ['Casa e pulizia', '🧽'],
        'animali' => ['Animali', '🐾'],
        'altro' => ['Altro', '🛒'],
    ];

    /** Espressioni di più parole, controllate per prime: frase => [reparto, icona]. */
    private const PHRASES = [
        'carta igienica' => ['igiene', '🧻'],
        'carta assorbente' => ['casa', '🧻'],
        'carta forno' => ['casa', '📜'],
        'carta stagnola' => ['casa', '📜'],
        'pellicola trasparente' => ['casa', '📜'],
        'olio di semi' => ['dispensa', '🫒'],
        'olio extravergine' => ['dispensa', '🫒'],
        'latte di soia' => ['bevande', '🥛'],
        'latte di mandorla' => ['bevande', '🥛'],
        'latte condensato' => ['dispensa', '🥫'],
        'acqua frizzante' => ['bevande', '💧'],
        'acqua naturale' => ['bevande', '💧'],
        'panna montata' => ['latticini', '🍦'],
        'pan grattato' => ['dispensa', '🍞'],
        'pangrattato' => ['dispensa', '🍞'],
        'frutti di bosco' => ['frutta', '🫐'],
        'frutti di mare' => ['pesce', '🦐'],
        'fondo di cucina' => ['casa', '🧽'],
        'cibo per gatti' => ['animali', '🐱'],
        'cibo per cani' => ['animali', '🐶'],
        'sacchetti spazzatura' => ['casa', '🗑️'],
        'sacchi spazzatura' => ['casa', '🗑️'],
        'spazzolino' => ['igiene', '🪥'],
        'patatine fritte' => ['surgelati', '🍟'],
        'bastoncini di pesce' => ['surgelati', '🐟'],
        'gelato' => ['surgelati', '🍨'],
    ];

    /** Radici dei nomi: radice => [reparto, icona]. */
    private const PRODUCTS = [
        // Frutta
        'mela' => ['frutta', '🍎'], 'mele' => ['frutta', '🍎'], 'pera' => ['frutta', '🍐'], 'pere' => ['frutta', '🍐'],
        'banan' => ['frutta', '🍌'], 'aranc' => ['frutta', '🍊'], 'mandarin' => ['frutta', '🍊'], 'clementin' => ['frutta', '🍊'],
        'limon' => ['frutta', '🍋'], 'fragol' => ['frutta', '🍓'], 'uva' => ['frutta', '🍇'], 'ciliegi' => ['frutta', '🍒'],
        'pesca' => ['frutta', '🍑'], 'pesche' => ['frutta', '🍑'], 'albicocc' => ['frutta', '🍑'], 'anguri' => ['frutta', '🍉'],
        'melon' => ['frutta', '🍈'], 'ananas' => ['frutta', '🍍'], 'kiwi' => ['frutta', '🥝'], 'mango' => ['frutta', '🥭'],
        'cocco' => ['frutta', '🥥'], 'mirtill' => ['frutta', '🫐'], 'lampon' => ['frutta', '🫐'], 'prugn' => ['frutta', '🍑'],
        'susin' => ['frutta', '🍑'], 'fichi' => ['frutta', '🍐'], 'fico' => ['frutta', '🍐'], 'frutta' => ['frutta', '🍎'],
        'avocado' => ['frutta', '🥑'], 'pompelm' => ['frutta', '🍊'], 'cachi' => ['frutta', '🍅'], 'melagran' => ['frutta', '🍎'],
        // Verdura
        'pomodor' => ['verdura', '🍅'], 'insalat' => ['verdura', '🥬'], 'lattug' => ['verdura', '🥬'], 'rucol' => ['verdura', '🥬'],
        'spinac' => ['verdura', '🥬'], 'carot' => ['verdura', '🥕'], 'patat' => ['verdura', '🥔'], 'cipoll' => ['verdura', '🧅'],
        'aglio' => ['verdura', '🧄'], 'zucchin' => ['verdura', '🥒'], 'cetriol' => ['verdura', '🥒'], 'melanzan' => ['verdura', '🍆'],
        'peperon' => ['verdura', '🫑'], 'peperoncin' => ['verdura', '🌶️'], 'broccol' => ['verdura', '🥦'], 'cavol' => ['verdura', '🥦'],
        'verza' => ['verdura', '🥬'], 'finocch' => ['verdura', '🥬'], 'sedan' => ['verdura', '🥬'], 'funghi' => ['verdura', '🍄'],
        'fungo' => ['verdura', '🍄'], 'champignon' => ['verdura', '🍄'], 'mais' => ['verdura', '🌽'], 'pannocch' => ['verdura', '🌽'],
        'piselli' => ['verdura', '🫛'], 'fagiolin' => ['verdura', '🫛'], 'zucca' => ['verdura', '🎃'], 'carciof' => ['verdura', '🥬'],
        'asparag' => ['verdura', '🥬'], 'radicchi' => ['verdura', '🥬'], 'basilic' => ['verdura', '🌿'], 'prezzemol' => ['verdura', '🌿'],
        'rosmarin' => ['verdura', '🌿'], 'verdur' => ['verdura', '🥦'], 'porri' => ['verdura', '🧅'], 'porro' => ['verdura', '🧅'],
        'zenzero' => ['verdura', '🫚'], 'ravanell' => ['verdura', '🥕'], 'barbabietol' => ['verdura', '🥕'],
        // Pane e forno
        'pane' => ['pane', '🍞'], 'pani' => ['pane', '🍞'], 'panin' => ['pane', '🥖'], 'baguette' => ['pane', '🥖'],
        'filone' => ['pane', '🍞'], 'pancarre' => ['pane', '🍞'], 'focacc' => ['pane', '🫓'], 'piadin' => ['pane', '🫓'],
        'grissin' => ['pane', '🥖'], 'cracker' => ['pane', '🍘'], 'crackers' => ['pane', '🍘'], 'fette biscottate' => ['pane', '🍞'],
        'cornett' => ['pane', '🥐'], 'croissant' => ['pane', '🥐'], 'brioche' => ['pane', '🥐'], 'pizza' => ['pane', '🍕'],
        'tarall' => ['pane', '🥨'], 'friselle' => ['pane', '🍞'],
        // Latticini e uova
        'latte' => ['latticini', '🥛'], 'yogurt' => ['latticini', '🥛'], 'burro' => ['latticini', '🧈'], 'formagg' => ['latticini', '🧀'],
        'mozzarell' => ['latticini', '🧀'], 'parmigian' => ['latticini', '🧀'], 'grana' => ['latticini', '🧀'], 'pecorin' => ['latticini', '🧀'],
        'ricott' => ['latticini', '🧀'], 'mascarpone' => ['latticini', '🧀'], 'gorgonzol' => ['latticini', '🧀'], 'stracchin' => ['latticini', '🧀'],
        'provol' => ['latticini', '🧀'], 'scamorz' => ['latticini', '🧀'], 'fontin' => ['latticini', '🧀'], 'emmental' => ['latticini', '🧀'],
        'sottilett' => ['latticini', '🧀'], 'philadelphia' => ['latticini', '🧀'], 'panna' => ['latticini', '🥛'], 'uova' => ['latticini', '🥚'],
        'uovo' => ['latticini', '🥚'], 'kefir' => ['latticini', '🥛'], 'burrata' => ['latticini', '🧀'],
        // Carne e salumi
        'carne' => ['carne', '🥩'], 'manzo' => ['carne', '🥩'], 'vitell' => ['carne', '🥩'], 'bistecc' => ['carne', '🥩'],
        'maiale' => ['carne', '🥩'], 'braciol' => ['carne', '🥩'], 'pollo' => ['carne', '🍗'], 'tacchin' => ['carne', '🍗'],
        'petto' => ['carne', '🍗'], 'cosce' => ['carne', '🍗'], 'agnello' => ['carne', '🥩'], 'macinat' => ['carne', '🥩'],
        'hamburger' => ['carne', '🍔'], 'salsicc' => ['carne', '🌭'], 'wurstel' => ['carne', '🌭'], 'prosciutt' => ['carne', '🥓'],
        'speck' => ['carne', '🥓'], 'pancett' => ['carne', '🥓'], 'bacon' => ['carne', '🥓'], 'salame' => ['carne', '🍖'],
        'salami' => ['carne', '🍖'], 'mortadell' => ['carne', '🍖'], 'bresaol' => ['carne', '🍖'], 'cotolett' => ['carne', '🍗'],
        'polpett' => ['carne', '🍖'], 'arrosto' => ['carne', '🍖'], 'spezzatin' => ['carne', '🥩'], 'coppa' => ['carne', '🥓'],
        // Pesce
        'pesce' => ['pesce', '🐟'], 'salmone' => ['pesce', '🐟'], 'tonno' => ['pesce', '🐟'], 'merluzz' => ['pesce', '🐟'],
        'orata' => ['pesce', '🐟'], 'branzin' => ['pesce', '🐟'], 'spigol' => ['pesce', '🐟'], 'sgombr' => ['pesce', '🐟'],
        'alic' => ['pesce', '🐟'], 'acciug' => ['pesce', '🐟'], 'sardin' => ['pesce', '🐟'], 'baccala' => ['pesce', '🐟'],
        'gamber' => ['pesce', '🦐'], 'scampi' => ['pesce', '🦐'], 'cozze' => ['pesce', '🦪'], 'vongol' => ['pesce', '🦪'],
        'calamar' => ['pesce', '🦑'], 'totan' => ['pesce', '🦑'], 'polpo' => ['pesce', '🐙'], 'seppi' => ['pesce', '🦑'],
        'surimi' => ['pesce', '🦀'], 'granchi' => ['pesce', '🦀'],
        // Pasta, riso e cereali
        'pasta' => ['pasta', '🍝'], 'spaghett' => ['pasta', '🍝'], 'penne' => ['pasta', '🍝'], 'fusill' => ['pasta', '🍝'],
        'rigaton' => ['pasta', '🍝'], 'linguin' => ['pasta', '🍝'], 'tagliatell' => ['pasta', '🍝'], 'lasagn' => ['pasta', '🍝'],
        'farfall' => ['pasta', '🍝'], 'maccheron' => ['pasta', '🍝'], 'orecchiett' => ['pasta', '🍝'], 'tortellin' => ['pasta', '🥟'],
        'ravioli' => ['pasta', '🥟'], 'gnocch' => ['pasta', '🥟'], 'riso' => ['pasta', '🍚'], 'basmati' => ['pasta', '🍚'],
        'couscous' => ['pasta', '🍚'], 'farro' => ['pasta', '🌾'], 'orzo' => ['pasta', '🌾'], 'quinoa' => ['pasta', '🌾'],
        'cereali' => ['pasta', '🥣'], 'muesli' => ['pasta', '🥣'], 'cornflakes' => ['pasta', '🥣'], 'avena' => ['pasta', '🥣'],
        'noodle' => ['pasta', '🍜'],
        // Dispensa
        'olio' => ['dispensa', '🫒'], 'aceto' => ['dispensa', '🍶'], 'sale' => ['dispensa', '🧂'], 'pepe' => ['dispensa', '🧂'],
        'zucchero' => ['dispensa', '🍬'], 'farina' => ['dispensa', '🌾'], 'lievito' => ['dispensa', '🌾'], 'passata' => ['dispensa', '🥫'],
        'pelati' => ['dispensa', '🥫'], 'polpa' => ['dispensa', '🥫'], 'concentrato' => ['dispensa', '🥫'], 'sugo' => ['dispensa', '🥫'],
        'pesto' => ['dispensa', '🥫'], 'ragu' => ['dispensa', '🥫'], 'legumi' => ['dispensa', '🫘'], 'fagioli' => ['dispensa', '🫘'],
        'ceci' => ['dispensa', '🫘'], 'lenticchi' => ['dispensa', '🫘'], 'maionese' => ['dispensa', '🥫'], 'ketchup' => ['dispensa', '🥫'],
        'senape' => ['dispensa', '🥫'], 'miele' => ['dispensa', '🍯'], 'marmellat' => ['dispensa', '🍯'], 'confettur' => ['dispensa', '🍯'],
        'nutella' => ['dispensa', '🍫'], 'olive' => ['dispensa', '🫒'], 'capperi' => ['dispensa', '🫒'], 'dado' => ['dispensa', '🥫'],
        'brodo' => ['dispensa', '🥣'], 'spezie' => ['dispensa', '🧂'], 'origano' => ['dispensa', '🌿'], 'noci' => ['dispensa', '🥜'],
        'mandorle' => ['dispensa', '🥜'], 'nocciol' => ['dispensa', '🥜'], 'arachid' => ['dispensa', '🥜'], 'pistacch' => ['dispensa', '🥜'],
        'caffe' => ['dispensa', '☕'], 'cialde' => ['dispensa', '☕'], 'capsule' => ['dispensa', '☕'], 'te' => ['dispensa', '🍵'],
        'the' => ['dispensa', '🍵'], 'tisan' => ['dispensa', '🍵'], 'camomill' => ['dispensa', '🍵'], 'cacao' => ['dispensa', '🍫'],
        'scatolam' => ['dispensa', '🥫'], 'mais in scatola' => ['dispensa', '🥫'],
        // Dolci e snack
        'biscott' => ['dolci', '🍪'], 'cioccolat' => ['dolci', '🍫'], 'merendin' => ['dolci', '🧁'], 'torta' => ['dolci', '🍰'],
        'crostat' => ['dolci', '🥧'], 'caramell' => ['dolci', '🍬'], 'gomme' => ['dolci', '🍬'], 'chewing' => ['dolci', '🍬'],
        'patatine' => ['dolci', '🥔'], 'chips' => ['dolci', '🥔'], 'popcorn' => ['dolci', '🍿'], 'budin' => ['dolci', '🍮'],
        'pandoro' => ['dolci', '🍰'], 'panettone' => ['dolci', '🍰'], 'colomba' => ['dolci', '🍰'], 'wafer' => ['dolci', '🍫'],
        'snack' => ['dolci', '🍫'], 'barrett' => ['dolci', '🍫'], 'dolci' => ['dolci', '🍰'],
        // Bevande
        'acqua' => ['bevande', '💧'], 'vino' => ['bevande', '🍷'], 'prosecco' => ['bevande', '🍾'], 'spumante' => ['bevande', '🍾'],
        'champagne' => ['bevande', '🍾'], 'birra' => ['bevande', '🍺'], 'birre' => ['bevande', '🍺'], 'succo' => ['bevande', '🧃'],
        'succhi' => ['bevande', '🧃'], 'spremut' => ['bevande', '🧃'], 'aranciata' => ['bevande', '🥤'], 'cola' => ['bevande', '🥤'],
        'coca' => ['bevande', '🥤'], 'bibit' => ['bevande', '🥤'], 'gassos' => ['bevande', '🥤'], 'chinotto' => ['bevande', '🥤'],
        'tonic' => ['bevande', '🥤'], 'amaro' => ['bevande', '🥃'], 'grappa' => ['bevande', '🥃'], 'whisky' => ['bevande', '🥃'],
        'vodka' => ['bevande', '🥃'], 'gin' => ['bevande', '🍸'], 'rum' => ['bevande', '🥃'], 'liquor' => ['bevande', '🥃'],
        'aperol' => ['bevande', '🍹'], 'spritz' => ['bevande', '🍹'], 'energy' => ['bevande', '🥤'], 'integrator' => ['bevande', '🥤'],
        // Surgelati
        'surgelat' => ['surgelati', '🧊'], 'ghiacciol' => ['surgelati', '🍦'], 'ghiaccio' => ['surgelati', '🧊'],
        'minestrone' => ['surgelati', '🥣'], 'sofficin' => ['surgelati', '🧊'], 'bastoncin' => ['surgelati', '🐟'],
        // Igiene personale
        'shampoo' => ['igiene', '🧴'], 'balsamo' => ['igiene', '🧴'], 'bagnoschiuma' => ['igiene', '🧴'], 'docciaschiuma' => ['igiene', '🧴'],
        'sapone' => ['igiene', '🧼'], 'saponett' => ['igiene', '🧼'], 'dentifricio' => ['igiene', '🪥'], 'collutorio' => ['igiene', '🪥'],
        'filo interdentale' => ['igiene', '🪥'], 'deodorant' => ['igiene', '🧴'], 'rasoi' => ['igiene', '🪒'], 'lamette' => ['igiene', '🪒'],
        'schiuma da barba' => ['igiene', '🪒'], 'assorbent' => ['igiene', '🩹'], 'pannolin' => ['igiene', '🧷'], 'salviett' => ['igiene', '🧻'],
        'fazzolett' => ['igiene', '🧻'], 'cotton' => ['igiene', '🧴'], 'cerotti' => ['igiene', '🩹'],
        'profumo' => ['igiene', '🧴'], 'trucco' => ['igiene', '💄'], 'struccant' => ['igiene', '🧴'], 'lacca' => ['igiene', '🧴'],
        // Casa e pulizia
        'detersiv' => ['casa', '🧴'], 'ammorbident' => ['casa', '🧴'], 'candeggin' => ['casa', '🧴'], 'sgrassator' => ['casa', '🧽'],
        'anticalcare' => ['casa', '🧽'], 'spugn' => ['casa', '🧽'], 'pastiglie' => ['casa', '🧼'], 'brillantant' => ['casa', '🧼'],
        'sacchett' => ['casa', '🛍️'], 'sacchi' => ['casa', '🗑️'], 'scotex' => ['casa', '🧻'], 'tovagliol' => ['casa', '🧻'],
        'piatti' => ['casa', '🍽️'], 'bicchier' => ['casa', '🥤'], 'posate' => ['casa', '🍴'], 'alluminio' => ['casa', '📜'],
        'lampadin' => ['casa', '💡'], 'pile' => ['casa', '🔋'], 'batteri' => ['casa', '🔋'], 'candel' => ['casa', '🕯️'],
        'insetticid' => ['casa', '🪰'], 'guanti' => ['casa', '🧤'], 'mocio' => ['casa', '🧹'], 'scopa' => ['casa', '🧹'],
        'fiammifer' => ['casa', '🔥'], 'accendin' => ['casa', '🔥'], 'lavatrice' => ['casa', '🧺'], 'lavastovigl' => ['casa', '🧼'],
        // Animali
        'crocchett' => ['animali', '🐾'], 'croccantin' => ['animali', '🐾'], 'lettiera' => ['animali', '🐱'], 'sabbia' => ['animali', '🐱'],
        'scatolett' => ['animali', '🐾'], 'gatto' => ['animali', '🐱'], 'gatti' => ['animali', '🐱'], 'cane' => ['animali', '🐶'],
        'cani' => ['animali', '🐶'], 'mangime' => ['animali', '🐾'],
    ];

    /**
     * Reparto e icona per il nome di un articolo.
     *
     * @return array{category: string, icon: string}
     */
    public static function detect(string $name): array
    {
        $found = self::find($name);

        return $found
            ? self::result($found[1])
            : ['category' => self::DEFAULT_CATEGORY, 'icon' => self::CATEGORIES[self::DEFAULT_CATEGORY][1]];
    }

    /**
     * Prodotto riconosciuto dal nome ("Latte intero 1 l" → "latte", "Pomodorini" → "pomodor"), null se sconosciuto:
     * è la chiave con cui si cercano i prezzi delle catene.
     */
    public static function productKey(string $name): ?string
    {
        return self::find($name)[0] ?? null;
    }

    /**
     * @return array{0: string, 1: array{0: string, 1: string}}|null [radice o frase riconosciuta, [reparto, icona]]
     */
    private static function find(string $name): ?array
    {
        $normalized = ' '.trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($name)))).' ';

        // Espressioni di più parole (e le radici che contengono spazi).
        foreach ([...self::PHRASES, ...array_filter(self::PRODUCTS, fn ($stem) => str_contains($stem, ' '), ARRAY_FILTER_USE_KEY)] as $phrase => $match) {
            if (str_contains($normalized, ' '.$phrase)) {
                return [$phrase, $match];
            }
        }

        // Prima parola riconosciuta; a parità di parola vince la radice più lunga (la più specifica).
        foreach (explode(' ', trim($normalized)) as $word) {
            $best = null;
            $bestLength = 0;
            foreach (self::PRODUCTS as $stem => $match) {
                $length = strlen($stem);
                $matches = $length < 4 ? $word === $stem : str_starts_with($word, $stem);
                if ($matches && $length > $bestLength) {
                    [$best, $bestLength] = [[$stem, $match], $length];
                }
            }
            if ($best) {
                return $best;
            }
        }

        // Prodotti comuni scritti in un'altra lingua ("Milk", "Lait", "Milch", "Leche" → Latte).
        if ($italian = self::italianName($normalized)) {
            return self::find($italian);
        }

        return null;
    }

    /** @var array<string, string>|null nome tradotto (normalizzato) => nome italiano */
    private static ?array $translated = null;

    /**
     * Nome italiano di un prodotto comune scritto in inglese, francese, tedesco o spagnolo (lang/{lingua}/products.php):
     * il nome deve iniziare con il prodotto tradotto ("Milk 2%" → Latte); vince la traduzione più lunga.
     */
    private static function italianName(string $normalized): ?string
    {
        if (! app()->bound('translator')) {
            return null;
        }
        if (self::$translated === null) {
            self::$translated = [];
            foreach (['en', 'fr', 'de', 'es'] as $locale) {
                foreach ((array) trans('products', [], $locale) as $italian => $name) {
                    $key = trim((string) preg_replace('/[^a-z0-9]+/', ' ', Str::lower(Str::ascii($name))));
                    // Stesso nome in italiano (es. "Pizza"): già gestito dal riconoscimento italiano.
                    if ($key !== '' && $key !== Str::lower(Str::ascii($italian))) {
                        self::$translated[$key] ??= $italian;
                    }
                }
            }
            uksort(self::$translated, fn ($a, $b) => strlen($b) <=> strlen($a));
        }
        foreach (self::$translated as $key => $italian) {
            if (str_starts_with($normalized, ' '.$key.' ')) {
                return $italian;
            }
        }

        return null;
    }

    /**
     * Icona del reparto (usata quando l'utente sceglie a mano un reparto diverso da quello riconosciuto).
     */
    public static function categoryIcon(string $category): string
    {
        return self::CATEGORIES[$category][1] ?? self::CATEGORIES[self::DEFAULT_CATEGORY][1];
    }

    /**
     * Elenco dei reparti per l'app.
     *
     * @return array<int, array{slug: string, label: string, icon: string}>
     */
    public static function categories(): array
    {
        return collect(self::CATEGORIES)
            ->map(fn (array $c, string $slug) => ['slug' => $slug, 'label' => __("app.categories.$slug"), 'icon' => $c[1]])
            ->values()
            ->all();
    }

    /**
     * @param  array{0: string, 1: string}  $match
     * @return array{category: string, icon: string}
     */
    private static function result(array $match): array
    {
        return ['category' => $match[0], 'icon' => $match[1]];
    }
}
