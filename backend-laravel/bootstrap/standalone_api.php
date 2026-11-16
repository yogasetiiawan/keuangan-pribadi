<?php

/**
 * Built-in Zero-Config Runner untuk Backend API Keuangan Pribadi
 * Mengizinkan server API langsung berjalan (`php -S 0.0.0.0:8000 -t public`)
 * menggunakan skema SQLite dan GoogleSheetService yang sama persis dengan Laravel.
 */

require_once dirname(__DIR__) . '/app/Services/GoogleSheetService.php';

use App\Services\GoogleSheetService;

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

// Load .env
$envFile = dirname(__DIR__) . '/.env';
if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$k, $v] = explode('=', $line, 2);
        $k = trim($k);
        $v = trim($v, " \t\n\r\0\x0B\"'");
        $_ENV[$k] = $v;
        putenv("$k=$v");
    }
}

// Setup SQLite Database
$dbDir = dirname(__DIR__) . '/database';
if (!is_dir($dbDir)) {
    mkdir($dbDir, 0777, true);
}
$dbPath = $dbDir . '/database.sqlite';
$pdo = new PDO('sqlite:' . $dbPath);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

// Auto-Migrate
$pdo->exec("
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
    icon TEXT DEFAULT 'category',
    color TEXT DEFAULT '#3B82F6',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NULL,
    type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
    amount REAL NOT NULL,
    transaction_date TEXT NOT NULL,
    description TEXT DEFAULT '',
    is_synced_to_sheet INTEGER DEFAULT 0,
    synced_at TEXT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
");

// Auto-Seed default categories & sample data if empty
$catCount = (int) $pdo->query("SELECT COUNT(*) FROM categories")->fetchColumn();
if ($catCount === 0) {
    $defaultCategories = [
        ['Gaji Bulanan', 'income', 'wallet', '#10B981'],
        ['Freelance & Proyek', 'income', 'laptop', '#06B6D4'],
        ['Investasi & Dividen', 'income', 'trending_up', '#8B5CF6'],
        ['Bonus / Hadiah', 'income', 'gift', '#F59E0B'],
        ['Makanan & Minuman', 'expense', 'restaurant', '#EF4444'],
        ['Transportasi & BBM', 'expense', 'car', '#F97316'],
        ['Tagihan & Utilitas', 'expense', 'bolt', '#EAB308'],
        ['Belanja Bulanan', 'expense', 'shopping_bag', '#EC4899'],
        ['Hiburan & Langganan', 'expense', 'movie', '#6366F1'],
        ['Kesehatan', 'expense', 'medical', '#14B8A6'],
    ];
    $stmt = $pdo->prepare("INSERT INTO categories (name, type, icon, color) VALUES (?, ?, ?, ?)");
    foreach ($defaultCategories as $c) {
        $stmt->execute($c);
    }

    // Seed initial realistic transactions for current month
    $ym = date('Y-m');
    $sampleTrx = [
        [1, 'income', 12500000, "$ym-01", 'Gaji Bulanan Kantor'],
        [2, 'income', 3200000, "$ym-05", 'Proyek Desain UI/UX'],
        [7, 'expense', 850000, "$ym-03", 'Tagihan Listrik & Internet Wi-Fi'],
        [8, 'expense', 1450000, "$ym-06", 'Belanja Bulanan Supermarket'],
        [5, 'expense', 320000, "$ym-08", 'Makan Siang & Kopi Mingguan'],
        [6, 'expense', 250000, "$ym-10", 'Isi BBM & Parkir'],
        [9, 'expense', 186000, "$ym-12", 'Langganan Apple One & Spotify'],
    ];
    $stmtTrx = $pdo->prepare("INSERT INTO transactions (category_id, type, amount, transaction_date, description) VALUES (?, ?, ?, ?, ?)");
    foreach ($sampleTrx as $t) {
        $stmtTrx->execute($t);
    }
}

function getSetting(PDO $pdo, string $key, string $default = ''): string
{
    $stmt = $pdo->prepare("SELECT value FROM settings WHERE key = ?");
    $stmt->execute([$key]);
    $val = $stmt->fetchColumn();
    if ($val !== false && $val !== null && $val !== '') {
        return (string) $val;
    }
    $envKey = strtoupper($key);
    return (string) ($_ENV[$envKey] ?? getenv($envKey) ?: $default);
}

function makeSheetService(PDO $pdo): GoogleSheetService
{
    return new GoogleSheetService([
        'webhook_url' => getSetting($pdo, 'google_sheets_webhook_url'),
        'spreadsheet_id' => getSetting($pdo, 'google_sheets_spreadsheet_id'),
        'tab_name' => getSetting($pdo, 'google_sheets_tab_name', 'Transaksi'),
    ]);
}

function fetchTransactionWithCategory(PDO $pdo, int $id): ?array
{
    $stmt = $pdo->prepare("
        SELECT t.*, c.name as c_name, c.icon as c_icon, c.color as c_color, c.type as c_type
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.id = ?
    ");
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) return null;
    return formatTransactionRow($row);
}

function formatTransactionRow(array $row): array
{
    return [
        'id' => (int) $row['id'],
        'category_id' => $row['category_id'] ? (int) $row['category_id'] : null,
        'type' => $row['type'],
        'amount' => (float) $row['amount'],
        'transaction_date' => $row['transaction_date'],
        'description' => $row['description'] ?? '',
        'is_synced_to_sheet' => (bool) $row['is_synced_to_sheet'],
        'synced_at' => $row['synced_at'],
        'created_at' => $row['created_at'],
        'updated_at' => $row['updated_at'],
        'category' => $row['category_id'] ? [
            'id' => (int) $row['category_id'],
            'name' => $row['c_name'] ?? 'Lainnya',
            'icon' => $row['c_icon'] ?? 'category',
            'color' => $row['c_color'] ?? '#64748B',
            'type' => $row['c_type'] ?? $row['type'],
        ] : null,
    ];
}

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];
$body = json_decode(file_get_contents('php://input'), true) ?? $_POST;

