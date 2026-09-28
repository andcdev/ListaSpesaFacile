<?php

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

// Canale personale: notifiche sull'elenco delle proprie liste.
Broadcast::channel('App.Models.User.{id}', function (User $user, $id) {
    return (int) $user->id === (int) $id;
});

// Canale di presenza per lista: aggiornamenti degli articoli e utenti che la stanno guardando.
Broadcast::channel('list.{list}', function (User $user, ShoppingList $list) {
    if ($list->permissionFor($user) === null) {
        return false;
    }

    return ['id' => $user->id, 'name' => $user->name];
});
