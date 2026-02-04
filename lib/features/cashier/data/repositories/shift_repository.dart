import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';

class ShiftRepository {
  final SupabaseClient _supabase;

  ShiftRepository(this._supabase);

  // ============================================================
  // SHIFT MANAGEMENT
  // ============================================================

  /// Open a new shift for a cashier
  Future<Shift> openShift({
    required String cashierId,
    required double startingCash,
  }) async {
    try {
      // Call the database function to open a shift
      final response = await _supabase.rpc(
        'open_shift',
        params: {
          'p_cashier_id': cashierId,
          'p_starting_cash': startingCash,
        },
      );

      final shiftId = response as String;

      // Fetch the newly created shift
      final shiftData = await _supabase
          .from('shifts')
          .select()
          .eq('id', shiftId)
          .single();

      return Shift.fromJson(shiftData);
    } catch (e) {
      throw Exception('Failed to open shift: $e');
    }
  }

  /// Close an active shift
  Future<void> closeShift({
    required String shiftId,
    required double endingCash,
    String? notes,
  }) async {
    try {
      await _supabase.rpc(
        'close_shift',
        params: {
          'p_shift_id': shiftId,
          'p_ending_cash': endingCash,
          'p_notes': notes,
        },
      );
    } catch (e) {
      throw Exception('Failed to close shift: $e');
    }
  }

