import 'package:flutter/material.dart';

class CurrencyHelper {
  static String formatRupiah(double amount, {bool showPrefix = true}) {
    final bool isNegative = amount < 0;
    final int val = amount.abs().round();
    final String str = val.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    final prefix = showPrefix ? 'Rp ' : '';
    return '${isNegative ? "-" : ""}$prefix${buffer.toString()}';
  }

  static String formatShortRupiah(double amount) {
    final double absVal = amount.abs();
    if (absVal >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (absVal >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (absVal >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return formatRupiah(amount);
  }

  static const List<String> monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String monthName(int month) {
    if (month < 1 || month > 12) return '';
    return monthNames[month - 1];
  }

  static Color hexToColor(String hex) {
    String clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    final int? val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : const Color(0xFF3B82F6);
  }

  static IconData iconFromName(String name) {
    switch (name) {
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'movie':
        return Icons.movie_creation_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class CategoryModel {
  final int id;
  final String name;
  final String type; // 'income' | 'expense'
  final String icon;
  final String color;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
      icon: (json['icon'] ?? 'category').toString(),
      color: (json['color'] ?? '#3B82F6').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
      };
}

class TransactionModel {
  final int id;
  final int? categoryId;
  final String type; // 'income' | 'expense'
  final double amount;
  final String transactionDate;
  final String description;
  final bool isSyncedToSheet;
  final CategoryModel? category;

  TransactionModel({
    required this.id,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    required this.description,
    this.isSyncedToSheet = false,
    this.category,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: (json['id'] as num).toInt(),
      categoryId: json['category_id'] != null ? (json['category_id'] as num).toInt() : null,
      type: (json['type'] ?? 'expense').toString(),
      amount: (json['amount'] as num).toDouble(),
      transactionDate: (json['transaction_date'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isSyncedToSheet: json['is_synced_to_sheet'] == true || json['is_synced_to_sheet'] == 1,
      category: json['category'] != null
          ? CategoryModel.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
    );
  }
}

class CategoryBreakdown {
  final int? categoryId;
  final String categoryName;
  final String color;
  final String icon;
  final double amount;
  final double percentage;

  CategoryBreakdown({
    this.categoryId,
    required this.categoryName,
    required this.color,
    required this.icon,
    required this.amount,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryId: json['category_id'] != null ? (json['category_id'] as num).toInt() : null,
      categoryName: (json['category_name'] ?? 'Lainnya').toString(),
      color: (json['color'] ?? '#64748B').toString(),
      icon: (json['icon'] ?? 'category').toString(),
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class MonthlyChartPoint {
  final String label;
  final int month;
  final int year;
  final double income;
  final double expense;

  MonthlyChartPoint({
    required this.label,
    required this.month,
    required this.year,
    required this.income,
    required this.expense,
  });

  factory MonthlyChartPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyChartPoint(
      label: (json['label'] ?? '').toString(),
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
    );
  }
}

class GoogleSheetsStatus {
  final bool configured;
  final String mode;
  final int unsyncedCount;

  GoogleSheetsStatus({
    required this.configured,
    required this.mode,
    required this.unsyncedCount,
  });

  factory GoogleSheetsStatus.fromJson(Map<String, dynamic> json) {
    return GoogleSheetsStatus(
      configured: json['configured'] == true,
      mode: (json['mode'] ?? 'not_configured').toString(),
      unsyncedCount: (json['unsynced_count'] as num? ?? 0).toInt(),
    );
  }
}

class DashboardData {
  final int month;
  final int year;
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<MonthlyChartPoint> monthlyChart;
  final List<TransactionModel> recentTransactions;
  final GoogleSheetsStatus googleSheets;

  DashboardData({
    required this.month,
    required this.year,
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.categoryBreakdown,
    required this.monthlyChart,
    required this.recentTransactions,
    required this.googleSheets,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      totalBalance: (json['total_balance'] as num).toDouble(),
      monthlyIncome: (json['monthly_income'] as num).toDouble(),
      monthlyExpense: (json['monthly_expense'] as num).toDouble(),
      categoryBreakdown: (json['category_breakdown'] as List? ?? [])
          .map((e) => CategoryBreakdown.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      monthlyChart: (json['monthly_chart'] as List? ?? [])
          .map((e) => MonthlyChartPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recentTransactions: (json['recent_transactions'] as List? ?? [])
          .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      googleSheets: GoogleSheetsStatus.fromJson(
        Map<String, dynamic>.from(json['google_sheets'] ?? {}),
      ),
    );
  }
}
