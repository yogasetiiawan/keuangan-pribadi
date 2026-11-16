import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/finance_models.dart';

class MonthlyBarChartWidget extends StatelessWidget {
  final List<MonthlyChartPoint> points;

  const MonthlyBarChartWidget({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Belum ada data grafik bulanan')),
      );
    }

    double maxVal = 1.0;
    for (final p in points) {
      if (p.income > maxVal) maxVal = p.income;
      if (p.expense > maxVal) maxVal = p.expense;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tren 6 Bulan Terakhir',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                _legendDot(const Color(0xFF10B981), 'Pemasukan'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFEF4444), 'Pengeluaran'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: points.map((p) {
              final incRatio = (p.income / maxVal).clamp(0.04, 1.0);
              final expRatio = (p.expense / maxVal).clamp(0.04, 1.0);

              return Expanded(
                child: Tooltip(
                  message:
                      '${p.label} ${p.year}\nMasuk: ${CurrencyHelper.formatShortRupiah(p.income)}\nKeluar: ${CurrencyHelper.formatShortRupiah(p.expense)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 12,
                              height: 130 * (p.income == 0 ? 0.03 : incRatio),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 12,
                              height: 130 * (p.expense == 0 ? 0.03 : expRatio),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CategoryDonutChartWidget extends StatelessWidget {
  final List<CategoryBreakdown> breakdown;
  final double totalExpense;

  const CategoryDonutChartWidget({
    super.key,
    required this.breakdown,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty || totalExpense <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Belum ada pengeluaran di bulan ini',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(150, 150),
                painter: _DonutChartPainter(breakdown),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total Keluar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyHelper.formatShortRupiah(totalExpense),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...breakdown.map((item) {
          final color = CurrencyHelper.hexToColor(item.color);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        CurrencyHelper.iconFromName(item.icon),
                        color: color,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      CurrencyHelper.formatRupiah(item.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item.percentage / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdown> items;

  _DonutChartPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) return;

    for (final item in items) {
      final sweepAngle = (item.amount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = CurrencyHelper.hexToColor(item.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.03, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
