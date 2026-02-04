import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final double? growthPercentage;
  final String? comparisonText;
  final Color? customColor;

  const AnalyticsMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.growthPercentage,
    this.comparisonText,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasGrowth = growthPercentage != null;
    final isPositive = hasGrowth && growthPercentage! > 0;
    final isNegative = hasGrowth && growthPercentage! < 0;
    final isNeutral = hasGrowth && growthPercentage == 0;

    Color growthColor = AppColors.textSecondary;
    IconData? growthIcon;

    if (isPositive) {
      growthColor = Colors.green;
      growthIcon = Icons.trending_up;
    } else if (isNegative) {
      growthColor = Colors.red;
      growthIcon = Icons.trending_down;
    } else if (isNeutral) {
      growthColor = Colors.orange;
      growthIcon = Icons.trending_flat;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (customColor ?? AppColors.infoBlue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: customColor ?? AppColors.infoBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: customColor ?? AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (hasGrowth || comparisonText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasGrowth) ...[
                    Icon(
                      growthIcon,
                      size: 16,
                      color: growthColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${growthPercentage!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: growthColor,
                      ),
                    ),
                  ],
                  if (comparisonText != null) ...[
                    if (hasGrowth) const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        comparisonText!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
