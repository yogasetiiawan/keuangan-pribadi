import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';
import '../widgets/charts_widget.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  final List<CategoryModel> categories;
  final int selectedMonth;
  final int selectedYear;
  final VoidCallback onChanged;

  const TransactionsScreen({
    super.key,
    required this.categories,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> _transactions = [];
  List<String> _walletNames = ['Semua', 'Tunai', 'Rekening Bank', 'E-Wallet'];
  bool _isLoading = true;
  String _filterType = 'all'; // 'all' | 'income' | 'expense'
  String _filterWallet = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletsAndTransactions();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear) {
      _loadTransactions();
    }
  }

  Future<void> _loadWalletsAndTransactions() async {
    final w = await ApiService.fetchWallets();
    if (mounted && w.isNotEmpty) {
      setState(() {
        _walletNames = ['Semua', ...w.map((e) => e.name)];
      });
    }
    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchTransactions(
        month: widget.selectedMonth,
        year: widget.selectedYear,
        type: _filterType == 'all' ? null : _filterType,
        search: _searchQuery,
        walletName: _filterWallet,
      );
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTransaction(TransactionModel trx) async {
    HapticFeedback.mediumImpact();
    try {
      await ApiService.deleteTransaction(trx.id);
      if (!mounted) return;
      await _loadTransactions();
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text('Transaksi dihapus'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              CupertinoSearchTextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                placeholder: 'Cari catatan, kategori, atau dompet...',
                onSubmitted: (val) {
                  _searchQuery = val.trim();
                  _loadTransactions();
                },
                onChanged: (val) {
                  if (val.isEmpty && _searchQuery.isNotEmpty) {
                    _searchQuery = '';
                    _loadTransactions();
                  }
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _filterType,
                  children: const {
                    'all': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Semua',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    'income': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Pemasukan',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    'expense': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Pengeluaran',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val == null) return;
                    HapticFeedback.selectionClick();
                    setState(() => _filterType = val);
                    _loadTransactions();
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _walletNames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final wName = _walletNames[idx];
                    final sel = wName == _filterWallet;
                    return ChoiceChip(
                      selected: sel,
                      label: Text(wName, style: const TextStyle(fontSize: 12)),
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: cardBg,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _filterWallet = wName);
                        _loadTransactions();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 15))
              : _transactions.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada transaksi yang ditemukan',
                        style: TextStyle(color: mutedColor),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTransactions,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final trx = _transactions[index];
                          final isIncome = trx.type == 'income';
                          final catColor = CurrencyHelper.hexToColor(
                            trx.category?.color ??
                                (isIncome ? '#10B981' : '#EF4444'),
                          );

                          return FadeSlideTransitionCard(
                            index: index,
                            child: Dismissible(
                              key: ValueKey('trx_${trx.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(CupertinoIcons.trash_fill,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteTransaction(trx),
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
                                        _loadTransactions();
                                        widget.onChanged();
                                      },
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color:
                                              catColor.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          CurrencyHelper.iconFromName(
                                              trx.category?.icon ?? 'category'),
                                          color: catColor,
                                          size: 21,
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
                                                fontSize: 14.5,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    '${trx.walletName} • ${trx.category?.name ?? "Lainnya"} • ${CurrencyHelper.formatIndonesianDate(trx.transactionDate)}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: mutedColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  trx.isSyncedToSheet
                                                      ? CupertinoIcons
                                                          .checkmark_seal_fill
                                                      : CupertinoIcons.clock,
                                                  size: 13,
                                                  color: trx.isSyncedToSheet
                                                      ? const Color(0xFF10B981)
                                                      : mutedColor,
                                                ),
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
                                          fontSize: 14.5,
                                          color: isIncome
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
