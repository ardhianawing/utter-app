import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/expense_models.dart';

class ExpenseRepository {
  final SupabaseClient _supabase;

  ExpenseRepository(this._supabase);

  // ============================================================
  // EXPENSE CATEGORIES
  // ============================================================

  /// Get all expense categories
  Future<List<ExpenseCategory>> getCategories({bool activeOnly = true}) async {
    try {
      var query = _supabase.from('expense_categories').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name', ascending: true);

      return (response as List)
          .map((json) => ExpenseCategory.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load expense categories: $e');
    }
  }

  // ============================================================
  // EXPENSES
  // ============================================================

  /// Get expenses with optional filters
  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    int limit = 100,
  }) async {
    try {
      var query = _supabase
          .from('expenses')
          .select('*, expense_categories(*)')
          .order('expense_date', ascending: false);

      if (startDate != null) {
        query = query.gte('expense_date', startDate.toIso8601String().split('T')[0]);
      }

      if (endDate != null) {
        query = query.lte('expense_date', endDate.toIso8601String().split('T')[0]);
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.limit(limit);

      return (response as List)
          .map((json) => Expense.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load expenses: $e');
    }
  }

  /// Create new expense
  Future<Expense> createExpense({
    required String categoryId,
    required double amount,
    required String description,
    required PaymentMethod paymentMethod,
    required DateTime expenseDate,
    String? receiptUrl,
    String? createdBy,
  }) async {
    try {
      final response = await _supabase
          .from('expenses')
          .insert({
            'category_id': categoryId,
            'amount': amount,
            'description': description,
            'payment_method': paymentMethod.dbValue,
            'expense_date': expenseDate.toIso8601String().split('T')[0],
            'receipt_url': receiptUrl,
            'created_by': createdBy,
          })
          .select('*, expense_categories(*)')
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create expense: $e');
    }
  }

  /// Update expense
  Future<void> updateExpense({
    required String expenseId,
    String? categoryId,
    double? amount,
    String? description,
    PaymentMethod? paymentMethod,
    DateTime? expenseDate,
    String? receiptUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (categoryId != null) updateData['category_id'] = categoryId;
      if (amount != null) updateData['amount'] = amount;
      if (description != null) updateData['description'] = description;
      if (paymentMethod != null) updateData['payment_method'] = paymentMethod.dbValue;
      if (expenseDate != null) {
        updateData['expense_date'] = expenseDate.toIso8601String().split('T')[0];
      }
      if (receiptUrl != null) updateData['receipt_url'] = receiptUrl;

      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('expenses')
          .update(updateData)
          .eq('id', expenseId);
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _supabase.from('expenses').delete().eq('id', expenseId);
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  /// Get expense summary for a period
  Future<ExpenseSummary> getExpenseSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final expenses = await getExpenses(
        startDate: startDate,
        endDate: endDate,
        limit: 10000,
      );

      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      final byCategory = <String, double>{};
      final byPaymentMethod = <PaymentMethod, double>{};

      for (final expense in expenses) {
        final categoryName = expense.category?.name ?? 'Tidak Ada Kategori';
        byCategory[categoryName] = (byCategory[categoryName] ?? 0) + expense.amount;

        byPaymentMethod[expense.paymentMethod] =
            (byPaymentMethod[expense.paymentMethod] ?? 0) + expense.amount;
      }

      return ExpenseSummary(
        totalExpenses: totalExpenses,
        expenseCount: expenses.length,
        byCategory: byCategory,
        byPaymentMethod: byPaymentMethod,
      );
    } catch (e) {
      throw Exception('Failed to calculate expense summary: $e');
    }
  }

  // ============================================================
  // BUDGETS
  // ============================================================

  /// Get budgets for a specific period
  Future<List<Budget>> getBudgets({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _supabase
          .from('budgets')
          .select('*, expense_categories(*)')
          .eq('month', month)
          .eq('year', year)
          .order('category_id');

      return (response as List)
          .map((json) => Budget.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load budgets: $e');
    }
  }

  /// Set or update budget
  Future<void> setBudget({
    required String categoryId,
    required double amount,
    required int month,
    required int year,
    String? notes,
    String? createdBy,
  }) async {
    try {
      await _supabase.from('budgets').upsert({
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
        'notes': notes,
        'created_by': createdBy,
      });
    } catch (e) {
      throw Exception('Failed to set budget: $e');
    }
  }

  /// Get budget vs actual comparison
  Future<List<BudgetVsActual>> getBudgetVsActual({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_budget_vs_actual',
        params: {
          'p_month': month,
          'p_year': year,
        },
      );

      return (response as List)
          .map((json) => BudgetVsActual.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get budget vs actual: $e');
    }
  }
}