  /// Get the active shift for a cashier
  Future<Shift?> getActiveShift(String cashierId) async {
    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .eq('cashier_id', cashierId)
          .eq('status', 'open')
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return Shift.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get active shift: $e');
    }
  }

  /// Get shift by ID with full details
  Future<Shift?> getShiftById(String shiftId) async {
    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .eq('id', shiftId)
          .single();

      return Shift.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get shift: $e');
    }
  }

  // ============================================================
  // SHIFT REPORTS
  // ============================================================

  /// Get shift summary with cashier details and order count
  Future<ShiftSummary?> getShiftSummary(String shiftId) async {
    try {
      // Get shift details (includes table columns which might be 0 for open shifts)
      final shiftData = await _supabase
          .from('shifts')
          .select('''
            *,
            profiles:cashier_id (
              name
            )
          ''')
          .eq('id', shiftId)
          .single();

      var shift = Shift.fromJson(shiftData);
      final cashierName = shiftData['profiles']['name'] as String;

      // Get real-time totals from orders for this shift
      final ordersResponse = await _supabase
          .from('orders')
          .select('total_amount, payment_method')
          .eq('shift_id', shiftId)
          .filter('status', 'in', '(PAID,PREPARING,READY,COMPLETED)');

      final orders = ordersResponse as List;
      final orderCount = orders.length;

      // If the shift is still open, we calculate the dynamic totals from orders
      // because the shifts table only updates these columns on close_shift() RPC
      if (shift.status == 'open') {
        double cash = 0, qris = 0, debit = 0;
        for (final o in orders) {
          final amt = (o['total_amount'] as num).toDouble();
          final method = o['payment_method'] as String;
          if (method == 'CASH') cash += amt;
          else if (method == 'QRIS') qris += amt;
          else if (method == 'DEBIT') debit += amt;
        }

        // Calculate expected cash in drawer
        // Expected Cash = Starting Cash + Cash Received - Cash Change
        final cashOrdersData = await _supabase
            .from('orders')
            .select('cash_received, cash_change')
            .eq('shift_id', shiftId)
            .eq('payment_method', 'CASH')
            .filter('status', 'in', '(PAID,PREPARING,READY,COMPLETED)');

        double totalCashReceived = 0;
        double totalCashChange = 0;

        for (final order in cashOrdersData as List) {
          totalCashReceived += (order['cash_received'] as num?)?.toDouble() ?? 0;
          totalCashChange += (order['cash_change'] as num?)?.toDouble() ?? 0;
        }

        final expectedCash = shift.startingCash + totalCashReceived - totalCashChange;

        // Create a new shift object with updated real-time totals
        shift = Shift(
          id: shift.id,
          cashierId: shift.cashierId,
          startTime: shift.startTime,
          endTime: shift.endTime,
          startingCash: shift.startingCash,
          endingCash: shift.endingCash,
          expectedCash: expectedCash, // Calculated expected cash
          totalCashReceived: cash, // Revenue from cash sales
          totalQrisReceived: qris,
          totalDebitReceived: debit,
          status: shift.status,
          notes: shift.notes,
        );
      }

      // Get top products for this shift
      final topProducts = await getTopProductsByShift(shiftId);

      return ShiftSummary(
        shift: shift,
        cashierName: cashierName,
        orderCount: orderCount,
        topProducts: topProducts,
      );
    } catch (e) {
      throw Exception('Failed to get shift summary: $e');
    }
  }

  /// Get top-selling products for a shift
  Future<List<TopProduct>> getTopProductsByShift(String shiftId, {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('shift_top_products')
          .select()
          .eq('shift_id', shiftId)
          .order('total_revenue', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => TopProduct.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get top products: $e');
    }
  }

  /// Get all shifts for a cashier (history)
  Future<List<Shift>> getShiftHistory({
    required String cashierId,
    int limit = 30,
  }) async {
    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .eq('cashier_id', cashierId)
          .order('start_time', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Shift.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get shift history: $e');
    }
  }

  /// Get all shifts for a date range (for admin reports)
  Future<List<Shift>> getShiftsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String())
          .order('start_time', ascending: false);

      return (response as List)
          .map((json) => Shift.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get shifts by date range: $e');
    }
  }

  // ============================================================
  // REAL-TIME UPDATES
  // ============================================================

  /// Watch active shift for a cashier (real-time updates)
  Stream<Shift?> watchActiveShift(String cashierId) {
    return _supabase
        .from('shifts')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filter for active shift of this cashier
          final activeShifts = data
              .where((shift) =>
                  shift['cashier_id'] == cashierId &&
                  shift['status'] == 'open')
              .toList();

          if (activeShifts.isEmpty) return null;

          // Sort by start_time and get the most recent
          activeShifts.sort((a, b) =>
              (b['start_time'] as String).compareTo(a['start_time'] as String));

          return Shift.fromJson(activeShifts.first);
        });
  }

  // ============================================================
  // MONTHLY ANALYTICS METHODS
  // ============================================================

  /// Get monthly shift analytics
  Future<Map<String, dynamic>> getMonthlyShiftAnalytics(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('shifts')
          .select()
          .gte('start_time', startDate.toIso8601String())
          .lt('start_time', endDate.toIso8601String());

      final shifts = (response as List<dynamic>)
          .map((json) => Shift.fromJson(json))
          .toList();

      // Calculate totals
      int totalShifts = shifts.length;
      double totalRevenue = shifts.fold(0, (sum, s) => sum + s.totalSales);

      // Calculate average shift duration
      int totalDurationMinutes = 0;
      int closedShifts = 0;

      for (var shift in shifts) {
        if (shift.endTime != null) {
          totalDurationMinutes += shift.duration.inMinutes;
          closedShifts++;
        }
      }

      double averageDuration = closedShifts > 0
          ? totalDurationMinutes / closedShifts
          : 0;

      double averageRevenue = totalShifts > 0 ? totalRevenue / totalShifts : 0;

      return {
        'total_shifts': totalShifts,
        'total_revenue': totalRevenue,
        'average_duration_minutes': averageDuration,
        'average_revenue': averageRevenue,
        'closed_shifts': closedShifts,
        'open_shifts': totalShifts - closedShifts,
      };
    } catch (e) {
      throw Exception('Failed to load monthly shift analytics: $e');
    }
  }

  /// Get cash reconciliation summary for the month
  Future<Map<String, int>> getCashReconciliationSummary(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('shifts')
          .select()
          .gte('start_time', startDate.toIso8601String())
          .lt('start_time', endDate.toIso8601String())
          .eq('status', 'closed'); // Only count closed shifts

      final shifts = (response as List<dynamic>)
          .map((json) => Shift.fromJson(json))
          .toList();

      int perfectMatches = 0;
      int discrepancies = 0;

      for (var shift in shifts) {
        if (shift.cashDifference != null) {
          if (shift.cashDifference == 0) {
            perfectMatches++;
          } else {
            discrepancies++;
          }
        }
      }

      return {
        'perfect_matches': perfectMatches,
        'discrepancies': discrepancies,
        'total_reconciled': perfectMatches + discrepancies,
      };
    } catch (e) {
      throw Exception('Failed to load cash reconciliation summary: $e');
    }
  }
}
