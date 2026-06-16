<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\TaskController;
use Illuminate\Support\Facades\Route;

// Health endpoints (no auth required)
Route::prefix('health')->group(function () {
    Route::get('/',        [HealthController::class, 'index'])->name('health.index');
    Route::get('/detailed', [HealthController::class, 'detailed'])->name('health.detailed');
});

// Task CRUD API
Route::apiResource('tasks', TaskController::class);
