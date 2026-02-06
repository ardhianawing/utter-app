import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

class SimulationSheet extends ConsumerStatefulWidget {
  final List<Product> products;
  final List<Ingredient> ingredients;

  const SimulationSheet({super.key, required this.products, required this.ingredients});

  @override
  ConsumerState<SimulationSheet> createState() => _SimulationSheetState();
}

class _SimulationSheetState extends ConsumerState<SimulationSheet> {
  Product? _selectedProduct;
  int _simQty = 1;
  _SimulationResult? _result;
  bool _isRunning = false;

  List<Product> get _productsWithRecipe => widget.products.where((p) => p.isActive).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.science_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Simulasi Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Lihat dampak order terhadap stok', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Pick product
                Text('Pilih menu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),
                ..._productsWithRecipe.map(_buildProductOption),
                const SizedBox(height: 20),

                // Qty
                if (_selectedProduct != null) ...[
                  Text('Jumlah pesanan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  _buildQtyRow(),
                  const SizedBox(height: 20),
                ],

                // Run button
                if (_selectedProduct != null && _result == null)
                  ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runSimulation,
                    icon: const Icon(Icons.science_rounded, size: 16),
                    label: Text(_isRunning ? 'Menghitung...' : 'Jalankan Simulasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.infoBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                // Results
                if (_result != null) ...[
                  _buildResultBanner(),
                  const SizedBox(height: 16),
                  Text('DETAIL PENGURANGAN STOK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ..._result!.deductions.map(_buildDeductionItem),
                  const SizedBox(height: 20),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ini hanya simulasi. Stok otomatis berkurang saat order masuk dari kasir.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductOption(Product p) {
    final isSelected = _selectedProduct?.id == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() {
          _selectedProduct = p;
          _result = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppColors.primaryBlack : const Color(0xFFF3F4F6), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? const Color(0xFFF9FAFB) : Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      '${p.category.displayName}${p.hpp != null ? " • HPP ${_formatRp(p.hpp!)}" : ""}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              Text(_formatRp(p.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyRow() {
    return Row(
      children: [
        _buildQtyButton(Icons.remove, () {
          if (_simQty > 1) setState(() { _simQty--; _result = null; });
        }),
        const SizedBox(width: 12),
        Container(
          width: 80,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$_simQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        _buildQtyButton(Icons.add, () => setState(() { _simQty++; _result = null; })),
        const SizedBox(width: 12),
        Text('cup', style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildResultBanner() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.canFulfill ? AppColors.successGreen.withOpacity(0.05) : AppColors.errorRed.withOpacity(0.05),
        border: Border.all(color: (r.canFulfill ? AppColors.successGreen : AppColors.errorRed).withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            r.canFulfill ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 36,
            color: r.canFulfill ? AppColors.successGreen : AppColors.errorRed,
          ),
          const SizedBox(height: 8),
          Text(
            r.canFulfill ? 'Bisa dibuat! ($_simQty× ${_selectedProduct!.name})' : 'Stok tidak cukup!',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: r.canFulfill ? AppColors.successGreen : AppColors.errorRed),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Maksimal bisa buat: ${r.maxServings} cup',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionItem(_DeductionDetail d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: d.sufficient ? const Color(0xFFF3F4F6) : AppColors.errorRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!d.sufficient)
            BoxShadow(color: AppColors.errorRed.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d.ingredient.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (!d.sufficient)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('KURANG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Butuh: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                TextSpan(text: '${d.totalNeeded.toStringAsFixed(0)} ${d.ingredient.unit.displayName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Sisa: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                TextSpan(
                  text: '${d.remaining.toStringAsFixed(0)} ${d.ingredient.unit.displayName}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: d.remaining < 0 ? AppColors.errorRed : AppColors.successGreen),
                ),
              ])),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: d.ingredient.currentStock > 0 ? (d.remaining / d.ingredient.currentStock).clamp(0.0, 1.0) : 0,
              backgroundColor: const Color(0xFFF3F4F6),
              color: d.sufficient ? AppColors.successGreen : AppColors.errorRed,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSimulation() async {
    if (_selectedProduct == null) return;
    setState(() => _isRunning = true);

    try {
      final repo = ref.read(storageRepositoryProvider);
      final recipes = await repo.getProductRecipes(_selectedProduct!.id);

      final deductions = recipes.map((r) {
        final ing = widget.ingredients.firstWhere(
          (i) => i.id == r.ingredientId,
          orElse: () => Ingredient(
            id: r.ingredientId, name: 'Unknown', unit: IngredientUnit.gram,
            currentStock: 0, costPerUnit: 0, minStock: 0,
            createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ),
        );
        final totalNeeded = r.quantity * _simQty;
        return _DeductionDetail(
          ingredient: ing,
          perServing: r.quantity,
          totalNeeded: totalNeeded,
          available: ing.currentStock,
          remaining: ing.currentStock - totalNeeded,
          sufficient: ing.currentStock >= totalNeeded,
        );
      }).toList();

      final canFulfill = deductions.every((d) => d.sufficient);
      final maxServings = recipes.isNotEmpty
          ? recipes.map((r) {
              final ing = widget.ingredients.firstWhere((i) => i.id == r.ingredientId,
                orElse: () => Ingredient(
                  id: '', name: '', unit: IngredientUnit.gram,
                  currentStock: 0, costPerUnit: 0, minStock: 0,
                  createdAt: DateTime.now(), updatedAt: DateTime.now(),
                ));
              return r.quantity > 0 ? (ing.currentStock / r.quantity).floor() : 999;
            }).reduce((a, b) => a < b ? a : b)
          : 0;

      setState(() {
        _result = _SimulationResult(
          deductions: deductions,
          canFulfill: canFulfill,
          maxServings: maxServings,
        );
        _isRunning = false;
      });
    } catch (e) {
      setState(() => _isRunning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  String _formatRp(double value) {
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }
}

class _SimulationResult {
  final List<_DeductionDetail> deductions;
  final bool canFulfill;
  final int maxServings;
  _SimulationResult({required this.deductions, required this.canFulfill, required this.maxServings});
}

class _DeductionDetail {
  final Ingredient ingredient;
  final double perServing;
  final double totalNeeded;
  final double available;
  final double remaining;
  final bool sufficient;
  _DeductionDetail({
    required this.ingredient, required this.perServing, required this.totalNeeded,
    required this.available, required this.remaining, required this.sufficient,
  });
}
