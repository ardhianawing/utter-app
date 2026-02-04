import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/storage_models.dart';

class StorageRepository {
  final SupabaseClient _supabase;

  StorageRepository(this._supabase);

  // ============================================================
  // INGREDIENTS CRUD
  // ============================================================

  /// Get all active ingredients
  Future<List<Ingredient>> getIngredients({bool activeOnly = true}) async {
    try {
      var query = _supabase.from('ingredients').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Ingredient.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load ingredients: $e');
    }
  }

  /// Stream of all active ingredients (real-time updates)
  Stream<List<Ingredient>> getIngredientsStream({bool activeOnly = true}) {
    return _supabase
        .from('ingredients')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((maps) => maps
            .map((map) => Ingredient.fromJson(map))
            .where((i) => !activeOnly || i.isActive)
            .toList());
  }

  /// Get a single ingredient by ID
  Future<Ingredient?> getIngredient(String ingredientId) async {
    try {
      final response = await _supabase
          .from('ingredients')
          .select()
          .eq('id', ingredientId)
          .maybeSingle();

      if (response == null) return null;
      return Ingredient.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load ingredient: $e');
    }
  }

  /// Create a new ingredient
  Future<Ingredient> createIngredient({
    required String name,
    required IngredientUnit unit,
    double currentStock = 0,
    double costPerUnit = 0,
    double minStock = 0,
    String? supplierName,
  }) async {
    try {
      final response = await _supabase
          .from('ingredients')
          .insert({
            'name': name,
            'unit': unit.dbValue,
            'current_stock': currentStock,
            'cost_per_unit': costPerUnit,
            'min_stock': minStock,
            'supplier_name': supplierName,
            'is_active': true,
          })
          .select()
          .single();

      return Ingredient.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create ingredient: $e');
    }
  }

  /// Update an ingredient
  Future<Ingredient> updateIngredient({
    required String ingredientId,
    String? name,
    IngredientUnit? unit,
    double? currentStock,
    double? costPerUnit,
    double? minStock,
    String? supplierName,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (unit != null) updateData['unit'] = unit.dbValue;
      if (currentStock != null) updateData['current_stock'] = currentStock;
      if (costPerUnit != null) updateData['cost_per_unit'] = costPerUnit;
      if (minStock != null) updateData['min_stock'] = minStock;
      if (supplierName != null) updateData['supplier_name'] = supplierName;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('ingredients')
          .update(updateData)
          .eq('id', ingredientId)
          .select()
          .single();

      return Ingredient.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update ingredient: $e');
    }
  }

  /// Soft delete an ingredient (set is_active to false)
  Future<void> deleteIngredient(String ingredientId) async {
    try {
      await _supabase
          .from('ingredients')
          .update({'is_active': false})
          .eq('id', ingredientId);
    } catch (e) {
      throw Exception('Failed to delete ingredient: $e');
    }
  }

  // ============================================================
  // LOW STOCK ALERTS
  // ============================================================

  /// Get ingredients that are at or below minimum stock level
  Future<List<Ingredient>> getLowStockIngredients() async {
    try {
      final response = await _supabase.rpc('get_low_stock_ingredients');

      return (response as List<dynamic>)
          .map((json) => Ingredient.fromJson({
                ...json as Map<String, dynamic>,
                'is_active': true,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }))
          .toList();
    } catch (e) {
      // Fallback to manual query if RPC not available
      try {
        final ingredients = await getIngredients();
        return ingredients.where((i) => i.isLowStock).toList();
      } catch (e2) {
        throw Exception('Failed to load low stock ingredients: $e');
      }
    }
  }

  /// Stream of low stock ingredients
  Stream<List<Ingredient>> getLowStockIngredientsStream() {
    return _supabase
        .from('ingredients')
        .stream(primaryKey: ['id'])
        .map((maps) => maps
            .map((map) => Ingredient.fromJson(map))
            .where((i) => i.isActive && i.isLowStock)
            .toList());
  }

  // ============================================================
  // STOCK MOVEMENTS
  // ============================================================

  /// Add stock (Stock In)
  Future<void> addStock({
    required String ingredientId,
    required double quantity,
    double? unitCost,
    String? notes,
    String? createdBy,
  }) async {
    try {
      // Update stock using RPC
      await _supabase.rpc('add_stock', params: {
        'p_ingredient_id': ingredientId,
        'p_quantity': quantity,
        'p_unit_cost': unitCost,
      });

      // Log movement
      await _supabase.from('stock_movements').insert({
        'ingredient_id': ingredientId,
        'movement_type': MovementType.STOCK_IN.dbValue,
        'quantity': quantity, // positive for stock in
        'unit_cost': unitCost,
        'reference_type': ReferenceType.PURCHASE.dbValue,
        'notes': notes,
        'created_by': createdBy,
      });
    } catch (e) {
      throw Exception('Failed to add stock: $e');
    }
  }

