import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/stock_in_sheet.dart';

class StorageDashboardTab extends ConsumerWidget {
  const StorageDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final movementsAsync = ref.watch(stockMovementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storage',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
        ),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          ingredientsAsync.whenOrNull(
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
        child: ingredientsAsync.when(
          data: (ingredients) => _buildDashboard(context, ref, ingredients, movementsAsync),
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
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    List<Ingredient> ingredients,
    AsyncValue<List<StockMovement>> movementsAsync,
  ) {
    final lowStock = ingredients.where((i) => i.isLowStock && !i.isOutOfStock).toList();
    final outOfStock = ingredients.where((i) => i.isOutOfStock).toList();
    final totalValue = ingredients.fold<double>(0, (sum, i) => sum + i.currentStock * i.costPerUnit);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Compact Summary Strip ──
          _buildSummaryStrip(ingredients.length, lowStock.length, outOfStock.length, totalValue),
          const SizedBox(height: 16),

          // ── Critical Alert ──
          if (outOfStock.isNotEmpty || lowStock.isNotEmpty)
            _buildCriticalAlert(context, outOfStock, lowStock),

          // ── Stock In Button ──
          const SizedBox(height: 16),
          _buildStockInButton(context, ref, ingredients),
          const SizedBox(height: 24),

          // ── All Ingredients ──
          _buildIngredientsSection(ingredients),
          const SizedBox(height: 24),

          // ── Recent Activity ──
          movementsAsync.whenOrNull(
            data: (movements) => movements.isNotEmpty
                ? _buildRecentActivity(movements.take(5).toList())
                : const SizedBox.shrink(),
          ) ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

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

  Widget _buildStockInButton(BuildContext context, WidgetRef ref, List<Ingredient> ingredients) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showStockInSheet(context, ref, ingredients),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Stock In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlack,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
        ),
      ),
    );
  }

  void _showStockInSheet(BuildContext context, WidgetRef ref, List<Ingredient> ingredients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StockInSheet(ingredients: ingredients),
    );
  }

  Widget _buildIngredientsSection(List<Ingredient> ingredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Semua Bahan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              '${ingredients.length} items',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...ingredients.map((ing) => _buildIngredientTile(ing)),
      ],
    );
  }

  Widget _buildIngredientTile(Ingredient ing) {
    final status = _getStockStatus(ing);
    final pct = ing.minStock > 0 ? (ing.currentStock / (ing.minStock * 2)).clamp(0.0, 1.0) : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ing.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                '${_formatStock(ing.currentStock)} ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: status.color),
              ),
              Text(
                ing.unit.displayName,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF3F4F6),
              color: status.color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<StockMovement> movements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktivitas Terakhir',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
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
