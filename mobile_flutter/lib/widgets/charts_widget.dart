import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../services/api_service.dart';

/// Animasi angka berjalan (Rolling Number Counter) + Dukungan Sensor Saldo (Privacy Mode)
class AnimatedRupiahText extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  const AnimatedRupiahText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    if (ApiService.isBalanceHidden) {
      return Text(
        '${prefix}Rp ••••••••',
        style: style,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        return Text(
          '$prefix${CurrencyHelper.formatRupiah(animatedVal)}',
          style: style,
        );
      },
    );
  }
}

/// Animasi masuk bertahap (Staggered Fade + Slide Up)
class FadeSlideTransitionCard extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideTransitionCard({
    super.key,
    required this.child,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final delayMs = (index * 65).clamp(0, 450);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, val, childWidget) {
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - val)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

class MonthlyBarChartWidget extends StatelessWidget {
  final List<MonthlyChartPoint> points;

  const MonthlyBarChartWidget({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text('Belum ada data grafik bulanan',
              style: TextStyle(color: mutedColor)),
        ),
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
            Text(
              'Tren 6 Bulan Terakhir',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Row(
              children: [
                _legendDot(const Color(0xFF10B981), 'Pemasukan', mutedColor),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFEF4444), 'Pengeluaran', mutedColor),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutBack,
          builder: (context, animProgress, _) {
            final safeProgress = animProgress.clamp(0.0, 1.0);
            return SizedBox(
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
                          '${p.label} ${p.year}\nMasuk: ${CurrencyHelper.formatRupiah(p.income)}\nKeluar: ${CurrencyHelper.formatRupiah(p.expense)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 12,
                                  height: 130 *
                                      (p.income == 0
                                          ? 0.03
                                          : incRatio * safeProgress),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF34D399),
                                        Color(0xFF059669)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 12,
                                  height: 130 *
                                      (p.expense == 0
                                          ? 0.03
                                          : expRatio * safeProgress),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF87171),
                                        Color(0xFFDC2626)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, Color textColor) {
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
          style: TextStyle(
            fontSize: 12,
            color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final trackColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    if (breakdown.isEmpty || totalExpense <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Belum ada pengeluaran di bulan ini',
            style: TextStyle(color: mutedColor),
          ),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Column(
          children: [
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(150, 150),
                    painter:
                        _DonutChartPainter(breakdown, progress, trackColor),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Keluar',
                        style: TextStyle(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ApiService.isBalanceHidden
                            ? 'Rp •••••'
                            : CurrencyHelper.formatShortRupiah(
                                totalExpense * progress),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
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
              final hasBudget = item.monthlyBudget > 0;
              final budgetRatio =
                  hasBudget ? (item.amount / item.monthlyBudget) : 0.0;

              Color budgetBadgeColor = const Color(0xFF10B981);
              String budgetLabel = 'Aman';
              if (budgetRatio >= 1.0) {
                budgetBadgeColor = const Color(0xFFEF4444);
                budgetLabel = 'Overbudget!';
              } else if (budgetRatio >= 0.8) {
                budgetBadgeColor = const Color(0xFFF59E0B);
                budgetLabel = 'Hampir Habis';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.categoryName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  color: textColor,
                                ),
                              ),
                              if (hasBudget)
                                Text(
                                  'Anggaran: ${CurrencyHelper.formatRupiah(item.monthlyBudget, isHidden: ApiService.isBalanceHidden)} ($budgetLabel)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: budgetBadgeColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${(item.percentage * progress).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          CurrencyHelper.formatRupiah(
                            item.amount,
                            isHidden: ApiService.isBalanceHidden,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hasBudget
                            ? (budgetRatio * progress).clamp(0.0, 1.0)
                            : ((item.percentage / 100.0) * progress)
                                .clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: trackColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasBudget ? budgetBadgeColor : color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdown> items;
  final double progress;
  final Color trackColor;

  _DonutChartPainter(this.items, this.progress, this.trackColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) return;

    for (final item in items) {
      final sweepAngle = (item.amount / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = CurrencyHelper.hexToColor(item.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.butt;

      if (sweepAngle > 0.04) {
        canvas.drawArc(rect, startAngle, sweepAngle - 0.03, false, paint);
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.items != items;
}