  /// Deduct stock manually (Adjustment)
  Future<void> deductStock({
    required String ingredientId,
    required double quantity,
    String? notes,
    String? createdBy,
  }) async {
    try {
      // Update stock using RPC
      await _supabase.rpc('deduct_stock', params: {
        'p_ingredient_id': ingredientId,
        'p_quantity': quantity,
      });

      // Get current cost for logging
      final ingredient = await getIngredient(ingredientId);

      // Log movement
      await _supabase.from('stock_movements').insert({
        'ingredient_id': ingredientId,
        'movement_type': MovementType.ADJUSTMENT.dbValue,
        'quantity': -quantity, // negative for stock out
        'unit_cost': ingredient?.costPerUnit,
        'reference_type': ReferenceType.MANUAL.dbValue,
        'notes': notes,
        'created_by': createdBy,
      });
    } catch (e) {
      throw Exception('Failed to deduct stock: $e');
    }
  }

  /// Adjust stock (can be positive or negative)
  Future<void> adjustStock({
    required String ingredientId,
    required double newStockLevel,
    String? notes,
    String? createdBy,
  }) async {
    try {
      final ingredient = await getIngredient(ingredientId);
      if (ingredient == null) {
        throw Exception('Ingredient not found');
      }

      final difference = newStockLevel - ingredient.currentStock;

      // Update stock directly
      await _supabase
          .from('ingredients')
          .update({'current_stock': newStockLevel})
          .eq('id', ingredientId);

      // Log movement
      await _supabase.from('stock_movements').insert({
        'ingredient_id': ingredientId,
        'movement_type': MovementType.ADJUSTMENT.dbValue,
        'quantity': difference,
        'unit_cost': ingredient.costPerUnit,
        'reference_type': ReferenceType.MANUAL.dbValue,
        'notes': notes ?? 'Stock adjustment from ${ingredient.currentStock} to $newStockLevel',
        'created_by': createdBy,
      });
    } catch (e) {
      throw Exception('Failed to adjust stock: $e');
    }
  }

  /// Get stock movements for an ingredient
  Future<List<StockMovement>> getStockMovements({
    String? ingredientId,
    MovementType? movementType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('stock_movements')
          .select('*, ingredient:ingredients(*)');

      if (ingredientId != null) {
        query = query.eq('ingredient_id', ingredientId);
      }

      if (movementType != null) {
        query = query.eq('movement_type', movementType.dbValue);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => StockMovement.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load stock movements: $e');
    }
  }

  /// Stream of stock movements
  Stream<List<StockMovement>> getStockMovementsStream({int limit = 50}) {
    return _supabase
        .from('stock_movements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((maps) => maps
            .map((map) => StockMovement.fromJson(map))
            .toList());
  }

  // ============================================================
  // PRODUCT RECIPES (BOM)
  // ============================================================

  /// Get recipes for a product
  Future<List<ProductRecipe>> getProductRecipes(String productId) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .select('*, ingredient:ingredients(*)')
          .eq('product_id', productId);

      return (response as List<dynamic>)
          .map((json) => ProductRecipe.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load product recipes: $e');
    }
  }

  /// Get all recipes with ingredient details
  Future<List<ProductRecipe>> getAllRecipes() async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .select('*, ingredient:ingredients(*)');

