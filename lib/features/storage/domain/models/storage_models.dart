// Storage/Inventory Models for Utter Ecosystem

/// Unit types for ingredients
enum IngredientUnit {
  gram,
  kg,
  ml,
  liter,
  pcs,
}

extension IngredientUnitExtension on IngredientUnit {
  String get displayName {
    switch (this) {
      case IngredientUnit.gram:
        return 'gram';
      case IngredientUnit.kg:
        return 'kg';
      case IngredientUnit.ml:
        return 'ml';
      case IngredientUnit.liter:
        return 'liter';
      case IngredientUnit.pcs:
        return 'pcs';
    }
  }

  String get dbValue => toString().split('.').last;

  /// Get the base unit (smallest unit) for this unit type
  IngredientUnit get baseUnit {
    switch (this) {
      case IngredientUnit.kg:
        return IngredientUnit.gram;
      case IngredientUnit.liter:
        return IngredientUnit.ml;
      default:
        return this;
    }
  }

  /// Check if this unit is compatible with another (can be converted)
  bool isCompatibleWith(IngredientUnit other) {
    return baseUnit == other.baseUnit;
  }

  /// Convert quantity from this unit to another compatible unit
  double convertTo(double quantity, IngredientUnit targetUnit) {
    if (!isCompatibleWith(targetUnit)) return quantity;

    // First convert to base unit
    double baseQuantity;
    switch (this) {
      case IngredientUnit.kg:
        baseQuantity = quantity * 1000; // kg to gram
        break;
      case IngredientUnit.liter:
        baseQuantity = quantity * 1000; // liter to ml
        break;
      default:
        baseQuantity = quantity;
    }

    // Then convert from base unit to target
    switch (targetUnit) {
      case IngredientUnit.kg:
        return baseQuantity / 1000; // gram to kg
      case IngredientUnit.liter:
        return baseQuantity / 1000; // ml to liter
      default:
        return baseQuantity;
    }
  }

  /// Get conversion factor to base unit (for recipe storage)
  double get toBaseUnitFactor {
    switch (this) {
      case IngredientUnit.kg:
        return 1000.0;
      case IngredientUnit.liter:
        return 1000.0;
      default:
        return 1.0;
    }
  }

  /// Get user-friendly units for recipe input based on stock unit
  List<IngredientUnit> get recipeInputUnits {
    switch (baseUnit) {
      case IngredientUnit.ml:
        return [IngredientUnit.ml, IngredientUnit.liter];
      case IngredientUnit.gram:
        return [IngredientUnit.gram, IngredientUnit.kg];
      default:
        return [this];
    }
  }

  static IngredientUnit fromString(String value) {
    return IngredientUnit.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => IngredientUnit.gram,
    );
  }
}

/// Stock movement types
enum MovementType {
  STOCK_IN,
  AUTO_DEDUCT,
  ADJUSTMENT,
}

extension MovementTypeExtension on MovementType {
  String get displayName {
    switch (this) {
      case MovementType.STOCK_IN:
        return 'Stock In';
      case MovementType.AUTO_DEDUCT:
        return 'Auto Deduct';
      case MovementType.ADJUSTMENT:
        return 'Adjustment';
    }
  }

  String get dbValue => toString().split('.').last;

  static MovementType fromString(String value) {
    return MovementType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => MovementType.ADJUSTMENT,
    );
  }
}

/// Reference types for stock movements
enum ReferenceType {
  ORDER,
  PURCHASE,
  MANUAL,
}

extension ReferenceTypeExtension on ReferenceType {
  String get displayName {
    switch (this) {
      case ReferenceType.ORDER:
        return 'Order';
      case ReferenceType.PURCHASE:
        return 'Purchase';
      case ReferenceType.MANUAL:
        return 'Manual';
    }
  }

  String get dbValue => toString().split('.').last;

  static ReferenceType fromString(String value) {
    return ReferenceType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => ReferenceType.MANUAL,
    );
  }
}

/// Ingredient Model - Bahan Baku
class Ingredient {
  final String id;
  final String name;
  final IngredientUnit unit;
  final double currentStock;
  final double costPerUnit;
  final double minStock;
  final String? supplierName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.costPerUnit,
    required this.minStock,
    this.supplierName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if stock is low (at or below minimum threshold)
  bool get isLowStock => currentStock <= minStock;

  /// Check if out of stock
  bool get isOutOfStock => currentStock <= 0;

