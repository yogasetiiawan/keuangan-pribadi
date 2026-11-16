import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';

class CategoriesScreen extends StatefulWidget {
  final List<CategoryModel> categories;
  final VoidCallback onCategoriesUpdated;

  const CategoriesScreen({
    super.key,
    required this.categories,
    required this.onCategoriesUpdated,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _selectedType = 'expense';

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    String chosenColor = '#EF4444';
    String chosenIcon = 'restaurant';

    final colors = [
      '#EF4444',
      '#F97316',
      '#F59E0B',
      '#10B981',
      '#06B6D4',
      '#3B82F6',
      '#6366F1',
      '#8B5CF6',
      '#EC4899',
    ];

    final icons = [
      'restaurant',
      'car',
      'bolt',
      'shopping_bag',
      'movie',
      'medical',
      'wallet',
      'laptop',
      'trending_up',
      'gift',
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _selectedType == 'expense'
                    ? 'Tambah Kategori Pengeluaran'
                    : 'Tambah Kategori Pemasukan',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Kategori',
                        hintText: 'Contoh: Pendidikan, Kopi, Komisi...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pilih Warna',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((hex) {
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
                                  ? Border.all(
                                      color: const Color(0xFF0F172A),
                                      width: 2.5)
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
                    const SizedBox(height: 16),
                    const Text('Pilih Ikon',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: icons.map((ic) {
                        final sel = ic == chosenIcon;
                        return GestureDetector(
                          onTap: () => setModalState(() => chosenIcon = ic),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CurrencyHelper.iconFromName(ic),
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              size: 19,
                            ),
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
                    await ApiService.createCategory(
                      name: nameCtrl.text.trim(),
                      type: _selectedType,
                      icon: chosenIcon,
                      color: chosenColor,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    widget.onCategoriesUpdated();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.categories.where((c) => c.type == _selectedType).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _selectedType,
                  children: const {
                    'expense': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Pengeluaran',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    'income': Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Pemasukan',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('Tambah'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cat = filtered[index];
              final color = CurrencyHelper.hexToColor(cat.color);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CurrencyHelper.iconFromName(cat.icon),
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.trash,
                          size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () async {
                        await ApiService.deleteCategory(cat.id);
                        widget.onCategoriesUpdated();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
