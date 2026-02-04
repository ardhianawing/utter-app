class MonthlyAnalyticsModel {
  // Date range
  final DateTime startDate;
  final DateTime endDate;
  final int year;
  final int month;

  // Overview metrics
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final int totalProductsSold;

  // Month-over-month comparison (nullable for first month)
  final double? previousMonthRevenue;
  final int? previousMonthOrders;
  final double? previousMonthAOV;
  final int? previousMonthProductsSold;

  // Payment breakdown
  final double cashRevenue;
  final double qrisRevenue;
  final double debitRevenue;
  final int cashCount;
  final int qrisCount;
  final int debitCount;

  // Order source breakdown
  final Map<String, double> revenueBySource;
  final Map<String, int> ordersBySource;

  // Order type breakdown
  final int dineInOrders;
  final int takeawayOrders;
  final double dineInRevenue;
  final double takeawayRevenue;

  // Category breakdown
  final Map<String, double> revenueByCategory;
  final Map<String, int> quantityByCategory;

  // Loyalty points
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final int netPoints;

  // Operational metrics
  final int cancelledOrders;
  final double cancelledRevenue;
  final double? averagePreparationTime;

  // Daily trends
  final List<DailyRevenueData> dailyRevenue;
  final List<DailyOrderData> dailyOrders;

  // Hourly distribution
  final Map<int, int> ordersByHour;
  final Map<int, double> revenueByHour;

  // Day of week distribution
  final Map<String, int> ordersByDayOfWeek;
  final Map<String, double> revenueByDayOfWeek;

  // Top products
  final List<ProductPerformance> topProductsByQuantity;
  final List<ProductPerformance> topProductsByRevenue;

  // Shift analytics
  final int totalShifts;
  final double averageShiftDuration;
  final double averageShiftRevenue;
  final int perfectCashReconciliations;
  final int cashDiscrepancies;

  MonthlyAnalyticsModel({
    required this.startDate,
    required this.endDate,
    required this.year,
    required this.month,
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalProductsSold,
    this.previousMonthRevenue,
    this.previousMonthOrders,
    this.previousMonthAOV,
    this.previousMonthProductsSold,
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.debitRevenue,
    required this.cashCount,
    required this.qrisCount,
    required this.debitCount,
    required this.revenueBySource,
    required this.ordersBySource,
    required this.dineInOrders,
    required this.takeawayOrders,
    required this.dineInRevenue,
    required this.takeawayRevenue,
    required this.revenueByCategory,
    required this.quantityByCategory,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.netPoints,
    required this.cancelledOrders,
    required this.cancelledRevenue,
    this.averagePreparationTime,
    required this.dailyRevenue,
    required this.dailyOrders,
    required this.ordersByHour,
    required this.revenueByHour,
    required this.ordersByDayOfWeek,
    required this.revenueByDayOfWeek,
    required this.topProductsByQuantity,
    required this.topProductsByRevenue,
    required this.totalShifts,
    required this.averageShiftDuration,
    required this.averageShiftRevenue,
    required this.perfectCashReconciliations,
    required this.cashDiscrepancies,
  });

  // Computed growth percentages
  double? get revenueGrowth {
    if (previousMonthRevenue == null || previousMonthRevenue == 0) return null;
    return ((totalRevenue - previousMonthRevenue!) / previousMonthRevenue!) * 100;
  }

  double? get ordersGrowth {
    if (previousMonthOrders == null || previousMonthOrders == 0) return null;
    return ((totalOrders - previousMonthOrders!) / previousMonthOrders!) * 100;
  }

  double? get aovGrowth {
    if (previousMonthAOV == null || previousMonthAOV == 0) return null;
    return ((averageOrderValue - previousMonthAOV!) / previousMonthAOV!) * 100;
  }

  double? get productsSoldGrowth {
    if (previousMonthProductsSold == null || previousMonthProductsSold == 0) return null;
    return ((totalProductsSold - previousMonthProductsSold!) / previousMonthProductsSold!) * 100;
  }

  // Helper getters
  double get cancelRate => totalOrders > 0 ? (cancelledOrders / totalOrders) * 100 : 0;

  double get cashPercentage => totalRevenue > 0 ? (cashRevenue / totalRevenue) * 100 : 0;
  double get qrisPercentage => totalRevenue > 0 ? (qrisRevenue / totalRevenue) * 100 : 0;
  double get debitPercentage => totalRevenue > 0 ? (debitRevenue / totalRevenue) * 100 : 0;

  double get dineInPercentage => totalOrders > 0 ? (dineInOrders / totalOrders) * 100 : 0;
  double get takeawayPercentage => totalOrders > 0 ? (takeawayOrders / totalOrders) * 100 : 0;

  double get cashReconciliationRate => totalShifts > 0
      ? (perfectCashReconciliations / totalShifts) * 100
      : 0;

  String get monthName {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  String get previousMonthName {
    final prevMonth = month == 1 ? 12 : month - 1;
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[prevMonth];
  }

  // Peak hour
  int? get peakHour {
    if (ordersByHour.isEmpty) return null;
    return ordersByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Best day of week
  String? get bestDayOfWeek {
    if (revenueByDayOfWeek.isEmpty) return null;
    return revenueByDayOfWeek.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Export to Markdown for AI Analysis
  String toAiContext() {
    final buffer = StringBuffer();
    buffer.writeln('# BUSINESS PERFORMANCE REPORT: $monthName $year');
    buffer.writeln('\n## KEY METRICS');
    buffer.writeln('- Total Revenue: Rp ${totalRevenue.toStringAsFixed(0)}');
    buffer.writeln('- Total Orders: $totalOrders');
    buffer.writeln('- Avg Order Value: Rp ${averageOrderValue.toStringAsFixed(0)}');
    buffer.writeln('- Products Sold: $totalProductsSold');
    
    if (revenueGrowth != null) {
      buffer.writeln('- Revenue Growth: ${revenueGrowth!.toStringAsFixed(1)}% vs $previousMonthName');
    }

    buffer.writeln('\n## PAYMENT & SOURCES');
    buffer.writeln('- Cash: Rp ${cashRevenue.toStringAsFixed(0)} (${cashPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('- QRIS: Rp ${qrisRevenue.toStringAsFixed(0)} (${qrisPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('- Dine-In: $dineInOrders orders (${dineInPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('- Takeaway: $takeawayOrders orders (${takeawayPercentage.toStringAsFixed(1)}%)');

    buffer.writeln('\n## TOP PRODUCTS (BY REVENUE)');
    for (var i = 0; i < topProductsByRevenue.length && i < 5; i++) {
      final p = topProductsByRevenue[i];
      buffer.writeln('${i + 1}. ${p.productName}: ${p.totalQuantity} units sold, Rp ${p.totalRevenue.toStringAsFixed(0)}');
    }

    buffer.writeln('\n## OPERATIONAL STATS');
    buffer.writeln('- Peak Hour: ${peakHour != null ? "$peakHour:00" : "N/A"}');
    buffer.writeln('- Best Day: $bestDayOfWeek');
    buffer.writeln('- Avg Prep Time: ${averagePreparationTime?.toStringAsFixed(1) ?? "N/A"} mins');
    buffer.writeln('- Cancellation Rate: ${cancelRate.toStringAsFixed(1)}%');
    buffer.writeln('- Cash Discrepancies: $cashDiscrepancies across $totalShifts shifts');

    return buffer.toString();
  }
}

class DailyRevenueData {
  final DateTime date;
  final double revenue;
  final int orderCount;

  DailyRevenueData({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });

  factory DailyRevenueData.fromJson(Map<String, dynamic> json) {
    return DailyRevenueData(
      date: DateTime.parse(json['date'] as String),
      revenue: (json['revenue'] as num).toDouble(),
      orderCount: json['order_count'] as int,
    );
  }
}

class DailyOrderData {
  final DateTime date;
  final int orderCount;
  final double revenue;

  DailyOrderData({
    required this.date,
    required this.orderCount,
    required this.revenue,
  });

  factory DailyOrderData.fromJson(Map<String, dynamic> json) {
    return DailyOrderData(
      date: DateTime.parse(json['date'] as String),
      orderCount: json['order_count'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

class ProductPerformance {
  final String productId;
  final String productName;
  final String category;
  final int totalQuantity;
  final double totalRevenue;
  final int timesOrdered;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.timesOrdered,
  });

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String,
      totalQuantity: json['total_quantity'] as int,
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      timesOrdered: json['times_ordered'] as int,
    );
  }
}
