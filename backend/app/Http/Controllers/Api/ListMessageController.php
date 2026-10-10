<?php

namespace App\Http\Controllers\Api;

use App\Events\ListMessageCreated;
use App\Events\ListMessageDeleted;
use App\Events\ListMessagesDelivered;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListMessageResource;
use App\Models\ListMessage;
use App\Models\ShoppingList;
use App\Notifications\ChatMessageReceived;
use App\Support\ImageModeration;
use App\Support\Notifier;
use App\Support\Realtime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Chat interna della lista: può scrivere chiunque abbia accesso, anche in sola lettura.
 * Un messaggio contiene testo, una foto (dalla galleria o dalla fotocamera) o entrambi.
 */
class ListMessageController extends Controller
{
    private const PAGE_SIZE = 50;

    /**
     * Messaggi dal più recente; ?before={id} per caricare quelli precedenti.
     */
    public function index(Request $request, ShoppingList $list): AnonymousResourceCollection
    {
        $this->authorize('view', $list);

        $before = $request->integer('before');
        // I messaggi delle persone bloccate non compaiono.
        $blocked = $request->user()->blockedIds();
        $messages = $list->messages()
            ->with('user')
            ->when($before > 0, fn ($q) => $q->where('id', '<', $before))
            ->when($blocked, fn ($q) => $q->where(fn ($q) => $q->whereNull('user_id')->orWhereNotIn('user_id', $blocked)))
            ->orderByDesc('id')
            ->limit(self::PAGE_SIZE + 1)
            ->get();

        return ListMessageResource::collection($messages->take(self::PAGE_SIZE))
            ->additional([
                'has_more' => $messages->count() > self::PAGE_SIZE,
                'delivered' => $this->deliveries($list),
            ]);
    }

    public function store(Request $request, ShoppingList $list): JsonResponse
    {
        $this->authorize('view', $list);

        $data = $request->validate([
            'body' => ['nullable', 'string', 'max:2000', 'required_without:image'],
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192'],
        ]);

        $sender = $request->user();
        $body = trim($data['body'] ?? '');
        if ($file = $request->file('image')) {
            ImageModeration::guard($file, $sender, 'chat', $list, $body === '' ? null : $body);
        }
        $message = new ListMessage(['body' => $body === '' ? null : $body]);
        $message->user()->associate($sender);
        if ($file = $request->file('image')) {
            $message->image_path = $file->storeAs(
                ListMessage::IMAGE_DIR.'/'.$list->id,
                Str::random(24).'.'.$file->extension(),
            );
        }
        $list->messages()->save($message);
        // Chi scrive ha di sicuro tutti i messaggi fino al proprio.
        $list->markChatDelivered($sender, $message->id);

        Realtime::broadcast(new ListMessageCreated($message));

        Notifier::send(
            array_diff($list->audienceIds(), [$sender->id]),
            new ChatMessageReceived($sender->name, $list->id, $list->name, $message->body, $message->id, $message->image_path !== null),
            $sender,
        );

        return (new ListMessageResource($message->load('user')))->response()->setStatusCode(201);
    }

    /**
     * Il telefono dell'utente ha ricevuto i messaggi fino a up_to (chat aperta, notifica arrivata…):
     * chi li ha scritti vede le due spunte blu.
     */
    public function delivered(Request $request, ShoppingList $list): JsonResponse
    {
        $this->authorize('view', $list);

        $data = $request->validate(['up_to' => ['required', 'integer', 'min:1']]);
        $user = $request->user();

        if ($upTo = $list->markChatDelivered($user, $data['up_to'])) {
            Realtime::broadcast(new ListMessagesDelivered($list->id, $user->id, $upTo));
        }

        return response()->json(status: 204);
    }

    /**
     * Fino a quale messaggio ha ricevuto ogni utente della lista (0 = nessuno): {user_id: up_to}.
     *
     * @return array<string, int>
     */
    private function deliveries(ShoppingList $list): array
    {
        $upTo = $list->chatDeliveries()->pluck('delivered_up_to', 'user_id');

        return collect($list->audienceIds())
            ->mapWithKeys(fn (int $id) => [(string) $id => (int) ($upTo[$id] ?? 0)])
            ->all();
    }

    /**
     * Foto allegata al messaggio (il file non è pubblico: serve il token di chi vede la lista).
     */
    public function image(ShoppingList $list, ListMessage $message): StreamedResponse
    {
        $this->authorize('view', $list);
        abort_unless($message->image_path && Storage::exists($message->image_path), 404);

        // La foto di un messaggio non cambia mai.
        return Storage::response($message->image_path, headers: ['Cache-Control' => 'private, max-age=31536000']);
    }

    /**
     * Elimina un messaggio (e la sua foto): l'autore oppure il proprietario della lista.
     */
    public function destroy(Request $request, ShoppingList $list, ListMessage $message): JsonResponse
    {
        $user = $request->user();
        abort_unless($message->user_id === $user->id || $list->owner_id === $user->id, 403);

        $message->delete();

        Realtime::broadcast(new ListMessageDeleted($list->id, $message->id));

        return response()->json(status: 204);
    }
}
