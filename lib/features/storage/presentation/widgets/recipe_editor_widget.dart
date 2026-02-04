import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

class RecipeEditorWidget extends ConsumerStatefulWidget {
  final Product product;
  final ScrollController scrollController;
  final VoidCallback? onSaved;

  const RecipeEditorWidget({
    super.key,
    required this.product,
    required this.scrollController,
    this.onSaved,
  });

  @override
  ConsumerState<RecipeEditorWidget> createState() => _RecipeEditorWidgetState();
}

class _RecipeEditorWidgetState extends ConsumerState<RecipeEditorWidget> {
  List<_RecipeItem> _recipeItems = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await ref
          .read(storageRepositoryProvider)
          .getProductRecipes(widget.product.id);

      setState(() {
        _recipeItems = recipes
            .map((r) => _RecipeItem(
                  id: r.id,
                  ingredientId: r.ingredientId,
                  ingredient: r.ingredient,
                  quantity: r.quantity,
                  isNew: false,
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load recipes: $e')),
        );
      }
    }
  }

  double get _totalHPP {
    return _recipeItems.fold(0.0, (sum, item) {
      return sum + (item.quantity * (item.ingredient?.costPerUnit ?? 0));
    });
  }

  double get _profitMargin => widget.product.price - _totalHPP;

  double get _profitPercent {
    if (widget.product.price <= 0) return 0;
    return (_profitMargin / widget.product.price) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.product.imageUrl != null
                    ? Image.network(
                        widget.product.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Selling Price: Rp ${widget.product.price.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // HPP Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  label: 'HPP',
                  value: 'Rp ${_totalHPP.toStringAsFixed(0)}',
                  color: AppColors.infoBlue,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.borderLight,
              ),
              Expanded(
                child: _buildSummaryItem(
                  label: 'Profit',
                  value: 'Rp ${_profitMargin.toStringAsFixed(0)}',
                  color: _profitMargin >= 0
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.borderLight,
              ),
              Expanded(
                child: _buildSummaryItem(
                  label: 'Margin',
                  value: '${_profitPercent.toStringAsFixed(1)}%',
                  color: _profitPercent >= 30
                      ? AppColors.successGreen
                      : _profitPercent >= 15
                          ? AppColors.warningYellow
                          : AppColors.errorRed,
                ),
              ),
            ],
          ),
        ),

        // Recipe Items Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ingredientsAsync.whenData(
                (ingredients) => TextButton.icon(
                  onPressed: () => _showAddIngredientDialog(ingredients),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ).value ?? const SizedBox.shrink(),
            ],
          ),
        ),

        // Recipe Items List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _recipeItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No ingredients added yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ingredientsAsync.when(
                            data: (ingredients) => ElevatedButton.icon(
                              onPressed: () => _showAddIngredientDialog(ingredients),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Ingredient'),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _recipeItems.length,
                      itemBuilder: (context, index) {
                        final item = _recipeItems[index];
                        return _buildRecipeItemCard(item, index);
                      },
                    ),
        ),

        // Save Button
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveRecipes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[300],
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeItemCard(_RecipeItem item, int index) {
    final cost = item.quantity * (item.ingredient?.costPerUnit ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.ingredient?.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} ${item.ingredient?.unit.displayName ?? ''} × Rp ${item.ingredient?.costPerUnit.toStringAsFixed(2) ?? '0'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Rp ${cost.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editQuantity(index),
              color: AppColors.infoBlue,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _removeItem(index),
              color: AppColors.errorRed,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddIngredientDialog(List<Ingredient> allIngredients) {
    // Filter out already added ingredients
    final availableIngredients = allIngredients.where((i) {
      return !_recipeItems.any((r) => r.ingredientId == i.id);
    }).toList();

    if (availableIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All ingredients have been added')),
      );
      return;
    }

    Ingredient? selectedIngredient;
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Ingredient>(
              decoration: const InputDecoration(
                labelText: 'Ingredient',
                border: OutlineInputBorder(),
              ),
              items: availableIngredients.map((i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text('${i.name} (${i.unit.displayName})'),
                );
              }).toList(),
              onChanged: (value) => selectedIngredient = value,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity per product',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedIngredient == null ||
                  quantityController.text.isEmpty) {
                return;
              }
              final qty = double.tryParse(quantityController.text);
              if (qty == null || qty <= 0) return;

              setState(() {
                _recipeItems.add(_RecipeItem(
                  ingredientId: selectedIngredient!.id,
                  ingredient: selectedIngredient,
                  quantity: qty,
                  isNew: true,
                ));
                _hasChanges = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editQuantity(int index) {
    final item = _recipeItems[index];
    final controller = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.ingredient?.name ?? 'Quantity'}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity',
            suffix: Text(item.ingredient?.unit.displayName ?? ''),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(controller.text);
              if (qty == null || qty <= 0) return;

              setState(() {
                _recipeItems[index] = _recipeItems[index].copyWith(
                  quantity: qty,
                  isModified: true,
                );
                _hasChanges = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _recipeItems.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _saveRecipes() async {
    try {
      final repository = ref.read(storageRepositoryProvider);

      // Convert to format expected by repository
      final recipes = _recipeItems
          .map((item) => {
                'ingredient_id': item.ingredientId,
                'quantity': item.quantity,
              })
          .toList();

      await repository.setProductRecipes(
        productId: widget.product.id,
        recipes: recipes,
      );

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe saved successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save recipe: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}

class _RecipeItem {
  final String? id;
  final String ingredientId;
  final Ingredient? ingredient;
  final double quantity;
  final bool isNew;
  final bool isModified;

  _RecipeItem({
    this.id,
    required this.ingredientId,
    this.ingredient,
    required this.quantity,
    this.isNew = false,
    this.isModified = false,
  });

  _RecipeItem copyWith({
    String? id,
    String? ingredientId,
    Ingredient? ingredient,
    double? quantity,
    bool? isNew,
    bool? isModified,
  }) {
    return _RecipeItem(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      ingredient: ingredient ?? this.ingredient,
      quantity: quantity ?? this.quantity,
      isNew: isNew ?? this.isNew,
      isModified: isModified ?? this.isModified,
    );
  }
}
