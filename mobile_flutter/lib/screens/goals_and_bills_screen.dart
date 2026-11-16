import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';
import '../widgets/charts_widget.dart';

class GoalsAndBillsScreen extends StatefulWidget {
  final List<CategoryModel> categories;
  final VoidCallback onDataChanged;

  const GoalsAndBillsScreen({
    super.key,
    required this.categories,
    required this.onDataChanged,
  });

  @override
  State<GoalsAndBillsScreen> createState() => _GoalsAndBillsScreenState();
}

class _GoalsAndBillsScreenState extends State<GoalsAndBillsScreen> {
  String _activeTab = 'goals'; // 'goals' | 'bills'
  List<SavingGoalModel> _goals = [];
  List<RecurringBillModel> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final g = await ApiService.fetchSavingGoals();
    final b = await ApiService.fetchRecurringBills();
    if (mounted) {
      setState(() {
        _goals = g;
        _bills = b;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddGoalDialog() async {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String chosenColor = '#10B981';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Buat Target Tabungan Baru',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Target Impian',
                        hintText: 'Contoh: Dana Darurat, Beli MacBook...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Target Nominal (Rp)',
                        prefixText: 'Rp ',
                        hintText: '10.000.000',
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
                    final raw =
                        targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                    final target = double.tryParse(raw) ?? 0;
                    if (titleCtrl.text.trim().isEmpty || target <= 0) return;
                    await ApiService.createSavingGoal(
                      title: titleCtrl.text.trim(),
                      targetAmount: target,
                      color: chosenColor,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _loadData();
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

  Future<void> _showAddSavingFundsDialog(SavingGoalModel goal) async {
    final amountCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Tambah Tabungan: ${goal.title}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              RupiahInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Nominal Ditabung (Rp)',
              prefixText: 'Rp ',
              hintText: '500.000',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                final addVal = double.tryParse(raw) ?? 0;
                if (addVal <= 0) return;
                HapticFeedback.mediumImpact();
                await ApiService.addFundsToSavingGoal(goal.id, addVal);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadData();
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddRecurringBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '5');
    String selectedWallet = 'Rekening Bank';

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah Tagihan / Langganan Rutin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Tagihan / Langganan',
                    hintText: 'Contoh: Listrik, Wi-Fi, Kos, Netflix...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RupiahInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Nominal Rutin (Rp)',
                    prefixText: 'Rp ',
                    hintText: '350.000',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jatuh Tempo Setiap Tanggal (1 - 31)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
                final raw = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                final amt = double.tryParse(raw) ?? 0;
                final day = (int.tryParse(dayCtrl.text) ?? 1).clamp(1, 31);
                if (titleCtrl.text.trim().isEmpty || amt <= 0) return;

                final expCat = widget.categories
                    .where((c) => c.type == 'expense')
                    .firstOrNull;
                await ApiService.createRecurringBill(
                  title: titleCtrl.text.trim(),
                  amount: amt,
                  categoryId: expCat?.id ?? 7,
                  categoryName: expCat?.name ?? 'Tagihan & Utilitas',
                  walletName: selectedWallet,
                  dayOfMonth: day,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadData();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _recordBillNow(RecurringBillModel bill) async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final isoDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final res = await ApiService.createTransaction(
      categoryId: bill.categoryId ?? 7,
      type: 'expense',
      amount: bill.amount,
      transactionDate: isoDate,
      description: bill.title,
      walletName: bill.walletName,
    );

    if (!mounted) return;
    widget.onDataChanged();
    final synced = (res['sheet_sync'] as Map?)?['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          synced
              ? '⚡ "${bill.title}" berhasil dicatat & disinkronkan ke Google Sheets!'
              : '⚡ "${bill.title}" berhasil dicatat ke riwayat transaksi!',
        ),
      ),
    );
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
      return const Center(child: CupertinoActivityIndicator(radius: 15));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _activeTab,
                  children: const {
                    'goals': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('🏆 Target Tabungan',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    'bills': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('📅 Tagihan Rutin',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val == null) return;
                    HapticFeedback.selectionClick();
                    setState(() => _activeTab = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _activeTab == 'goals'
                    ? _showAddGoalDialog
                    : _showAddRecurringBillDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('Tambah'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _activeTab == 'goals'
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final color = CurrencyHelper.hexToColor(goal.color);
                    final pct = (goal.progress * 100).toStringAsFixed(1);

                    return FadeSlideTransitionCard(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    CurrencyHelper.iconFromName(goal.icon),
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Terkumpul: ${CurrencyHelper.formatRupiah(goal.savedAmount, isHidden: ApiService.isBalanceHidden)} / ${CurrencyHelper.formatRupiah(goal.targetAmount, isHidden: ApiService.isBalanceHidden)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: mutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAddSavingFundsDialog(goal),
                                  icon: Icon(CupertinoIcons.add_circled_solid,
                                      size: 16, color: color),
                                  label: Text(
                                    'Nabung',
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(CupertinoIcons.trash,
                                      size: 17, color: mutedColor),
                                  onPressed: () async {
                                    await ApiService.deleteSavingGoal(goal.id);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progres Tabungan',
                                  style: TextStyle(
                                      fontSize: 12, color: mutedColor),
                                ),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              tween:
                                  Tween<double>(begin: 0, end: goal.progress),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, _) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: val,
                                    minHeight: 8,
                                    backgroundColor:
                                        color.withValues(alpha: 0.12),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                  itemCount: _bills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    return FadeSlideTransitionCard(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.calendar_badge_plus,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${CurrencyHelper.formatRupiah(bill.amount)} • Setiap Tgl ${bill.dayOfMonth} (${bill.walletName})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _recordBillNow(bill),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text(
                                '⚡ Catat',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              icon: Icon(CupertinoIcons.trash,
                                  size: 17, color: mutedColor),
                              onPressed: () async {
                                await ApiService.deleteRecurringBill(bill.id);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
