<?php

namespace App\Support;

use App\Models\ListItem;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use App\Models\SupermarketPrice;
use Illuminate\Support\Collection;

/**
 * Prezzi indicativi di un gruppo di articoli, letti con due sole query (segnalazioni e listino) e poi scelti in memoria.
 *
 * Per ogni articolo e catena vale, nell'ordine:
 * 1. le segnalazioni dello stesso prodotto di marca (codice a barre), se l'articolo ne ha uno;
 * 2. altrimenti le segnalazioni dello stesso tipo di prodotto ("latte", "pomodor"…, vedi ProductCatalog::productKey);
 *    tra queste vince la zona più vicina a quella della lista (stessa località, stessa città, stesso paese; i prezzi
 *    di un altro paese non valgono)
 *    e, a parità di zona, la più recente;
 * 3. altrimenti il listino caricato da CSV (supermarket_prices).
 *
 * Il prezzo dell'articolo è il prezzo trovato moltiplicato per il numero di pezzi e, se il prezzo è al kg o al litro
 * (o è di una confezione di contenuto noto) e l'articolo ha un peso o volume, per la quantità in proporzione.
 */
class PriceBook
{
    /** Conversione delle unità dell'articolo in kg o litri. */
    public const TO_UNIT = [
        'kg' => ['g' => 0.001, 'hg' => 0.1, 'kg' => 1.0],
        'l' => ['ml' => 0.001, 'cl' => 0.01, 'l' => 1.0],
    ];

    /** @var array<int, string> */
    private array $keys;

    /** @var array<int, string> */
    private array $barcodes;

    /** @var Collection<int, PriceReport> dalla più recente */
    private Collection $reports;

    /** @var array<int, array<string, array{price: float, per: string}>> catena => chiave del prodotto => prezzo di listino */
    private array $catalog = [];

    /**
     * @param  array{0: string, 1: string|null, 2: string|null}  $zone  paese, città, località
     * @param  Collection<int, ListItem>  $items
     * @param  array<int, int>|null  $supermarketIds  solo queste catene (null = tutte)
     */
    public function __construct(private array $zone, Collection $items, private ?array $supermarketIds = null)
    {
        $this->keys = $items->map(fn (ListItem $i) => ProductCatalog::productKey($i->name))->filter()->unique()->values()->all();
        $this->barcodes = $items->pluck('barcode')->filter()->unique()->values()->all();

        $this->reports = $this->keys === [] && $this->barcodes === [] ? collect() : PriceReport::query()
            ->when($supermarketIds !== null, fn ($q) => $q->whereIn('supermarket_id', $supermarketIds))
            ->where(fn ($q) => $q->whereIn('product_key', $this->keys)->orWhereIn('barcode', $this->barcodes))
            ->orderByDesc('observed_at')
            ->orderByDesc('id')
            ->get();

        if ($this->keys !== []) {
            SupermarketPrice::query()
                ->when($supermarketIds !== null, fn ($q) => $q->whereIn('supermarket_id', $supermarketIds))
                ->whereIn('product_key', $this->keys)
                ->get()
                ->each(function (SupermarketPrice $p) {
                    $this->catalog[$p->supermarket_id][$p->product_key] = ['price' => (float) $p->price, 'per' => $p->per];
                });
        }
    }

    /**
     * @param  Collection<int, ListItem>  $items
     * @param  array<int, int>|null  $supermarketIds
     */
    public static function forList(ShoppingList $list, Collection $items, ?array $supermarketIds = null): self
    {
        return new self($list->zone(), $items, $supermarketIds);
    }

    /**
     * Il libro contiene già tutto ciò che serve per l'articolo, nella stessa zona e per la stessa catena.
     *
     * @param  array{0: string, 1: string|null, 2: string|null}  $zone
     */
    public function covers(ListItem $item, array $zone, int $supermarketId): bool
    {
        $key = ProductCatalog::productKey($item->name);

        return $zone === $this->zone
            && ($this->supermarketIds === null || in_array($supermarketId, $this->supermarketIds, true))
            && ($key === null || in_array($key, $this->keys, true))
            && ($item->barcode === null || in_array($item->barcode, $this->barcodes, true));
    }

    /**
     * Catene che hanno almeno un prezzo per questi articoli.
     *
     * @return array<int, int>
     */
    public function supermarketIds(): array
    {
        return $this->reports->pluck('supermarket_id')->merge(array_keys($this->catalog))->unique()->values()->all();
    }

