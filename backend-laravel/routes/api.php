<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\FinanceController;

Route::get('/dashboard', [FinanceController::class, 'dashboard']);

Route::get('/categories', [FinanceController::class, 'getCategories']);
Route::post('/categories', [FinanceController::class, 'storeCategory']);
Route::delete('/categories/{id}', [FinanceController::class, 'deleteCategory']);

Route::get('/transactions', [FinanceController::class, 'getTransactions']);
Route::post('/transactions', [FinanceController::class, 'storeTransaction']);
Route::put('/transactions/{id}', [FinanceController::class, 'updateTransaction']);
Route::delete('/transactions/{id}', [FinanceController::class, 'deleteTransaction']);

Route::post('/sync-sheets', [FinanceController::class, 'syncToGoogleSheets']);

Route::get('/settings', [FinanceController::class, 'getSettings']);
Route::post('/settings', [FinanceController::class, 'saveSettings']);
