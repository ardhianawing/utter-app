import 'package:flutter/material.dart';
import '../../domain/models/monthly_analytics_model.dart';
import 'analytics_metric_card.dart';
import 'hourly_bar_chart.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class AnalyticsOperationsTab extends StatelessWidget {
  final MonthlyAnalyticsModel analytics;

  const AnalyticsOperationsTab({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final peakDay = analytics.bestDayOfWeek ?? 'N/A';
    final peakHour = analytics.peakHour;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              AnalyticsMetricCard(
                title: 'Total Shifts',
                value: analytics.totalShifts.toString(),
                icon: Icons.access_time,
              ),
              AnalyticsMetricCard(
                title: 'Avg Shift Duration',
                value: '${(analytics.averageShiftDuration / 60).toStringAsFixed(1)}h',
                subtitle: '${analytics.averageShiftDuration.toStringAsFixed(0)} minutes',
                icon: Icons.timelapse,
              ),
              AnalyticsMetricCard(
                title: 'Avg Shift Revenue',
                value: formatter.format(analytics.averageShiftRevenue),
                icon: Icons.trending_up,
              ),
              AnalyticsMetricCard(
                title: 'Cash Reconciliation',
                value: '${analytics.cashReconciliationRate.toStringAsFixed(1)}%',
                subtitle: '${analytics.perfectCashReconciliations} perfect matches',
                icon: Icons.check_circle,
                customColor: analytics.cashReconciliationRate >= 90
                    ? Colors.green
                    : analytics.cashReconciliationRate >= 70
                        ? Colors.orange
                        : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash Reconciliation Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReconciliationCard(
                          'Perfect Matches',
                          analytics.perfectCashReconciliations.toString(),
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReconciliationCard(
                          'Discrepancies',
                          analytics.cashDiscrepancies.toString(),
                          Colors.orange,
                          Icons.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: HourlyBarChart(
              hourlyData: analytics.ordersByHour,
              title: 'Orders by Hour (Peak Time Analysis)',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Operational Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMetricRow(
                    'Average Preparation Time',
                    analytics.averagePreparationTime != null
                        ? '${analytics.averagePreparationTime!.toStringAsFixed(1)} min'
                        : 'N/A',
                    Icons.timer,
                    Colors.blue,
                  ),
                  const Divider(),
                  _buildMetricRow(
                    'Cancellation Rate',
                    '${analytics.cancelRate.toStringAsFixed(1)}%',
                    Icons.cancel,
                    analytics.cancelRate > 10 ? Colors.red : Colors.green,
                    subtitle: '${analytics.cancelledOrders} cancelled orders',
                  ),
                  const Divider(),
                  _buildMetricRow(
                    'Peak Hour',
                    peakHour != null ? _formatHour(peakHour) : 'N/A',
                    Icons.trending_up,
                    Colors.purple,
                    subtitle: peakHour != null
                        ? '${analytics.ordersByHour[peakHour]} orders'
                        : null,
                  ),
                  const Divider(),
                  _buildMetricRow(
                    'Best Day of Week',
                    peakDay,
                    Icons.calendar_today,
                    Colors.orange,
                    subtitle: analytics.revenueByDayOfWeek[peakDay] != null
                        ? formatter.format(analytics.revenueByDayOfWeek[peakDay])
                        : null,
                  ),
                  const Divider(),
                  _buildMetricRow(
                    'Dine-In Orders',
                    '${analytics.dineInOrders} (${analytics.dineInPercentage.toStringAsFixed(1)}%)',
                    Icons.restaurant,
                    Colors.teal,
                  ),
                  const Divider(),
                  _buildMetricRow(
                    'Takeaway Orders',
                    '${analytics.takeawayOrders} (${analytics.takeawayPercentage.toStringAsFixed(1)}%)',
                    Icons.takeout_dining,
                    Colors.indigo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}
