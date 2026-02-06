enum OrderSource { APP, POS_MANUAL, GOFOOD, GRABFOOD, SHOPEEFOOD, MANUAL_ENTRY }
enum OrderType { DINE_IN, TAKEAWAY }
enum OrderStatus {
  PENDING_PAYMENT,  // Order created, waiting for payment
  PAID,             // Payment confirmed, ready for kitchen
  PREPARING,        // Kitchen is cooking
  READY,            // Food ready, waiting to be served
  SERVED,           // Served to customer
  COMPLETED,        // Order fully completed
  CANCELLED         // Order cancelled
}
enum PaymentMethod { QRIS, CASH, DEBIT }
enum ProductCategory {
  BEVERAGE_COFFEE,
  BEVERAGE_NON_COFFEE,
  FOOD,
  SNACK,
  OTHER
}

enum ProductType { STANDARD, RAMEN, DRINK }

extension ProductCategoryExtension on ProductCategory {
  String get displayName {
    switch (this) {
      case ProductCategory.BEVERAGE_COFFEE:
        return 'Beverages - Coffee';
      case ProductCategory.BEVERAGE_NON_COFFEE:
        return 'Beverages - Non Coffee';
      case ProductCategory.FOOD:
        return 'Food';
      case ProductCategory.SNACK:
        return 'Snack';
      case ProductCategory.OTHER:
        return 'Other';
    }
  }

  String get dbValue {
    return toString().split('.').last;
  }
}
enum UserTier { STANDARD, IXON_ELITE }

class Product {
  final String id;
  final String name;
  final String description;
  final double price; // base price
  final ProductCategory category;
  final int stockQty;
  final bool isFeaturedIxon;
  final double ixonMultiplier;
  final String? imageUrl; // primary product image URL
  final bool isFeatured; // featured menu
  final bool isPromo; // promo menu
  final double promoDiscountPercent; // discount %
  final bool isPackage; // bundle package
  final Map<OrderSource, double>? platformPrices; // platform-specific prices
  final ProductType type;
  final bool isActive;
  final List<ProductModifier>? availableModifiers;
  final double? hpp; // Harga Pokok Penjualan (calculated from recipes)

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQty,
    this.isFeaturedIxon = false,
    this.ixonMultiplier = 1.0,
    this.imageUrl,
    this.isFeatured = false,
    this.isPromo = false,
    this.promoDiscountPercent = 0,
    this.isPackage = false,
    this.platformPrices,
    this.type = ProductType.STANDARD,
    this.isActive = true,
    this.availableModifiers,
    this.hpp,
  });

  /// Calculate profit margin (selling price - HPP)
  double get profitMargin => hpp != null ? price - hpp! : price;

  /// Calculate profit percentage
  double get profitPercent {
    if (price <= 0 || hpp == null) return 100;
    return (profitMargin / price) * 100;
  }

  /// Check if product is profitable
  bool get isProfitable => hpp == null || profitMargin > 0;

  List<ProductModifier>? get modifiers => availableModifiers;

  double get finalPrice {
    if (isPromo && promoDiscountPercent > 0) {
      return price * (1 - promoDiscountPercent / 100);
    }
    return price;
  }

  // Get price for specific platform
  double getPriceForPlatform(OrderSource source) {
    if (platformPrices != null && platformPrices!.containsKey(source)) {
      return platformPrices![source]!;
    }
    return price; // fallback to base price
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      category: ProductCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => ProductCategory.FOOD,
      ),
      stockQty: json['stock_qty'] as int? ?? 0,
      isFeaturedIxon: json['is_featured_ixon'] as bool? ?? false,
      ixonMultiplier: (json['ixon_multiplier'] as num?)?.toDouble() ?? 1.0,
      imageUrl: json['image_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPromo: json['is_promo'] as bool? ?? false,
      promoDiscountPercent: (json['promo_discount_percent'] as num?)?.toDouble() ?? 0,
      isPackage: json['is_package'] as bool? ?? false,
      platformPrices: null, // will be loaded separately if needed
      type: ProductType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] ?? 'STANDARD'),
        orElse: () => ProductType.STANDARD,
      ),
      isActive: json['is_active'] as bool? ?? true,
      availableModifiers: json['modifiers'] != null
          ? (json['modifiers'] as List)
              .map((m) => ProductModifier.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
      hpp: (json['hpp'] as num?)?.toDouble(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    ProductCategory? category,
    int? stockQty,
    bool? isFeaturedIxon,
    double? ixonMultiplier,
    String? imageUrl,
    bool? isFeatured,
    bool? isPromo,
    double? promoDiscountPercent,
    bool? isPackage,
    Map<OrderSource, double>? platformPrices,
    ProductType? type,
    bool? isActive,
    List<ProductModifier>? availableModifiers,
    double? hpp,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      stockQty: stockQty ?? this.stockQty,
      isFeaturedIxon: isFeaturedIxon ?? this.isFeaturedIxon,
      ixonMultiplier: ixonMultiplier ?? this.ixonMultiplier,
      imageUrl: imageUrl ?? this.imageUrl,
      isFeatured: isFeatured ?? this.isFeatured,
      isPromo: isPromo ?? this.isPromo,
      promoDiscountPercent: promoDiscountPercent ?? this.promoDiscountPercent,
      isPackage: isPackage ?? this.isPackage,
      platformPrices: platformPrices ?? this.platformPrices,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      availableModifiers: availableModifiers ?? this.availableModifiers,
      hpp: hpp ?? this.hpp,
    );
  }
}

