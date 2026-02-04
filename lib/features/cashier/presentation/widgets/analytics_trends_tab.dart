import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/monthly_analytics_model.dart';
import 'revenue_line_chart.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class AnalyticsTrendsTab extends StatelessWidget {
  final MonthlyAnalyticsModel analytics;

  const AnalyticsTrendsTab({
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
            'Daily Trends',
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
            child: Column(
              children: [
                RevenueLineChart(
                  dailyData: analytics.dailyRevenue,
                  title: 'Daily Revenue',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _DailyOrdersChart(dailyData: analytics.dailyOrders),
          ),
          const SizedBox(height: 24),
          const Text(
            'Revenue by Day of Week',
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
            child: _DayOfWeekBarChart(dayData: analytics.revenueByDayOfWeek),
          ),
          const SizedBox(height: 24),
          const Text(
            'Week-over-Week Comparison',
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
              child: _buildWeekOverWeekTable(analytics),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekOverWeekTable(MonthlyAnalyticsModel analytics) {
    final weeks = _groupByWeek(analytics.dailyRevenue);

    if (weeks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No data available')),
      );
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        Table(
          border: TableBorder.all(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withOpacity(0.1),
              ),
              children: const [
                _TableHeader('Week'),
                _TableHeader('Revenue'),
                _TableHeader('Orders'),
                _TableHeader('Avg'),
              ],
            ),
            ...weeks.asMap().entries.map((entry) {
              final index = entry.key;
              final week = entry.value;

              final prevWeek = index > 0 ? weeks[index - 1] : null;
              final revenueGrowth = prevWeek != null && (prevWeek['revenue'] ?? 0) > 0
                  ? ((week['revenue']! - prevWeek['revenue']!) / prevWeek['revenue']!) * 100
                  : null;

              return TableRow(
                children: [
                  _TableCell('Week ${index + 1}'),
                  _TableCell(
                    formatter.format(week['revenue']),
                    growth: revenueGrowth,
                  ),
                  _TableCell('${week['orders']}'),
                  _TableCell(
                    formatter.format(week['orders']! > 0
                        ? week['revenue']! / week['orders']!
                        : 0),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  List<Map<String, double>> _groupByWeek(List<DailyRevenueData> dailyData) {
    if (dailyData.isEmpty) return [];

    final weeks = <Map<String, double>>[];
    final firstDate = dailyData.first.date;

    int currentWeek = -1;
    double weekRevenue = 0;
    int weekOrders = 0;

    for (var data in dailyData) {
      final daysSinceStart = data.date.difference(firstDate).inDays;
      final week = daysSinceStart ~/ 7;

      if (week != currentWeek) {
        if (currentWeek >= 0) {
          weeks.add({
            'revenue': weekRevenue,
            'orders': weekOrders.toDouble(),
          });
        }
        currentWeek = week;
        weekRevenue = 0;
        weekOrders = 0;
      }

      weekRevenue += data.revenue;
      weekOrders += data.orderCount;
    }

    if (weekRevenue > 0 || weekOrders > 0) {
      weeks.add({
        'revenue': weekRevenue,
        'orders': weekOrders.toDouble(),
      });
    }

    return weeks;
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final double? growth;

  const _TableCell(this.text, {this.growth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (growth != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  growth! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: growth! > 0 ? Colors.green : Colors.red,
                ),
                Text(
                  '${growth!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: growth! > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyOrdersChart extends StatelessWidget {
  final List<DailyOrderData> dailyData;

  const _DailyOrdersChart({required this.dailyData});

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No data available'),
        ),
      );
    }

    final spots = dailyData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.orderCount.toDouble(),
      );
    }).toList();

    final maxOrders = dailyData.map((d) => d.orderCount).reduce((a, b) => a > b ? a : b);
    final minOrders = dailyData.map((d) => d.orderCount).reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Daily Orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: dailyData.length > 15 ? 5 : (dailyData.length > 7 ? 2 : 1),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${dailyData[index].date.day}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: (dailyData.length - 1).toDouble(),
                minY: minOrders * 0.9,
                maxY: maxOrders * 1.1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: FlDotData(show: dailyData.length <= 15),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayOfWeekBarChart extends StatelessWidget {
  final Map<String, double> dayData;

  const _DayOfWeekBarChart({required this.dayData});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final maxRevenue = dayData.values.isEmpty ? 0.0 : dayData.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Revenue by Day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: BarChart(
              BarChartData(
                maxY: maxRevenue * 1.2,
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _formatCurrency(value),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[index].substring(0, 3),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                barGroups: days.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final revenue = dayData[day] ?? 0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenue,
                        color: AppColors.infoBlue,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}
