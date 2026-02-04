import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/storage_models.dart';

class MovementListTile extends StatelessWidget {
  final StockMovement movement;
  final VoidCallback? onTap;

  const MovementListTile({
    super.key,
    required this.movement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getIcon(),
          color: _getColor(),
          size: 22,
        ),
      ),
      title: Text(
        movement.ingredient?.name ?? 'Unknown Ingredient',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            movement.movementType.displayName,
            style: TextStyle(
              fontSize: 12,
              color: _getColor(),
            ),
          ),
          const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
          Text(
            _formatTime(movement.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            movement.quantityDisplay,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: movement.isIncoming ? AppColors.successGreen : AppColors.errorRed,
            ),
          ),
          if (movement.referenceType != null)
            Text(
              movement.referenceType!.displayName,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (movement.movementType) {
      case MovementType.STOCK_IN:
        return AppColors.successGreen;
      case MovementType.AUTO_DEDUCT:
        return AppColors.infoBlue;
      case MovementType.ADJUSTMENT:
        return AppColors.warningYellow;
    }
  }

  IconData _getIcon() {
    switch (movement.movementType) {
      case MovementType.STOCK_IN:
        return Icons.add_box;
      case MovementType.AUTO_DEDUCT:
        return Icons.shopping_cart;
      case MovementType.ADJUSTMENT:
        return Icons.tune;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class MovementSummaryCard extends StatelessWidget {
  final List<StockMovement> movements;
  final String title;

  const MovementSummaryCard({
    super.key,
    required this.movements,
    this.title = 'Recent Movements',
  });

  @override
  Widget build(BuildContext context) {
    double totalIn = 0;
    double totalOut = 0;

    for (final movement in movements) {
      if (movement.isIncoming) {
        totalIn += movement.absoluteQuantity;
      } else {
        totalOut += movement.absoluteQuantity;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.arrow_downward,
                    label: 'Stock In',
                    value: '+${totalIn.toStringAsFixed(2)}',
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.arrow_upward,
                    label: 'Stock Out',
                    value: '-${totalOut.toStringAsFixed(2)}',
                    color: AppColors.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${movements.length} movements',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