class ProductModifier {
  final String id;
  final String category; // e.g., 'Broth', 'Topping', 'Temperature', 'Sugar'
  final String name;
  final double extraPrice;

  ProductModifier({
    required this.id,
    required this.category,
    required this.name,
    this.extraPrice = 0,
  });

  factory ProductModifier.fromJson(Map<String, dynamic> json) {
    return ProductModifier(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      extraPrice: (json['extra_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'extra_price': extraPrice,
    };
  }
}

class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final int displayOrder;
  final bool isPrimary;
  final DateTime createdAt;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.displayOrder = 0,
    this.isPrimary = false,
    required this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      imageUrl: json['image_url'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}


class User {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final int currentPoints;
  final UserTier tierLevel;

  User({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    required this.currentPoints,
    required this.tierLevel,
  });
}

class Order {
  final String id;
  final OrderSource source;
  final OrderType type;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? tableId;
  final String? userId;
  final String? shiftId;
  final double totalAmount;
  final int pointsEarned;
  final int pointsRedeemed;
  final String? transactionId;
  final String? notes;
  final String? customerName;
  final String? displayId;
  final String? cancelReason;
  final DateTime? preparationStartedAt;
  final DateTime? preparationCompletedAt;
  final double? cashReceived;
  final double? cashChange;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.source,
    required this.type,
    required this.status,
    required this.paymentMethod,
    this.tableId,
    this.userId,
    this.shiftId,
    this.customerName,
    required this.totalAmount,
    required this.pointsEarned,
    required this.pointsRedeemed,
    this.transactionId,
    this.notes,
    this.displayId,
    this.cancelReason,
    this.preparationStartedAt,
    this.preparationCompletedAt,
    this.cashReceived,
    this.cashChange,
    required this.createdAt,
  });

  Duration? get preparationTime {
    if (preparationStartedAt != null && preparationCompletedAt != null) {
      return preparationCompletedAt!.difference(preparationStartedAt!);
    }
    return null;
  }

  Duration get timeSinceOrder {
    return DateTime.now().difference(createdAt);
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      source: OrderSource.values.firstWhere(
        (e) => e.toString().split('.').last == json['source'],
        orElse: () => OrderSource.APP,
      ),
      type: OrderType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => OrderType.DINE_IN,
      ),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => OrderStatus.PENDING_PAYMENT,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == json['payment_method'],
        orElse: () => PaymentMethod.CASH,
      ),
      tableId: json['table_id'] as String?,
      userId: json['user_id'] as String?,
      shiftId: json['shift_id'] as String?,
      customerName: json['customer_name'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      pointsEarned: json['points_earned'] as int? ?? 0,
      pointsRedeemed: json['points_redeemed'] as int? ?? 0,
      transactionId: json['transaction_id'] as String?,
      notes: json['notes'] as String?,
      displayId: json['display_id'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      preparationStartedAt: json['preparation_started_at'] != null
          ? DateTime.parse(json['preparation_started_at'] as String)
          : null,
      preparationCompletedAt: json['preparation_completed_at'] != null
          ? DateTime.parse(json['preparation_completed_at'] as String)
          : null,
      cashReceived: (json['cash_received'] as num?)?.toDouble(),
      cashChange: (json['cash_change'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

enum UserRole { ADMIN, CASHIER, KITCHEN }

class StaffProfile {
  final String id;
  final String name;
  final String username; // Username for login (bisa berupa apapun, tidak harus nomor HP)
  final UserRole role;
  final String? phone;
  final bool isActive;

  StaffProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.phone,
    this.isActive = true,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String? ?? json['phone'] as String? ?? '', // fallback untuk data lama
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == (json['role'] as String).toLowerCase(),
        orElse: () => UserRole.CASHIER,
      ),
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role.toString().split('.').last.toLowerCase(),
      'phone': phone,
      'is_active': isActive,
    };
  }
}

class Shift {
  final String id;
  final String cashierId;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingCash;
  final double? endingCash;
  final double totalCashReceived;
  final double totalQrisReceived;
  final double totalDebitReceived;
  final double? expectedCash;
  final double? cashDifference;
  final String status;
  final String? notes;

  Shift({
    required this.id,
    required this.cashierId,
    required this.startTime,
    this.endTime,
    required this.startingCash,
    this.endingCash,
    this.totalCashReceived = 0,
    this.totalQrisReceived = 0,
    this.totalDebitReceived = 0,
    this.expectedCash,
    this.cashDifference,
    required this.status,
    this.notes,
  });

  // Computed properties
  double get totalSales => totalCashReceived + totalQrisReceived + totalDebitReceived;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      cashierId: json['cashier_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      startingCash: (json['starting_cash'] as num).toDouble(),
      endingCash: (json['ending_cash'] as num?)?.toDouble(),
      totalCashReceived: (json['total_cash_received'] as num?)?.toDouble() ?? 0,
      totalQrisReceived: (json['total_qris_received'] as num?)?.toDouble() ?? 0,
      totalDebitReceived: (json['total_debit_received'] as num?)?.toDouble() ?? 0,
      expectedCash: (json['expected_cash'] as num?)?.toDouble(),
      cashDifference: (json['cash_difference'] as num?)?.toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashier_id': cashierId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'starting_cash': startingCash,
      'ending_cash': endingCash,
      'total_cash_received': totalCashReceived,
      'total_qris_received': totalQrisReceived,
      'total_debit_received': totalDebitReceived,
      'status': status,
      'notes': notes,
    };
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;
  final List<ProductModifier>? selectedModifiers;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
    this.selectedModifiers,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      notes: json['notes'] as String?,
      selectedModifiers: json['selected_modifiers'] != null
          ? (json['selected_modifiers'] as List)
              .map((m) => ProductModifier.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  double get totalPrice => subtotal;
}

class RestaurantTable {
  final String id;
  final int tableNumber;
  final String qrCodeString;
  final int capacity;
  final String status;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.qrCodeString,
    required this.capacity,
    required this.status,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'] as String,
      tableNumber: json['table_number'] as int,
      qrCodeString: json['qr_code_string'] as String,
      capacity: json['capacity'] as int,
      status: json['status'] as String,
    );
  }
}

