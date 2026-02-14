import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../cashier/data/providers/product_provider.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/recipe_editor_sheet.dart';
import '../widgets/simulation_sheet.dart';

class RecipeManagementPage extends ConsumerStatefulWidget {
  final bool embedded;
  const RecipeManagementPage({super.key, this.embedded = false});

  @override
  ConsumerState<RecipeManagementPage> createState() => _RecipeManagementPageState();
}

class _RecipeManagementPageState extends ConsumerState<RecipeManagementPage> {
  String _searchQuery = '';
  ProductCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productNotifierProvider);
    final hppSummaryAsync = ref.watch(productHPPSummaryProvider);
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);

    final body = productsAsync.when(
      data: (products) => _buildBody(context, ref, products, hppSummaryAsync, ingredientsAsync),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resep & HPP',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
        ),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          // Simulation button
          ingredientsAsync.whenOrNull(
            data: (ingredients) => productsAsync.whenOrNull(
              data: (products) => TextButton.icon(
                onPressed: () => _showSimulation(context, products, ingredients),
                icon: const Icon(Icons.science_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Simulasi',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.infoBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ) ?? const SizedBox.shrink(),
          const SizedBox(width: 12),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Product> products,
    AsyncValue<List<ProductHPP>> hppAsync,
    AsyncValue<List<Ingredient>> ingredientsAsync,
  ) {
    // Filter products
    var filtered = products.where((p) => p.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // Build HPP map
    final hppMap = <String, ProductHPP>{};
    hppAsync.whenData((list) {
      for (final hpp in list) {
        hppMap[hpp.productId] = hpp;
      }
    });

    final categories = products.where((p) => p.isActive).map((p) => p.category).toSet().toList();

    return Column(
      children: [
        // Search bar
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
                hintText: 'Cari produk...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),

        // Category filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildCategoryChip(null, 'All'),
              ...categories.map((cat) => _buildCategoryChip(cat, cat.displayName)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Tidak ada produk', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final hpp = hppMap[product.id];
                    return _buildProductCard(context, ref, product, hpp, ingredientsAsync);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(ProductCategory? category, String label) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: AppColors.primaryBlack,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: selected ? AppColors.primaryBlack : const Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
    ProductHPP? hppData,
    AsyncValue<List<Ingredient>> ingredientsAsync,
  ) {
    final hpp = hppData?.hpp ?? product.hpp ?? 0;
    final hasRecipe = hppData != null && hppData.recipes.isNotEmpty || (product.hpp != null && product.hpp! > 0);
    final margin = product.price > 0 ? ((product.price - hpp) / product.price) * 100 : 0.0;
    final marginColor = _getMarginColor(margin);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showRecipeEditor(context, ref, product, ingredientsAsync),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
            ],
            border: Border(left: BorderSide(color: hasRecipe ? marginColor : const Color(0xFFD1D5DB), width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${product.category.displayName}${hasRecipe ? " • ${hppData?.recipes.length ?? 0} bahan" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatRp(product.price),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),

              // HPP info (if has recipe)
              if (hasRecipe && hpp > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF3F4F6), style: BorderStyle.solid)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('HPP ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          Text(_formatRp(hpp), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 16),
                          Text('Profit ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          Text(
                            _formatRp(product.price - hpp),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: marginColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: marginColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${margin.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: marginColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // No recipe warning
              if (!hasRecipe || hpp <= 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warningYellow),
                      const SizedBox(width: 6),
                      Text(
                        'Tap untuk tambah resep',
                        style: TextStyle(fontSize: 12, color: AppColors.warningYellow, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRecipeEditor(BuildContext context, WidgetRef ref, Product product, AsyncValue<List<Ingredient>> ingredientsAsync) {
    ingredientsAsync.whenData((ingredients) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RecipeEditorSheet(product: product, ingredients: ingredients),
      );
    });
  }

  void _showSimulation(BuildContext context, List<Product> products, List<Ingredient> ingredients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SimulationSheet(products: products, ingredients: ingredients),
    );
  }

  Color _getMarginColor(double pct) {
    if (pct >= 70) return AppColors.successGreen;
    if (pct >= 50) return AppColors.infoBlue;
    if (pct >= 30) return AppColors.warningYellow;
    return AppColors.errorRed;
  }

  String _formatRp(double value) {
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }
}
