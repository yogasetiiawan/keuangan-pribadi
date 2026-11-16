import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';
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
  bool _isLoading = true;
  String _filterType = 'all'; // 'all' | 'income' | 'expense'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchTransactions(
        month: widget.selectedMonth,
        year: widget.selectedYear,
        type: _filterType == 'all' ? null : _filterType,
        search: _searchQuery,
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
    try {
      await ApiService.deleteTransaction(trx.id);
      if (!mounted) return;
      await _loadTransactions();
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi dihapus')),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Cari catatan atau kategori...',
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
                    setState(() => _filterType = val);
                    _loadTransactions();
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
                  ? const Center(
                      child: Text(
                        'Tidak ada transaksi yang ditemukan',
                        style: TextStyle(color: Color(0xFF94A3B8)),
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

                          return Dismissible(
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                '${trx.category?.name ?? "Lainnya"} • ${trx.transactionDate}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
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
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isIncome ? "+" : "-"}${CurrencyHelper.formatRupiah(trx.amount)}',
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
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
