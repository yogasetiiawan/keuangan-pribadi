import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'models/finance_models.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const KeuanganPribadiApp());
}

class KeuanganPribadiApp extends StatelessWidget {
  const KeuanganPribadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keuangan Pribadi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
        ),
        fontFamily: '.SF Pro Text',
      ),
      home: const MainHomeShell(),
    );
  }
}

class MainHomeShell extends StatefulWidget {
  const MainHomeShell({super.key});

  @override
  State<MainHomeShell> createState() => _MainHomeShellState();
}

class _MainHomeShellState extends State<MainHomeShell> {
  int _currentIndex = 0;
  List<CategoryModel> _categories = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _refreshSeed = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.fetchCategories();
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (_) {}
  }

  void _triggerRefresh() {
    _loadCategories();
    setState(() => _refreshSeed++);
  }

  void _openAddTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        categories: _categories,
        onSaved: _triggerRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Ringkasan Keuangan',
      'Riwayat Transaksi',
      'Kategori',
      'Pengaturan & Sheets',
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.chart_pie_fill,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              titles[_currentIndex],
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: _triggerRefresh,
            icon: const Icon(CupertinoIcons.refresh,
                size: 20, color: Color(0xFF475569)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            key: ValueKey('dash_$_refreshSeed'),
            categories: _categories,
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            onMonthYearChanged: (m, y) {
              setState(() {
                _selectedMonth = m;
                _selectedYear = y;
              });
            },
            onRefreshRequested: _triggerRefresh,
          ),
          TransactionsScreen(
            key: ValueKey('trx_$_refreshSeed'),
            categories: _categories,
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            onChanged: _triggerRefresh,
          ),
          CategoriesScreen(
            categories: _categories,
            onCategoriesUpdated: _triggerRefresh,
          ),
          SettingsScreen(
            onSettingsSaved: _triggerRefresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransaction,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(CupertinoIcons.add_circled_solid, size: 20),
        label: const Text(
          'Catat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: const Color(0xFFE2E8F0),
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.list_bullet),
            selectedIcon: Icon(CupertinoIcons.list_bullet_below_rectangle),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.tag),
            selectedIcon: Icon(CupertinoIcons.tag_fill),
            label: 'Kategori',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.slider_horizontal_3),
            selectedIcon: Icon(CupertinoIcons.settings_solid),
            label: 'Sheets',
          ),
        ],
      ),
    );
  }
}
