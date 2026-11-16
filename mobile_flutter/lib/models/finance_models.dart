import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formatter otomatis saat mengetik nominal Rupiah dengan pemisah titik (contoh: 1.500.000)
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final parsed = int.tryParse(digitsOnly) ?? 0;
    if (parsed == 0) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    final formatted = CurrencyHelper.formatThousands(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CurrencyHelper {
  static String formatThousands(num value) {
    final int val = value.abs().round();
    final String str = val.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String formatRupiah(double amount, {bool showPrefix = true, bool isHidden = false}) {
    if (isHidden) {
      return '${showPrefix ? "Rp " : ""}••••••••';
    }
    final bool isNegative = amount < 0;
    final formatted = formatThousands(amount);
    final prefix = showPrefix ? 'Rp ' : '';
    return '${isNegative ? "-" : ""}$prefix$formatted';
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

  /// Mengubah tanggal "2026-11-16" menjadi "16 November 2026"
  static String formatIndonesianDate(String rawDate) {
    if (rawDate.trim().isEmpty) return '-';
    final clean = rawDate.trim().split('T').first.split(' ').first;
    final parts = clean.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null && month >= 1 && month <= 12) {
        return '$day ${monthNames[month - 1]} $year';
      }
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return '${parsed.day} ${monthNames[parsed.month - 1]} ${parsed.year}';
    }
    return rawDate;
  }

  static String formatDateTimeObj(DateTime dt) {
    return '${dt.day} ${monthNames[dt.month - 1]} ${dt.year}';
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
      case 'bank':
        return Icons.account_balance_rounded;
      case 'ewallet':
        return Icons.phone_iphone_rounded;
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
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class WalletModel {
  final int id;
  final String name;
  final String icon;
  final String color;
  final double initialBalance;
  final double currentBalance;

  WalletModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.initialBalance = 0,
    this.currentBalance = 0,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json, {double? computedBalance}) {
    final initBal = (json['initial_balance'] as num?)?.toDouble() ?? 0.0;
    return WalletModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? 'Tunai').toString(),
      icon: (json['icon'] ?? 'wallet').toString(),
      color: (json['color'] ?? '#10B981').toString(),
      initialBalance: initBal,
      currentBalance: computedBalance ?? (json['current_balance'] as num?)?.toDouble() ?? initBal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'initial_balance': initialBalance,
      };
}

class CategoryModel {
  final int id;
  final String name;
  final String type; // 'income' | 'expense'
  final String icon;
  final String color;
  final double monthlyBudget;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.monthlyBudget = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
      icon: (json['icon'] ?? 'category').toString(),
      color: (json['color'] ?? '#3B82F6').toString(),
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'monthly_budget': monthlyBudget,
      };
}

class TransactionModel {
  final int id;
  final int? categoryId;
  final String type; // 'income' | 'expense'
  final double amount;
  final String transactionDate;
  final String description;
  final String walletName;
  final bool isSyncedToSheet;
  final CategoryModel? category;

  TransactionModel({
    required this.id,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    required this.description,
    this.walletName = 'Tunai',
    this.isSyncedToSheet = false,
    this.category,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    String rawDesc = (json['description'] ?? '').toString();
    String wallet = (json['wallet_name'] ?? '').toString();

    // Ekstrak prefix [Nama Dompet] jika berasal dari sinkronisasi Google Sheets
    if (wallet.isEmpty && rawDesc.startsWith('[') && rawDesc.contains(']')) {
      final endIdx = rawDesc.indexOf(']');
      wallet = rawDesc.substring(1, endIdx).trim();
      rawDesc = rawDesc.substring(endIdx + 1).trim();
    }
    if (wallet.isEmpty) wallet = 'Tunai';

    return TransactionModel(
      id: (json['id'] as num).toInt(),
      categoryId: json['category_id'] != null ? (json['category_id'] as num).toInt() : null,
      type: (json['type'] ?? 'expense').toString(),
      amount: (json['amount'] as num).toDouble(),
      transactionDate: (json['transaction_date'] ?? '').toString(),
      description: rawDesc,
      walletName: wallet,
      isSyncedToSheet: json['is_synced_to_sheet'] == true || json['is_synced_to_sheet'] == 1,
      category: json['category'] != null
          ? CategoryModel.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
    );
  }
}

class SavingGoalModel {
  final int id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final String color;
  final String icon;

  SavingGoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    this.color = '#10B981',
    this.icon = 'savings',
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  factory SavingGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingGoalModel(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (json['saved_amount'] as num?)?.toDouble() ?? 0.0,
      color: (json['color'] ?? '#10B981').toString(),
      icon: (json['icon'] ?? 'savings').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'color': color,
        'icon': icon,
      };
}

class RecurringBillModel {
  final int id;
  final String title;
  final double amount;
  final int? categoryId;
  final String categoryName;
  final String walletName;
  final int dayOfMonth;

  RecurringBillModel({
    required this.id,
    required this.title,
    required this.amount,
    this.categoryId,
    required this.categoryName,
    this.walletName = 'Rekening Bank',
    this.dayOfMonth = 1,
  });

  factory RecurringBillModel.fromJson(Map<String, dynamic> json) {
    return RecurringBillModel(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: (json['category_name'] ?? 'Tagihan & Utilitas').toString(),
      walletName: (json['wallet_name'] ?? 'Rekening Bank').toString(),
      dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'category_name': categoryName,
        'wallet_name': walletName,
        'day_of_month': dayOfMonth,
      };
}

class CategoryBreakdown {
  final int? categoryId;
  final String categoryName;
  final String color;
  final String icon;
  final double amount;
  final double percentage;
  final double monthlyBudget;

  CategoryBreakdown({
    this.categoryId,
    required this.categoryName,
    required this.color,
    required this.icon,
    required this.amount,
    required this.percentage,
    this.monthlyBudget = 0,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryId: json['category_id'] != null ? (json['category_id'] as num).toInt() : null,
      categoryName: (json['category_name'] ?? 'Lainnya').toString(),
      color: (json['color'] ?? '#64748B').toString(),
      icon: (json['icon'] ?? 'category').toString(),
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble() ?? 0.0,
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
  final List<WalletModel> wallets;
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
    this.wallets = const [],
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
      wallets: (json['wallets'] as List? ?? [])
          .map((e) => WalletModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
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
