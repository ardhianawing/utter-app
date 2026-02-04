import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class SourcePieChart extends StatelessWidget {
  final Map<String, double> sourceData;
  final String title;

  const SourcePieChart({
    super.key,
    required this.sourceData,
    this.title = 'Order Source Distribution',
  });

  @override
  Widget build(BuildContext context) {
    final totalRevenue = sourceData.values.fold(0.0, (sum, value) => sum + value);

    if (totalRevenue == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No source data available'),
        ),
      );
    }

    final sections = _buildPieSections(totalRevenue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildLegend(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(double total) {
    final List<PieChartSectionData> sections = [];
    final colorMap = {
      'APP': AppColors.infoBlue,
      'POS_MANUAL': Colors.purple,
      'GOFOOD': Colors.green,
      'GRABFOOD': Colors.teal,
      'SHOPEEFOOD': Colors.orange,
      'MANUAL_ENTRY': Colors.grey,
    };

    int colorIndex = 0;
    final fallbackColors = [
      Colors.blue,
      Colors.red,
      Colors.amber,
      Colors.cyan,
      Colors.pink,
    ];

    sourceData.forEach((source, amount) {
      if (amount > 0) {
        final percentage = (amount / total) * 100;
        sections.add(
          PieChartSectionData(
            value: amount,
            title: '${percentage.toStringAsFixed(1)}%',
            color: colorMap[source] ?? fallbackColors[colorIndex++ % fallbackColors.length],
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return sections;
  }

  Widget _buildLegend() {
    final colorMap = {
      'APP': AppColors.infoBlue,
      'POS_MANUAL': Colors.purple,
      'GOFOOD': Colors.green,
      'GRABFOOD': Colors.teal,
      'SHOPEEFOOD': Colors.orange,
      'MANUAL_ENTRY': Colors.grey,
    };

    int colorIndex = 0;
    final fallbackColors = [
      Colors.blue,
      Colors.red,
      Colors.amber,
      Colors.cyan,
      Colors.pink,
    ];

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sourceData.entries.where((e) => e.value > 0).map((entry) {
          final color = colorMap[entry.key] ?? fallbackColors[colorIndex++ % fallbackColors.length];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSourceName(entry.key),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        formatter.format(entry.value),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatSourceName(String source) {
    switch (source) {
      case 'APP':
        return 'App';
      case 'POS_MANUAL':
        return 'POS Manual';
      case 'GOFOOD':
        return 'GoFood';
      case 'GRABFOOD':
        return 'GrabFood';
      case 'SHOPEEFOOD':
        return 'ShopeeFood';
      case 'MANUAL_ENTRY':
        return 'Manual Entry';
      default:
        return source;
    }
  }
}
