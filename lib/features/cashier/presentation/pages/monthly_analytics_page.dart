import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/services/analytics_pdf_service.dart';
import '../../domain/models/monthly_analytics_model.dart';
import '../widgets/month_selector_widget.dart';
import '../widgets/analytics_overview_tab.dart';
import '../widgets/analytics_products_tab.dart';
import '../widgets/analytics_operations_tab.dart';
import '../widgets/analytics_trends_tab.dart';
import '../../../../core/constants/app_colors.dart';

class MonthlyAnalyticsPage extends ConsumerStatefulWidget {
  const MonthlyAnalyticsPage({super.key});

  @override
  ConsumerState<MonthlyAnalyticsPage> createState() => _MonthlyAnalyticsPageState();
}

class _MonthlyAnalyticsPageState extends ConsumerState<MonthlyAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;

  MonthlyAnalyticsModel? _analytics;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderRepo = OrderRepository(Supabase.instance.client);
      final shiftRepo = ShiftRepository(Supabase.instance.client);

      // Fetch all data in parallel
      final results = await Future.wait([
        orderRepo.getMonthlyAnalytics(_selectedYear, _selectedMonth),
        orderRepo.getPreviousMonthAnalytics(_selectedYear, _selectedMonth),
        orderRepo.getDailyRevenue(_selectedYear, _selectedMonth),
        orderRepo.getOrdersByHour(_selectedYear, _selectedMonth),
        orderRepo.getRevenueBySource(_selectedYear, _selectedMonth),
        orderRepo.getRevenueByCategory(_selectedYear, _selectedMonth),
        orderRepo.getOrdersByDayOfWeek(_selectedYear, _selectedMonth),
        orderRepo.getTopProducts(_selectedYear, _selectedMonth),
        orderRepo.getTotalProductsSold(_selectedYear, _selectedMonth),
        orderRepo.getAveragePreparationTime(_selectedYear, _selectedMonth),
        shiftRepo.getMonthlyShiftAnalytics(_selectedYear, _selectedMonth),
        shiftRepo.getCashReconciliationSummary(_selectedYear, _selectedMonth),
      ]);

      final currentMonth = results[0] as Map<String, dynamic>;
      final previousMonth = results[1] as Map<String, dynamic>;
      final dailyRevenue = results[2] as List<Map<String, dynamic>>;
      final ordersByHour = results[3] as Map<int, int>;
      final revenueBySource = results[4] as Map<String, double>;
      final revenueByCategory = results[5] as Map<String, double>;
      final ordersByDayOfWeek = results[6] as Map<String, int>;
      final topProducts = results[7] as List<Map<String, dynamic>>;
      final totalProductsSold = results[8] as int;
      final avgPrepTime = results[9] as double?;
      final shiftAnalytics = results[10] as Map<String, dynamic>;
      final cashReconciliation = results[11] as Map<String, int>;

      // Calculate revenue by day of week
      final revenueByDayOfWeek = <String, double>{};
      for (var entry in ordersByDayOfWeek.entries) {
        revenueByDayOfWeek[entry.key] = 0;
      }

      for (var daily in dailyRevenue) {
        final date = DateTime.parse(daily['date'] as String);
        const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final dayName = dayNames[date.weekday - 1];
        revenueByDayOfWeek[dayName] = (revenueByDayOfWeek[dayName] ?? 0) + (daily['revenue'] as num).toDouble();
      }

      // Calculate category quantity (not available from current queries, so using empty map)
      final quantityByCategory = <String, int>{};

      // Calculate orders by source
      final ordersBySource = <String, int>{};
      // This would require additional query, using placeholder
      for (var source in revenueBySource.keys) {
        ordersBySource[source] = 0; // Placeholder
      }

      // Calculate hourly revenue (not available, using placeholder)
      final revenueByHour = <int, double>{};
      for (var hour in ordersByHour.keys) {
        revenueByHour[hour] = 0; // Placeholder
      }

      final analytics = MonthlyAnalyticsModel(
        startDate: DateTime(_selectedYear, _selectedMonth, 1),
        endDate: DateTime(_selectedYear, _selectedMonth + 1, 1),
        year: _selectedYear,
        month: _selectedMonth,
        totalRevenue: currentMonth['total_revenue'] as double,
        totalOrders: currentMonth['total_orders'] as int,
        averageOrderValue: currentMonth['average_order_value'] as double,
        totalProductsSold: totalProductsSold,
        previousMonthRevenue: previousMonth['total_revenue'] as double?,
        previousMonthOrders: previousMonth['total_orders'] as int?,
        previousMonthAOV: previousMonth['average_order_value'] as double?,
        previousMonthProductsSold: null, // Would need separate query
        cashRevenue: currentMonth['cash_revenue'] as double,
        qrisRevenue: currentMonth['qris_revenue'] as double,
        debitRevenue: currentMonth['debit_revenue'] as double,
        cashCount: currentMonth['cash_count'] as int,
        qrisCount: currentMonth['qris_count'] as int,
        debitCount: currentMonth['debit_count'] as int,
        revenueBySource: revenueBySource,
        ordersBySource: ordersBySource,
        dineInOrders: currentMonth['dine_in_orders'] as int,
        takeawayOrders: currentMonth['takeaway_orders'] as int,
        dineInRevenue: currentMonth['dine_in_revenue'] as double,
        takeawayRevenue: currentMonth['takeaway_revenue'] as double,
        revenueByCategory: revenueByCategory,
        quantityByCategory: quantityByCategory,
        totalPointsEarned: currentMonth['total_points_earned'] as int,
        totalPointsRedeemed: currentMonth['total_points_redeemed'] as int,
        netPoints: (currentMonth['total_points_earned'] as int) - (currentMonth['total_points_redeemed'] as int),
        cancelledOrders: currentMonth['cancelled_orders'] as int,
        cancelledRevenue: currentMonth['cancelled_revenue'] as double,
        averagePreparationTime: avgPrepTime,
        dailyRevenue: dailyRevenue.map((d) => DailyRevenueData.fromJson(d)).toList(),
        dailyOrders: dailyRevenue.map((d) => DailyOrderData.fromJson(d)).toList(),
        ordersByHour: ordersByHour,
        revenueByHour: revenueByHour,
        ordersByDayOfWeek: ordersByDayOfWeek,
        revenueByDayOfWeek: revenueByDayOfWeek,
        topProductsByQuantity: topProducts
            .map((p) => ProductPerformance.fromJson(p))
            .toList()
          ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity)),
        topProductsByRevenue: topProducts
            .map((p) => ProductPerformance.fromJson(p))
            .toList()
          ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue)),
        totalShifts: shiftAnalytics['total_shifts'] as int,
        averageShiftDuration: shiftAnalytics['average_duration_minutes'] as double,
        averageShiftRevenue: shiftAnalytics['average_revenue'] as double,
        perfectCashReconciliations: cashReconciliation['perfect_matches'] as int,
        cashDiscrepancies: cashReconciliation['discrepancies'] as int,
      );

      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadAnalytics,
            ),
          ),
        );
      }
    }
  }

  void _onMonthChanged(int year, int month) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
    });
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Analytics'),
        backgroundColor: AppColors.infoBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Products'),
            Tab(text: 'Operations'),
            Tab(text: 'Trends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Copy for AI Analysis',
            onPressed: _analytics != null ? _copyToAi : null,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: _analytics != null ? _exportToPDF : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: Column(
          children: [
            MonthSelectorWidget(
              selectedYear: _selectedYear,
              selectedMonth: _selectedMonth,
              onMonthChanged: _onMonthChanged,
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading analytics...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.infoBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_analytics == null) {
      return const Center(
        child: Text('No data available for this month'),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        AnalyticsOverviewTab(analytics: _analytics!),
        AnalyticsProductsTab(analytics: _analytics!),
        AnalyticsOperationsTab(analytics: _analytics!),
        AnalyticsTrendsTab(analytics: _analytics!),
      ],
    );
  }

  Future<void> _exportToPDF() async {
    if (_analytics == null) return;

    try {
      await AnalyticsPdfService.exportMonthlyReport(analytics: _analytics!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToAi() async {
    if (_analytics == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _analytics!.toAiContext()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data copied! Paste it into your AI (ChatGPT/Gemini) for analysis.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
