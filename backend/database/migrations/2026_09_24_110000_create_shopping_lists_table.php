<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('shopping_lists', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_id')->constrained('users')->cascadeOnDelete();
            $table->string('name');
            $table->text('notes')->nullable();
            $table->dateTime('scheduled_at')->index();
            $table->timestamps();
        });

        Schema::create('list_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('quantity', 50)->nullable();
            $table->boolean('checked')->default(false);
            $table->unsignedInteger('position')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('checked_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        // Condivisione di una singola lista con un utente.
        Schema::create('shopping_list_user', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shopping_list_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('can_edit')->default(true);
            $table->timestamps();
            $table->unique(['shopping_list_id', 'user_id']);
        });

        // Condivisione globale: tutte le liste (presenti e future) di owner_id sono visibili a user_id.
        Schema::create('global_shares', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('can_edit')->default(true);
            $table->timestamps();
            $table->unique(['owner_id', 'user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('global_shares');
        Schema::dropIfExists('shopping_list_user');
        Schema::dropIfExists('list_items');
        Schema::dropIfExists('shopping_lists');
    }
};
