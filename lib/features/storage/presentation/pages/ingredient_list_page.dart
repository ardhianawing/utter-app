import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/ingredient_form_dialog.dart';

class IngredientListPage extends ConsumerStatefulWidget {
  const IngredientListPage({super.key});

  @override
  ConsumerState<IngredientListPage> createState() => _IngredientListPageState();
}

class _IngredientListPageState extends ConsumerState<IngredientListPage> {
  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(stockFilteredIngredientsProvider);
    final searchQuery = ref.watch(ingredientSearchQueryProvider);
    final stockFilter = ref.watch(stockFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients'),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ingredientsStreamProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                ref.read(ingredientSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  selected: stockFilter == StockFilter.all,
                  onSelected: () => ref.read(stockFilterProvider.notifier).state = StockFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Low Stock',
                  selected: stockFilter == StockFilter.lowStock,
                  onSelected: () => ref.read(stockFilterProvider.notifier).state = StockFilter.lowStock,
                  color: AppColors.warningYellow,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Out of Stock',
                  selected: stockFilter == StockFilter.outOfStock,
                  onSelected: () => ref.read(stockFilterProvider.notifier).state = StockFilter.outOfStock,
                  color: AppColors.errorRed,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Healthy',
                  selected: stockFilter == StockFilter.healthy,
                  onSelected: () => ref.read(stockFilterProvider.notifier).state = StockFilter.healthy,
                  color: AppColors.successGreen,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ingredient List
          Expanded(
            child: ingredientsAsync.when(
              data: (ingredients) {
                if (ingredients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No ingredients found'
                              : 'No ingredients yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showIngredientForm(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Ingredient'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = ingredients[index];
                    return IngredientCard(
                      ingredient: ingredient,
                      onTap: () => _showIngredientDetails(context, ingredient),
                      onEdit: () => _showIngredientForm(context, ingredient: ingredient),
                      onDelete: () => _confirmDelete(context, ingredient),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(ingredientsStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIngredientForm(context),
        backgroundColor: AppColors.successGreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Ingredient'),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? AppColors.primaryBlack).withOpacity(0.2),
      checkmarkColor: color ?? AppColors.primaryBlack,
      labelStyle: TextStyle(
        color: selected ? (color ?? AppColors.primaryBlack) : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _showIngredientForm(BuildContext context, {Ingredient? ingredient}) {
    showDialog(
      context: context,
      builder: (context) => IngredientFormDialog(
        ingredient: ingredient,
        onSave: (data) async {
          final notifier = ref.read(ingredientNotifierProvider.notifier);

          bool success;
          if (ingredient == null) {
            success = await notifier.createIngredient(
              name: data['name'],
              unit: data['unit'],
              currentStock: data['currentStock'] ?? 0,
              costPerUnit: data['costPerUnit'] ?? 0,
              minStock: data['minStock'] ?? 0,
              supplierName: data['supplierName'],
            );
          } else {
            success = await notifier.updateIngredient(
              ingredientId: ingredient.id,
              name: data['name'],
              unit: data['unit'],
              costPerUnit: data['costPerUnit'],
              minStock: data['minStock'],
              supplierName: data['supplierName'],
            );
          }

          if (success && context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ingredient == null
                    ? 'Ingredient created successfully'
                    : 'Ingredient updated successfully'),
              ),
            );
          }
        },
      ),
    );
  }

  void _showIngredientDetails(BuildContext context, Ingredient ingredient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ingredient.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (ingredient.supplierName != null)
                Text(
                  'Supplier: ${ingredient.supplierName}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 24),
              _buildDetailRow('Current Stock', ingredient.stockDisplay),
              _buildDetailRow('Minimum Stock', '${ingredient.minStock} ${ingredient.unit.displayName}'),
              _buildDetailRow('Cost per Unit', ingredient.costDisplay),
              _buildDetailRow('Status', ingredient.isLowStock ? 'Low Stock' : 'Normal',
                  color: ingredient.isLowStock ? AppColors.errorRed : AppColors.successGreen),
              _buildDetailRow('Last Updated', _formatDateTime(ingredient.updatedAt)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showIngredientForm(context, ingredient: ingredient);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to stock in with this ingredient pre-selected
                      },
                      icon: const Icon(Icons.add_box),
                      label: const Text('Add Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Ingredient ingredient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ingredient'),
        content: Text('Are you sure you want to delete "${ingredient.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(ingredientNotifierProvider.notifier)
                  .deleteIngredient(ingredient.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingredient deleted successfully')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