    /**
     * Prezzo stimato dell'articolo nella catena, con la sua provenienza; null se non si conosce.
     *
     * @return array{line: float, price: float, per: string, source: string, reporter: string|null, observed_at: string|null, city: string|null, locality: string|null, report_id: int|null}|null
     */
    public function quote(Supermarket $supermarket, ListItem $item): ?array
    {
        $key = ProductCatalog::productKey($item->name);
        $chainReports = $this->reports->where('supermarket_id', $supermarket->id);
        $sameProduct = $item->barcode ? $chainReports->where('barcode', $item->barcode) : collect();
        $candidates = $sameProduct->isNotEmpty() ? $sameProduct : ($key ? $chainReports->where('product_key', $key) : collect());

        if ($report = $this->closest($candidates)) {
            // Una confezione di contenuto noto si riporta in proporzione, salvo che sia proprio lo stesso prodotto.
            $package = $sameProduct->isEmpty() && $report->per === 'pz' && $report->package_amount
                ? [$report->package_amount, $report->package_unit]
                : null;

            return [
                'line' => self::line($report->price, $report->per, $item, $package),
                'price' => $report->price,
                'per' => $report->per,
                'source' => $report->source,
                'reporter' => $report->reporter_name,
                'observed_at' => $report->observed_at->toIso8601String(),
                'city' => $report->city,
                'locality' => $report->locality,
                'report_id' => $report->id,
            ];
        }

        $listed = $key ? ($this->catalog[$supermarket->id][$key] ?? null) : null;
        if ($listed === null) {
            return null;
        }

        return [
            'line' => self::line($listed['price'], $listed['per'], $item),
            'price' => $listed['price'],
            'per' => $listed['per'],
            'source' => 'catalog',
            'reporter' => null,
            'observed_at' => null,
            'city' => null,
            'locality' => null,
            'report_id' => null,
        ];
    }

    /**
     * La segnalazione della zona più vicina, nello stesso paese; a parità di zona la prima, cioè la più recente.
     *
     * @param  Collection<int, PriceReport>  $reports
     */
    private function closest(Collection $reports): ?PriceReport
    {
        $best = null;
        $bestRank = 0;
        foreach ($reports as $report) {
            $rank = $this->zoneRank($report);
            if ($rank > $bestRank) {
                [$best, $bestRank] = [$report, $rank];
            }
        }

        return $best;
    }

    /**
     * 3 = stessa località, 2 = stessa città, 1 = stesso paese, 0 = altro paese (non vale).
     */
    private function zoneRank(PriceReport $report): int
    {
        [$country, $city, $locality] = $this->zone;
        if ($report->country !== $country) {
            return 0;
        }
        if ($city === null || Supermarket::normalize((string) $report->city) !== Supermarket::normalize($city)) {
            return 1;
        }

        return $locality !== null && Supermarket::normalize((string) $report->locality) === Supermarket::normalize($locality) ? 3 : 2;
    }

    /**
     * Prezzo per il numero di pezzi e, quando si può, per il peso o volume dell'articolo.
     *
     * @param  array{0: float, 1: string}|null  $package  contenuto della confezione a cui si riferisce il prezzo (in kg o l)
     */
    public static function line(float $price, string $per, ListItem $item, ?array $package = null): float
    {
        $units = 1.0;
        if (isset(self::TO_UNIT[$per][$item->unit]) && $item->amount !== null) {
            $units = $item->amount * self::TO_UNIT[$per][$item->unit];
        } elseif ($package !== null && isset(self::TO_UNIT[$package[1]][$item->unit]) && $item->amount !== null) {
            $units = $item->amount * self::TO_UNIT[$package[1]][$item->unit] / $package[0];
        }

        return round($price * $units * self::pieces($item->quantity), 2);
    }

    /**
     * Numero di pezzi dalla quantità scritta dall'utente: "2" → 2, "3 confezioni" → 3, "1,5" → 1.5, "qualche" → 1.
     */
    public static function pieces(?string $quantity): float
    {
        if ($quantity === null || ! preg_match('/^\s*(\d+(?:[.,]\d+)?)/', $quantity, $m)) {
            return 1.0;
        }
        $pieces = (float) str_replace(',', '.', $m[1]);

        return $pieces > 0 ? min($pieces, 1000.0) : 1.0;
    }

    /**
     * Contenuto di una confezione in kg o litri: 500 g → [0.5, "kg"], 1500 ml → [1.5, "l"]; null se non si sa.
     *
     * @return array{0: float, 1: string}|null
     */
    public static function package(?float $amount, ?string $unit): ?array
    {
        foreach (self::TO_UNIT as $to => $factors) {
            if ($amount !== null && $amount > 0 && isset($factors[$unit])) {
                return [round($amount * $factors[$unit], 3), $to];
            }
        }

        return null;
    }
}
