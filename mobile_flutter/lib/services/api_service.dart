import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';

/// ApiService dengan sistem Hybrid (Laravel Backend + Penyimpanan Lokal iPhone + Direct Google Sheets)
/// Sehingga saat aplikasi di-install di iPhone (.ipa), aplikasi tetap bisa digunakan 100%
/// meskipun laptop sedang mati atau saat Anda sedang berada di luar rumah!
class ApiService {
  static const String _prefBaseUrlKey = 'laravel_api_base_url';
  static const String _prefLocalCategoriesKey = 'local_categories_v1';
  static const String _prefLocalTransactionsKey = 'local_transactions_v1';
  static const String _prefWebhookUrlKey = 'local_gsheets_webhook_url';
  static const String _prefSpreadsheetIdKey = 'local_gsheets_spreadsheet_id';
  static const String _prefTabNameKey = 'local_gsheets_tab_name';

  // Default langsung mengarah ke IP Laptop Windows Anda
  static String _baseUrl = 'http://192.168.31.156:8000/api';

  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefBaseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = saved.trim().replaceAll(RegExp(r'/$'), '');
    }
    await _ensureLocalSeed(prefs);
  }

  static Future<void> _ensureLocalSeed(SharedPreferences prefs) async {
    if (!prefs.containsKey(_prefLocalCategoriesKey)) {
      final defaultCats = [
        {'id': 1, 'name': 'Gaji Bulanan', 'type': 'income', 'icon': 'wallet', 'color': '#10B981'},
        {'id': 2, 'name': 'Freelance & Proyek', 'type': 'income', 'icon': 'laptop', 'color': '#06B6D4'},
        {'id': 3, 'name': 'Investasi & Dividen', 'type': 'income', 'icon': 'trending_up', 'color': '#8B5CF6'},
        {'id': 4, 'name': 'Bonus / Hadiah', 'type': 'income', 'icon': 'gift', 'color': '#F59E0B'},
        {'id': 5, 'name': 'Makanan & Minuman', 'type': 'expense', 'icon': 'restaurant', 'color': '#EF4444'},
        {'id': 6, 'name': 'Transportasi & BBM', 'type': 'expense', 'icon': 'car', 'color': '#F97316'},
        {'id': 7, 'name': 'Tagihan & Utilitas', 'type': 'expense', 'icon': 'bolt', 'color': '#EAB308'},
        {'id': 8, 'name': 'Belanja Bulanan', 'type': 'expense', 'icon': 'shopping_bag', 'color': '#EC4899'},
        {'id': 9, 'name': 'Hiburan & Langganan', 'type': 'expense', 'icon': 'movie', 'color': '#6366F1'},
        {'id': 10, 'name': 'Kesehatan', 'type': 'expense', 'icon': 'medical', 'color': '#14B9A6'},
      ];
      await prefs.setString(_prefLocalCategoriesKey, jsonEncode(defaultCats));
    }

    if (!prefs.containsKey(_prefLocalTransactionsKey)) {
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final defaultTrx = [
        {
          'id': 1,
          'category_id': 1,
          'type': 'income',
          'amount': 12500000.0,
          'transaction_date': '$ym-01',
          'description': 'Gaji Bulanan Kantor',
          'is_synced_to_sheet': false,
        },
        {
          'id': 2,
          'category_id': 8,
          'type': 'expense',
          'amount': 1450000.0,
          'transaction_date': '$ym-05',
          'description': 'Belanja Bulanan Supermarket',
          'is_synced_to_sheet': false,
        },
        {
          'id': 3,
          'category_id': 5,
          'type': 'expense',
          'amount': 320000.0,
          'transaction_date': '$ym-08',
          'description': 'Makan Siang & Kopi',
          'is_synced_to_sheet': false,
        },
      ];
      await prefs.setString(_prefLocalTransactionsKey, jsonEncode(defaultTrx));
    }
  }

  static Future<void> setBaseUrl(String url) async {
    String clean = url.trim().replaceAll(RegExp(r'/$'), '');
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrlKey, _baseUrl);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<List<CategoryModel>> _getLocalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureLocalSeed(prefs);
    final raw = prefs.getString(_prefLocalCategoriesKey) ?? '[]';
    final List list = jsonDecode(raw);
    return list
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<TransactionModel>> _getLocalTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final catMap = {for (final c in cats) c.id: c};

    final raw = prefs.getString(_prefLocalTransactionsKey) ?? '[]';
    final List list = jsonDecode(raw);
    final result = <TransactionModel>[];

    for (final item in list) {
      final map = Map<String, dynamic>.from(item);
      final cid = map['category_id'] != null ? (map['category_id'] as num).toInt() : null;
      if (cid != null && catMap.containsKey(cid)) {
        map['category'] = catMap[cid]!.toJson();
      }
      result.add(TransactionModel.fromJson(map));
    }

    result.sort((a, b) {
      final cmp = b.transactionDate.compareTo(a.transactionDate);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
    return result;
  }

  static Future<DashboardData> fetchDashboard({int? month, int? year}) async {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;

    try {
      final uri = Uri.parse('$_baseUrl/dashboard?month=$m&year=$y');
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 3),
          );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return DashboardData.fromJson(Map<String, dynamic>.from(body['data']));
      }
    } catch (_) {
      // Jika laptop mati / di luar jaringan Wi-Fi, gunakan database lokal di iPhone
    }

    return _buildLocalDashboard(m, y);
  }

  static Future<DashboardData> _buildLocalDashboard(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final allTrx = await _getLocalTransactions();
    final ymPrefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

    double totalIncomeAll = 0;
    double totalExpenseAll = 0;
    for (final t in allTrx) {
      if (t.type == 'income') {
        totalIncomeAll += t.amount;
      } else {
        totalExpenseAll += t.amount;
      }
    }

    final monthTrx = allTrx.where((t) => t.transactionDate.startsWith(ymPrefix)).toList();
    double monthlyIncome = 0;
    double monthlyExpense = 0;
    final Map<int, CategoryBreakdown> catGroups = {};

    for (final t in monthTrx) {
      if (t.type == 'income') {
        monthlyIncome += t.amount;
      } else {
        monthlyExpense += t.amount;
        final cid = t.categoryId ?? 0;
        final existing = catGroups[cid];
        final newAmount = (existing?.amount ?? 0) + t.amount;
        catGroups[cid] = CategoryBreakdown(
          categoryId: t.categoryId,
          categoryName: t.category?.name ?? 'Lainnya',
          color: t.category?.color ?? '#64748B',
          icon: t.category?.icon ?? 'category',
          amount: newAmount,
          percentage: 0,
        );
      }
    }

    final breakdown = catGroups.values.map((cb) {
      return CategoryBreakdown(
        categoryId: cb.categoryId,
        categoryName: cb.categoryName,
        color: cb.color,
        icon: cb.icon,
        amount: cb.amount,
        percentage: monthlyExpense > 0
            ? double.parse(((cb.amount / monthlyExpense) * 100).toStringAsFixed(1))
            : 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final chart = <MonthlyChartPoint>[];
    for (int i = 5; i >= 0; i--) {
      final dt = DateTime(year, month - i, 1);
      final prefix = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
      double inc = 0;
      double exp = 0;
      for (final t in allTrx) {
        if (t.transactionDate.startsWith(prefix)) {
          if (t.type == 'income') {
            inc += t.amount;
          } else {
            exp += t.amount;
          }
        }
      }
      chart.add(MonthlyChartPoint(
        label: shortMonths[dt.month - 1],
        month: dt.month,
        year: dt.year,
        income: inc,
        expense: exp,
      ));
    }

    final webhookUrl = prefs.getString(_prefWebhookUrlKey) ?? '';
    final unsyncedCount = allTrx.where((t) => !t.isSyncedToSheet).length;

    return DashboardData(
      month: month,
      year: year,
      totalBalance: totalIncomeAll - totalExpenseAll,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      categoryBreakdown: breakdown,
      monthlyChart: chart,
      recentTransactions: monthTrx.take(10).toList(),
      googleSheets: GoogleSheetsStatus(
        configured: webhookUrl.isNotEmpty,
        mode: webhookUrl.isNotEmpty ? 'apps_script_webhook' : 'not_configured',
        unsyncedCount: unsyncedCount,
      ),
    );
  }

  static Future<List<CategoryModel>> fetchCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/categories');
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 3),
          );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLocalCategoriesKey, jsonEncode(body['data']));
        return (body['data'] as List)
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    return _getLocalCategories();
  }

  static Future<CategoryModel> createCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/categories');
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'type': type,
              'icon': icon,
              'color': color,
            }),
          )
          .timeout(const Duration(seconds: 3));

      final body = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return CategoryModel.fromJson(Map<String, dynamic>.from(body['data']));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final newId = cats.isEmpty ? 1 : (cats.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1);
    final newCat = CategoryModel(id: newId, name: name, type: type, icon: icon, color: color);
    cats.add(newCat);
    await prefs.setString(
      _prefLocalCategoriesKey,
      jsonEncode(cats.map((c) => c.toJson()).toList()),
    );
    return newCat;
  }

  static Future<void> deleteCategory(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/categories/$id');
      await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 3));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    cats.removeWhere((c) => c.id == id);
    await prefs.setString(
      _prefLocalCategoriesKey,
      jsonEncode(cats.map((c) => c.toJson()).toList()),
    );
  }

  static Future<List<TransactionModel>> fetchTransactions({
    int? month,
    int? year,
    String? type,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      if (type != null && type.isNotEmpty) params['type'] = type;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$_baseUrl/transactions').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 3),
          );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (body['data'] as List)
            .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    var list = await _getLocalTransactions();
    if (month != null && year != null) {
      final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      list = list.where((t) => t.transactionDate.startsWith(prefix)).toList();
    }
    if (type != null && type.isNotEmpty) {
      list = list.where((t) => t.type == type).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((t) =>
              t.description.toLowerCase().contains(q) ||
              (t.category?.name.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  static Future<Map<String, dynamic>> createTransaction({
    required int? categoryId,
    required String type,
    required double amount,
    required String transactionDate,
    required String description,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/transactions');
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'category_id': categoryId,
              'type': type,
              'amount': amount,
              'transaction_date': transactionDate,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 4));

      final body = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return Map<String, dynamic>.from(body);
      }
    } catch (_) {}

    // Simpan ke penyimpanan lokal iPhone + kirim langsung ke Google Sheets jika ada Webhook URL
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;

    final raw = prefs.getString(_prefLocalTransactionsKey) ?? '[]';
    final List list = jsonDecode(raw);
    int maxId = 0;
    for (final item in list) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) maxId = id;
    }
    final newId = maxId + 1;

    bool synced = false;
    final webhookUrl = prefs.getString(_prefWebhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      synced = await _pushDirectToWebhook(webhookUrl, {
        'action': 'upsert',
        'transaction': {
          'id': newId,
          'transaction_date': transactionDate,
          'type': type,
          'category_name': cat?.name ?? 'Lainnya',
          'amount': amount,
          'description': description,
          'updated_at': DateTime.now().toIso8601String(),
        }
      });
    }

    final newTrx = {
      'id': newId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'transaction_date': transactionDate,
      'description': description,
      'is_synced_to_sheet': synced,
    };
    list.add(newTrx);
    await prefs.setString(_prefLocalTransactionsKey, jsonEncode(list));

    return {
      'success': true,
      'data': newTrx,
      'sheet_sync': {'success': synced},
    };
  }

  static Future<Map<String, dynamic>> updateTransaction({
    required int id,
    required int? categoryId,
    required String type,
    required double amount,
    required String transactionDate,
    required String description,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/transactions/$id');
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: jsonEncode({
              'category_id': categoryId,
              'type': type,
              'amount': amount,
              'transaction_date': transactionDate,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 4));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body);
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;

    final raw = prefs.getString(_prefLocalTransactionsKey) ?? '[]';
    final List list = jsonDecode(raw);

    bool synced = false;
    final webhookUrl = prefs.getString(_prefWebhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      synced = await _pushDirectToWebhook(webhookUrl, {
        'action': 'upsert',
        'transaction': {
          'id': id,
          'transaction_date': transactionDate,
          'type': type,
          'category_name': cat?.name ?? 'Lainnya',
          'amount': amount,
          'description': description,
          'updated_at': DateTime.now().toIso8601String(),
        }
      });
    }

    for (int i = 0; i < list.length; i++) {
      if ((list[i]['id'] as num).toInt() == id) {
        list[i] = {
          'id': id,
          'category_id': categoryId,
          'type': type,
          'amount': amount,
          'transaction_date': transactionDate,
          'description': description,
          'is_synced_to_sheet': synced,
        };
        break;
      }
    }
    await prefs.setString(_prefLocalTransactionsKey, jsonEncode(list));

    return {
      'success': true,
      'sheet_sync': {'success': synced},
    };
  }

  static Future<void> deleteTransaction(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/transactions/$id');
      await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 3));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefLocalTransactionsKey) ?? '[]';
    final List list = jsonDecode(raw);
    list.removeWhere((item) => (item['id'] as num).toInt() == id);
    await prefs.setString(_prefLocalTransactionsKey, jsonEncode(list));

    final webhookUrl = prefs.getString(_prefWebhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      await _pushDirectToWebhook(webhookUrl, {'action': 'delete', 'id': id});
    }
  }

  static Future<Map<String, dynamic>> syncToGoogleSheets() async {
    try {
      final uri = Uri.parse('$_baseUrl/sync-sheets');
      final response = await http.post(uri, headers: _headers).timeout(
            const Duration(seconds: 8),
          );
      final body = jsonDecode(response.body);
      return Map<String, dynamic>.from(body);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final webhookUrl = prefs.getString(_prefWebhookUrlKey) ?? '';
    if (webhookUrl.isEmpty) {
      return {
        'success': false,
        'message': 'Masukkan Google Apps Script Web App URL di menu Sheets terlebih dahulu.',
      };
    }

    final allTrx = await _getLocalTransactions();
    final payload = allTrx
        .map((t) => {
              'id': t.id,
              'transaction_date': t.transactionDate,
              'type': t.type,
              'category_name': t.category?.name ?? 'Lainnya',
              'amount': t.amount,
              'description': t.description,
              'updated_at': DateTime.now().toIso8601String(),
            })
        .toList();

    final ok = await _pushDirectToWebhook(webhookUrl, {
      'action': 'sync_all',
      'transactions': payload,
    });

    if (ok) {
      final raw = prefs.getString(_prefLocalTransactionsKey) ?? '[]';
      final List list = jsonDecode(raw);
      for (final item in list) {
        item['is_synced_to_sheet'] = true;
      }
      await prefs.setString(_prefLocalTransactionsKey, jsonEncode(list));
      return {
        'success': true,
        'message': 'Berhasil menyinkronkan ${payload.length} transaksi langsung dari iPhone ke Google Sheets!',
      };
    }

    return {
      'success': false,
      'message': 'Gagal menghubungi URL Google Apps Script. Pastikan koneksi internet aktif.',
    };
  }

  static Future<bool> _pushDirectToWebhook(String url, Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> fetchSettings() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final uri = Uri.parse('$_baseUrl/settings');
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 3));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = Map<String, dynamic>.from(body['data']);
        return {
          'google_sheets_webhook_url': (data['google_sheets_webhook_url'] ?? '').toString(),
          'google_sheets_spreadsheet_id': (data['google_sheets_spreadsheet_id'] ?? '').toString(),
          'google_sheets_tab_name': (data['google_sheets_tab_name'] ?? 'Transaksi').toString(),
        };
      }
    } catch (_) {}

    return {
      'google_sheets_webhook_url': prefs.getString(_prefWebhookUrlKey) ?? '',
      'google_sheets_spreadsheet_id': prefs.getString(_prefSpreadsheetIdKey) ?? '',
      'google_sheets_tab_name': prefs.getString(_prefTabNameKey) ?? 'Transaksi',
    };
  }

  static Future<void> saveSettings({
    required String webhookUrl,
    required String spreadsheetId,
    required String tabName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefWebhookUrlKey, webhookUrl);
    await prefs.setString(_prefSpreadsheetIdKey, spreadsheetId);
    await prefs.setString(_prefTabNameKey, tabName);

    try {
      final uri = Uri.parse('$_baseUrl/settings');
      await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'google_sheets_webhook_url': webhookUrl,
              'google_sheets_spreadsheet_id': spreadsheetId,
              'google_sheets_tab_name': tabName,
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
