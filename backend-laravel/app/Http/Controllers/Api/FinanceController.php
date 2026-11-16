<?php

namespace App\Http\Controllers\Api;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\Setting;
use App\Services\GoogleSheetService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class FinanceController extends Controller
{
    protected function makeSheetService(): GoogleSheetService
    {
        $webhookUrl = Setting::find('google_sheets_webhook_url')?->value ?? env('GOOGLE_SHEETS_WEBHOOK_URL', '');
        $spreadsheetId = Setting::find('google_sheets_spreadsheet_id')?->value ?? env('GOOGLE_SHEETS_SPREADSHEET_ID', '');
        $tabName = Setting::find('google_sheets_tab_name')?->value ?? env('GOOGLE_SHEETS_TAB_NAME', 'Transaksi');

        return new GoogleSheetService([
            'webhook_url' => $webhookUrl,
            'spreadsheet_id' => $spreadsheetId,
            'tab_name' => $tabName,
        ]);
    }

    public function dashboard(Request $request)
    {
        $month = (int) $request->query('month', date('n'));
        $year = (int) $request->query('year', date('Y'));

        $startDate = sprintf('%04d-%02d-01', $year, $month);
        $endDate = date('Y-m-t', strtotime($startDate));

        $totalIncomeAll = (float) Transaction::where('type', 'income')->sum('amount');
        $totalExpenseAll = (float) Transaction::where('type', 'expense')->sum('amount');
        $totalBalance = $totalIncomeAll - $totalExpenseAll;

        $monthTransactions = Transaction::with('category')
            ->whereBetween('transaction_date', [$startDate, $endDate])
            ->orderBy('transaction_date', 'desc')
            ->orderBy('id', 'desc')
            ->get();

        $monthlyIncome = (float) $monthTransactions->where('type', 'income')->sum('amount');
        $monthlyExpense = (float) $monthTransactions->where('type', 'expense')->sum('amount');

        $categoryBreakdown = [];
        foreach ($monthTransactions->where('type', 'expense')->groupBy('category_id') as $catId => $items) {
            $first = $items->first();
            $sum = (float) $items->sum('amount');
            $categoryBreakdown[] = [
                'category_id' => $catId,
                'category_name' => $first->category?->name ?? 'Lainnya',
                'color' => $first->category?->color ?? '#64748B',
                'icon' => $first->category?->icon ?? 'category',
                'amount' => $sum,
                'percentage' => $monthlyExpense > 0 ? round(($sum / $monthlyExpense) * 100, 1) : 0,
            ];
        }
        usort($categoryBreakdown, fn($a, $b) => $b['amount'] <=> $a['amount']);

        // Grafik perbandingan 6 bulan terakhir
        $monthlyChart = [];
        for ($i = 5; $i >= 0; $i--) {
            $ts = strtotime("-$i months", strtotime($startDate));
            $mStart = date('Y-m-01', $ts);
            $mEnd = date('Y-m-t', $ts);
            $inc = (float) Transaction::where('type', 'income')->whereBetween('transaction_date', [$mStart, $mEnd])->sum('amount');
            $exp = (float) Transaction::where('type', 'expense')->whereBetween('transaction_date', [$mStart, $mEnd])->sum('amount');
            $monthlyChart[] = [
                'label' => date('M', $ts),
                'month' => (int) date('n', $ts),
                'year' => (int) date('Y', $ts),
                'income' => $inc,
                'expense' => $exp,
            ];
        }

        $sheetService = $this->makeSheetService();
        $unsyncedCount = Transaction::where('is_synced_to_sheet', false)->count();

        return response()->json([
            'success' => true,
            'data' => [
                'month' => $month,
                'year' => $year,
                'total_balance' => $totalBalance,
                'monthly_income' => $monthlyIncome,
                'monthly_expense' => $monthlyExpense,
                'category_breakdown' => $categoryBreakdown,
                'monthly_chart' => $monthlyChart,
                'recent_transactions' => $monthTransactions->take(10)->values(),
                'google_sheets' => [
                    'configured' => $sheetService->isConfigured(),
                    'mode' => $sheetService->getMode(),
                    'unsynced_count' => $unsyncedCount,
                ],
            ],
        ]);
    }

    public function getCategories()
    {
        return response()->json([
            'success' => true,
            'data' => Category::orderBy('type')->orderBy('name')->get(),
        ]);
    }

    public function storeCategory(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'type' => 'required|in:income,expense',
            'icon' => 'nullable|string|max:50',
            'color' => 'nullable|string|max:20',
        ]);

        $category = Category::create([
            'name' => $validated['name'],
            'type' => $validated['type'],
            'icon' => $validated['icon'] ?? 'category',
            'color' => $validated['color'] ?? '#3B82F6',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kategori berhasil ditambahkan',
            'data' => $category,
        ], 201);
    }

    public function deleteCategory($id)
    {
        $category = Category::findOrFail($id);
        $category->delete();

        return response()->json([
            'success' => true,
            'message' => 'Kategori berhasil dihapus',
        ]);
    }

    public function getTransactions(Request $request)
    {
        $query = Transaction::with('category')
            ->orderBy('transaction_date', 'desc')
            ->orderBy('id', 'desc');

        if ($request->filled('month') && $request->filled('year')) {
            $start = sprintf('%04d-%02d-01', (int) $request->year, (int) $request->month);
            $end = date('Y-m-t', strtotime($start));
            $query->whereBetween('transaction_date', [$start, $end]);
        }

        if ($request->filled('type') && in_array($request->type, ['income', 'expense'])) {
            $query->where('type', $request->type);
        }

        if ($request->filled('search')) {
            $s = $request->search;
            $query->where('description', 'like', "%$s%");
        }

        return response()->json([
            'success' => true,
            'data' => $query->get(),
        ]);
    }

    public function storeTransaction(Request $request)
    {
        $validated = $request->validate([
            'category_id' => 'nullable|integer',
            'type' => 'required|in:income,expense',
            'amount' => 'required|numeric|min:1',
            'transaction_date' => 'required|date',
            'description' => 'nullable|string|max:255',
        ]);

        $transaction = Transaction::create([
            'category_id' => $validated['category_id'] ?? null,
            'type' => $validated['type'],
            'amount' => $validated['amount'],
            'transaction_date' => $validated['transaction_date'],
            'description' => $validated['description'] ?? '',
            'is_synced_to_sheet' => false,
        ]);

        $transaction->load('category');

        $sheetService = $this->makeSheetService();
        $sheetSyncResult = ['success' => false, 'message' => 'Google Sheets belum dikonfigurasi'];

        if ($sheetService->isConfigured()) {
            $sheetSyncResult = $sheetService->upsertTransaction([
                'id' => $transaction->id,
                'transaction_date' => $transaction->transaction_date,
                'type' => $transaction->type,
                'category_name' => $transaction->category?->name ?? 'Lainnya',
                'amount' => $transaction->amount,
                'description' => $transaction->description,
                'updated_at' => (string) $transaction->updated_at,
            ]);

            if (!empty($sheetSyncResult['success'])) {
                $transaction->update([
                    'is_synced_to_sheet' => true,
                    'synced_at' => now(),
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Transaksi berhasil disimpan',
            'data' => $transaction,
            'sheet_sync' => $sheetSyncResult,
        ], 201);
    }

    public function updateTransaction(Request $request, $id)
    {
        $transaction = Transaction::findOrFail($id);

        $validated = $request->validate([
            'category_id' => 'nullable|integer',
            'type' => 'required|in:income,expense',
            'amount' => 'required|numeric|min:1',
            'transaction_date' => 'required|date',
            'description' => 'nullable|string|max:255',
        ]);

        $transaction->update([
            'category_id' => $validated['category_id'] ?? null,
            'type' => $validated['type'],
            'amount' => $validated['amount'],
            'transaction_date' => $validated['transaction_date'],
            'description' => $validated['description'] ?? '',
        ]);

        $transaction->load('category');

        $sheetService = $this->makeSheetService();
        $sheetSyncResult = ['success' => false];

        if ($sheetService->isConfigured()) {
            $sheetSyncResult = $sheetService->upsertTransaction([
                'id' => $transaction->id,
                'transaction_date' => $transaction->transaction_date,
                'type' => $transaction->type,
                'category_name' => $transaction->category?->name ?? 'Lainnya',
                'amount' => $transaction->amount,
                'description' => $transaction->description,
                'updated_at' => (string) $transaction->updated_at,
            ]);

            if (!empty($sheetSyncResult['success'])) {
                $transaction->update([
                    'is_synced_to_sheet' => true,
                    'synced_at' => now(),
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Transaksi berhasil diperbarui',
            'data' => $transaction,
            'sheet_sync' => $sheetSyncResult,
        ]);
    }

    public function deleteTransaction($id)
    {
        $transaction = Transaction::findOrFail($id);
        $transaction->delete();

        $sheetService = $this->makeSheetService();
        if ($sheetService->isConfigured()) {
            $sheetService->deleteTransaction($id);
        }

        return response()->json([
            'success' => true,
            'message' => 'Transaksi berhasil dihapus',
        ]);
    }

    public function syncToGoogleSheets()
    {
        $sheetService = $this->makeSheetService();
        if (!$sheetService->isConfigured()) {
            return response()->json([
                'success' => false,
                'message' => 'Google Sheets belum dikonfigurasi. Masukkan URL Web App Google Apps Script di menu Pengaturan.',
            ], 400);
        }

        $transactions = Transaction::with('category')
            ->orderBy('transaction_date', 'asc')
            ->orderBy('id', 'asc')
            ->get();

        $payload = $transactions->map(fn($t) => [
            'id' => $t->id,
            'transaction_date' => $t->transaction_date,
            'type' => $t->type,
            'category_name' => $t->category?->name ?? 'Lainnya',
            'amount' => (float) $t->amount,
            'description' => $t->description,
            'updated_at' => (string) $t->updated_at,
        ])->toArray();

        $result = $sheetService->syncAllTransactions($payload);

        if (!empty($result['success'])) {
            Transaction::query()->update([
                'is_synced_to_sheet' => true,
                'synced_at' => now(),
            ]);
        }

        return response()->json($result, !empty($result['success']) ? 200 : 400);
    }

    public function getSettings()
    {
        $webhookUrl = Setting::find('google_sheets_webhook_url')?->value ?? env('GOOGLE_SHEETS_WEBHOOK_URL', '');
        $spreadsheetId = Setting::find('google_sheets_spreadsheet_id')?->value ?? env('GOOGLE_SHEETS_SPREADSHEET_ID', '');
        $tabName = Setting::find('google_sheets_tab_name')?->value ?? env('GOOGLE_SHEETS_TAB_NAME', 'Transaksi');

        return response()->json([
            'success' => true,
            'data' => [
                'google_sheets_webhook_url' => $webhookUrl,
                'google_sheets_spreadsheet_id' => $spreadsheetId,
                'google_sheets_tab_name' => $tabName,
            ],
        ]);
    }

    public function saveSettings(Request $request)
    {
        $keys = [
            'google_sheets_webhook_url',
            'google_sheets_spreadsheet_id',
            'google_sheets_tab_name',
        ];

        foreach ($keys as $key) {
            if ($request->has($key)) {
                Setting::updateOrCreate(
                    ['key' => $key],
                    ['value' => (string) $request->input($key, '')]
                );
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Pengaturan Google Sheets berhasil disimpan',
        ]);
    }
}
