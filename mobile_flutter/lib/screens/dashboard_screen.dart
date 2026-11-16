import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';
import '../widgets/charts_widget.dart';
import 'add_transaction_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final List<CategoryModel> categories;
  final int selectedMonth;
  final int selectedYear;
  final void Function(int month, int year) onMonthYearChanged;
  final VoidCallback onRefreshRequested;

  const DashboardScreen({
    super.key,
    required this.categories,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthYearChanged,
    required this.onRefreshRequested,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear) {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchDashboard(
        month: widget.selectedMonth,
        year: widget.selectedYear,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    try {
      final res = await ApiService.syncToGoogleSheets();
      if (!mounted) return;
      final success = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor:
              success ? const Color(0xFF10B981) : Colors.orange.shade800,
          content: Text(
            (res['message'] ?? 'Sinkronisasi selesai').toString(),
          ),
        ),
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal sinkronisasi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    int m = widget.selectedMonth + delta;
    int y = widget.selectedYear;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    widget.onMonthYearChanged(m, y);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }

    if (_error != null || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.wifi_exclamationmark,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Data Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data!;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
        children: [
          // Pemilih Bulan & Status Google Sheets
          FadeSlideTransitionCard(
            index: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(CupertinoIcons.chevron_left, size: 17),
                        onPressed: () => _changeMonth(-1),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Padding(
                          key: ValueKey(
                              '${widget.selectedMonth}_${widget.selectedYear}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${CurrencyHelper.monthName(widget.selectedMonth)} ${widget.selectedYear}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon:
                            const Icon(CupertinoIcons.chevron_right, size: 17),
                        onPressed: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _isSyncing ? null : _syncNow,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: d.googleSheets.configured
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: d.googleSheets.configured
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSyncing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            CupertinoIcons.table_fill,
                            size: 15,
                            color: d.googleSheets.configured
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _isSyncing
                              ? 'Syncing...'
                              : (d.googleSheets.configured
                                  ? 'Sync Sheets'
                                  : 'Setup Sheets'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: d.googleSheets.configured
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kartu Saldo Utama dengan Animasi Angka Berjalan (Rolling Counter)
          FadeSlideTransitionCard(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F2942)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Saldo Bersih',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.cloud_upload_fill,
                                size: 13, color: Color(0xFF38BDF8)),
                            SizedBox(width: 5),
                            Text(
                              'Google Sheets Connected',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedRupiahText(
                    value: d.totalBalance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_down_left,
                                  color: Color(0xFF34D399),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pemasukan Bulan Ini',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedRupiahText(
                                      value: d.monthlyIncome,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_up_right,
                                  color: Color(0xFFF87171),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pengeluaran Bulan Ini',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedRupiahText(
                                      value: d.monthlyExpense,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Grafik Bulanan
          FadeSlideTransitionCard(
            index: 2,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: MonthlyBarChartWidget(points: d.monthlyChart),
            ),
          ),

          const SizedBox(height: 18),

          // Grafik Donut Kategori Pengeluaran
          FadeSlideTransitionCard(
            index: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribusi Pengeluaran per Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CategoryDonutChartWidget(
                    breakdown: d.categoryBreakdown,
                    totalExpense: d.monthlyExpense,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Transaksi Terbaru dengan Tanggal Format Indonesia ("16 November 2026")
          FadeSlideTransitionCard(
            index: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaksi Terbaru Bulan Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (d.recentTransactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi pada bulan ini',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  else
                    ...d.recentTransactions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final trx = entry.value;
                      final isIncome = trx.type == 'income';
                      final catColor = CurrencyHelper.hexToColor(
                        trx.category?.color ??
                            (isIncome ? '#10B981' : '#EF4444'),
                      );
                      return FadeSlideTransitionCard(
                        index: 4 + idx,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => AddTransactionSheet(
                                categories: widget.categories,
                                existingTransaction: trx,
                                onSaved: () {
                                  _loadDashboard();
                                  widget.onRefreshRequested();
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    CurrencyHelper.iconFromName(
                                        trx.category?.icon ?? 'category'),
                                    color: catColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trx.description.isNotEmpty
                                            ? trx.description
                                            : (trx.category?.name ??
                                                'Transaksi'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${trx.category?.name ?? "Lainnya"} • ${CurrencyHelper.formatIndonesianDate(trx.transactionDate)}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          if (trx.isSyncedToSheet) ...[
                                            const SizedBox(width: 6),
                                            const Icon(
                                              CupertinoIcons
                                                  .checkmark_seal_fill,
                                              size: 13,
                                              color: Color(0xFF10B981),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isIncome ? "+" : "-"}${CurrencyHelper.formatRupiah(trx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isIncome
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
