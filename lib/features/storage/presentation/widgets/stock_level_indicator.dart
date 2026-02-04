import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StockLevelIndicator extends StatelessWidget {
  final double currentStock;
  final double minStock;
  final double size;
  final bool showPercentage;

  const StockLevelIndicator({
    super.key,
    required this.currentStock,
    required this.minStock,
    this.size = 48,
    this.showPercentage = false,
  });

  double get _percentage {
    if (minStock <= 0) return 100;
    // Cap at 200% for visual purposes (double the minimum is "full")
    return (currentStock / minStock * 50).clamp(0, 100);
  }

  Color get _color {
    if (currentStock <= 0) return AppColors.errorRed;
    if (currentStock <= minStock) return AppColors.warningYellow;
    if (currentStock <= minStock * 1.5) return AppColors.infoBlue;
    return AppColors.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 4,
              backgroundColor: Colors.grey[200],
              color: Colors.grey[200],
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: _percentage / 100,
              strokeWidth: 4,
              backgroundColor: Colors.transparent,
              color: _color,
            ),
          ),
          // Icon or percentage
          if (showPercentage)
            Text(
              '${_percentage.toInt()}%',
              style: TextStyle(
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            )
          else
            Icon(
              _getIcon(),
              size: size * 0.4,
              color: _color,
            ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (currentStock <= 0) return Icons.error_outline;
    if (currentStock <= minStock) return Icons.warning_amber;
    return Icons.check;
  }
}

class StockLevelBar extends StatelessWidget {
  final double currentStock;
  final double minStock;
  final double height;
  final bool showLabels;

  const StockLevelBar({
    super.key,
    required this.currentStock,
    required this.minStock,
    this.height = 8,
    this.showLabels = false,
  });

  double get _percentage {
    if (minStock <= 0) return 100;
    return (currentStock / minStock * 50).clamp(0, 100);
  }

  Color get _color {
    if (currentStock <= 0) return AppColors.errorRed;
    if (currentStock <= minStock) return AppColors.warningYellow;
    if (currentStock <= minStock * 1.5) return AppColors.infoBlue;
    return AppColors.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Level',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${_percentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: _percentage / 100,
            minHeight: height,
            backgroundColor: Colors.grey[200],
            color: _color,
          ),
        ),
      ],
    );
  }
}