      return (response as List<dynamic>)
          .map((json) => ProductRecipe.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load all recipes: $e');
    }
  }

  /// Add ingredient to product recipe
  Future<ProductRecipe> addRecipeItem({
    required String productId,
    required String ingredientId,
    required double quantity,
  }) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .insert({
            'product_id': productId,
            'ingredient_id': ingredientId,
            'quantity': quantity,
          })
          .select('*, ingredient:ingredients(*)')
          .single();

      return ProductRecipe.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add recipe item: $e');
    }
  }

  /// Update recipe item quantity
  Future<ProductRecipe> updateRecipeItem({
    required String recipeId,
    required double quantity,
  }) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .update({'quantity': quantity})
          .eq('id', recipeId)
          .select('*, ingredient:ingredients(*)')
          .single();

      return ProductRecipe.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update recipe item: $e');
    }
  }

  /// Remove ingredient from product recipe
  Future<void> removeRecipeItem(String recipeId) async {
    try {
      await _supabase.from('product_recipes').delete().eq('id', recipeId);
    } catch (e) {
      throw Exception('Failed to remove recipe item: $e');
    }
  }

  /// Replace all recipes for a product
  Future<void> setProductRecipes({
    required String productId,
    required List<Map<String, dynamic>> recipes,
  }) async {
    try {
      // Delete existing recipes
      await _supabase
          .from('product_recipes')
          .delete()
          .eq('product_id', productId);

      // Insert new recipes
      if (recipes.isNotEmpty) {
        final recipeItems = recipes.map((r) => {
          'product_id': productId,
          'ingredient_id': r['ingredient_id'],
          'quantity': r['quantity'],
        }).toList();

        await _supabase.from('product_recipes').insert(recipeItems);
      }
    } catch (e) {
      throw Exception('Failed to set product recipes: $e');
    }
  }

  // ============================================================
  // HPP (Harga Pokok Penjualan) CALCULATION
  // ============================================================

  /// Calculate HPP for a product
  Future<double> calculateProductHPP(String productId) async {
    try {
      final response = await _supabase.rpc(
        'calculate_product_hpp',
        params: {'p_product_id': productId},
      );

      return (response as num?)?.toDouble() ?? 0;
    } catch (e) {
      // Fallback to manual calculation
      try {
        final recipes = await getProductRecipes(productId);
        return recipes.fold<double>(0, (sum, r) => sum + r.itemCost);
      } catch (e2) {
        throw Exception('Failed to calculate HPP: $e');
      }
    }
  }

  /// Get HPP summary for all products
  Future<List<ProductHPP>> getProductHPPSummary() async {
    try {
      final response = await _supabase
          .from('product_hpp_summary')
          .select();

      return (response as List<dynamic>)
          .map((json) => ProductHPP.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load HPP summary: $e');
    }
  }

  // ============================================================
  // ORDER INTEGRATION - AUTO DEDUCT
  // ============================================================

  /// Process ingredient deduction for completed order
  /// Called when order status changes to COMPLETED
  Future<void> processOrderDeduction({
    required String orderId,
    String? createdBy,
  }) async {
    try {
      await _supabase.rpc(
        'process_order_ingredient_deduction',
        params: {
          'p_order_id': orderId,
          'p_created_by': createdBy,
        },
      );
    } catch (e) {
      throw Exception('Failed to process order deduction: $e');
    }
  }

  /// Manual deduction for order items (fallback if RPC not available)
  Future<void> deductIngredientsForOrder({
    required String orderId,
    required List<Map<String, dynamic>> orderItems,
    String? createdBy,
  }) async {
    try {
      for (final item in orderItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;

        // Get recipes for this product
        final recipes = await getProductRecipes(productId);

        for (final recipe in recipes) {
          final deductQty = recipe.quantity * quantity;

          // Deduct stock
          await _supabase.rpc('deduct_stock', params: {
            'p_ingredient_id': recipe.ingredientId,
            'p_quantity': deductQty,
          });

          // Log movement
          await _supabase.from('stock_movements').insert({
            'ingredient_id': recipe.ingredientId,
            'movement_type': MovementType.AUTO_DEDUCT.dbValue,
            'quantity': -deductQty,
            'unit_cost': recipe.ingredient?.costPerUnit,
            'reference_type': ReferenceType.ORDER.dbValue,
            'reference_id': orderId,
            'created_by': createdBy,
          });
        }
      }
    } catch (e) {
      throw Exception('Failed to deduct ingredients for order: $e');
    }
  }

  // ============================================================
  // STOCK SUMMARY & REPORTS
  // ============================================================

  /// Get stock summary statistics
  Future<StockSummary> getStockSummary() async {
    try {
      final ingredients = await getIngredients();
      return StockSummary.fromIngredients(ingredients);
    } catch (e) {
      throw Exception('Failed to load stock summary: $e');
    }
  }

  /// Get stock value report
  Future<Map<String, dynamic>> getStockValueReport() async {
    try {
      final ingredients = await getIngredients();

      double totalValue = 0;
      double lowStockValue = 0;
      int totalItems = 0;
      int lowStockItems = 0;

      for (final ingredient in ingredients) {
        final value = ingredient.currentStock * ingredient.costPerUnit;
        totalValue += value;
        totalItems++;

        if (ingredient.isLowStock) {
          lowStockValue += value;
          lowStockItems++;
        }
      }

      return {
        'total_value': totalValue,
        'total_items': totalItems,
        'low_stock_value': lowStockValue,
        'low_stock_items': lowStockItems,
        'healthy_stock_items': totalItems - lowStockItems,
      };
    } catch (e) {
      throw Exception('Failed to load stock value report: $e');
    }
  }

  /// Get movement statistics for a date range
  Future<Map<String, dynamic>> getMovementStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final movements = await getStockMovements(
        startDate: startDate,
        endDate: endDate,
        limit: 10000,
      );

      double totalIn = 0;
      double totalOut = 0;
      int stockInCount = 0;
      int autoDeductCount = 0;
      int adjustmentCount = 0;

      for (final movement in movements) {
        if (movement.isIncoming) {
          totalIn += movement.absoluteQuantity;
        } else {
          totalOut += movement.absoluteQuantity;
        }

        switch (movement.movementType) {
          case MovementType.STOCK_IN:
            stockInCount++;
            break;
          case MovementType.AUTO_DEDUCT:
            autoDeductCount++;
            break;
          case MovementType.ADJUSTMENT:
            adjustmentCount++;
            break;
        }
      }

      return {
        'total_movements': movements.length,
        'total_in': totalIn,
        'total_out': totalOut,
        'stock_in_count': stockInCount,
        'auto_deduct_count': autoDeductCount,
        'adjustment_count': adjustmentCount,
      };
    } catch (e) {
      throw Exception('Failed to load movement stats: $e');
    }
  }
}
