<?php

namespace App\Support;

use App\Models\ListItem;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\Supermarket;
use Illuminate\Support\Collection;

/**
 * Prezzi indicativi di un gruppo di articoli, letti con una sola query e poi scelti in memoria.
 *
 * Contano le segnalazioni approvate: quelle di Open Prices e le rettifiche degli utenti confermate da altri utenti.
 * Per ogni articolo e catena vale, nell'ordine:
 * 1. le segnalazioni dello stesso prodotto di marca (codice a barre), se l'articolo ne ha uno;
 * 2. altrimenti le segnalazioni dello stesso tipo di prodotto ("latte", "pomodor"…, vedi ProductCatalog::productKey);
 *    tra queste vince la zona più vicina a quella della lista (stessa località, stessa città o paese, stessa
 *    provincia, stesso stato; i prezzi di un altro stato non valgono), poi quella con più conferme degli utenti e,
 *    a parità, la più recente.
 *
 * Le rettifiche in attesa di conferma le vede solo chi le ha scritte (myPending); agli altri si dice solo quante
 * ce ne sono da confermare (pendingCount).
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

    /** @var Collection<int, PriceReport> approvate, dalla più recente */
    private Collection $reports;

    /** @var Collection<int, PriceReport> in attesa di conferma, dalla più recente */
    private Collection $pending;

    /**
     * @param  array{0: string, 1: string|null, 2: string|null, 3: string|null}  $zone  stato, provincia, città, località
     * @param  Collection<int, ListItem>  $items
     * @param  array<int, int>|null  $supermarketIds  solo queste catene (null = tutte)
     */
    public function __construct(private array $zone, Collection $items, private ?array $supermarketIds = null)
    {
        $this->keys = $items->map(fn (ListItem $i) => ProductCatalog::productKey($i->name))->filter()->unique()->values()->all();
        $this->barcodes = $items->pluck('barcode')->filter()->unique()->values()->all();

        $all = $this->keys === [] && $this->barcodes === [] ? collect() : PriceReport::query()
            ->when($supermarketIds !== null, fn ($q) => $q->whereIn('supermarket_id', $supermarketIds))
            ->where('country', $zone[0])
            ->whereIn('status', [PriceReport::APPROVED, PriceReport::PENDING])
            ->where(fn ($q) => $q->whereIn('product_key', $this->keys)->orWhereIn('barcode', $this->barcodes))
            ->orderByDesc('observed_at')
            ->orderByDesc('id')
            ->get();
        [$this->reports, $this->pending] = $all->partition(fn (PriceReport $r) => $r->status === PriceReport::APPROVED);
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
     * @param  array{0: string, 1: string|null, 2: string|null, 3: string|null}  $zone
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
     * Catene che hanno almeno un prezzo approvato per questi articoli.
     *
     * @return array<int, int>
     */
    public function supermarketIds(): array
    {
        return $this->reports->pluck('supermarket_id')->unique()->values()->all();
    }

    /**
     * Prezzo stimato dell'articolo nella catena (solo segnalazioni approvate), con la sua provenienza;
     * null se non si conosce.
     *
     * @return array<string, mixed>|null
     */
    public function quote(Supermarket $supermarket, ListItem $item): ?array
    {
        [$candidates, $sameProduct] = $this->candidates($this->reports, $supermarket, $item);
        $report = $this->closest($candidates);

        return $report ? $this->describe($report, $item, $sameProduct) : null;
    }

    /**
     * La rettifica più recente di [$userId] per l'articolo ancora in attesa di conferma (la vede solo lui).
     *
     * @return array<string, mixed>|null
     */
    public function myPending(Supermarket $supermarket, ListItem $item, int $userId): ?array
    {
        $mine = $this->pending->where('user_id', $userId);
        [$candidates, $sameProduct] = $this->candidates($mine, $supermarket, $item);
        $report = $candidates->first();

        return $report ? $this->describe($report, $item, $sameProduct) : null;
    }

    /**
     * Quante rettifiche di altri utenti per l'articolo aspettano una conferma.
     */
    public function pendingCount(Supermarket $supermarket, ListItem $item, ?int $exceptUserId): int
    {
        $others = $this->pending->filter(fn (PriceReport $r) => $exceptUserId === null || $r->user_id !== $exceptUserId);

        return $this->candidates($others, $supermarket, $item)[0]->count();
    }

    /**
     * Segnalazioni che valgono per l'articolo: dello stesso prodotto di marca se ce ne sono, altrimenti dello stesso
     * tipo di prodotto.
     *
     * @param  Collection<int, PriceReport>  $reports
     * @return array{0: Collection<int, PriceReport>, 1: bool} segnalazioni, true se sono dello stesso prodotto di marca
     */
    private function candidates(Collection $reports, Supermarket $supermarket, ListItem $item): array
    {
        $chainReports = $reports->where('supermarket_id', $supermarket->id);
        $sameProduct = $item->barcode ? $chainReports->where('barcode', $item->barcode) : collect();
        if ($sameProduct->isNotEmpty()) {
            return [$sameProduct, true];
        }
        $key = ProductCatalog::productKey($item->name);

        return [$key ? $chainReports->where('product_key', $key) : collect(), false];
    }

    /**
     * @return array<string, mixed>
     */
    private function describe(PriceReport $report, ListItem $item, bool $sameProduct): array
    {
        // Una confezione di contenuto noto si riporta in proporzione, salvo che sia proprio lo stesso prodotto.
        $package = ! $sameProduct && $report->per === 'pz' && $report->package_amount
            ? [$report->package_amount, $report->package_unit]
            : null;

        return [
            'line' => self::line($report->price, $report->per, $item, $package),
            'price' => $report->price,
            'currency' => $report->currency,
            'per' => $report->per,
            'source' => $report->source,
            'status' => $report->status,
            'reporter' => $report->reporter_name,
            'observed_at' => $report->observed_at->toIso8601String(),
            'city' => $report->city,
            'locality' => $report->locality,
            'report_id' => $report->id,
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
        $bestScore = [0, -1];
        foreach ($reports as $report) {
            $score = [self::zoneRank($this->zone, $report), $report->approvals];
            if ($score[0] > 0 && $score > $bestScore) {
                [$best, $bestScore] = [$report, $score];
            }
        }

        return $best;
    }

    /**
     * Vicinanza della segnalazione alla zona: 4 = stessa località, 3 = stessa città o paese, 2 = stessa provincia,
     * 1 = stesso stato, 0 = altro stato (non vale).
     *
     * @param  array{0: string, 1: string|null, 2: string|null, 3: string|null}  $zone  stato, provincia, città, località
     */
    public static function zoneRank(array $zone, PriceReport $report): int
    {
        [$country, $province, $city, $locality] = $zone;
        $same = fn (?string $a, ?string $b) => $a !== null && $b !== null && Supermarket::normalize($a) === Supermarket::normalize($b)
            && Supermarket::normalize($a) !== '';

        return match (true) {
            $report->country !== $country => 0,
            $same($city, $report->city) && $same($locality, $report->locality) => 4,
            $same($city, $report->city) => 3,
            $same($province, $report->province) => 2,
            default => 1,
        };
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
