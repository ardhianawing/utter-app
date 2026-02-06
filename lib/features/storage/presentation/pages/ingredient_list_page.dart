import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/stock_in_sheet.dart';
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
        title: const Text(
          'Bahan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
        ),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(ingredientsStreamProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari bahan...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(ingredientSearchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Semua', StockFilter.all, stockFilter, ref),
                const SizedBox(width: 8),
                _buildFilterChip('Low Stock', StockFilter.lowStock, stockFilter, ref, color: AppColors.warningYellow),
                const SizedBox(width: 8),
                _buildFilterChip('Habis', StockFilter.outOfStock, stockFilter, ref, color: AppColors.errorRed),
                const SizedBox(width: 8),
                _buildFilterChip('Aman', StockFilter.healthy, stockFilter, ref, color: AppColors.successGreen),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: ingredientsAsync.when(
              data: (ingredients) {
                if (ingredients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty ? 'Tidak ditemukan' : 'Belum ada bahan',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) => _buildIngredientCard(context, ref, ingredients[index], ingredients),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final allIngredients = ref.read(ingredientsStreamProvider).valueOrNull ?? [];
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => StockInSheet(ingredients: allIngredients),
          );
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Stock In', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildFilterChip(String label, StockFilter filter, StockFilter current, WidgetRef ref, {Color? color}) {
    final selected = current == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(stockFilterProvider.notifier).state = filter,
      selectedColor: color ?? AppColors.primaryBlack,
      labelStyle: TextStyle(
        color: selected ? Colors.white : (color ?? AppColors.textSecondary),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: selected ? (color ?? AppColors.primaryBlack) : const Color(0xFFE5E7EB)),
    );
  }

  Widget _buildIngredientCard(BuildContext context, WidgetRef ref, Ingredient ing, List<Ingredient> allIngredients) {
    final status = _getStatus(ing);
    final pct = ing.minStock > 0 ? (ing.currentStock / (ing.minStock * 2)).clamp(0.0, 1.0) : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showIngredientActions(context, ref, ing, allIngredients),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
            ],
            border: Border(left: BorderSide(color: status.color, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ing.costDisplay,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                            if (ing.supplierName != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                ing.supplierName!,
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatStock(ing.currentStock),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: status.color),
                      ),
                      Text(
                        ing.unit.displayName,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: const Color(0xFFF3F4F6),
                        color: status.color,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Min: ${ing.minStock.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIngredientActions(BuildContext context, WidgetRef ref, Ingredient ing, List<Ingredient> allIngredients) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              Text(
                '${_formatStock(ing.currentStock)} ${ing.unit.displayName} • ${ing.costDisplay}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              _buildActionTile(
                icon: Icons.add_box_rounded,
                color: AppColors.successGreen,
                title: 'Stock In',
                subtitle: 'Tambah stok bahan ini',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => StockInSheet(ingredients: allIngredients, preSelected: ing),
                  );
                },
              ),
              _buildActionTile(
                icon: Icons.edit_rounded,
                color: AppColors.infoBlue,
                title: 'Edit',
                subtitle: 'Ubah nama, satuan, atau minimum stok',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => IngredientFormDialog(
                      ingredient: ing,
                      onSave: (data) async {
                        await ref.read(ingredientNotifierProvider.notifier).updateIngredient(
                          ingredientId: ing.id,
                          name: data['name'],
                          unit: data['unit'] as IngredientUnit?,
                          costPerUnit: data['costPerUnit'] != null ? data['costPerUnit'] as double? : null,
                          minStock: data['minStock'] != null ? data['minStock'] as double? : null,
                          supplierName: data['supplierName'],
                        );
                        ref.invalidate(ingredientsStreamProvider);
                      },
                    ),
                  );
                },
              ),
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                color: AppColors.errorRed,
                title: 'Hapus',
                subtitle: 'Nonaktifkan bahan ini',
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus bahan?'),
                      content: Text('${ing.name} akan dinonaktifkan.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(ingredientNotifierProvider.notifier).deleteIngredient(ing.id);
                    ref.invalidate(ingredientsStreamProvider);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      onTap: onTap,
    );
  }

  _Status _getStatus(Ingredient ing) {
    if (ing.isOutOfStock) return _Status(AppColors.errorRed, 'Habis');
    if (ing.isLowStock) return _Status(AppColors.warningYellow, 'Low');
    if (ing.currentStock <= ing.minStock * 1.5) return _Status(AppColors.infoBlue, 'OK');
    return _Status(AppColors.successGreen, 'Aman');
  }

  String _formatStock(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

class _Status {
  final Color color;
  final String label;
  const _Status(this.color, this.label);
}