// Helper class for displaying order items with product details
class OrderItemWithProduct {
  final OrderItem orderItem;
  final Product? product;

  OrderItemWithProduct({
    required this.orderItem,
    this.product,
  });

  String get productName => product?.name ?? 'Unknown Product';
  String get notes => orderItem.notes ?? '';
  bool get hasNotes => orderItem.notes != null && orderItem.notes!.isNotEmpty;
}

// Helper class for shift summary reports
class ShiftSummary {
  final Shift shift;
  final String cashierName;
  final int orderCount;
  final List<TopProduct> topProducts;

  ShiftSummary({
    required this.shift,
    required this.cashierName,
    required this.orderCount,
    this.topProducts = const [],
  });

  double get totalSales => shift.totalSales;
  String get duration => shift.durationFormatted;
  bool get hasCashDifference => shift.cashDifference != null && shift.cashDifference! != 0;
  String get cashDifferenceFormatted {
    if (shift.cashDifference == null) return 'N/A';
    final amount = shift.cashDifference!;
    if (amount > 0) return '+Rp ${amount.toStringAsFixed(0)}';
    if (amount < 0) return '-Rp ${(-amount).toStringAsFixed(0)}';
    return 'Rp 0';
  }
}

// Helper class for top-selling products in a shift
class TopProduct {
  final String productId;
  final String productName;
  final ProductCategory category;
  final int timesOrdered;
  final int totalQuantity;
  final double totalRevenue;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.timesOrdered,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      category: ProductCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => ProductCategory.FOOD,
      ),
      timesOrdered: json['times_ordered'] as int,
      totalQuantity: json['total_quantity'] as int,
      totalRevenue: (json['total_revenue'] as num).toDouble(),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  String? notes;
  final List<ProductModifier> selectedModifiers;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
    this.selectedModifiers = const [],
  });

  double get unitPrice {
    double modifiersTotal = selectedModifiers.fold(0, (sum, m) => sum + m.extraPrice);
    
    // Special logic for ramen with 0 base price (price depends on topping)
    if (product.type == ProductType.RAMEN && (product.price == 0)) {
      final topping = selectedModifiers.firstWhere(
        (m) => m.category.toLowerCase() == 'topping',
        orElse: () => ProductModifier(id: '', category: '', name: '', extraPrice: 0),
      );
      return topping.extraPrice;
    }
    
    return product.finalPrice + modifiersTotal;
  }

  double get totalPrice => unitPrice * quantity;

  bool get hasNotes => notes != null && notes!.isNotEmpty;

  String get uniqueKey {
    final modIds = selectedModifiers.map((m) => m.id).toList()..sort();
    final notesKey = notes != null ? '_note_${notes.hashCode}' : '';
    return '${product.id}_${modIds.join("_")}$notesKey';
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? notes,
    List<ProductModifier>? selectedModifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }
}

