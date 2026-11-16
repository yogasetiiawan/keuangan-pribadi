import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  late String _type;
  int? _selectedCategoryId;
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
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.round().toString() : '',
    );
    _descController = TextEditingController(
      text: existing?.description ?? '',
    );
    _selectedDate = existing != null
        ? (DateTime.tryParse(existing.transactionDate) ?? DateTime.now())
        : DateTime.now();

    _ensureCategorySelection();
  }

  void _ensureCategorySelection() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> res;
      if (widget.existingTransaction != null) {
        res = await ApiService.updateTransaction(
          id: widget.existingTransaction!.id,
          categoryId: _selectedCategoryId,
          type: _type,
          amount: amount,
          transactionDate: _formatDateIso(_selectedDate),
          description: _descController.text.trim(),
        );
      } else {
        res = await ApiService.createTransaction(
          categoryId: _selectedCategoryId,
          type: _type,
          amount: amount,
          transactionDate: _formatDateIso(_selectedDate),
          description: _descController.text.trim(),
        );
      }

      if (!mounted) return;
      final sheetSync = res['sheet_sync'] as Map<String, dynamic>?;
      final synced = sheetSync?['success'] == true;

      Navigator.of(context).pop();
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: Text(
            synced
                ? 'Tersimpan di Database & disinkronkan ke Google Sheets!'
                : 'Tersimpan di Database Laravel',
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
    final filteredCategories =
        widget.categories.where((c) => c.type == _type).toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: const Color(0xFFE2E8F0),
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
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill,
                      color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _type,
                backgroundColor: const Color(0xFFF1F5F9),
                thumbColor: _type == 'expense'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                children: {
                  'expense': Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Pengeluaran',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _type == 'expense'
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  'income': Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Pemasukan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _type == 'income'
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                },
                onValueChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _type = val;
                    _ensureCategorySelection();
                  });
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nominal (Rp)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
                hintText: '0',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
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
                  backgroundColor: color.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
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
                    setState(() => _selectedCategoryId = cat.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tanggal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
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
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.calendar,
                                  size: 18, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateIso(_selectedDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Catatan / Keterangan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Contoh: Makan siang, Gaji bulanan, Tagihan Wi-Fi...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
                  backgroundColor: const Color(0xFF0F172A),
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
                      ? 'Menyimpan & Sinkronisasi...'
                      : 'Simpan Transaksi',
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
    );
  }
}
