import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';
import '../../../storage/data/repositories/storage_repository.dart';

class OrderRepository {
  final SupabaseClient _supabase;
  late final StorageRepository _storageRepository;

  OrderRepository(this._supabase) {
    _storageRepository = StorageRepository(_supabase);
  }

  // Stream of incoming orders (active orders: PENDING_PAYMENT, PAID, PREPARING, READY)
  Stream<List<Order>> getIncomingOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps
            .map((map) => Order.fromJson(map))
            .where((order) =>
                order.status == OrderStatus.PENDING_PAYMENT ||
                order.status == OrderStatus.PAID ||
                order.status == OrderStatus.PREPARING ||
                order.status == OrderStatus.READY ||
                order.status == OrderStatus.SERVED)
            .toList());
  }

  Stream<List<Order>> getTodayCompletedOrdersStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'COMPLETED')
        .order('created_at', ascending: false)
        .map((maps) => maps
            .map((map) => Order.fromJson(map))
            .where((order) => order.createdAt.isAfter(startOfDay))
            .toList());
  }
  
  Future<List<Map<String, dynamic>>> getOrderItemsWithProducts(String orderId) async {
     try {
      final response = await _supabase
          .from('order_items')
          .select('*, products(name)')
          .eq('order_id', orderId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load order items: $e');
    }
  }

  Future<List<OrderItem>> getOrderItems(String orderId) async {
     try {
      final response = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);
      
      return (response as List<dynamic>)
          .map((json) => OrderItem.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load order items: $e');
    }
  }

  Future<String> createOrderWithItems(
    Order order,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final orderMap = {
        'source': order.source.toString().split('.').last,
        'type': order.type.toString().split('.').last,
        'status': order.status.toString().split('.').last,
        'payment_method': order.paymentMethod.toString().split('.').last,
        'total_amount': order.totalAmount,
        'points_earned': order.pointsEarned,
        'points_redeemed': order.pointsRedeemed,
        'table_id': order.tableId,
        'user_id': order.userId,
        'customer_name': order.customerName,
        'notes': order.notes,
        'cash_received': order.cashReceived,
        'cash_change': order.cashChange,
        'created_at': order.createdAt.toIso8601String(),
        'shift_id': order.shiftId, // Added shift_id
      };

      final orderResponse = await _supabase
          .from('orders')
          .insert(orderMap)
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      if (items.isNotEmpty) {
        final orderItems = items.map((item) {
          return {
            'order_id': orderId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'subtotal': item['subtotal'],
            'notes': item['notes'],
            'selected_modifiers': item['selected_modifiers'] != null 
                ? (item['selected_modifiers'] as List).map((m) => m is ProductModifier ? m.toJson() : m).toList()
                : null,
          };
        }).toList();

        await _supabase.from('order_items').insert(orderItems);
      }

      return orderId;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<void> createOrder(Order order) async {
    final orderMap = {
      'source': order.source.toString().split('.').last,
      'type': order.type.toString().split('.').last,
      'status': order.status.toString().split('.').last,
      'payment_method': order.paymentMethod.toString().split('.').last,
      'total_amount': order.totalAmount,
      'points_earned': order.pointsEarned,
      'points_redeemed': order.pointsRedeemed,
      'table_id': order.tableId,
      'user_id': order.userId,
      'customer_name': order.customerName,
      'shift_id': order.shiftId, // Added shift_id
    };
    
    await _supabase.from('orders').insert(orderMap);
  }

  Stream<Order> watchOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) {
          if (data.isEmpty) throw Exception('Order not found');
          return Order.fromJson(data.first);
        });
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  Future<Order?> getOrderByDisplayId(String displayId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('display_id', displayId)
          .maybeSingle(); 

      if (response == null) return null;
      return Order.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch order by display ID: $e');
    }
  }

  Future<Map<String, dynamic>> getOrderWithTableInfo(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            tables (
              table_number,
              qr_code_string
            )
          ''')
          .eq('id', orderId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch order with table info: $e');
    }
  }

  Future<Map<String, dynamic>> getTodaySalesSummary() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .neq('status', 'CANCELLED');

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      double totalSales = 0;
      int appOrders = 0;
      int posOrders = 0;
      int onlineOrders = 0;

      for (var order in orders) {
        totalSales += order.totalAmount;
        if (order.source == OrderSource.APP) {
          appOrders++;
        } else if (order.source == OrderSource.POS_MANUAL || order.source == OrderSource.MANUAL_ENTRY) {
          posOrders++;
        } else {
          onlineOrders++;
        }
      }

      return {
        'total_sales': totalSales,
        'total_orders': orders.length,
        'app_orders': appOrders,
        'pos_orders': posOrders,
        'online_orders': onlineOrders,
      };
    } catch (e) {
      throw Exception('Failed to load sales summary: $e');
    }
  }

  Future<List<RestaurantTable>> getTables() async {
    try {
      final response = await _supabase
          .from('tables')
          .select()
          .order('table_number', ascending: true);

      return (response as List<dynamic>)
          .map((json) => RestaurantTable.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load tables: $e');
    }
  }

  // ============================================================
  // KITCHEN DISPLAY & ORDER STATUS MANAGEMENT
  // ============================================================

  Stream<List<Order>> getKitchenQueueStream() {
    // Stream data yang baru masuk hari ini agar performa tetap cepat
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((maps) => maps
            .map((map) => Order.fromJson(map))
            .where((order) => order.status == OrderStatus.PAID || order.status == OrderStatus.PREPARING)
            .toList());
  }

  Stream<List<Order>> getReadyOrdersStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'READY')
        .order('preparation_completed_at', ascending: true)
        .map((maps) => maps
            .map((map) => Order.fromJson(map))
            .where((order) => order.status == OrderStatus.READY) // Double check status
            .toList());
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
      };

      if (newStatus == OrderStatus.PREPARING) {
        updateData['preparation_started_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == OrderStatus.READY) {
        updateData['preparation_completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<void> startPreparation(String orderId) async => updateOrderStatus(orderId, OrderStatus.PREPARING);
  Future<void> markAsReady(String orderId) async => updateOrderStatus(orderId, OrderStatus.READY);
  Future<void> markAsServed(String orderId) async => updateOrderStatus(orderId, OrderStatus.SERVED);

  /// Complete order and auto-deduct ingredients from stock
  Future<void> completeOrder(String orderId, {String? createdBy}) async {
    // Update order status to COMPLETED
    await updateOrderStatus(orderId, OrderStatus.COMPLETED);

    // Auto-deduct ingredients based on product recipes
    try {
      await _storageRepository.processOrderDeduction(
        orderId: orderId,
        createdBy: createdBy,
      );
    } catch (e) {
      // Log error but don't fail the order completion
      // Ingredient deduction failure should not block order completion
      print('Warning: Failed to deduct ingredients for order $orderId: $e');
    }
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': 'CANCELLED',
            'cancel_reason': reason,
          })
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // ============================================================
  // PRODUCT SALES REPORT
  // ============================================================
  
  /// Get product sales statistics for a date range
  /// Returns list of products with their total quantity sold
  Future<List<Map<String, dynamic>>> getProductSalesReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Default to today if no dates provided
      final start = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final end = endDate ?? DateTime.now().add(const Duration(days: 1));

      // Query order_items with product info, filtering by order date
      final response = await _supabase
          .from('order_items')
          .select('''
            product_id,
            quantity,
            unit_price,
            subtotal,
            orders!inner(
              created_at,
              status,
              source
            ),
            products(
              name,
              category,
              price
            )
          ''')
          .gte('orders.created_at', start.toIso8601String())
          .lt('orders.created_at', end.toIso8601String())
          .neq('orders.status', 'CANCELLED');

      // Group by product and calculate totals
      final Map<String, Map<String, dynamic>> productStats = {};

      for (var item in response) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        final productData = item['products'] as Map<String, dynamic>;
        final orderData = item['orders'] as Map<String, dynamic>;
        final orderSource = orderData['source'] as String;

        if (!productStats.containsKey(productId)) {
          productStats[productId] = {
            'product_id': productId,
            'product_name': productData['name'],
            'category': productData['category'],
            'base_price': productData['price'],
            'total_quantity': 0,
            'total_revenue': 0.0,
            'online_quantity': 0,
            'pos_quantity': 0,
          };
        }

        productStats[productId]!['total_quantity'] += quantity;
        
        // Track revenue (only for non-online orders since online orders have unit_price = 0)
        final subtotal = (item['subtotal'] ?? 0).toDouble();
        productStats[productId]!['total_revenue'] += subtotal;

        // Track by source
        if (orderSource == 'GOFOOD' || orderSource == 'GRABFOOD' || orderSource == 'SHOPEEFOOD') {
          productStats[productId]!['online_quantity'] += quantity;
        } else {
          productStats[productId]!['pos_quantity'] += quantity;
        }
      }

      // Convert to list and sort by total quantity (most sold first)
      final result = productStats.values.toList();
      result.sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));

      return result;
    } catch (e) {
      throw Exception('Failed to load product sales report: $e');
    }
  }

  // ============================================================
  // MONTHLY ANALYTICS METHODS
  // ============================================================

  /// Get comprehensive monthly analytics data
  Future<Map<String, dynamic>> getMonthlyAnalytics(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String());

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      // Filter out cancelled orders for most metrics
      final completedOrders = orders.where((o) => o.status != OrderStatus.CANCELLED).toList();
      final cancelledOrders = orders.where((o) => o.status == OrderStatus.CANCELLED).toList();

      // Calculate totals
      double totalRevenue = completedOrders.fold(0, (sum, o) => sum + o.totalAmount);
      int totalOrders = completedOrders.length;

      // Payment method breakdown
      double cashRevenue = 0;
      double qrisRevenue = 0;
      double debitRevenue = 0;
      int cashCount = 0;
      int qrisCount = 0;
      int debitCount = 0;

      for (var order in completedOrders) {
        switch (order.paymentMethod) {
          case PaymentMethod.CASH:
            cashRevenue += order.totalAmount;
            cashCount++;
            break;
          case PaymentMethod.QRIS:
            qrisRevenue += order.totalAmount;
            qrisCount++;
            break;
          case PaymentMethod.DEBIT:
            debitRevenue += order.totalAmount;
            debitCount++;
            break;
        }
      }

      // Order type breakdown
      int dineInOrders = completedOrders.where((o) => o.type == OrderType.DINE_IN).length;
      int takeawayOrders = completedOrders.where((o) => o.type == OrderType.TAKEAWAY).length;
      double dineInRevenue = completedOrders
          .where((o) => o.type == OrderType.DINE_IN)
          .fold(0, (sum, o) => sum + o.totalAmount);
      double takeawayRevenue = completedOrders
          .where((o) => o.type == OrderType.TAKEAWAY)
          .fold(0, (sum, o) => sum + o.totalAmount);

      // Loyalty points
      int totalPointsEarned = completedOrders.fold(0, (sum, o) => sum + o.pointsEarned);
      int totalPointsRedeemed = completedOrders.fold(0, (sum, o) => sum + o.pointsRedeemed);

      // Cancelled orders
      double cancelledRevenue = cancelledOrders.fold(0, (sum, o) => sum + o.totalAmount);

      return {
        'total_revenue': totalRevenue,
        'total_orders': totalOrders,
        'average_order_value': totalOrders > 0 ? totalRevenue / totalOrders : 0,
        'cash_revenue': cashRevenue,
        'qris_revenue': qrisRevenue,
        'debit_revenue': debitRevenue,
        'cash_count': cashCount,
        'qris_count': qrisCount,
        'debit_count': debitCount,
        'dine_in_orders': dineInOrders,
        'takeaway_orders': takeawayOrders,
        'dine_in_revenue': dineInRevenue,
        'takeaway_revenue': takeawayRevenue,
        'total_points_earned': totalPointsEarned,
        'total_points_redeemed': totalPointsRedeemed,
        'cancelled_orders': cancelledOrders.length,
        'cancelled_revenue': cancelledRevenue,
      };
    } catch (e) {
      throw Exception('Failed to load monthly analytics: $e');
    }
  }

  /// Get previous month analytics for comparison
  Future<Map<String, dynamic>> getPreviousMonthAnalytics(int year, int month) async {
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    return getMonthlyAnalytics(prevYear, prevMonth);
  }

  /// Get daily revenue breakdown for the month
  Future<List<Map<String, dynamic>>> getDailyRevenue(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .neq('status', 'CANCELLED');

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      // Group by date
      final Map<String, Map<String, dynamic>> dailyData = {};

      for (var order in orders) {
        final dateKey = '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}';

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'date': dateKey,
            'revenue': 0.0,
            'order_count': 0,
          };
        }

        dailyData[dateKey]!['revenue'] = (dailyData[dateKey]!['revenue'] as double) + order.totalAmount;
        dailyData[dateKey]!['order_count'] = (dailyData[dateKey]!['order_count'] as int) + 1;
      }

      final result = dailyData.values.toList();
      result.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      return result;
    } catch (e) {
      throw Exception('Failed to load daily revenue: $e');
    }
  }

  /// Get orders grouped by hour of day
  Future<Map<int, int>> getOrdersByHour(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .neq('status', 'CANCELLED');

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      final Map<int, int> hourlyData = {};

      for (var order in orders) {
        final hour = order.createdAt.hour;
        hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
      }

      return hourlyData;
    } catch (e) {
      throw Exception('Failed to load orders by hour: $e');
    }
  }

  /// Get revenue breakdown by payment method
  Future<Map<String, double>> getRevenueByPaymentMethod(int year, int month) async {
    try {
      final analytics = await getMonthlyAnalytics(year, month);

      return {
        'CASH': analytics['cash_revenue'] as double,
        'QRIS': analytics['qris_revenue'] as double,
        'DEBIT': analytics['debit_revenue'] as double,
      };
    } catch (e) {
      throw Exception('Failed to load revenue by payment method: $e');
    }
  }

  /// Get revenue breakdown by order source
  Future<Map<String, double>> getRevenueBySource(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .neq('status', 'CANCELLED');

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      final Map<String, double> sourceData = {};

      for (var order in orders) {
        final source = order.source.toString().split('.').last;
        sourceData[source] = (sourceData[source] ?? 0) + order.totalAmount;
      }

      return sourceData;
    } catch (e) {
      throw Exception('Failed to load revenue by source: $e');
    }
  }

  /// Get revenue breakdown by product category
  Future<Map<String, double>> getRevenueByCategory(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('order_items')
          .select('''
            product_id,
            quantity,
            subtotal,
            orders!inner(
              created_at,
              status
            ),
            products(
              category
            )
          ''')
          .gte('orders.created_at', startDate.toIso8601String())
          .lt('orders.created_at', endDate.toIso8601String())
          .neq('orders.status', 'CANCELLED');

      final Map<String, double> categoryData = {};

      for (var item in response) {
        final productData = item['products'] as Map<String, dynamic>;
        final category = productData['category'] as String;
        final subtotal = (item['subtotal'] as num).toDouble();

        categoryData[category] = (categoryData[category] ?? 0) + subtotal;
      }

      return categoryData;
    } catch (e) {
      throw Exception('Failed to load revenue by category: $e');
    }
  }

  /// Get loyalty points summary
  Future<Map<String, int>> getLoyaltyPointsSummary(int year, int month) async {
    try {
      final analytics = await getMonthlyAnalytics(year, month);

      return {
        'points_earned': analytics['total_points_earned'] as int,
        'points_redeemed': analytics['total_points_redeemed'] as int,
        'net_points': (analytics['total_points_earned'] as int) - (analytics['total_points_redeemed'] as int),
      };
    } catch (e) {
      throw Exception('Failed to load loyalty points summary: $e');
    }
  }

  /// Get cancelled orders statistics
  Future<Map<String, dynamic>> getCancelledOrdersStats(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .eq('status', 'CANCELLED');

      final cancelledOrders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      double totalCancelled = cancelledOrders.fold(0, (sum, o) => sum + o.totalAmount);

      return {
        'count': cancelledOrders.length,
        'total_amount': totalCancelled,
      };
    } catch (e) {
      throw Exception('Failed to load cancelled orders stats: $e');
    }
  }

  /// Get average preparation time in minutes
  Future<double?> getAveragePreparationTime(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .neq('status', 'CANCELLED')
          .not('preparation_started_at', 'is', null)
          .not('preparation_completed_at', 'is', null);

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      if (orders.isEmpty) return null;

      int totalMinutes = 0;
      int count = 0;

      for (var order in orders) {
        if (order.preparationTime != null) {
          totalMinutes += order.preparationTime!.inMinutes;
          count++;
        }
      }

      return count > 0 ? totalMinutes / count : null;
    } catch (e) {
      throw Exception('Failed to load average preparation time: $e');
    }
  }

  /// Get orders grouped by day of week
  Future<Map<String, int>> getOrdersByDayOfWeek(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .neq('status', 'CANCELLED');

      final orders = (response as List<dynamic>)
          .map((json) => Order.fromJson(json))
          .toList();

      final Map<String, int> dayData = {
        'Monday': 0,
        'Tuesday': 0,
        'Wednesday': 0,
        'Thursday': 0,
        'Friday': 0,
        'Saturday': 0,
        'Sunday': 0,
      };

      const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

      for (var order in orders) {
        final dayOfWeek = order.createdAt.weekday; // 1 = Monday, 7 = Sunday
        final dayName = dayNames[dayOfWeek - 1];
        dayData[dayName] = (dayData[dayName] ?? 0) + 1;
      }

      return dayData;
    } catch (e) {
      throw Exception('Failed to load orders by day of week: $e');
    }
  }

  /// Get top products by quantity and revenue
  Future<List<Map<String, dynamic>>> getTopProducts(int year, int month, {int limit = 10}) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('order_items')
          .select('''
            product_id,
            quantity,
            subtotal,
            orders!inner(
              created_at,
              status
            ),
            products(
              name,
              category
            )
          ''')
          .gte('orders.created_at', startDate.toIso8601String())
          .lt('orders.created_at', endDate.toIso8601String())
          .neq('orders.status', 'CANCELLED');

      final Map<String, Map<String, dynamic>> productStats = {};

      for (var item in response) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        final subtotal = (item['subtotal'] as num).toDouble();
        final productData = item['products'] as Map<String, dynamic>;

        if (!productStats.containsKey(productId)) {
          productStats[productId] = {
            'product_id': productId,
            'product_name': productData['name'],
            'category': productData['category'],
            'total_quantity': 0,
            'total_revenue': 0.0,
            'times_ordered': 0,
          };
        }

        productStats[productId]!['total_quantity'] =
            (productStats[productId]!['total_quantity'] as int) + quantity;
        productStats[productId]!['total_revenue'] =
            (productStats[productId]!['total_revenue'] as double) + subtotal;
        productStats[productId]!['times_ordered'] =
            (productStats[productId]!['times_ordered'] as int) + 1;
      }

      return productStats.values.toList();
    } catch (e) {
      throw Exception('Failed to load top products: $e');
    }
  }

  /// Get total quantity of products sold
  Future<int> getTotalProductsSold(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from('order_items')
          .select('''
            quantity,
            orders!inner(
              created_at,
              status
            )
          ''')
          .gte('orders.created_at', startDate.toIso8601String())
          .lt('orders.created_at', endDate.toIso8601String())
          .neq('orders.status', 'CANCELLED');

      int totalQuantity = 0;
      for (var item in response) {
        totalQuantity += item['quantity'] as int;
      }

      return totalQuantity;
    } catch (e) {
      throw Exception('Failed to load total products sold: $e');
    }
  }
}
