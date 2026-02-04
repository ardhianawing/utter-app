import 'package:flutter/material.dart';
import '../../domain/models/monthly_analytics_model.dart';
import 'analytics_metric_card.dart';
import 'revenue_line_chart.dart';
import 'payment_pie_chart.dart';
import 'source_pie_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsOverviewTab extends StatelessWidget {
  final MonthlyAnalyticsModel analytics;

  const AnalyticsOverviewTab({
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
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
                title: 'Total Revenue',
                value: formatter.format(analytics.totalRevenue),
                icon: Icons.attach_money,
                growthPercentage: analytics.revenueGrowth,
                comparisonText: analytics.revenueGrowth != null
                    ? 'from ${analytics.previousMonthName}'
                    : null,
              ),
              AnalyticsMetricCard(
                title: 'Total Orders',
                value: analytics.totalOrders.toString(),
                icon: Icons.shopping_cart,
                growthPercentage: analytics.ordersGrowth,
                comparisonText: analytics.ordersGrowth != null
                    ? 'from ${analytics.previousMonthName}'
                    : null,
              ),
              AnalyticsMetricCard(
                title: 'Average Order Value',
                value: formatter.format(analytics.averageOrderValue),
                icon: Icons.receipt,
                growthPercentage: analytics.aovGrowth,
                comparisonText: analytics.aovGrowth != null
                    ? 'from ${analytics.previousMonthName}'
                    : null,
              ),
              AnalyticsMetricCard(
                title: 'Products Sold',
                value: analytics.totalProductsSold.toString(),
                subtitle: '${(analytics.totalOrders > 0 ? analytics.totalProductsSold / analytics.totalOrders : 0).toStringAsFixed(1)} per order',
                icon: Icons.inventory,
                growthPercentage: analytics.productsSoldGrowth,
                comparisonText: analytics.productsSoldGrowth != null
                    ? 'from ${analytics.previousMonthName}'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: RevenueLineChart(dailyData: analytics.dailyRevenue),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PaymentPieChart(
                    paymentData: {
                      'CASH': analytics.cashRevenue,
                      'QRIS': analytics.qrisRevenue,
                      'DEBIT': analytics.debitRevenue,
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SourcePieChart(
                    sourceData: analytics.revenueBySource,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Stats',
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
                  _buildStatRow(
                    'Cash Transactions',
                    '${analytics.cashCount} orders',
                    formatter.format(analytics.cashRevenue),
                    Icons.money,
                  ),
                  const Divider(),
                  _buildStatRow(
                    'QRIS Transactions',
                    '${analytics.qrisCount} orders',
                    formatter.format(analytics.qrisRevenue),
                    Icons.qr_code,
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Debit Transactions',
                    '${analytics.debitCount} orders',
                    formatter.format(analytics.debitRevenue),
                    Icons.credit_card,
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Loyalty Points Earned',
                    '${analytics.totalPointsEarned} points',
                    '',
                    Icons.star,
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Loyalty Points Redeemed',
                    '${analytics.totalPointsRedeemed} points',
                    '',
                    Icons.redeem,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String title, String subtitle, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: Colors.blue),
          ),
          const SizedBox(width: 12),
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
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
