<?php

namespace App\Policies;

use App\Models\ShoppingList;
use App\Models\User;

class ShoppingListPolicy
{
    public function view(User $user, ShoppingList $list): bool
    {
        return $list->permissionFor($user) !== null;
    }

    /**
     * Modifica dei dati della lista e dei suoi articoli.
     */
    public function update(User $user, ShoppingList $list): bool
    {
        return in_array($list->permissionFor($user), [
            ShoppingList::PERMISSION_OWNER,
            ShoppingList::PERMISSION_EDIT,
        ], true);
    }

    public function delete(User $user, ShoppingList $list): bool
    {
        return $list->owner_id === $user->id;
    }

    public function share(User $user, ShoppingList $list): bool
    {
        return $list->owner_id === $user->id;
    }
}
