<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Supermarket;
use Illuminate\Http\JsonResponse;

class SupermarketController extends Controller
{
    /**
     * Catene note, per suggerire il supermercato mentre si scrive.
     */
    public function index(): JsonResponse
    {
        return response()->json(['data' => Supermarket::orderBy('name')->get(['id', 'name', 'description'])]);
    }
}
