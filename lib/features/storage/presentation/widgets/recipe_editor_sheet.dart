import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

class RecipeEditorSheet extends ConsumerStatefulWidget {
  final Product product;
  final List<Ingredient> ingredients;

  const RecipeEditorSheet({super.key, required this.product, required this.ingredients});

  @override
  ConsumerState<RecipeEditorSheet> createState() => _RecipeEditorSheetState();
}

class _RecipeEditorSheetState extends ConsumerState<RecipeEditorSheet> {
  List<_RecipeItem> _recipeItems = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _showAddIng = false;
  String _addSearch = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await ref.read(storageRepositoryProvider).getProductRecipes(widget.product.id);
      setState(() {
        _recipeItems = recipes.map((r) => _RecipeItem(
          id: r.id,
          ingredientId: r.ingredientId,
          ingredient: r.ingredient,
          quantity: r.quantity,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalHPP {
    return _recipeItems.fold(0.0, (sum, item) {
      return sum + (item.quantity * (item.ingredient?.costPerUnit ?? 0));
    });
  }

  double get _margin {
    if (widget.product.price <= 0) return 0;
    return ((widget.product.price - _totalHPP) / widget.product.price) * 100;
  }

  double get _profit => widget.product.price - _totalHPP;

  Color get _marginColor {
    if (_margin >= 70) return AppColors.successGreen;
    if (_margin >= 50) return AppColors.infoBlue;
    if (_margin >= 30) return AppColors.warningYellow;
    return AppColors.errorRed;
  }

  List<Ingredient> get _availableIngredients {
    final usedIds = _recipeItems.map((r) => r.ingredientId).toSet();
    return widget.ingredients.where((i) =>
      !usedIds.contains(i.id) &&
      i.name.toLowerCase().contains(_addSearch.toLowerCase())
    ).toList();
  }

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
                      Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('Edit resep & gramasi', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // HPP Summary Card
                      _buildHPPCard(),
                      const SizedBox(height: 20),

                      // Recipe items header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BAHAN (${_recipeItems.length})'.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1),
                          ),
                          Text(
                            'Gramasi → Cost',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Empty state
                      if (_recipeItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Belum ada bahan.\nTambahkan bahan untuk membuat resep.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                            ],
                          ),
                        ),

                      // Recipe items
                      ..._recipeItems.map(_buildRecipeItem),
                      const SizedBox(height: 16),

                      // Add ingredient
                      if (!_showAddIng)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showAddIng = true),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah Bahan'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFD1D5DB), style: BorderStyle.solid),
                            foregroundColor: AppColors.textSecondary,
                          ),
                        )
                      else
                        _buildAddIngredientPanel(),
                    ],
                  ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRecipes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Resep', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHPPCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _marginColor.withOpacity(0.05),
        border: Border.all(color: _marginColor.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HARGA JUAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(_formatRp(widget.product.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('MARGIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('${_margin.toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _marginColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_margin / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.black.withOpacity(0.05),
              color: _marginColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'HPP: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                TextSpan(text: _formatRp(_totalHPP), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Profit: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                TextSpan(text: _formatRp(_profit), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _marginColor)),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeItem(_RecipeItem item) {
    final ing = item.ingredient;
    if (ing == null) return const SizedBox.shrink();
    final cost = item.quantity * ing.costPerUnit;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '@ ${ing.costPerUnit < 1 ? "Rp ${_formatRibuan(ing.costPerUnit * 1000)}/1000${ing.unit.displayName}" : "${_formatRp(ing.costPerUnit)}/${ing.unit.displayName}"}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _removeIngredient(item.ingredientId),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, size: 14, color: AppColors.errorRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Qty controls
                Row(
                  children: [
                    _buildSmallButton(Icons.remove, () => _updateQty(item.ingredientId, item.quantity - 1)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: TextEditingController(text: item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          isDense: true,
                        ),
                        onSubmitted: (v) => _updateQty(item.ingredientId, double.tryParse(v) ?? item.quantity),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSmallButton(Icons.add, () => _updateQty(item.ingredientId, item.quantity + 1)),
                    const SizedBox(width: 8),
                    Text(ing.unit.displayName, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
                // Cost
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_formatRp(cost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildAddIngredientPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBlack, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Cari bahan...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _addSearch = v),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() { _showAddIng = false; _addSearch = ''; }),
                  child: Text('Batal', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: _availableIngredients.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Semua bahan sudah ditambahkan', style: TextStyle(color: Colors.grey[400], fontSize: 13), textAlign: TextAlign.center),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: _availableIngredients.map((ing) => ListTile(
                      dense: true,
                      title: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('Stok: ${ing.currentStock.toStringAsFixed(0)} ${ing.unit.displayName}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.successGreen),
                      onTap: () => _addIngredient(ing),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  void _addIngredient(Ingredient ing) {
    setState(() {
      _recipeItems.add(_RecipeItem(ingredientId: ing.id, ingredient: ing, quantity: 0));
      _showAddIng = false;
      _addSearch = '';
      _hasChanges = true;
    });
  }

  void _removeIngredient(String ingredientId) {
    setState(() {
      _recipeItems.removeWhere((r) => r.ingredientId == ingredientId);
      _hasChanges = true;
    });
  }

  void _updateQty(String ingredientId, double newQty) {
    setState(() {
      final idx = _recipeItems.indexWhere((r) => r.ingredientId == ingredientId);
      if (idx != -1) {
        _recipeItems[idx] = _recipeItems[idx].copyWith(quantity: newQty.clamp(0, 99999));
        _hasChanges = true;
      }
    });
  }

  Future<void> _saveRecipes() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(storageRepositoryProvider);
      await repo.setProductRecipes(
        productId: widget.product.id,
        recipes: _recipeItems
            .where((r) => r.quantity > 0)
            .map((r) => {'ingredient_id': r.ingredientId, 'quantity': r.quantity})
            .toList(),
      );

      ref.invalidate(productHPPSummaryProvider);
      ref.invalidate(allRecipesProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Resep ${widget.product.name} disimpan'),
            backgroundColor: AppColors.primaryBlack,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatRibuan(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  String _formatRp(double value) {
    return 'Rp ${_formatRibuan(value)}';
  }
}

class _RecipeItem {
  final String? id;
  final String ingredientId;
  final Ingredient? ingredient;
  final double quantity;

  _RecipeItem({this.id, required this.ingredientId, this.ingredient, required this.quantity});

  _RecipeItem copyWith({String? id, String? ingredientId, Ingredient? ingredient, double? quantity}) {
    return _RecipeItem(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      ingredient: ingredient ?? this.ingredient,
      quantity: quantity ?? this.quantity,
    );
  }
}
