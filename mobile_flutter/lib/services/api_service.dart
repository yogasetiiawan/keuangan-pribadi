import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';

class ApiService {
  static const String _prefAccountsListKey = 'registered_user_accounts_v1';
  static const String _prefActiveUserIdKey = 'active_logged_in_user_id_v1';
  static const String _prefBaseUrlKey = 'laravel_api_base_url';
  static const String _prefDarkModeKey = 'app_dark_mode_v1';
  static const String _prefHideBalanceKey = 'app_hide_balance_v1';
  static const String _prefPinCodeKey = 'app_pin_code_v1';

  static String _baseUrl = 'http://192.168.31.156:8000/api';
  static bool _isDarkMode = false;
  static bool _isBalanceHidden = false;
  static String _pinCode = '';
  static UserAccountModel? _currentUser;

  static String get baseUrl => _baseUrl;
  static bool get isDarkMode => _isDarkMode;
  static bool get isBalanceHidden => _isBalanceHidden;
  static String get pinCode => _pinCode;
  static bool get hasPin => _pinCode.trim().length == 4;
  static UserAccountModel? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;

  // Gunakan key asli untuk user_1 (Yoga Setiawan) agar data sebelumnya di iPhone tetap aman
  static String get _prefix {
    final uid = _currentUser?.id ?? 'user_1';
    return uid == 'user_1' ? '' : '${uid}_';
  }