// Normalize prefix /api
$path = preg_replace('#^/api#', '', $uri);
if ($path === '') $path = '/';

if ($method === 'GET' && ($uri === '/' || $uri === '/app' || $uri === '/app/')) {
    header('Location: /app/index.html');
    exit;
}

if ($method === 'GET' && $path === '/health') {
    echo json_encode([
        'success' => true,
        'app' => 'Keuangan Pribadi API (Laravel + Google Sheets)',
        'status' => 'online',
    ]);
    exit;
}

if ($method === 'GET' && $path === '/dashboard') {
    $month = isset($_GET['month']) ? (int) $_GET['month'] : (int) date('n');
    $year = isset($_GET['year']) ? (int) $_GET['year'] : (int) date('Y');

    $startDate = sprintf('%04d-%02d-01', $year, $month);
    $endDate = date('Y-m-t', strtotime($startDate));

    $totalIncomeAll = (float) $pdo->query("SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'income'")->fetchColumn();
    $totalExpenseAll = (float) $pdo->query("SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'expense'")->fetchColumn();
    $totalBalance = $totalIncomeAll - $totalExpenseAll;

    $stmt = $pdo->prepare("
        SELECT t.*, c.name as c_name, c.icon as c_icon, c.color as c_color, c.type as c_type
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.transaction_date BETWEEN ? AND ?
        ORDER BY t.transaction_date DESC, t.id DESC
    ");
    $stmt->execute([$startDate, $endDate]);
    $rows = $stmt->fetchAll();

    $monthTransactions = array_map('formatTransactionRow', $rows);

    $monthlyIncome = 0.0;
    $monthlyExpense = 0.0;
    $catGroups = [];

    foreach ($monthTransactions as $t) {
        if ($t['type'] === 'income') {
            $monthlyIncome += $t['amount'];
        } else {
            $monthlyExpense += $t['amount'];
            $cid = $t['category_id'] ?? 0;
            if (!isset($catGroups[$cid])) {
                $catGroups[$cid] = [
                    'category_id' => $t['category_id'],
                    'category_name' => $t['category']['name'] ?? 'Lainnya',
                    'color' => $t['category']['color'] ?? '#64748B',
                    'icon' => $t['category']['icon'] ?? 'category',
                    'amount' => 0.0,
                ];
            }
            $catGroups[$cid]['amount'] += $t['amount'];
        }
    }

    $categoryBreakdown = array_values($catGroups);
    foreach ($categoryBreakdown as &$cb) {
        $cb['percentage'] = $monthlyExpense > 0 ? round(($cb['amount'] / $monthlyExpense) * 100, 1) : 0;
    }
    unset($cb);
    usort($categoryBreakdown, fn($a, $b) => $b['amount'] <=> $a['amount']);

    $monthlyChart = [];
    $stmtSum = $pdo->prepare("SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = ? AND transaction_date BETWEEN ? AND ?");
    for ($i = 5; $i >= 0; $i--) {
        $ts = strtotime("-$i months", strtotime($startDate));
        $mStart = date('Y-m-01', $ts);
        $mEnd = date('Y-m-t', $ts);
        $stmtSum->execute(['income', $mStart, $mEnd]);
        $inc = (float) $stmtSum->fetchColumn();
        $stmtSum->execute(['expense', $mStart, $mEnd]);
        $exp = (float) $stmtSum->fetchColumn();

        $monthlyChart[] = [
            'label' => date('M', $ts),
            'month' => (int) date('n', $ts),
            'year' => (int) date('Y', $ts),
            'income' => $inc,
            'expense' => $exp,
        ];
    }

    $sheetService = makeSheetService($pdo);
    $unsyncedCount = (int) $pdo->query("SELECT COUNT(*) FROM transactions WHERE is_synced_to_sheet = 0")->fetchColumn();

    echo json_encode([
        'success' => true,
        'data' => [
            'month' => $month,
            'year' => $year,
            'total_balance' => $totalBalance,
            'monthly_income' => $monthlyIncome,
            'monthly_expense' => $monthlyExpense,
            'category_breakdown' => $categoryBreakdown,
            'monthly_chart' => $monthlyChart,
            'recent_transactions' => array_slice($monthTransactions, 0, 10),
            'google_sheets' => [
                'configured' => $sheetService->isConfigured(),
                'mode' => $sheetService->getMode(),
                'unsynced_count' => $unsyncedCount,
            ],
        ],
    ]);
    exit;
}

if ($method === 'GET' && $path === '/categories') {
    $rows = $pdo->query("SELECT * FROM categories ORDER BY type ASC, name ASC")->fetchAll();
    foreach ($rows as &$r) {
        $r['id'] = (int) $r['id'];
    }
    echo json_encode(['success' => true, 'data' => $rows]);
    exit;
}

if ($method === 'POST' && $path === '/categories') {
    $name = trim((string) ($body['name'] ?? ''));
    $type = $body['type'] ?? 'expense';
    $icon = $body['icon'] ?? 'category';
    $color = $body['color'] ?? '#3B82F6';

    if ($name === '') {
        http_response_code(422);
        echo json_encode(['success' => false, 'message' => 'Nama kategori wajib diisi']);
        exit;
    }

    $stmt = $pdo->prepare("INSERT INTO categories (name, type, icon, color) VALUES (?, ?, ?, ?)");
    $stmt->execute([$name, $type, $icon, $color]);
    $id = (int) $pdo->lastInsertId();

    $stmt2 = $pdo->prepare("SELECT * FROM categories WHERE id = ?");
    $stmt2->execute([$id]);
    $cat = $stmt2->fetch();
    $cat['id'] = (int) $cat['id'];

    http_response_code(201);
    echo json_encode(['success' => true, 'message' => 'Kategori berhasil ditambahkan', 'data' => $cat]);
    exit;
}

if ($method === 'DELETE' && preg_match('#^/categories/(\d+)$#', $path, $m)) {
    $stmt = $pdo->prepare("DELETE FROM categories WHERE id = ?");
    $stmt->execute([(int) $m[1]]);
    echo json_encode(['success' => true, 'message' => 'Kategori berhasil dihapus']);
    exit;
}

if ($method === 'GET' && $path === '/transactions') {
    $where = ['1=1'];
    $params = [];

    if (!empty($_GET['month']) && !empty($_GET['year'])) {
        $start = sprintf('%04d-%02d-01', (int) $_GET['year'], (int) $_GET['month']);
        $end = date('Y-m-t', strtotime($start));
        $where[] = 't.transaction_date BETWEEN ? AND ?';
        $params[] = $start;
        $params[] = $end;
    }

    if (!empty($_GET['type']) && in_array($_GET['type'], ['income', 'expense'])) {
        $where[] = 't.type = ?';
        $params[] = $_GET['type'];
    }

    if (!empty($_GET['search'])) {
        $where[] = '(t.description LIKE ? OR c.name LIKE ?)';
        $params[] = '%' . $_GET['search'] . '%';
        $params[] = '%' . $_GET['search'] . '%';
    }

    $sql = "
        SELECT t.*, c.name as c_name, c.icon as c_icon, c.color as c_color, c.type as c_type
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE " . implode(' AND ', $where) . "
        ORDER BY t.transaction_date DESC, t.id DESC
    ";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = array_map('formatTransactionRow', $stmt->fetchAll());

    echo json_encode(['success' => true, 'data' => $rows]);
    exit;
}

if ($method === 'POST' && $path === '/transactions') {
    $catId = !empty($body['category_id']) ? (int) $body['category_id'] : null;
    $type = $body['type'] ?? 'expense';
    $amount = (float) ($body['amount'] ?? 0);
    $date = $body['transaction_date'] ?? date('Y-m-d');
    $desc = trim((string) ($body['description'] ?? ''));

    if ($amount <= 0) {
        http_response_code(422);
        echo json_encode(['success' => false, 'message' => 'Nominal harus lebih dari 0']);
        exit;
    }

    $stmt = $pdo->prepare("
        INSERT INTO transactions (category_id, type, amount, transaction_date, description, is_synced_to_sheet)
        VALUES (?, ?, ?, ?, ?, 0)
    ");
    $stmt->execute([$catId, $type, $amount, $date, $desc]);
    $id = (int) $pdo->lastInsertId();

    $trx = fetchTransactionWithCategory($pdo, $id);
    $sheetService = makeSheetService($pdo);
    $sheetSync = ['success' => false, 'message' => 'Google Sheets belum dikonfigurasi'];

    if ($sheetService->isConfigured() && $trx) {
        $sheetSync = $sheetService->upsertTransaction([
            'id' => $trx['id'],
            'transaction_date' => $trx['transaction_date'],
            'type' => $trx['type'],
            'category_name' => $trx['category']['name'] ?? 'Lainnya',
            'amount' => $trx['amount'],
            'description' => $trx['description'],
            'updated_at' => $trx['updated_at'],
        ]);

        if (!empty($sheetSync['success'])) {
            $now = date('Y-m-d H:i:s');
            $pdo->prepare("UPDATE transactions SET is_synced_to_sheet = 1, synced_at = ? WHERE id = ?")->execute([$now, $id]);
            $trx = fetchTransactionWithCategory($pdo, $id);
        }
    }

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Transaksi berhasil disimpan',
        'data' => $trx,
        'sheet_sync' => $sheetSync,
    ]);
    exit;
}

