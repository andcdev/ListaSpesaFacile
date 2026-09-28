<?php

namespace Database\Factories;

use App\Models\ListItem;
use App\Models\ShoppingList;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ListItem>
 */
class ListItemFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'shopping_list_id' => ShoppingList::factory(),
            'name' => fake()->word(),
            'quantity' => null,
            'checked' => false,
            'position' => 0,
        ];
    }
}
