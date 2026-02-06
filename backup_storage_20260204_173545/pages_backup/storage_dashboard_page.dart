import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import 'ingredient_list_page.dart';
import 'stock_in_page.dart';
import 'stock_movement_page.dart';
import 'recipe_management_page.dart';
import 'stock_adjustment_page.dart';

class StorageDashboardPage extends ConsumerWidget {
  const StorageDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockSummary = ref.watch(stockSummaryProvider);
    final lowStockIngredients = ref.watch(lowStockIngredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage & Inventory'),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(stockSummaryProvider);
              ref.invalidate(lowStockIngredientsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockSummaryProvider);
          ref.invalidate(lowStockIngredientsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stock Summary Cards
              stockSummary.when(
                data: (summary) => _buildSummaryCards(summary),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildErrorCard('Failed to load summary'),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),

              const SizedBox(height: 24),

              // Low Stock Alert
              lowStockIngredients.when(
                data: (ingredients) => ingredients.isNotEmpty
                    ? _buildLowStockAlert(context, ingredients)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // Menu Grid
              const Text(
                'Storage Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMenuGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(StockSummary summary) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          title: 'Total Ingredients',
          value: '${summary.activeIngredients}',
          icon: Icons.inventory_2,
          color: AppColors.infoBlue,
        ),
        _buildSummaryCard(
          title: 'Low Stock',
          value: '${summary.lowStockCount}',
          icon: Icons.warning_amber,
          color: summary.lowStockCount > 0 ? AppColors.errorRed : AppColors.successGreen,
        ),
        _buildSummaryCard(
          title: 'Out of Stock',
          value: '${summary.outOfStockCount}',
          icon: Icons.remove_shopping_cart,
          color: summary.outOfStockCount > 0 ? AppColors.errorRed : AppColors.successGreen,
        ),
        _buildSummaryCard(
          title: 'Stock Value',
          value: 'Rp ${_formatNumber(summary.totalStockValue)}',
          icon: Icons.attach_money,
          color: AppColors.primaryBlack,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            context: context,
            icon: Icons.add_box,
            label: 'Stock In',
            color: AppColors.successGreen,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockInPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            context: context,
            icon: Icons.tune,
            label: 'Adjust',
            color: AppColors.warningYellow,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockAdjustmentPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            context: context,
            icon: Icons.history,
            label: 'History',
            color: AppColors.infoBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockMovementPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert(BuildContext context, List<Ingredient> ingredients) {
    return Card(
      color: AppColors.errorRed.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: AppColors.errorRed),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Low Stock Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.errorRed,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IngredientListPage()),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ingredients.take(3).map((ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ingredient.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    ingredient.stockDisplay,
                    style: TextStyle(
                      color: ingredient.isOutOfStock
                          ? AppColors.errorRed
                          : AppColors.warningYellow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
            if (ingredients.length > 3)
              Text(
                '+ ${ingredients.length - 3} more items',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildMenuCard(
          context: context,
          icon: Icons.inventory_2,
          title: 'Ingredients',
          subtitle: 'Manage raw materials',
          color: AppColors.primaryBlack,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IngredientListPage()),
          ),
        ),
        _buildMenuCard(
          context: context,
          icon: Icons.receipt_long,
          title: 'Recipes',
          subtitle: 'Product recipes & HPP',
          color: AppColors.successGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecipeManagementPage()),
          ),
        ),
        _buildMenuCard(
          context: context,
          icon: Icons.add_box,
          title: 'Stock In',
          subtitle: 'Add new stock',
          color: AppColors.infoBlue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockInPage()),
          ),
        ),
        _buildMenuCard(
          context: context,
          icon: Icons.history,
          title: 'Movements',
          subtitle: 'Stock history',
          color: AppColors.warningYellow,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockMovementPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: AppColors.errorRed.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorRed),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.errorRed),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
