import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/finance_models.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/goals_and_bills_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const KeuanganPribadiApp());
}

class KeuanganPribadiApp extends StatefulWidget {
  const KeuanganPribadiApp({super.key});

  @override
  State<KeuanganPribadiApp> createState() => _KeuanganPribadiAppState();
}

class _KeuanganPribadiAppState extends State<KeuanganPribadiApp> {
  bool _isLocked = ApiService.hasPin;

  void _refreshTheme() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ApiService.isDarkMode;

    return MaterialApp(
      title: 'KeuanganKu',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
        ),
        fontFamily: '.SF Pro Text',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF38BDF8),
          primary: const Color(0xFF38BDF8),
        ),
        fontFamily: '.SF Pro Text',
      ),
      home: _isLocked
          ? PinLockScreen(
              onUnlocked: () => setState(() => _isLocked = false),
            )
          : MainHomeShell(
              onThemeChanged: _refreshTheme,
              onLockRequested: () {
                if (ApiService.hasPin) {
                  setState(() => _isLocked = true);
                }
              },
            ),
    );
  }
}

/// Layar Kunci PIN 4 Digit bergaya iOS Passcode
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  bool _hasError = false;

  void _onKeyTap(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      if (_enteredPin == ApiService.pinCode) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked();
      } else {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _enteredPin = '';
              _hasError = true;
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.lock_shield_fill,
                color: Color(0xFF38BDF8),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Masukkan PIN KeuanganKu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasError ? 'PIN salah, silakan coba lagi' : 'PIN 4 Digit Keamanan',
              style: TextStyle(
                color: _hasError
                    ? const Color(0xFFF87171)
                    : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (idx) {
                final filled = idx < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFF38BDF8)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 280,
              child: Wrap(
                spacing: 24,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    _buildPinButton(d),
                  const SizedBox(width: 72, height: 72),
                  _buildPinButton('0'),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      onPressed: _onBackspace,
                      icon: const Icon(CupertinoIcons.delete_left_fill,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinButton(String digit) {
    return InkWell(
      onTap: () => _onKeyTap(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Text(
          digit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class MainHomeShell extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final VoidCallback onLockRequested;

  const MainHomeShell({
    super.key,
    required this.onThemeChanged,
    required this.onLockRequested,
  });

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
    HapticFeedback.lightImpact();
    _loadCategories();
    setState(() => _refreshSeed++);
  }

  void _openAddTransaction() {
    HapticFeedback.mediumImpact();
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

  Widget _buildActiveScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(
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
        );
      case 1:
        return TransactionsScreen(
          key: ValueKey('trx_$_refreshSeed'),
          categories: _categories,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
          onChanged: _triggerRefresh,
        );
      case 2:
        return GoalsAndBillsScreen(
          key: ValueKey('goals_$_refreshSeed'),
          categories: _categories,
          onDataChanged: _triggerRefresh,
        );
      case 3:
        return CategoriesScreen(
          key: ValueKey('cat_$_refreshSeed'),
          categories: _categories,
          onCategoriesUpdated: _triggerRefresh,
        );
      default:
        return SettingsScreen(
          key: ValueKey('set_$_refreshSeed'),
          onSettingsSaved: _triggerRefresh,
          onThemeChanged: widget.onThemeChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final titles = [
      'Ringkasan Keuangan',
      'Riwayat Transaksi',
      'Target & Tagihan Rutin',
      'Kategori & Budget',
      'Sheets & Keamanan',
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: barBg,
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
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: Text(
                  titles[_currentIndex],
                  key: ValueKey('title_$_currentIndex'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Tombol Cepat Mode Gelap (Dark Mode)
          IconButton(
            tooltip: 'Mode Gelap / Terang',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await ApiService.setDarkMode(!ApiService.isDarkMode);
              widget.onThemeChanged();
            },
            icon: Icon(
              ApiService.isDarkMode
                  ? CupertinoIcons.sun_max_fill
                  : CupertinoIcons.moon_stars_fill,
              size: 19,
              color: ApiService.isDarkMode
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF475569),
            ),
          ),
          if (ApiService.hasPin)
            IconButton(
              tooltip: 'Kunci Aplikasi',
              onPressed: widget.onLockRequested,
              icon: Icon(CupertinoIcons.lock_fill, size: 19, color: textColor),
            ),
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: _triggerRefresh,
            icon: Icon(CupertinoIcons.refresh, size: 19, color: textColor),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildActiveScreen(),
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
        onDestinationSelected: (idx) {
          if (idx == _currentIndex) return;
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = idx);
        },
        backgroundColor: barBg,
        surfaceTintColor: barBg,
        indicatorColor:
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        animationDuration: const Duration(milliseconds: 350),
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
            icon: Icon(CupertinoIcons.star_circle),
            selectedIcon: Icon(CupertinoIcons.star_circle_fill),
            label: 'Target',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.tag),
            selectedIcon: Icon(CupertinoIcons.tag_fill),
            label: 'Budget',
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
