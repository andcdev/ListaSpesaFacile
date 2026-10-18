<?php

namespace App\Http\Controllers\Api;

use App\Events\ListItemSaved;
use App\Events\ListMessageCreated;
use App\Events\ListsChanged;
use App\Events\ShoppingListDeleted;
use App\Events\ShoppingListUpdated;
use App\Http\Controllers\Controller;
use App\Http\Resources\ShoppingListResource;
use App\Models\ListItem;
use App\Models\ListMessage;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListActivity;
use App\Notifications\ListCreated;
use App\Notifications\ListDeleted;
use App\Notifications\ListShared;
use App\Notifications\ShoppingAssigned;
use App\Notifications\ShoppingFinished;
use App\Support\Notifier;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ShoppingListController extends Controller
{
    /**
     * Liste accessibili all'utente, ordinate per data e ora.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        // "product": solo le liste con un articolo che contiene tutte le parole scritte (ricerca dall'elenco).
        $data = $request->validate(['product' => ['sometimes', 'nullable', 'string', 'max:100']]);
        $words = preg_split('/\s+/', trim((string) ($data['product'] ?? '')), -1, PREG_SPLIT_NO_EMPTY);

        $user = $request->user();
        $blocked = $user->blockedIds();
        $lists = ShoppingList::query()
            ->accessibleBy($user)
            // Con chi è condivisa: l'app filtra l'elenco per persona.
            ->with(['owner', 'sharedWith'])
            ->withCount([
                'items',
                'items as checked_items_count' => fn (Builder $q) => $q->where('checked', true),
                // Messaggi degli altri in chat non ancora letti (dopo l'ultimo letto con la chat aperta), senza gli
                // eventi della lista e senza le persone bloccate: il pallino nell'elenco e in alto nella home.
                'messages as unread_messages_count' => fn (Builder $q) => $q
                    ->whereNull('event')
                    ->where('user_id', '!=', $user->id)
                    ->when($blocked, fn (Builder $q) => $q->whereNotIn('user_id', $blocked))
                    ->whereRaw('list_messages.id > COALESCE((SELECT delivered_up_to FROM chat_deliveries WHERE chat_deliveries.shopping_list_id = list_messages.shopping_list_id AND chat_deliveries.user_id = ?), 0)', [$user->id]),
            ])
            ->when($words, fn (Builder $q) => $q->whereHas('items', function (Builder $items) use ($words) {
                foreach ($words as $word) {
                    $items->whereRaw('LOWER(name) LIKE ?', ['%'.mb_strtolower(addcslashes($word, '%_\\')).'%']);
                }
            }))
            ->orderBy('scheduled_at')
            ->orderBy('id')
            ->get();

        return ShoppingListResource::collection($lists);
    }

    /**
     * Crea la lista; con "shares" la condivide subito con gli utenti indicati. Con "copy_from" è la copia di una
     * lista che l'utente vede: nome, data e il resto arrivano dal modulo, articoli e foto dalla lista copiata.
     * Con "shopper_email" sceglie chi fa la spesa: il proprietario o una delle persone della lista.
     */
    public function store(Request $request): JsonResponse
    {
        $owner = $request->user();
        $data = $this->validateList($request);
        $shares = $this->resolveShares($request, $owner);
        $shopperEmail = $request->validate(['shopper_email' => ['sometimes', 'nullable', 'email']])['shopper_email'] ?? null;
        $source = null;
        if ($copyFrom = $request->validate(['copy_from' => ['sometimes', 'nullable', 'integer']])['copy_from'] ?? null) {
            $source = ShoppingList::findOrFail($copyFrom);
            $this->authorize('view', $source);
        }

        $list = DB::transaction(function () use ($owner, $data, $shares, $source, $shopperEmail) {
            $list = $owner->ownedLists()->create($data);
            $list->sharedWith()->attach($shares);
            if ($shopperEmail !== null) {
                $list->shopper_id = $this->member($list, User::where('email', strtolower($shopperEmail))->value('id'), 'shopper_email');
                $list->save();
            }
            if ($source) {
                $this->copyContents($source, $list, $owner);
            }

            return $list;
        });

        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));

        foreach ($shares as $userId => $pivot) {
            Notifier::send([$userId], new ListShared($owner->name, $list->id, $list->name, $pivot['can_edit']));
        }
        // Chi riceve tutte le liste del proprietario (e non l'ha già ricevuta singolarmente).
        Notifier::send(
            $owner->globalShareRecipients()->whereKeyNot(array_keys($shares))->get(),
            new ListCreated($owner->name, $list->id, $list->name),
        );
        if ($list->shopper_id !== null && $list->shopper_id !== $owner->id) {
            Notifier::send([$list->shopper_id], new ShoppingAssigned($owner->name, $list->id, $list->name));
        }

        return $this->detail($list)->response()->setStatusCode(201);
    }

    public function show(ShoppingList $list): ShoppingListResource
    {
        $this->authorize('view', $list);

        return $this->detail($list);
    }

    public function update(Request $request, ShoppingList $list): ShoppingListResource
    {
        $this->authorize('update', $list);

        $user = $request->user();
        $list->fill($this->validateList($request, partial: true));
        // Chi fa la spesa (null = chiunque): lo può cambiare chiunque possa modificare la lista.
        if ($request->has('shopper_id')) {
            $shopperId = $request->validate(['shopper_id' => ['nullable', 'integer']])['shopper_id'];
            $list->shopper_id = $shopperId === null ? null : $this->member($list, $shopperId, 'shopper_id');
        }
        $shopperChanged = $list->isDirty('shopper_id');
        if ($shopperChanged) {
            $list->clearFinished();
        }

        // Solo il proprietario decide se gli altri possono rinominare la lista.
        if ($list->isDirty('members_can_rename') && $list->owner_id !== $user->id) {
            abort(403, __('app.errors.owner_only_permission'));
        }
        if ($list->isDirty('name') && ! $list->canRename($user)) {
            throw ValidationException::withMessages(['name' => [__('app.errors.rename_not_allowed')]]);
        }

        // Cambiato solo chi fa la spesa: l'avviso dice chi è.
        $onlyShopper = array_values(array_diff(array_keys($list->getDirty()), ['finished_at', 'finished_by', 'finish_message'])) === ['shopper_id'];
        $oldName = $list->getOriginal('name');
        $renamed = $list->isDirty('name');
        $changed = $list->isDirty();
        $list->save();

        Realtime::broadcast(new ShoppingListUpdated($list));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
        if ($changed) {
            match (true) {
                $renamed => ListActivity::notify($list, $user, 'list_renamed', ['old' => $oldName, 'new' => $list->name]),
                $onlyShopper && $list->shopper_id !== null => ListActivity::notify($list, $user, 'shopper_changed', ['shopper' => $list->shopper->name], [$list->shopper_id]),
                default => ListActivity::notify($list, $user, 'list_edited'),
            };
        }
        if ($shopperChanged && $list->shopper_id !== null) {
            ListMessage::postEvent($list, $user, 'shopper_changed', __('app.activity.shopper_changed', ['actor' => $user->name, 'shopper' => $list->shopper->name]), [
                'shopper' => $list->shopper->name,
            ]);
        }
        if ($shopperChanged && $list->shopper_id !== null && $list->shopper_id !== $user->id) {
            Notifier::send([$list->shopper_id], new ShoppingAssigned($user->name, $list->id, $list->name), $user);
        }

        return $this->detail($list);
    }

    /**
     * "Spesa finita": chi fa la spesa ha finito il suo giro, anche se mancano prodotti. Quelli non trovati tornano
     * da prendere (come quelli mai segnati) e le altre persone della lista ricevono una notifica con ciò che manca.
     * Il messaggio facoltativo finisce anche nella chat della lista.
     */
    public function finish(Request $request, ShoppingList $list): ShoppingListResource
    {
        $this->authorize('update', $list);
        $user = $request->user();
        $this->ensureCanMark($list, $user);
        $data = $request->validate(['message' => ['sometimes', 'nullable', 'string', 'max:500']]);
        $message = trim($data['message'] ?? '');
        $message = $message === '' ? null : $message;

        $items = $list->items()->get();
        if ($items->isEmpty()) {
            throw ValidationException::withMessages(['items' => [__('app.errors.nothing_to_finish')]]);
        }
        $missing = $items->where('status', '!=', 'taken')->values();
        foreach ($missing->where('status', 'missing') as $item) {
            $item->status = 'todo';
            $item->checked = false;
            $item->checked_by = null;
            $item->save();
            Realtime::broadcast(new ListItemSaved($item));
        }

        $list->finished_at = now();
        $list->finished_by = $user->id;
        $list->finish_message = $message;
        $list->save();

        // In chat, in grigio: la spesa è finita (prima dell'eventuale messaggio di chi l'ha finita).
        ListMessage::postEvent($list, $user, 'finished', trim(__('app.notifications.shopping_finished_title', ['actor' => $user->name, 'list' => $list->name])), [
            'missing' => $missing->count(),
        ]);
        if ($message !== null) {
            $chat = new ListMessage(['body' => $message]);
            $chat->user()->associate($user);
            $list->messages()->save($chat);
            Realtime::broadcast(new ListMessageCreated($chat));
        }

        Realtime::broadcast(new ShoppingListUpdated($list));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
        // Con una persona sola nella lista non c'è nessuno da avvisare.
        Notifier::send(
            array_diff($list->audienceIds(), [$user->id]),
            new ShoppingFinished($user->name, $list->id, $list->name, $missing->map(fn (ListItem $i) => ListItemController::label($i))->all(), $message),
            $user,
        );

        return $this->detail($list);
    }

    /**
     * "Continuo io": la spesa passa a chi tocca il pulsante, che da quel momento segna i prodotti.
     */
    public function takeOver(Request $request, ShoppingList $list): ShoppingListResource
    {
        $this->authorize('update', $list);
        $user = $request->user();

        if ($list->activeShopperId() !== $user->id || $list->finished_at !== null) {
            $list->shopper_id = $user->id;
            $list->clearFinished();
            $list->save();

            Realtime::broadcast(new ShoppingListUpdated($list));
            Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
            ListActivity::notify($list, $user, 'took_over');
            ListMessage::postEvent($list, $user, 'took_over', __('app.activity.took_over', ['actor' => $user->name]));
        }

        return $this->detail($list);
    }

    public function destroy(ShoppingList $list): JsonResponse
    {
        $this->authorize('delete', $list);

        $audience = $list->audienceIds();
        $listId = $list->id;
        $list->delete();

        Realtime::broadcast(new ShoppingListDeleted($listId));
        Realtime::broadcast(new ListsChanged($audience, $listId));
        Notifier::send(array_diff($audience, [$list->owner_id]), new ListDeleted($list->owner->name, $list->name));

        return response()->json(status: 204);
    }

    /**
     * [$userId] se è una delle persone della lista (proprietario compreso), altrimenti errore sul campo [$field].
     */
    private function member(ShoppingList $list, ?int $userId, string $field): int
    {
        if ($userId === null || ! in_array($userId, $list->audienceIds(), true)) {
            throw ValidationException::withMessages([$field => [__('app.errors.shopper_not_member')]]);
        }

        return $userId;
    }

    /**
     * Solo chi fa la spesa segna i prodotti e la finisce, quando è stato scelto qualcuno.
     */
    public static function ensureCanMark(ShoppingList $list, User $user): void
    {
        if (! $list->canMarkItems($user)) {
            abort(403, __('app.errors.not_shopper', ['name' => User::find($list->activeShopperId())?->name]));
        }
    }

    /**
     * Copia in [$copy] gli articoli di [$source], tutti da prendere e aggiunti da [$owner], con le loro foto e la
     * foto della lista.
     */
    private function copyContents(ShoppingList $source, ShoppingList $copy, User $owner): void
    {
        if ($source->image_path && Storage::exists($source->image_path)) {
            $copy->image_path = 'list-images/'.$copy->id.'-'.Str::random(12).'.'.pathinfo($source->image_path, PATHINFO_EXTENSION);
            Storage::copy($source->image_path, $copy->image_path);
            $copy->save();
        }

        foreach ($source->items as $original) {
            $item = new ListItem($original->only([
                'name', 'barcode', 'brand', 'category', 'custom_icon', 'image_url', 'image_auto', 'quantity', 'amount',
                'unit', 'position',
            ]));
            $item->created_by = $owner->id;
            if ($original->image_path && Storage::exists($original->image_path)) {
                $item->image_path = ListItem::IMAGE_DIR.'/'.$copy->id.'/'.Str::random(24).'.'.pathinfo($original->image_path, PATHINFO_EXTENSION);
                Storage::copy($original->image_path, $item->image_path);
            }
            $copy->items()->save($item);
        }
    }

    private function detail(ShoppingList $list): ShoppingListResource
    {
        $list->load(['owner', 'items.creator', 'items.checker', 'sharedWith', 'shopper', 'finisher']);
        // Gli articoli usano la catena della lista per il prezzo: stessa istanza, una sola ricerca.
        $list->items->each->setRelation('shoppingList', $list);

        return new ShoppingListResource($list);
    }

    /**
     * @return array<string, mixed>
     */
    private function validateList(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        $data = $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:5000'],
            // Supermercato dove si fa la spesa (testo libero, con i suggerimenti delle catene note).
            'supermarket' => ['sometimes', 'nullable', 'string', 'max:100'],
            'scheduled_at' => [$required, 'date'],
            // Minuti di anticipo del promemoria (null = nessuno), fino a 30 giorni.
            'reminder_minutes' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:43200'],
            'reminder_target' => ['sometimes', Rule::in(ShoppingList::REMINDER_TARGETS)],
            // Chi può modificare la lista può anche cambiarne il nome (deciso dal proprietario).
            'members_can_rename' => ['sometimes', 'boolean'],
        ]);

        // Le date arrivano con il fuso del dispositivo: le salviamo sempre nel fuso dell'applicazione (UTC).
        if (isset($data['scheduled_at'])) {
            $data['scheduled_at'] = Carbon::parse($data['scheduled_at'])->setTimezone(config('app.timezone'));
        }

        return $data;
    }

    /**
     * Utenti con cui condividere la lista alla creazione: [user_id => ['can_edit' => bool]].
     *
     * @return array<int, array{can_edit: bool}>
     */
    private function resolveShares(Request $request, User $owner): array
    {
        $request->validate([
            'shares' => ['sometimes', 'array', 'max:'.ShoppingList::MAX_PEOPLE],
            'shares.*.email' => ['required', 'email'],
            'shares.*.can_edit' => ['sometimes', 'boolean'],
        ]);

        $shares = [];
        foreach ($request->input('shares', []) as $i => $share) {
            $user = User::where('email', strtolower($share['email']))->first();
            if (! $user) {
                throw ValidationException::withMessages(["shares.$i.email" => [__('app.errors.no_user_email', ['email' => $share['email']])]]);
            }
            if ($user->is($owner)) {
                throw ValidationException::withMessages(["shares.$i.email" => [__('app.errors.share_self_list')]]);
            }
            if ($reason = $owner->shareBlockedReason($user)) {
                throw ValidationException::withMessages(["shares.$i.email" => [$reason]]);
            }
            $shares[$user->id] = ['can_edit' => (bool) ($share['can_edit'] ?? true)];
        }

        // Anche chi ha ricevuto tutte le liste del proprietario vedrà questa.
        $people = collect(array_keys($shares))->merge($owner->globalShareRecipients()->pluck('users.id'))->unique();
        if ($people->count() > ShoppingList::MAX_PEOPLE) {
            throw ValidationException::withMessages(['shares' => [__('app.errors.list_full', ['max' => ShoppingList::MAX_PEOPLE])]]);
        }

        return $shares;
    }
}
