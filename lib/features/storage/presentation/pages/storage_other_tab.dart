import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import 'recipe_management_page.dart';
import 'stock_movement_page.dart';

/// Tab "Lainnya" — segmented toggle between Resep and Riwayat
class StorageOtherTab extends ConsumerStatefulWidget {
  const StorageOtherTab({super.key});

  @override
  ConsumerState<StorageOtherTab> createState() => _StorageOtherTabState();
}

class _StorageOtherTabState extends ConsumerState<StorageOtherTab> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Segmented control
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegment(0, 'Resep & HPP', Icons.receipt_long_rounded),
                _buildSegment(1, 'Riwayat', Icons.history_rounded),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: IndexedStack(
            index: _selectedSegment,
            children: const [
              RecipeManagementPage(embedded: true),
              StockMovementPage(embedded: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegment(int index, String label, IconData icon) {
    final selected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primaryBlack : Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryBlack : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
