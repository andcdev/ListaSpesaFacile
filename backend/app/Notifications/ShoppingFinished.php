<?php

namespace App\Notifications;

/**
 * Chi faceva la spesa ha toccato "Spesa finita": tutto preso, oppure con i prodotti che mancano ancora (e che
 * restano da prendere per gli altri). Va nell'elenco "Notifiche" e sul telefono.
 */
class ShoppingFinished extends AppNotification
{
    /** Prodotti mancanti scritti per nome nella notifica; degli altri si dice solo quanti sono. */
    private const NAMED = 5;

    /**
     * @param  array<int, string>  $missing  prodotti ancora da prendere (es. "🥛 Latte")
     */
    public function __construct(
        public string $actorName,
        public int $finishedListId,
        public string $finishedListName,
        public array $missing,
        public ?string $message = null,
    ) {}

    public function kind(): string
    {
        return 'shopping_finished';
    }

    public function title(): string
    {
        return __('app.notifications.shopping_finished_title', ['actor' => $this->actorName, 'list' => $this->finishedListName]);
    }

    public function body(): string
    {
        $count = count($this->missing);
        if ($count === 0) {
            $text = __('app.notifications.shopping_finished_complete');
        } else {
            $items = implode(', ', array_slice($this->missing, 0, self::NAMED));
            if ($count > self::NAMED) {
                $items = __('app.notifications.shopping_finished_more', ['items' => $items, 'count' => $count - self::NAMED]);
            }
            $text = trans_choice('app.notifications.shopping_finished_missing', $count, ['count' => $count, 'items' => $items]);
        }

        return $this->message === null ? $text : $text.' '.__('app.notifications.quoted', ['text' => $this->message]);
    }

    public function listId(): ?int
    {
        return $this->finishedListId;
    }

    public function sender(): ?string
    {
        return $this->actorName;
    }

    public function listName(): ?string
    {
        return $this->finishedListName;
    }
}
