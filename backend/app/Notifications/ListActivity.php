<?php

namespace App\Notifications;

use App\Models\ShoppingList;
use App\Models\User;
use App\Support\Notifier;

/**
 * Modifica a una lista (articolo aggiunto, preso, eliminato, lista rinominata…) fatta da un altro utente.
 * Come i messaggi della chat: solo sul telefono, nella conversazione della lista, non nell'elenco "Notifiche".
 */
class ListActivity extends AppNotification
{
    public function __construct(
        public string $actorName,
        public int $changedListId,
        public string $changedListName,
        public string $action,
        public array $params = [],
    ) {}

    /**
     * Avvisa tutti gli utenti della lista tranne chi ha fatto la modifica.
     * [$action] è una chiave di activity in lang/{lingua}/app.php (es. "added" con ['item' => '🥛 Latte']):
     * il testo si compone nella lingua di chi riceve.
     *
     * @param  array<string, string|int>  $params
     */
    public static function notify(ShoppingList $list, User $actor, string $action, array $params = []): void
    {
        Notifier::send(
            array_diff($list->audienceIds(), [$actor->id]),
            new self($actor->name, $list->id, $list->name, $action, $params),
            $actor,
        );
    }

    public function kind(): string
    {
        return 'list_activity';
    }

    public function title(): string
    {
        return $this->changedListName;
    }

    public function body(): string
    {
        $params = ['actor' => $this->actorName, ...$this->params];

        // Il testo inizia sempre con il nome: l'app lo usa come mittente nella conversazione della lista.
        return isset($this->params['count'])
            ? trans_choice("app.activity.{$this->action}", $this->params['count'], $params)
            : __("app.activity.{$this->action}", $params);
    }

    public function listId(): ?int
    {
        return $this->changedListId;
    }

    public function sender(): ?string
    {
        return $this->actorName;
    }

    public function listName(): ?string
    {
        return $this->changedListName;
    }

    protected function stored(): bool
    {
        return false;
    }

    public function pushTag(): ?string
    {
        return 'list-'.$this->changedListId;
    }
}
