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

  Future<void> _showAddWalletDialog() async {
    final nameCtrl = TextEditingController();
    final initBalCtrl = TextEditingController();
    String chosenColor = '#3B82F6';
    String chosenIcon = 'bank';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Tambah Dompet / Rekening',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Dompet / Bank / E-Wallet',
                        hintText: 'Contoh: BCA, Mandiri, GoPay, ShopeePay...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: initBalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Saldo Awal (Opsional)',
                        prefixText: 'Rp ',
                        hintText: '0',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        '#10B981',
                        '#3B82F6',
                        '#8B5CF6',
                        '#F59E0B',
                        '#EC4899'
                      ].map((hex) {
                        final c = CurrencyHelper.hexToColor(hex);
                        final sel = hex == chosenColor;
                        return GestureDetector(
                          onTap: () => setModalState(() => chosenColor = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: sel
                                  ? Border.all(color: Colors.black, width: 2.5)
                                  : null,
                            ),
                            child: sel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final raw =
                        initBalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                    final initBal = double.tryParse(raw) ?? 0;
                    await ApiService.createWallet(
                      name: nameCtrl.text.trim(),
                      icon: chosenIcon,
                      color: chosenColor,
                      initialBalance: initBal,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _loadDashboard();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
              Text(
                'Gagal Memuat Data Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
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
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: Icon(CupertinoIcons.chevron_left,
                            size: 17, color: textColor),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: Icon(CupertinoIcons.chevron_right,
                            size: 17, color: textColor),
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

          // Kartu Saldo Utama + Tombol Sensor Saldo (Privacy Mode)
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
                      Row(
                        children: [
                          const Text(
                            'Total Saldo Bersih',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await ApiService.setBalanceHidden(
                                  !ApiService.isBalanceHidden);
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                ApiService.isBalanceHidden
                                    ? CupertinoIcons.eye_slash_fill
                                    : CupertinoIcons.eye_fill,
                                size: 17,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
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
                              'Google Sheets',
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

          // FITUR 1: Kartu Multi-Dompet / Rekening (Horizontal Scroll)
          FadeSlideTransitionCard(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo per Dompet & Rekening',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddWalletDialog,
                      icon: const Icon(CupertinoIcons.add_circled, size: 15),
                      label: const Text('Tambah Dompet',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: d.wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final w = d.wallets[idx];
                      final wColor = CurrencyHelper.hexToColor(w.color);
                      return Container(
                        width: 165,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: wColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    CurrencyHelper.iconFromName(w.icon),
                                    size: 15,
                                    color: wColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: mutedColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              CurrencyHelper.formatRupiah(
                                w.currentBalance,
                                isHidden: ApiService.isBalanceHidden,
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Grafik Bulanan
          FadeSlideTransitionCard(
            index: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: MonthlyBarChartWidget(points: d.monthlyChart),
            ),
          ),

          const SizedBox(height: 18),

          // Grafik Donut Kategori Pengeluaran & Indikator Budget
          FadeSlideTransitionCard(
            index: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribusi Pengeluaran & Status Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
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

          // Transaksi Terbaru dengan Tanggal Format Indonesia ("16 November 2026") & Label Dompet
          FadeSlideTransitionCard(
            index: 5,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaksi Terbaru Bulan Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (d.recentTransactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi pada bulan ini',
                          style: TextStyle(color: mutedColor),
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
                        index: 5 + idx,
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
                                    color: catColor.withValues(alpha: 0.14),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${trx.walletName} • ${CurrencyHelper.formatIndonesianDate(trx.transactionDate)}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: mutedColor,
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
                                  '${isIncome ? "+" : "-"}${CurrencyHelper.formatRupiah(trx.amount, isHidden: ApiService.isBalanceHidden)}',
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
