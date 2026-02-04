import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/storage_repository.dart';
import '../../domain/models/storage_models.dart';

// ============================================================
// REPOSITORY PROVIDER
// ============================================================

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final supabase = Supabase.instance.client;
  return StorageRepository(supabase);
});

// ============================================================
// INGREDIENTS PROVIDERS
// ============================================================

/// Stream of all active ingredients
final ingredientsStreamProvider = StreamProvider<List<Ingredient>>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getIngredientsStream();
});

/// Future provider for ingredients list
final ingredientsProvider = FutureProvider<List<Ingredient>>((ref) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getIngredients();
});

/// Stream of low stock ingredients for alerts
final lowStockIngredientsProvider = StreamProvider<List<Ingredient>>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getLowStockIngredientsStream();
});

/// Single ingredient provider with parameter
final ingredientProvider = FutureProvider.family<Ingredient?, String>((ref, ingredientId) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getIngredient(ingredientId);
});

// ============================================================
// STOCK MOVEMENTS PROVIDERS
// ============================================================

/// Stream of recent stock movements
final stockMovementsStreamProvider = StreamProvider<List<StockMovement>>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getStockMovementsStream();
});

/// Stock movements for a specific ingredient
final ingredientMovementsProvider = FutureProvider.family<List<StockMovement>, String>((ref, ingredientId) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getStockMovements(ingredientId: ingredientId);
});

// ============================================================
// PRODUCT RECIPES PROVIDERS
// ============================================================

/// Recipes for a specific product
final productRecipesProvider = FutureProvider.family<List<ProductRecipe>, String>((ref, productId) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getProductRecipes(productId);
});

/// All recipes
final allRecipesProvider = FutureProvider<List<ProductRecipe>>((ref) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getAllRecipes();
});

// ============================================================
// HPP PROVIDERS
// ============================================================

/// HPP for a specific product
final productHPPProvider = FutureProvider.family<double, String>((ref, productId) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.calculateProductHPP(productId);
});

/// HPP summary for all products
final productHPPSummaryProvider = FutureProvider<List<ProductHPP>>((ref) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getProductHPPSummary();
});

// ============================================================
// STOCK SUMMARY PROVIDERS
// ============================================================

/// Stock summary statistics
final stockSummaryProvider = FutureProvider<StockSummary>((ref) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getStockSummary();
});

/// Stock value report
final stockValueReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(storageRepositoryProvider);
  return repository.getStockValueReport();
});

// ============================================================
// INGREDIENT STATE MANAGEMENT
// ============================================================

/// State class for ingredient management
class IngredientState {
  final bool isLoading;
  final String? error;
  final Ingredient? selectedIngredient;

  IngredientState({
    this.isLoading = false,
    this.error,
    this.selectedIngredient,
  });

  IngredientState copyWith({
    bool? isLoading,
    String? error,
    Ingredient? selectedIngredient,
  }) {
    return IngredientState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedIngredient: selectedIngredient ?? this.selectedIngredient,
    );
  }
}

/// StateNotifier for ingredient operations
class IngredientNotifier extends StateNotifier<IngredientState> {
  final StorageRepository _repository;

  IngredientNotifier(this._repository) : super(IngredientState());

