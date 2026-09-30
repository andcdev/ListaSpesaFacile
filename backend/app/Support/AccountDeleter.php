<?php

namespace App\Support;

use App\Events\ListMessageDeleted;
use App\Events\ListsChanged;
use App\Events\ShoppingListDeleted;
use App\Models\ListMessage;
use App\Models\PriceReport;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Eliminazione definitiva di un account e di tutto ciò che è suo.
 *
 * Passa dai modelli e non dalle sole cascate del database: le foto di liste, articoli e chat e l'avatar
 * stanno su disco e le cancellano gli eventi "deleted" dei modelli, che una cascata SQL non fa scattare.
 * Chi condivideva le liste riceve gli stessi eventi in tempo reale di un'eliminazione fatta dall'app.
 */
class AccountDeleter
{
    public static function delete(User $user): void
    {
        // Le sue liste spariscono per tutti, con articoli, foto e chat.
        foreach ($user->ownedLists()->get() as $list) {
            $audience = $list->audienceIds();
            $listId = $list->id;
            $list->delete();
            Realtime::broadcast(new ShoppingListDeleted($listId), new ListsChanged($audience, $listId));
        }

        // I suoi messaggi nelle liste degli altri, con le foto.
        foreach (ListMessage::where('user_id', $user->id)->get() as $message) {
            $message->delete();
            Realtime::broadcast(new ListMessageDeleted($message->shopping_list_id, $message->id));
        }

        // Liste altrui a cui partecipava: chi resta deve vederlo sparire dai membri.
        $shared = ShoppingList::whereHas('sharedWith', fn ($q) => $q->whereKey($user->id))->get();
        $audiences = $shared->map(fn (ShoppingList $list) => [$list->audienceIds(), $list->id]);
        $globalOwners = $user->globalShareOwners()->pluck('users.id')->all();

        // I prezzi che ha segnalato restano utili a tutti, ma senza nome né email.
        PriceReport::where('user_id', $user->id)->update(['reporter_name' => null, 'reporter_email' => null, 'user_id' => null]);

        // Nessuna chiave esterna verso users per questi: vanno tolti a mano.
        $user->tokens()->delete();
        $user->notifications()->delete();
        DB::table('sessions')->where('user_id', $user->id)->delete();
        DB::table('password_reset_tokens')->where('email', $user->email)->delete();

        // Il resto va a cascata: login social, dispositivi, condivisioni, conferme di lettura. L'avatar con l'evento.
        $user->delete();

        foreach ($audiences as [$audience, $listId]) {
            Realtime::broadcast(new ListsChanged(array_values(array_diff($audience, [$user->id])), $listId));
        }
        if ($globalOwners) {
            Realtime::broadcast(new ListsChanged(array_map('intval', $globalOwners)));
        }
    }
}
