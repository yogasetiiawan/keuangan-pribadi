import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';

class AddTransactionSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final TransactionModel? existingTransaction;
  final VoidCallback onSaved;

  const AddTransactionSheet({
    super.key,
    required this.categories,
    this.existingTransaction,
    required this.onSaved,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late String _type; // 'expense' | 'income' | 'transfer'
  int? _selectedCategoryId;
  String _selectedWallet = 'Tunai';
  String _transferToWallet = 'E-Wallet';
  List<WalletModel> _wallets = [];
  late TextEditingController _amountController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    _type = existing?.type ?? 'expense';
    _selectedCategoryId = existing?.categoryId;
    _selectedWallet = existing?.walletName ?? 'Tunai';
    _amountController = TextEditingController(
      text: existing != null
          ? CurrencyHelper.formatThousands(existing.amount)
          : '',
    );
    _descController = TextEditingController(
      text: existing?.description ?? '',
    );
    _selectedDate = existing != null
        ? (DateTime.tryParse(existing.transactionDate) ?? DateTime.now())
        : DateTime.now();

    _ensureCategorySelection();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final w = await ApiService.fetchWallets();
    if (mounted && w.isNotEmpty) {
      setState(() {
        _wallets = w;
        if (!w.any((item) => item.name == _selectedWallet)) {
          _selectedWallet = w.first.name;
        }
        if (w.length > 1) {
          _transferToWallet =
              w.firstWhere((item) => item.name != _selectedWallet, orElse: () => w.last).name;
        }
      });
    }
  }

  void _ensureCategorySelection() {
    if (_type == 'transfer') return;
    final filtered = widget.categories.where((c) => c.type == _type).toList();
    if (filtered.isNotEmpty &&
        !filtered.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = filtered.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(rawAmount) ?? 0;

    if (amount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid')),
      );
      return;
    }

    if (_type == 'transfer' && _selectedWallet == _transferToWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dompet asal dan tujuan harus berbeda')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      if (_type == 'transfer') {
        await ApiService.transferBetweenWallets(
          fromWallet: _selectedWallet,
          toWallet: _transferToWallet,
          amount: amount,
          date: _formatDateIso(_selectedDate),
          note: _descController.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: const Color(0xFF3B82F6),
            content: Text(
              '✓ Transfer $_selectedWallet → $_transferToWallet berhasil dicatat!',
            ),
          ),
        );
        return;
      }

      Map<String, dynamic> res;
      if (widget.existingTransaction != null) {
        res = await ApiService.updateTransaction(
          id: widget.existingTransaction!.id,
          categoryId: _selectedCategoryId,
          type: _type,
          amount: amount,
          transactionDate: _formatDateIso(_selectedDate),
          description: _descController.text.trim(),
          walletName: _selectedWallet,
        );
      } else {
        res = await ApiService.createTransaction(
          categoryId: _selectedCategoryId,
          type: _type,
          amount: amount,
          transactionDate: _formatDateIso(_selectedDate),
          description: _descController.text.trim(),
          walletName: _selectedWallet,
        );
      }

      if (!mounted) return;
      final sheetSync = res['sheet_sync'] as Map<String, dynamic>?;
      final synced = sheetSync?['success'] == true;

      Navigator.of(context).pop();
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFF0F172A),
          content: Text(
            synced
                ? '✓ Tersimpan & disinkronkan ke Google Sheets!'
                : '✓ Transaksi berhasil disimpan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menyimpan: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filteredCategories =
        widget.categories.where((c) => c.type == _type).toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    Color activeAccent = const Color(0xFFEF4444);
    if (_type == 'income') activeAccent = const Color(0xFF10B981);
    if (_type == 'transfer') activeAccent = const Color(0xFF3B82F6);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.94, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scaleVal, child) {
        return Transform.scale(
          scale: scaleVal,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingTransaction != null
                        ? 'Edit Transaksi'
                        : 'Catat Transaksi Baru',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(CupertinoIcons.xmark_circle_fill,
                        color: mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _type,
                  backgroundColor: fieldBg,
                  thumbColor: activeAccent,
                  children: {
                    'expense': Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Pengeluaran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _type == 'expense' ? Colors.white : mutedColor,
                        ),
                      ),
                    ),
                    'income': Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Pemasukan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _type == 'income' ? Colors.white : mutedColor,
                        ),
                      ),
                    ),
                    if (widget.existingTransaction == null)
                      'transfer': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Transfer',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                _type == 'transfer' ? Colors.white : mutedColor,
                          ),
                        ),
                      ),
                  },
                  onValueChanged: (val) {
                    if (val == null) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _type = val;
                      _ensureCategorySelection();
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Nominal (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: activeAccent,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: activeAccent.withValues(alpha: 0.75),
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: mutedColor.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: activeAccent, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pilihan Dompet / Rekening
              Text(
                _type == 'transfer' ? 'Dari Dompet Asal' : 'Dompet / Rekening',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_wallets.isNotEmpty
                        ? _wallets.map((w) => w.name).toList()
                        : ['Tunai', 'Rekening Bank', 'E-Wallet'])
                    .map((wName) {
                  final sel = wName == _selectedWallet;
                  return ChoiceChip(
                    selected: sel,
                    label: Text(wName),
                    selectedColor: const Color(0xFF0F172A),
                    backgroundColor: fieldBg,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedWallet = wName);
                    },
                  );
                }).toList(),
              ),

              if (_type == 'transfer') ...[
                const SizedBox(height: 16),
                Text(
                  'Ke Dompet Tujuan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (_wallets.isNotEmpty
                          ? _wallets.map((w) => w.name).toList()
                          : ['Tunai', 'Rekening Bank', 'E-Wallet'])
                      .map((wName) {
                    final sel = wName == _transferToWallet;
                    return ChoiceChip(
                      selected: sel,
                      label: Text(wName),
                      selectedColor: const Color(0xFF3B82F6),
                      backgroundColor: fieldBg,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _transferToWallet = wName);
                      },
                    );
                  }).toList(),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredCategories.map((cat) {
                    final isSelected = cat.id == _selectedCategoryId;
                    final color = CurrencyHelper.hexToColor(cat.color);
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CurrencyHelper.iconFromName(cat.icon),
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Text(cat.name),
                        ],
                      ),
                      selectedColor: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? color : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategoryId = cat.id);
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                'Tanggal Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar,
                          size: 18, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 10),
                      Text(
                        CurrencyHelper.formatDateTimeObj(_selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Catatan / Keterangan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Contoh: Makan siang, Gaji bulanan, Top-Up...',
                  hintStyle: TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(CupertinoIcons.checkmark_alt_circle_fill),
                  label: Text(
                    _isSaving
                        ? 'Menyimpan...'
                        : (_type == 'transfer'
                            ? 'Simpan Transfer Antar Dompet'
                            : 'Simpan Transaksi'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