  /// Create a new ingredient
  Future<bool> createIngredient({
    required String name,
    required IngredientUnit unit,
    double currentStock = 0,
    double costPerUnit = 0,
    double minStock = 0,
    String? supplierName,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final ingredient = await _repository.createIngredient(
        name: name,
        unit: unit,
        currentStock: currentStock,
        costPerUnit: costPerUnit,
        minStock: minStock,
        supplierName: supplierName,
      );
      state = state.copyWith(isLoading: false, selectedIngredient: ingredient);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update an ingredient
  Future<bool> updateIngredient({
    required String ingredientId,
    String? name,
    IngredientUnit? unit,
    double? costPerUnit,
    double? minStock,
    String? supplierName,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final ingredient = await _repository.updateIngredient(
        ingredientId: ingredientId,
        name: name,
        unit: unit,
        costPerUnit: costPerUnit,
        minStock: minStock,
        supplierName: supplierName,
        isActive: isActive,
      );
      state = state.copyWith(isLoading: false, selectedIngredient: ingredient);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete an ingredient
  Future<bool> deleteIngredient(String ingredientId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteIngredient(ingredientId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final ingredientNotifierProvider = StateNotifierProvider<IngredientNotifier, IngredientState>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return IngredientNotifier(repository);
});

// ============================================================
// STOCK OPERATIONS STATE MANAGEMENT
// ============================================================

/// State class for stock operations
class StockOperationState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  StockOperationState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  StockOperationState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return StockOperationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// StateNotifier for stock operations
class StockOperationNotifier extends StateNotifier<StockOperationState> {
  final StorageRepository _repository;

  StockOperationNotifier(this._repository) : super(StockOperationState());

  /// Add stock (Stock In)
  Future<bool> addStock({
    required String ingredientId,
    required double quantity,
    double? unitCost,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.addStock(
        ingredientId: ingredientId,
        quantity: quantity,
        unitCost: unitCost,
        notes: notes,
        createdBy: createdBy,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Stock added successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Deduct stock manually
  Future<bool> deductStock({
    required String ingredientId,
    required double quantity,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deductStock(
        ingredientId: ingredientId,
        quantity: quantity,
        notes: notes,
        createdBy: createdBy,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Stock deducted successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Adjust stock to a specific level
  Future<bool> adjustStock({
    required String ingredientId,
    required double newStockLevel,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.adjustStock(
        ingredientId: ingredientId,
        newStockLevel: newStockLevel,
        notes: notes,
        createdBy: createdBy,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Stock adjusted successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final stockOperationProvider = StateNotifierProvider<StockOperationNotifier, StockOperationState>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return StockOperationNotifier(repository);
});

// ============================================================
// RECIPE MANAGEMENT STATE
// ============================================================

/// State class for recipe management
class RecipeManagementState {
  final bool isLoading;
  final String? error;
  final List<ProductRecipe> recipes;

  RecipeManagementState({
    this.isLoading = false,
    this.error,
    this.recipes = const [],
  });

  RecipeManagementState copyWith({
    bool? isLoading,
    String? error,
    List<ProductRecipe>? recipes,
  }) {
    return RecipeManagementState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recipes: recipes ?? this.recipes,
    );
  }
}

/// StateNotifier for recipe management
class RecipeManagementNotifier extends StateNotifier<RecipeManagementState> {
  final StorageRepository _repository;

  RecipeManagementNotifier(this._repository) : super(RecipeManagementState());

  /// Load recipes for a product
  Future<void> loadProductRecipes(String productId) async {
    state = state.copyWith(isLoading: true);
    try {
      final recipes = await _repository.getProductRecipes(productId);
      state = state.copyWith(isLoading: false, recipes: recipes);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add a recipe item
  Future<bool> addRecipeItem({
    required String productId,
    required String ingredientId,
    required double quantity,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final recipe = await _repository.addRecipeItem(
        productId: productId,
        ingredientId: ingredientId,
        quantity: quantity,
      );
      state = state.copyWith(
        isLoading: false,
        recipes: [...state.recipes, recipe],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update a recipe item
  Future<bool> updateRecipeItem({
    required String recipeId,
    required double quantity,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.updateRecipeItem(
        recipeId: recipeId,
        quantity: quantity,
      );
      state = state.copyWith(
        isLoading: false,
        recipes: state.recipes.map((r) => r.id == recipeId ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Remove a recipe item
  Future<bool> removeRecipeItem(String recipeId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.removeRecipeItem(recipeId);
      state = state.copyWith(
        isLoading: false,
        recipes: state.recipes.where((r) => r.id != recipeId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Calculate total HPP from current recipes
  double get totalHPP {
    return state.recipes.fold(0.0, (sum, r) => sum + r.itemCost);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final recipeManagementProvider = StateNotifierProvider<RecipeManagementNotifier, RecipeManagementState>((ref) {
  final repository = ref.watch(storageRepositoryProvider);
  return RecipeManagementNotifier(repository);
});

// ============================================================
// SEARCH & FILTER PROVIDERS
// ============================================================

/// Search query for ingredients
final ingredientSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered ingredients based on search query
final filteredIngredientsProvider = Provider<AsyncValue<List<Ingredient>>>((ref) {
  final ingredientsAsync = ref.watch(ingredientsStreamProvider);
  final searchQuery = ref.watch(ingredientSearchQueryProvider).toLowerCase();

  return ingredientsAsync.whenData((ingredients) {
    if (searchQuery.isEmpty) return ingredients;
    return ingredients
        .where((i) =>
            i.name.toLowerCase().contains(searchQuery) ||
            (i.supplierName?.toLowerCase().contains(searchQuery) ?? false))
        .toList();
  });
});

/// Filter for stock level
enum StockFilter { all, lowStock, outOfStock, healthy }

final stockFilterProvider = StateProvider<StockFilter>((ref) => StockFilter.all);

/// Filtered ingredients based on stock filter
final stockFilteredIngredientsProvider = Provider<AsyncValue<List<Ingredient>>>((ref) {
  final filteredAsync = ref.watch(filteredIngredientsProvider);
  final filter = ref.watch(stockFilterProvider);

  return filteredAsync.whenData((ingredients) {
    switch (filter) {
      case StockFilter.all:
        return ingredients;
      case StockFilter.lowStock:
        return ingredients.where((i) => i.isLowStock && !i.isOutOfStock).toList();
      case StockFilter.outOfStock:
        return ingredients.where((i) => i.isOutOfStock).toList();
      case StockFilter.healthy:
        return ingredients.where((i) => !i.isLowStock).toList();
    }
  });
});