if ($method === 'PUT' && preg_match('#^/transactions/(\d+)$#', $path, $m)) {
    $id = (int) $m[1];
    $catId = !empty($body['category_id']) ? (int) $body['category_id'] : null;
    $type = $body['type'] ?? 'expense';
    $amount = (float) ($body['amount'] ?? 0);
    $date = $body['transaction_date'] ?? date('Y-m-d');
    $desc = trim((string) ($body['description'] ?? ''));
    $now = date('Y-m-d H:i:s');

    $stmt = $pdo->prepare("
        UPDATE transactions
        SET category_id = ?, type = ?, amount = ?, transaction_date = ?, description = ?, updated_at = ?
        WHERE id = ?
    ");
    $stmt->execute([$catId, $type, $amount, $date, $desc, $now, $id]);

    $trx = fetchTransactionWithCategory($pdo, $id);
    $sheetService = makeSheetService($pdo);
    $sheetSync = ['success' => false];

    if ($sheetService->isConfigured() && $trx) {
        $sheetSync = $sheetService->upsertTransaction([
            'id' => $trx['id'],
            'transaction_date' => $trx['transaction_date'],
            'type' => $trx['type'],
            'category_name' => $trx['category']['name'] ?? 'Lainnya',
            'amount' => $trx['amount'],
            'description' => $trx['description'],
            'updated_at' => $trx['updated_at'],
        ]);
        if (!empty($sheetSync['success'])) {
            $pdo->prepare("UPDATE transactions SET is_synced_to_sheet = 1, synced_at = ? WHERE id = ?")->execute([$now, $id]);
            $trx = fetchTransactionWithCategory($pdo, $id);
        }
    }

    echo json_encode([
        'success' => true,
        'message' => 'Transaksi berhasil diperbarui',
        'data' => $trx,
        'sheet_sync' => $sheetSync,
    ]);
    exit;
}

if ($method === 'DELETE' && preg_match('#^/transactions/(\d+)$#', $path, $m)) {
    $id = (int) $m[1];
    $pdo->prepare("DELETE FROM transactions WHERE id = ?")->execute([$id]);

    $sheetService = makeSheetService($pdo);
    if ($sheetService->isConfigured()) {
        $sheetService->deleteTransaction($id);
    }

    echo json_encode(['success' => true, 'message' => 'Transaksi berhasil dihapus']);
    exit;
}

if ($method === 'POST' && $path === '/sync-sheets') {
    $sheetService = makeSheetService($pdo);
    if (!$sheetService->isConfigured()) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Google Sheets belum dikonfigurasi. Masukkan URL Web App Google Apps Script di menu Pengaturan.',
        ]);
        exit;
    }

    $rows = $pdo->query("
        SELECT t.*, c.name as c_name
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        ORDER BY t.transaction_date ASC, t.id ASC
    ")->fetchAll();

    $payload = array_map(fn($r) => [
        'id' => (int) $r['id'],
        'transaction_date' => $r['transaction_date'],
        'type' => $r['type'],
        'category_name' => $r['c_name'] ?? 'Lainnya',
        'amount' => (float) $r['amount'],
        'description' => $r['description'] ?? '',
        'updated_at' => $r['updated_at'],
    ], $rows);

    $result = $sheetService->syncAllTransactions($payload);
    if (!empty($result['success'])) {
        $now = date('Y-m-d H:i:s');
        $pdo->prepare("UPDATE transactions SET is_synced_to_sheet = 1, synced_at = ?")->execute([$now]);
    } else {
        http_response_code(400);
    }

    echo json_encode($result);
    exit;
}

if ($method === 'GET' && $path === '/settings') {
    echo json_encode([
        'success' => true,
        'data' => [
            'google_sheets_webhook_url' => getSetting($pdo, 'google_sheets_webhook_url'),
            'google_sheets_spreadsheet_id' => getSetting($pdo, 'google_sheets_spreadsheet_id'),
            'google_sheets_tab_name' => getSetting($pdo, 'google_sheets_tab_name', 'Transaksi'),
        ],
    ]);
    exit;
}

if ($method === 'POST' && $path === '/settings') {
    $keys = ['google_sheets_webhook_url', 'google_sheets_spreadsheet_id', 'google_sheets_tab_name'];
    $stmt = $pdo->prepare("
        INSERT INTO settings (key, value, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP
    ");
    foreach ($keys as $k) {
        if (array_key_exists($k, $body)) {
            $stmt->execute([$k, trim((string) $body[$k])]);
        }
    }
    echo json_encode([
        'success' => true,
        'message' => 'Pengaturan Google Sheets berhasil disimpan',
    ]);
    exit;
}

http_response_code(404);
echo json_encode(['success' => false, 'message' => 'Endpoint tidak ditemukan: ' . $path]);
