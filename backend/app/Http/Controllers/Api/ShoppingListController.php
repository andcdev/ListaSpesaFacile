<?php

namespace App\Http\Controllers\Api;

use App\Events\ListsChanged;
use App\Events\ShoppingListDeleted;
use App\Events\ShoppingListUpdated;
use App\Http\Controllers\Controller;
use App\Http\Resources\ShoppingListResource;
use App\Models\ShoppingList;
use App\Models\User;
use App\Notifications\ListActivity;
use App\Notifications\ListCreated;
use App\Notifications\ListDeleted;
use App\Notifications\ListShared;
use App\Support\Notifier;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
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

        $lists = ShoppingList::query()
            ->accessibleBy($request->user())
            // Con chi è condivisa: l'app filtra l'elenco per persona.
            ->with(['owner', 'sharedWith'])
            ->withCount(['items', 'items as checked_items_count' => fn (Builder $q) => $q->where('checked', true)])
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
     * Crea la lista; con "shares" la condivide subito con gli utenti indicati.
     */
    public function store(Request $request): JsonResponse
    {
        $owner = $request->user();
        $data = $this->validateList($request);
        $shares = $this->resolveShares($request, $owner);

        $list = DB::transaction(function () use ($owner, $data, $shares) {
            $list = $owner->ownedLists()->create($data);
            $list->sharedWith()->attach($shares);

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

        // Solo il proprietario decide se gli altri possono rinominare la lista.
        if ($list->isDirty('members_can_rename') && $list->owner_id !== $user->id) {
            abort(403, __('app.errors.owner_only_permission'));
        }
        if ($list->isDirty('name') && ! $list->canRename($user)) {
            throw ValidationException::withMessages(['name' => [__('app.errors.rename_not_allowed')]]);
        }

        $oldName = $list->getOriginal('name');
        $renamed = $list->isDirty('name');
        $changed = $list->isDirty();
        $list->save();

        Realtime::broadcast(new ShoppingListUpdated($list));
        Realtime::broadcast(new ListsChanged($list->audienceIds(), $list->id));
        if ($changed) {
            $renamed
                ? ListActivity::notify($list, $user, 'list_renamed', ['old' => $oldName, 'new' => $list->name])
                : ListActivity::notify($list, $user, 'list_edited');
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

    private function detail(ShoppingList $list): ShoppingListResource
    {
        $list->load(['owner', 'items.creator', 'items.checker', 'sharedWith']);
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
