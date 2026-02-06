import 'package:flutter/foundation.dart';

// ============================================================
// ENUMS
// ============================================================

enum PaymentMethod {
  CASH,
  TRANSFER,
  DEBIT;

  String get displayName {
    switch (this) {
      case PaymentMethod.CASH:
        return 'Tunai';
      case PaymentMethod.TRANSFER:
        return 'Transfer';
      case PaymentMethod.DEBIT:
        return 'Kartu Debit';
    }
  }

  String get dbValue => name;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentMethod.CASH,
    );
  }
}

// ============================================================
// MODELS
// ============================================================

@immutable
class ExpenseCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.isActive = true,
    required this.createdAt,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class Expense {
  final String id;
  final String? categoryId;
  final ExpenseCategory? category;
  final double amount;
  final String description;
  final PaymentMethod paymentMethod;
  final String? receiptUrl;
  final DateTime expenseDate;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? createdBy;
  final DateTime createdAt;

  const Expense({
    required this.id,
    this.categoryId,
    this.category,
    required this.amount,
    required this.description,
    required this.paymentMethod,
    this.receiptUrl,
    required this.expenseDate,
    this.approvedBy,
    this.approvedAt,
    this.createdBy,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      category: json['expense_categories'] != null
          ? ExpenseCategory.fromJson(json['expense_categories'] as Map<String, dynamic>)
          : null,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] as String),
      receiptUrl: json['receipt_url'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedAmount => 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
}

@immutable
class Budget {
  final String id;
  final String categoryId;
  final ExpenseCategory? category;
  final double amount;
  final int month;
  final int year;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  const Budget({
    required this.id,
    required this.categoryId,
    this.category,
    required this.amount,
    required this.month,
    required this.year,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      category: json['expense_categories'] != null
          ? ExpenseCategory.fromJson(json['expense_categories'] as Map<String, dynamic>)
          : null,
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get periodLabel {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[month - 1]} $year';
  }
}

// ============================================================
// SUMMARY MODELS
// ============================================================

@immutable
class ExpenseSummary {
  final double totalExpenses;
  final int expenseCount;
  final Map<String, double> byCategory;
  final Map<PaymentMethod, double> byPaymentMethod;

  const ExpenseSummary({
    required this.totalExpenses,
    required this.expenseCount,
    required this.byCategory,
    required this.byPaymentMethod,
  });

  String get formattedTotal => 'Rp ${totalExpenses.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
}

@immutable
class BudgetVsActual {
  final String categoryId;
  final String categoryName;
  final double budgetAmount;
  final double actualAmount;
  final double variance;
  final double variancePercent;

  const BudgetVsActual({
    required this.categoryId,
    required this.categoryName,
    required this.budgetAmount,
    required this.actualAmount,
    required this.variance,
    required this.variancePercent,
  });

  bool get isOverBudget => variance < 0;
  double get utilizationPercent => (actualAmount / budgetAmount * 100).clamp(0, 200);

  factory BudgetVsActual.fromJson(Map<String, dynamic> json) {
    return BudgetVsActual(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      budgetAmount: (json['budget_amount'] as num).toDouble(),
      actualAmount: (json['actual_amount'] as num).toDouble(),
      variance: (json['variance'] as num).toDouble(),
      variancePercent: (json['variance_percent'] as num).toDouble(),
    );
  }
}
