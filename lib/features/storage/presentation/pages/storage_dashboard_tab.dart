import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/stock_in_sheet.dart';
import '../widgets/ingredient_form_dialog.dart';

/// Tab "Stok" — merged dashboard summary + ingredient list with search/filter/actions
class StorageDashboardTab extends ConsumerStatefulWidget {
  const StorageDashboardTab({super.key});

  @override
  ConsumerState<StorageDashboardTab> createState() => _StorageDashboardTabState();
}

class _StorageDashboardTabState extends ConsumerState<StorageDashboardTab> {
  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(stockFilteredIngredientsProvider);
    final allIngredientsAsync = ref.watch(ingredientsStreamProvider);
    final movementsAsync = ref.watch(stockMovementsStreamProvider);
    final searchQuery = ref.watch(ingredientSearchQueryProvider);
    final stockFilter = ref.watch(stockFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storage',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
        ),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          allIngredientsAsync.whenOrNull(
            data: (ingredients) {
              final criticalCount = ingredients.where((i) => i.isLowStock).length;
              if (criticalCount == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$criticalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ingredientsStreamProvider);
          ref.invalidate(stockMovementsStreamProvider);
        },
        child: allIngredientsAsync.when(
          data: (allIngredients) => _buildBody(
            context, ref, allIngredients, ingredientsAsync, movementsAsync, searchQuery, stockFilter,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
                const SizedBox(height: 16),
                Text('Gagal memuat data', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(ingredientsStreamProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Ingredient> allIngredients,
    AsyncValue<List<Ingredient>> filteredAsync,
    AsyncValue<List<StockMovement>> movementsAsync,
    String searchQuery,
    StockFilter stockFilter,
  ) {
    final lowStock = allIngredients.where((i) => i.isLowStock && !i.isOutOfStock).toList();
    final outOfStock = allIngredients.where((i) => i.isOutOfStock).toList();
    final totalValue = allIngredients.fold<double>(0, (sum, i) => sum + i.currentStock * i.costPerUnit);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Summary Strip ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildSummaryStrip(allIngredients.length, lowStock.length, outOfStock.length, totalValue),
          ),
        ),

        // ── Critical Alert ──
        if (outOfStock.isNotEmpty || lowStock.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildCriticalAlert(context, outOfStock, lowStock),
            ),
          ),

        // ── Recent Activity (3 items) ──
        SliverToBoxAdapter(
          child: movementsAsync.whenOrNull(
            data: (movements) => movements.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildRecentActivity(movements.take(3).toList()),
                  )
                : const SizedBox.shrink(),
          ) ?? const SizedBox.shrink(),
        ),

        // ── Search Bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
        ),

        // ── Filter Chips ──
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
        ),

        // ── Ingredient List ──
        filteredAsync.when(
          data: (ingredients) {
            if (ingredients.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildIngredientCard(context, ref, ingredients[index], allIngredients),
                  childCount: ingredients.length,
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SliverFillRemaining(
            child: Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // ── Summary Strip ──

  Widget _buildSummaryStrip(int total, int low, int outOf, double value) {
    return Row(
      children: [
        _buildSummaryChip('Bahan', '$total', AppColors.infoBlue),
        const SizedBox(width: 8),
        _buildSummaryChip('Low', '$low', low > 0 ? AppColors.warningYellow : AppColors.successGreen),
        const SizedBox(width: 8),
        _buildSummaryChip('Habis', '$outOf', outOf > 0 ? AppColors.errorRed : AppColors.successGreen),
        const SizedBox(width: 8),
        _buildSummaryChip('Nilai', _formatCompactRp(value), AppColors.primaryBlack),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Critical Alert ──

  Widget _buildCriticalAlert(BuildContext context, List<Ingredient> outOfStock, List<Ingredient> lowStock) {
    final isOutOfStock = outOfStock.isNotEmpty;
    final alertColor = isOutOfStock ? AppColors.errorRed : AppColors.warningYellow;
    final items = [...outOfStock, ...lowStock].take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.08),
        border: Border.all(color: alertColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOutOfStock ? Icons.error_rounded : Icons.warning_amber_rounded,
                color: alertColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Perlu Perhatian',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: alertColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final ing = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0x0D000000)))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ing.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    ing.isOutOfStock ? 'HABIS' : '${ing.currentStock.toStringAsFixed(0)} ${ing.unit.displayName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ing.isOutOfStock ? AppColors.errorRed : AppColors.warningYellow,
                    ),
                  ),
                ],
              ),
            );
          }),
          if ([...outOfStock, ...lowStock].length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${[...outOfStock, ...lowStock].length - 4} lainnya',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Recent Activity ──

  Widget _buildRecentActivity(List<StockMovement> movements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktivitas Terakhir',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            children: movements.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final isStockIn = m.movementType == MovementType.STOCK_IN;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: i < movements.length - 1
                      ? const Border(bottom: BorderSide(color: Color(0xFFF9FAFB)))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isStockIn ? AppColors.successGreen.withOpacity(0.1) : AppColors.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isStockIn ? Icons.inventory_2_rounded : Icons.trending_down_rounded,
                        size: 16,
                        color: isStockIn ? AppColors.successGreen : AppColors.errorRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.ingredient?.name ?? 'Unknown',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${m.movementType.displayName} • ${_formatTime(m.createdAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      m.quantityDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: m.isIncoming ? AppColors.successGreen : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Filter Chips ──

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

  // ── Ingredient Cards (from IngredientListPage) ──

  Widget _buildIngredientCard(BuildContext context, WidgetRef ref, Ingredient ing, List<Ingredient> allIngredients) {
    final status = _getStockStatus(ing);
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

  // ── Ingredient Actions Bottom Sheet ──

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

  // ── Helpers ──

  _StockStatus _getStockStatus(Ingredient ing) {
    if (ing.isOutOfStock) return _StockStatus(AppColors.errorRed, 'Habis');
    if (ing.isLowStock) return _StockStatus(AppColors.warningYellow, 'Low');
    if (ing.currentStock <= ing.minStock * 1.5) return _StockStatus(AppColors.infoBlue, 'OK');
    return _StockStatus(AppColors.successGreen, 'Aman');
  }

  String _formatStock(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }

  String _formatCompactRp(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

class _StockStatus {
  final Color color;
  final String label;
  const _StockStatus(this.color, this.label);
}