  static String get _categoriesKey => '${_prefix}local_categories_v1';
  static String get _transactionsKey => '${_prefix}local_transactions_v1';
  static String get _walletsKey => '${_prefix}local_wallets_v1';
  static String get _goalsKey => '${_prefix}local_saving_goals_v1';
  static String get _billsKey => '${_prefix}local_recurring_bills_v1';
  static String get _webhookUrlKey => '${_prefix}local_gsheets_webhook_url';
  static String get _spreadsheetIdKey => '${_prefix}local_gsheets_spreadsheet_id';
  static String get _tabNameKey => '${_prefix}local_gsheets_tab_name';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefBaseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = saved.trim().replaceAll(RegExp(r'/$'), '');
    }
    _isDarkMode = prefs.getBool(_prefDarkModeKey) ?? false;
    _isBalanceHidden = prefs.getBool(_prefHideBalanceKey) ?? false;
    _pinCode = prefs.getString(_prefPinCodeKey) ?? '';

    await _ensureAccountsSeed(prefs);

    final activeId = prefs.getString(_prefActiveUserIdKey);
    if (activeId != null && activeId.isNotEmpty) {
      final accounts = await getAllAccounts();
      _currentUser =
          accounts.where((a) => a.id == activeId).firstOrNull ?? accounts.firstOrNull;
    }

    if (_currentUser != null) {
      await _ensureLocalSeed(prefs);
    }
  }

  static Future<void> _ensureAccountsSeed(SharedPreferences prefs) async {
    if (!prefs.containsKey(_prefAccountsListKey)) {
      final defaultAccounts = [
        {
          'id': 'user_1',
          'name': 'Yoga Setiawan',
          'email': 'yoga@keuanganku.id',
          'password': '123456',
        }
      ];
      await prefs.setString(_prefAccountsListKey, jsonEncode(defaultAccounts));
      // Secara default langsung aktifkan user_1 agar tidak mengganggu pengalaman awal
      await prefs.setString(_prefActiveUserIdKey, 'user_1');
    }
  }

  static Future<List<UserAccountModel>> getAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureAccountsSeed(prefs);
    final raw = prefs.getString(_prefAccountsListKey) ?? '[]';
    final List list = jsonDecode(raw);
    return list
        .map((e) => UserAccountModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<UserAccountModel> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();
    final cleanEmail = email.trim().toLowerCase();

    final match = accounts.where((a) {
      return (a.email.toLowerCase() == cleanEmail ||
              a.name.toLowerCase() == cleanEmail) &&
          a.password == password;
    }).firstOrNull;

    if (match == null) {
      throw Exception('Email/Nama atau Password tidak sesuai');
    }

    _currentUser = match;
    await prefs.setString(_prefActiveUserIdKey, match.id);
    await _ensureLocalSeed(prefs);
    return match;
  }

  static Future<UserAccountModel> register({
    required String name,
    required String email,
    required String password,
    String webhookUrl = '',
    String spreadsheetId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();
    final cleanEmail = email.trim().toLowerCase();

    if (accounts.any((a) => a.email.toLowerCase() == cleanEmail)) {
      throw Exception('Email sudah terdaftar, silakan langsung Masuk (Login)');
    }

    final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = UserAccountModel(
      id: newId,
      name: name.trim(),
      email: cleanEmail,
      password: password,
    );

    accounts.add(newUser);
    await prefs.setString(
      _prefAccountsListKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );

    _currentUser = newUser;
    await prefs.setString(_prefActiveUserIdKey, newUser.id);
    await _ensureLocalSeed(prefs);

    if (webhookUrl.trim().isNotEmpty || spreadsheetId.trim().isNotEmpty) {
      await saveSettings(
        webhookUrl: webhookUrl.trim(),
        spreadsheetId: spreadsheetId.trim(),
        tabName: 'Transaksi',
      );
    }

    return newUser;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = null;
    await prefs.remove(_prefActiveUserIdKey);
  }

  static Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkModeKey, value);
  }

  static Future<void> setBalanceHidden(bool value) async {
    _isBalanceHidden = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHideBalanceKey, value);
  }

  static Future<void> setPinCode(String pin) async {
    _pinCode = pin.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPinCodeKey, _pinCode);
  }

  static Future<void> _ensureLocalSeed(SharedPreferences prefs) async {
    if ((_currentUser?.id ?? 'user_1') == 'user_1' &&
        (prefs.getString(_spreadsheetIdKey) ?? '').isEmpty) {
      await prefs.setString(
        _spreadsheetIdKey,
        '1-k8FqqSIn_ZrOG7Cw5qFaau96o4j8XoKYPcPjaBy7dw',
      );
    }

    if (!prefs.containsKey(_walletsKey)) {
      final defaultWallets = [
        {'id': 1, 'name': 'Tunai', 'icon': 'wallet', 'color': '#10B981', 'initial_balance': 0.0},
        {'id': 2, 'name': 'Rekening Bank', 'icon': 'bank', 'color': '#3B82F6', 'initial_balance': 0.0},
        {'id': 3, 'name': 'E-Wallet', 'icon': 'ewallet', 'color': '#8B5CF6', 'initial_balance': 0.0},
      ];
      await prefs.setString(_walletsKey, jsonEncode(defaultWallets));
    }

    if (!prefs.containsKey(_categoriesKey)) {
      final defaultCats = [
        {'id': 1, 'name': 'Gaji Bulanan', 'type': 'income', 'icon': 'wallet', 'color': '#10B981', 'monthly_budget': 0.0},
        {'id': 2, 'name': 'Freelance & Proyek', 'type': 'income', 'icon': 'laptop', 'color': '#06B6D4', 'monthly_budget': 0.0},
        {'id': 3, 'name': 'Investasi & Dividen', 'type': 'income', 'icon': 'trending_up', 'color': '#8B5CF6', 'monthly_budget': 0.0},
        {'id': 4, 'name': 'Bonus / Hadiah', 'type': 'income', 'icon': 'gift', 'color': '#F59E0B', 'monthly_budget': 0.0},
        {'id': 5, 'name': 'Makanan & Minuman', 'type': 'expense', 'icon': 'restaurant', 'color': '#EF4444', 'monthly_budget': 1000000.0},
        {'id': 6, 'name': 'Transportasi & BBM', 'type': 'expense', 'icon': 'car', 'color': '#F97316', 'monthly_budget': 400000.0},
        {'id': 7, 'name': 'Tagihan & Utilitas', 'type': 'expense', 'icon': 'bolt', 'color': '#EAB308', 'monthly_budget': 500000.0},
        {'id': 8, 'name': 'Belanja Bulanan', 'type': 'expense', 'icon': 'shopping_bag', 'color': '#EC4899', 'monthly_budget': 800000.0},
        {'id': 9, 'name': 'Hiburan & Langganan', 'type': 'expense', 'icon': 'movie', 'color': '#6366F1', 'monthly_budget': 300000.0},
        {'id': 10, 'name': 'Kesehatan', 'type': 'expense', 'icon': 'medical', 'color': '#14B9A6', 'monthly_budget': 300000.0},
      ];
      await prefs.setString(_categoriesKey, jsonEncode(defaultCats));
    }

    if (!prefs.containsKey(_goalsKey)) {
      final defaultGoals = [
        {
          'id': 1,
          'title': 'Dana Darurat',
          'target_amount': 10000000.0,
          'saved_amount': (_currentUser?.id == 'user_1') ? 1500000.0 : 0.0,
          'color': '#10B981',
          'icon': 'savings',
        },
      ];
      await prefs.setString(_goalsKey, jsonEncode(defaultGoals));
    }

    if (!prefs.containsKey(_billsKey)) {
      final defaultBills = [
        {
          'id': 1,
          'title': 'Tagihan Listrik & Wi-Fi',
          'amount': 350000.0,
          'category_id': 7,
          'category_name': 'Tagihan & Utilitas',
          'wallet_name': 'Rekening Bank',
          'day_of_month': 5,
        },
      ];
      await prefs.setString(_billsKey, jsonEncode(defaultBills));
    }

    if (!prefs.containsKey(_transactionsKey)) {
      if ((_currentUser?.id ?? 'user_1') == 'user_1') {
        final now = DateTime.now();
        final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final defaultTrx = [
          {
            'id': 1,
            'category_id': 1,
            'type': 'income',
            'amount': 1500000.0,
            'transaction_date': '$ym-13',
            'description': 'Gaji Pokok Bulanan',
            'wallet_name': 'Rekening Bank',
            'is_synced_to_sheet': true,
          },
          {
            'id': 2,
            'category_id': 5,
            'type': 'expense',
            'amount': 12000.0,
            'transaction_date': '$ym-16',
            'description': 'Makan Pagi',
            'wallet_name': 'Tunai',
            'is_synced_to_sheet': true,
          },
          {
            'id': 3,
            'category_id': 5,
            'type': 'expense',
            'amount': 12000.0,
            'transaction_date': '$ym-16',
            'description': 'Makan Siang',
            'wallet_name': 'Tunai',
            'is_synced_to_sheet': true,
          },
          {
            'id': 4,
            'category_id': 5,
            'type': 'expense',
            'amount': 9000.0,
            'transaction_date': '$ym-16',
            'description': 'Jajan Pentol Goreng',
            'wallet_name': 'Tunai',
            'is_synced_to_sheet': true,
          },
        ];
        await prefs.setString(_transactionsKey, jsonEncode(defaultTrx));
      } else {
        await prefs.setString(_transactionsKey, jsonEncode([]));
      }
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

  static Future<List<WalletModel>> fetchWallets() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureLocalSeed(prefs);
    final raw = prefs.getString(_walletsKey) ?? '[]';
    final List list = jsonDecode(raw);
    final allTrx = await _getLocalTransactions();

    return list.map((e) {
      final map = Map<String, dynamic>.from(e);
      final name = (map['name'] ?? 'Tunai').toString();
      final initBal = (map['initial_balance'] as num?)?.toDouble() ?? 0.0;
      double computed = initBal;
      for (final t in allTrx) {
        if (t.walletName.toLowerCase() == name.toLowerCase()) {
          if (t.type == 'income') {
            computed += t.amount;
          } else {
            computed -= t.amount;
          }
        }
      }
      return WalletModel.fromJson(map, computedBalance: computed);
    }).toList();
  }

  static Future<void> createWallet({
    required String name,
    required String icon,
    required String color,
    double initialBalance = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_walletsKey) ?? '[]';
    final List list = jsonDecode(raw);
    int maxId = 0;
    for (final item in list) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) maxId = id;
    }
    list.add({
      'id': maxId + 1,
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'initial_balance': initialBalance,
    });
    await prefs.setString(_walletsKey, jsonEncode(list));
  }

  static Future<void> transferBetweenWallets({
    required String fromWallet,
    required String toWallet,
    required double amount,
    required String date,
    String note = '',
  }) async {
    if (fromWallet == toWallet || amount <= 0) return;
    final cleanNote = note.trim().isNotEmpty ? ' ($note)' : '';

    await createTransaction(
      categoryId: null,
      type: 'expense',
      amount: amount,
      transactionDate: date,
      description: 'Transfer ke $toWallet$cleanNote',
      walletName: fromWallet,
    );

    await createTransaction(
      categoryId: null,
      type: 'income',
      amount: amount,
      transactionDate: date,
      description: 'Transfer dari $fromWallet$cleanNote',
      walletName: toWallet,
    );
  }

  static Future<List<SavingGoalModel>> fetchSavingGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureLocalSeed(prefs);
    final raw = prefs.getString(_goalsKey) ?? '[]';
    final List list = jsonDecode(raw);
    return list
        .map((e) => SavingGoalModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> createSavingGoal({
    required String title,
    required double targetAmount,
    double savedAmount = 0,
    String color = '#10B981',
    String icon = 'savings',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await fetchSavingGoals();
    final newId = goals.isEmpty
        ? 1
        : (goals.map((g) => g.id).reduce((a, b) => a > b ? a : b) + 1);
    goals.add(SavingGoalModel(
      id: newId,
      title: title,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      color: color,
      icon: icon,
    ));
    await prefs.setString(
      _goalsKey,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }

  static Future<void> addFundsToSavingGoal(int id, double addAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await fetchSavingGoals();
    final updated = goals.map((g) {
      if (g.id == id) {
        return SavingGoalModel(
          id: g.id,
          title: g.title,
          targetAmount: g.targetAmount,
          savedAmount: (g.savedAmount + addAmount).clamp(0, g.targetAmount * 10),
          color: g.color,
          icon: g.icon,
        );
      }
      return g;
    }).toList();
    await prefs.setString(
      _goalsKey,
      jsonEncode(updated.map((g) => g.toJson()).toList()),
    );
  }

  static Future<void> deleteSavingGoal(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await fetchSavingGoals();
    goals.removeWhere((g) => g.id == id);
    await prefs.setString(
      _goalsKey,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }

  static Future<List<RecurringBillModel>> fetchRecurringBills() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureLocalSeed(prefs);
    final raw = prefs.getString(_billsKey) ?? '[]';
    final List list = jsonDecode(raw);
    return list
        .map((e) => RecurringBillModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> createRecurringBill({
    required String title,
    required double amount,
    int? categoryId,
    required String categoryName,
    required String walletName,
    required int dayOfMonth,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bills = await fetchRecurringBills();
    final newId = bills.isEmpty
        ? 1
        : (bills.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1);
    bills.add(RecurringBillModel(
      id: newId,
      title: title,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      walletName: walletName,
      dayOfMonth: dayOfMonth,
    ));
    await prefs.setString(
      _billsKey,
      jsonEncode(bills.map((b) => b.toJson()).toList()),
    );
  }

  static Future<void> deleteRecurringBill(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final bills = await fetchRecurringBills();
    bills.removeWhere((b) => b.id == id);
    await prefs.setString(
      _billsKey,
      jsonEncode(bills.map((b) => b.toJson()).toList()),
    );
  }

  static Future<List<CategoryModel>> _getLocalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureLocalSeed(prefs);
    final raw = prefs.getString(_categoriesKey) ?? '[]';
    final List list = jsonDecode(raw);
    return list
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> updateCategoryBudget(int categoryId, double budget) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final updated = cats.map((c) {
      if (c.id == categoryId) {
        return CategoryModel(
          id: c.id,
          name: c.name,
          type: c.type,
          icon: c.icon,
          color: c.color,
          monthlyBudget: budget,
        );
      }
      return c;
    }).toList();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(updated.map((c) => c.toJson()).toList()),
    );
  }

  static Future<List<TransactionModel>> _getLocalTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final catMap = {for (final c in cats) c.id: c};

    final raw = prefs.getString(_transactionsKey) ?? '[]';
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
    return _buildLocalDashboard(m, y);
  }

  static Future<DashboardData> _buildLocalDashboard(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();
    final allTrx = await _getLocalTransactions();
    final cats = await _getLocalCategories();
    final catMap = {for (final c in cats) c.id: c};
    final wallets = await fetchWallets();
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
        final catObj = cid != 0 ? catMap[cid] : null;
        catGroups[cid] = CategoryBreakdown(
          categoryId: t.categoryId,
          categoryName: t.category?.name ?? catObj?.name ?? 'Lainnya',
          color: t.category?.color ?? catObj?.color ?? '#64748B',
          icon: t.category?.icon ?? catObj?.icon ?? 'category',
          amount: newAmount,
          percentage: 0,
          monthlyBudget: catObj?.monthlyBudget ?? 0,
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
        monthlyBudget: cb.monthlyBudget,
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

    final webhookUrl = prefs.getString(_webhookUrlKey) ?? '';
    final unsyncedCount = allTrx.where((t) => !t.isSyncedToSheet).length;

    return DashboardData(
      month: month,
      year: year,
      totalBalance: totalIncomeAll - totalExpenseAll,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      wallets: wallets,
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
    return _getLocalCategories();
  }

  static Future<CategoryModel> createCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
    double monthlyBudget = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final newId = cats.isEmpty
        ? 1
        : (cats.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1);
    final newCat = CategoryModel(
      id: newId,
      name: name,
      type: type,
      icon: icon,
      color: color,
      monthlyBudget: monthlyBudget,
    );
    cats.add(newCat);
    await prefs.setString(
      _categoriesKey,
      jsonEncode(cats.map((c) => c.toJson()).toList()),
    );
    return newCat;
  }

  static Future<void> deleteCategory(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    cats.removeWhere((c) => c.id == id);
    await prefs.setString(
      _categoriesKey,
      jsonEncode(cats.map((c) => c.toJson()).toList()),
    );
  }

  static Future<List<TransactionModel>> fetchTransactions({
    int? month,
    int? year,
    String? type,
    String? search,
    String? walletName,
  }) async {
    var list = await _getLocalTransactions();
    if (month != null && year != null) {
      final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      list = list.where((t) => t.transactionDate.startsWith(prefix)).toList();
    }
    if (type != null && type.isNotEmpty) {
      list = list.where((t) => t.type == type).toList();
    }
    if (walletName != null && walletName.isNotEmpty && walletName != 'Semua') {
      list = list
          .where((t) => t.walletName.toLowerCase() == walletName.toLowerCase())
          .toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((t) =>
              t.description.toLowerCase().contains(q) ||
              t.walletName.toLowerCase().contains(q) ||
              (t.category?.name.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  static String _buildSheetDescription(String walletName, String description) {
    final cleanDesc = description.trim();
    final cleanWallet = walletName.trim().isEmpty ? 'Tunai' : walletName.trim();
    if (cleanDesc.startsWith('[$cleanWallet]')) return cleanDesc;
    return '[$cleanWallet] ${cleanDesc.isEmpty ? "-" : cleanDesc}';
  }

  static Future<Map<String, dynamic>> createTransaction({
    required int? categoryId,
    required String type,
    required double amount,
    required String transactionDate,
    required String description,
    String walletName = 'Tunai',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;

    final raw = prefs.getString(_transactionsKey) ?? '[]';
    final List list = jsonDecode(raw);
    int maxId = 0;
    for (final item in list) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) maxId = id;
    }
    final newId = maxId + 1;

    bool synced = false;
    final webhookUrl = prefs.getString(_webhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      synced = await _pushDirectToWebhook(webhookUrl, {
        'action': 'upsert',
        'transaction': {
          'id': newId,
          'transaction_date': transactionDate,
          'type': type,
          'category_name': cat?.name ?? 'Lainnya',
          'amount': amount,
          'description': _buildSheetDescription(walletName, description),
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
      'wallet_name': walletName,
      'is_synced_to_sheet': synced,
    };
    list.add(newTrx);
    await prefs.setString(_transactionsKey, jsonEncode(list));

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
    String walletName = 'Tunai',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _getLocalCategories();
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;

    final raw = prefs.getString(_transactionsKey) ?? '[]';
    final List list = jsonDecode(raw);

    bool synced = false;
    final webhookUrl = prefs.getString(_webhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      synced = await _pushDirectToWebhook(webhookUrl, {
        'action': 'upsert',
        'transaction': {
          'id': id,
          'transaction_date': transactionDate,
          'type': type,
          'category_name': cat?.name ?? 'Lainnya',
          'amount': amount,
          'description': _buildSheetDescription(walletName, description),
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
          'wallet_name': walletName,
          'is_synced_to_sheet': synced,
        };
        break;
      }
    }
    await prefs.setString(_transactionsKey, jsonEncode(list));

    return {
      'success': true,
      'sheet_sync': {'success': synced},
    };
  }

  static Future<void> deleteTransaction(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transactionsKey) ?? '[]';
    final List list = jsonDecode(raw);
    list.removeWhere((item) => (item['id'] as num).toInt() == id);
    await prefs.setString(_transactionsKey, jsonEncode(list));

    final webhookUrl = prefs.getString(_webhookUrlKey) ?? '';
    if (webhookUrl.isNotEmpty) {
      await _pushDirectToWebhook(webhookUrl, {'action': 'delete', 'id': id});
    }
  }

  static Future<Map<String, dynamic>> syncToGoogleSheets() async {
    final prefs = await SharedPreferences.getInstance();
    final webhookUrl = prefs.getString(_webhookUrlKey) ?? '';
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
              'description': _buildSheetDescription(t.walletName, t.description),
              'updated_at': DateTime.now().toIso8601String(),
            })
        .toList();

    final ok = await _pushDirectToWebhook(webhookUrl, {
      'action': 'sync_all',
      'transactions': payload,
    });

    if (ok) {
      final raw = prefs.getString(_transactionsKey) ?? '[]';
      final List list = jsonDecode(raw);
      for (final item in list) {
        item['is_synced_to_sheet'] = true;
      }
      await prefs.setString(_transactionsKey, jsonEncode(list));
      return {
        'success': true,
        'message': '✓ Berhasil mengirim ${payload.length} transaksi ke Google Sheets!',
      };
    }

    return {
      'success': false,
      'message': 'Gagal menghubungi URL Google Apps Script. Pastikan koneksi internet aktif.',
    };
  }

  /// FITUR 3: Tarik Data dari Google Sheets (Termasuk data yang diketik langsung di Google Sheets!)
  static Future<Map<String, dynamic>> pullFromGoogleSheets() async {
    final prefs = await SharedPreferences.getInstance();
    final spreadsheetId = (prefs.getString(_spreadsheetIdKey) ??
            '1-k8FqqSIn_ZrOG7Cw5qFaau96o4j8XoKYPcPjaBy7dw')
        .trim();
    final tabName = (prefs.getString(_tabNameKey) ?? 'Transaksi').trim();
    final webhookUrl = (prefs.getString(_webhookUrlKey) ?? '').trim();

    final cats = await _getLocalCategories();
    int? matchCatId(String name, String type) {
      final clean = name.trim().toLowerCase();
      for (final c in cats) {
        if (c.name.toLowerCase() == clean) return c.id;
      }
      for (final c in cats) {
        if (clean.contains(c.name.toLowerCase().split(' ').first)) return c.id;
      }
      return cats.where((c) => c.type == type).firstOrNull?.id;
    }

    // 1. Coba tarik lewat Webhook Apps Script (GET ?action=pull atau POST action=pull)
    if (webhookUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(webhookUrl).replace(queryParameters: {'action': 'pull'});
        final bodyStr = await _fetchFollowingRedirect(uri);
        if (bodyStr != null) {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map && decoded['transactions'] is List) {
            final rows = decoded['transactions'] as List;
            final imported = _convertImportedRows(rows, matchCatId);
            if (imported.isNotEmpty) {
              await prefs.setString(_transactionsKey, jsonEncode(imported));
              return {
                'success': true,
                'message':
                    '✓ Berhasil menarik ${imported.length} transaksi dari Google Sheets ke aplikasi!',
              };
            }
          }
        }
      } catch (_) {}
    }

    // 2. Coba tarik langsung dari Google Sheets CSV Endpoint (Tanpa perlu update Apps Script!)
    if (spreadsheetId.isNotEmpty) {
      try {
        final csvUrl =
            'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&sheet=${Uri.encodeComponent(tabName)}';
        final res = await http.get(Uri.parse(csvUrl)).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 &&
            !res.body.trim().startsWith('<!DOCTYPE') &&
            !res.body.trim().startsWith('<html')) {
          final lines = const LineSplitter().convert(res.body);
          final rawRows = <Map<String, dynamic>>[];
          for (int i = 1; i < lines.length; i++) {
            final cols = _parseCsvLine(lines[i]);
            if (cols.length >= 5) {
              rawRows.add({
                'id': cols[0],
                'transaction_date': cols[1],
                'type': cols[2],
                'category_name': cols[3],
                'amount': cols[4],
                'description': cols.length > 5 ? cols[5] : '',
              });
            }
          }
          final imported = _convertImportedRows(rawRows, matchCatId);
          if (imported.isNotEmpty) {
            await prefs.setString(_transactionsKey, jsonEncode(imported));
            return {
              'success': true,
              'message':
                  '✓ Berhasil menarik ${imported.length} transaksi langsung dari Google Sheets!',
            };
          }
        }
      } catch (_) {}
    }

    return {
      'success': false,
      'message':
          'Agar data yang diketik di Google Sheets bisa ditarik ke HP, klik tombol "Share/Bagikan" di Google Sheets -> ubah General Access ke "Anyone with the link (Viewer)", atau perbarui Code.gs di Apps Script.',
    };
  }

  static List<Map<String, dynamic>> _convertImportedRows(
    List rows,
    int? Function(String, String) matchCatId,
  ) {
    final imported = <Map<String, dynamic>>[];
    int autoId = 1;
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r);
      final rawAmtStr = (m['amount'] ?? '0').toString().replaceAll(RegExp(r'[^0-9]'), '');
      final amt = double.tryParse(rawAmtStr) ?? 0.0;
      if (amt <= 0) continue;

      final typeStr = (m['type'] ?? 'expense').toString().trim().toLowerCase();
      final normType = (typeStr == 'income' ||
              typeStr == 'pemasukan' ||
              typeStr == 'masuk')
          ? 'income'
          : 'expense';

      final catName = (m['category_name'] ?? 'Lainnya').toString().trim();
      final rawDate = (m['transaction_date'] ?? '').toString().trim();
      final isoDate = CurrencyHelper.normalizeIsoDate(rawDate);

      final rawDesc = (m['description'] ?? '').toString().trim();
      String wallet = 'Tunai';
      String cleanDesc = rawDesc;
      if (rawDesc.startsWith('[') && rawDesc.contains(']')) {
        final idx = rawDesc.indexOf(']');
        wallet = rawDesc.substring(1, idx).trim();
        cleanDesc = rawDesc.substring(idx + 1).trim();
      }

      final parsedId =
          int.tryParse((m['id'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
              autoId;
      if (parsedId >= autoId) autoId = parsedId + 1;

      imported.add({
        'id': parsedId,
        'category_id': matchCatId(catName, normType),
        'type': normType,
        'amount': amt,
        'transaction_date': isoDate,
        'description': cleanDesc == '-' ? '' : cleanDesc,
        'wallet_name': wallet,
        'is_synced_to_sheet': true,
      });
    }
    return imported;
  }

  static Future<String?> _fetchFollowingRedirect(Uri uri) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', uri)..followRedirects = false;
      final streamed = await client.send(req).timeout(const Duration(seconds: 12));
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return await streamed.stream.bytesToString();
      }
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final loc = streamed.headers['location'] ?? '';
        if (loc.isNotEmpty && !loc.contains('accounts.google.com')) {
          final res2 = await client.get(Uri.parse(loc)).timeout(const Duration(seconds: 10));
          if (res2.statusCode == 200) return res2.body;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static Future<bool> _pushDirectToWebhook(String url, Map<String, dynamic> payload) async {
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse(url.trim()))
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode(payload);

      final streamedRes = await client.send(req).timeout(const Duration(seconds: 15));
      final status = streamedRes.statusCode;

      if (status >= 200 && status < 300) {
        return true;
      }

      if (status == 302 || status == 301 || status == 307 || status == 308) {
        final location = streamedRes.headers['location'] ?? '';
        if (location.contains('accounts.google.com')) {
          return false;
        }
        if (location.isNotEmpty) {
          final getRes = await client.get(Uri.parse(location)).timeout(const Duration(seconds: 10));
          return getRes.statusCode >= 200 && getRes.statusCode < 400;
        }
        return true;
      }

      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, String>> fetchSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultSheetId = ((_currentUser?.id ?? 'user_1') == 'user_1')
        ? '1-k8FqqSIn_ZrOG7Cw5qFaau96o4j8XoKYPcPjaBy7dw'
        : '';
    return {
      'google_sheets_webhook_url': prefs.getString(_webhookUrlKey) ?? '',
      'google_sheets_spreadsheet_id':
          prefs.getString(_spreadsheetIdKey) ?? defaultSheetId,
      'google_sheets_tab_name': prefs.getString(_tabNameKey) ?? 'Transaksi',
    };
  }

  static Future<void> saveSettings({
    required String webhookUrl,
    required String spreadsheetId,
    required String tabName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webhookUrlKey, webhookUrl);
    await prefs.setString(_spreadsheetIdKey, spreadsheetId);
    await prefs.setString(_tabNameKey, tabName);
  }
}