  /// Stock level as percentage of minimum (useful for indicators)
  double get stockLevelPercent {
    if (minStock <= 0) return 100;
    return (currentStock / minStock) * 100;
  }

  /// Format stock display with unit
  String get stockDisplay {
    final stockStr = currentStock == currentStock.roundToDouble()
        ? currentStock.toStringAsFixed(0)
        : currentStock.toStringAsFixed(1);
    return '$stockStr ${unit.displayName}';
  }

  /// Format cost display
  String get costDisplay {
    final formatted = costPerUnit.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted/${unit.displayName}';
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: IngredientUnitExtension.fromString(json['unit'] as String),
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0,
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble() ?? 0,
      minStock: (json['min_stock'] as num?)?.toDouble() ?? 0,
      supplierName: json['supplier_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit.dbValue,
      'current_stock': currentStock,
      'cost_per_unit': costPerUnit,
      'min_stock': minStock,
      'supplier_name': supplierName,
      'is_active': isActive,
    };
  }

  /// For creating new ingredient (without id, timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'unit': unit.dbValue,
      'current_stock': currentStock,
      'cost_per_unit': costPerUnit,
      'min_stock': minStock,
      'supplier_name': supplierName,
      'is_active': isActive,
    };
  }

  Ingredient copyWith({
    String? id,
    String? name,
    IngredientUnit? unit,
    double? currentStock,
    double? costPerUnit,
    double? minStock,
    String? supplierName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      minStock: minStock ?? this.minStock,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ProductRecipe Model - Resep/BOM (Bill of Materials)
class ProductRecipe {
  final String id;
  final String productId;
  final String ingredientId;
  final double quantity; // stored in BASE unit (gram/ml)
  final DateTime createdAt;
  final Ingredient? ingredient; // joined data

  ProductRecipe({
    required this.id,
    required this.productId,
    required this.ingredientId,
    required this.quantity,
    required this.createdAt,
    this.ingredient,
  });

  /// Calculate cost for this recipe item (quantity is in base unit, cost is per stock unit)
  double get itemCost {
    if (ingredient == null) return 0;
    // Convert recipe quantity (base unit) to ingredient's stock unit for cost calculation
    final stockUnit = ingredient!.unit;
    final baseUnit = stockUnit.baseUnit;
    final qtyInStockUnit = baseUnit.convertTo(quantity, stockUnit);
    return qtyInStockUnit * ingredient!.costPerUnit;
  }

  /// Format quantity display in user-friendly unit
  String get quantityDisplay {
    if (ingredient == null) return '${quantity.toStringAsFixed(1)}';

    final stockUnit = ingredient!.unit;
    final baseUnit = stockUnit.baseUnit;

    // Auto-select display unit based on quantity size
    String displayQty;
    String displayUnit;

    if (baseUnit == IngredientUnit.ml) {
      if (quantity >= 1000) {
        displayQty = (quantity / 1000).toStringAsFixed(quantity % 1000 == 0 ? 0 : 2);
        displayUnit = 'liter';
      } else {
        displayQty = quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1);
        displayUnit = 'ml';
      }
    } else if (baseUnit == IngredientUnit.gram) {
      if (quantity >= 1000) {
        displayQty = (quantity / 1000).toStringAsFixed(quantity % 1000 == 0 ? 0 : 2);
        displayUnit = 'kg';
      } else {
        displayQty = quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1);
        displayUnit = 'gram';
      }
    } else {
      displayQty = quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1);
      displayUnit = stockUnit.displayName;
    }

    return '$displayQty $displayUnit';
  }

  factory ProductRecipe.fromJson(Map<String, dynamic> json) {
    return ProductRecipe(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      ingredient: json['ingredient'] != null
          ? Ingredient.fromJson(json['ingredient'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
    };
  }

  /// For creating new recipe (without id, timestamp)
  Map<String, dynamic> toInsertJson() {
    return {
      'product_id': productId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
    };
  }

  ProductRecipe copyWith({
    String? id,
    String? productId,
    String? ingredientId,
    double? quantity,
    DateTime? createdAt,
    Ingredient? ingredient,
  }) {
    return ProductRecipe(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ingredientId: ingredientId ?? this.ingredientId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      ingredient: ingredient ?? this.ingredient,
    );
  }
}

/// StockMovement Model - Audit Log for stock changes
class StockMovement {
  final String id;
  final String ingredientId;
  final MovementType movementType;
  final double quantity; // positive = in, negative = out
  final double? unitCost;
  final ReferenceType? referenceType;
  final String? referenceId;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final Ingredient? ingredient; // joined data

  StockMovement({
    required this.id,
    required this.ingredientId,
    required this.movementType,
    required this.quantity,
    this.unitCost,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.ingredient,
  });

  /// Check if this is an incoming movement (stock increase)
  bool get isIncoming => quantity > 0;

  /// Check if this is an outgoing movement (stock decrease)
  bool get isOutgoing => quantity < 0;

  /// Absolute quantity (always positive)
  double get absoluteQuantity => quantity.abs();

  /// Total cost for this movement
  double? get totalCost =>
      unitCost != null ? (unitCost! * absoluteQuantity) : null;

  /// Format quantity display with sign and unit
  String get quantityDisplay {
    final sign = isIncoming ? '+' : '';
    final unitStr = ingredient?.unit.displayName ?? '';
    return '$sign${quantity.toStringAsFixed(3)} $unitStr';
  }

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      ingredientId: json['ingredient_id'] as String,
      movementType:
          MovementTypeExtension.fromString(json['movement_type'] as String),
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num?)?.toDouble(),
      referenceType: json['reference_type'] != null
          ? ReferenceTypeExtension.fromString(json['reference_type'] as String)
          : null,
      referenceId: json['reference_id'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      ingredient: json['ingredient'] != null
          ? Ingredient.fromJson(json['ingredient'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'movement_type': movementType.dbValue,
      'quantity': quantity,
      'unit_cost': unitCost,
      'reference_type': referenceType?.dbValue,
      'reference_id': referenceId,
      'notes': notes,
      'created_by': createdBy,
    };
  }

  /// For creating new movement (without id, timestamp)
  Map<String, dynamic> toInsertJson() {
    return {
      'ingredient_id': ingredientId,
      'movement_type': movementType.dbValue,
      'quantity': quantity,
      'unit_cost': unitCost,
      'reference_type': referenceType?.dbValue,
      'reference_id': referenceId,
      'notes': notes,
      'created_by': createdBy,
    };
  }
}

/// Helper class for HPP (Harga Pokok Penjualan) calculation
class ProductHPP {
  final String productId;
  final String productName;
  final double sellingPrice;
  final double hpp;
  final List<ProductRecipe> recipes;

  ProductHPP({
    required this.productId,
    required this.productName,
    required this.sellingPrice,
    required this.hpp,
    this.recipes = const [],
  });

  /// Profit margin in Rupiah
  double get profitMargin => sellingPrice - hpp;

  /// Profit percentage
  double get profitPercent {
    if (sellingPrice <= 0) return 0;
    return (profitMargin / sellingPrice) * 100;
  }

  /// Check if profitable
  bool get isProfitable => profitMargin > 0;

  /// Format HPP display
  String get hppDisplay => 'Rp ${hpp.toStringAsFixed(0)}';

  /// Format profit margin display
  String get profitMarginDisplay {
    final sign = profitMargin >= 0 ? '+' : '';
    return '${sign}Rp ${profitMargin.toStringAsFixed(0)}';
  }

  /// Format profit percent display
  String get profitPercentDisplay => '${profitPercent.toStringAsFixed(1)}%';

  factory ProductHPP.fromJson(Map<String, dynamic> json) {
    return ProductHPP(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      hpp: (json['hpp'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Helper class for Stock Summary statistics
class StockSummary {
  final int totalIngredients;
  final int activeIngredients;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockValue;

  StockSummary({
    required this.totalIngredients,
    required this.activeIngredients,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalStockValue,
  });

  /// Percentage of ingredients with healthy stock levels
  double get healthyStockPercent {
    if (activeIngredients <= 0) return 100;
    final healthy = activeIngredients - lowStockCount;
    return (healthy / activeIngredients) * 100;
  }

  factory StockSummary.fromIngredients(List<Ingredient> ingredients) {
    final active = ingredients.where((i) => i.isActive).toList();
    final lowStock = active.where((i) => i.isLowStock).toList();
    final outOfStock = active.where((i) => i.isOutOfStock).toList();
    final totalValue = active.fold<double>(
      0,
      (sum, i) => sum + (i.currentStock * i.costPerUnit),
    );

    return StockSummary(
      totalIngredients: ingredients.length,
      activeIngredients: active.length,
      lowStockCount: lowStock.length,
      outOfStockCount: outOfStock.length,
      totalStockValue: totalValue,
    );
  }
}
