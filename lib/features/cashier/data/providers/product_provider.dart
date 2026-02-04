import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../customer/data/repositories/product_repository.dart';
import 'repository_providers.dart';

// ============================================================
// PRODUCT STATE PROVIDERS
// ============================================================

// Provider for all products
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProducts();
});

// Provider for products by category
final productsByCategoryProvider = FutureProvider.family<List<Product>, ProductCategory>((ref, category) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsByCategory(category);
});

// Provider for single product by ID
final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(id);
});

// Provider for search products
final searchProductsProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  final repository = ref.watch(productRepositoryProvider);
  if (query.isEmpty) {
    return repository.getProducts();
  }
  return repository.searchProducts(query);
});

// ============================================================
// PRODUCT MANAGEMENT NOTIFIER
// ============================================================

class ProductNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _repository;

  ProductNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = const AsyncValue.loading();
    try {
      final products = await _repository.getProducts();
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Product> createProduct({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    int stockQty = 0,
    bool isFeaturedIxon = false,
    double ixonMultiplier = 1.0,
    String? imageUrl,
    bool isFeatured = false,
    bool isPromo = false,
    double promoDiscountPercent = 0,
    bool isPackage = false,
    ProductType type = ProductType.STANDARD,
    List<ProductModifier>? modifiers,
    List<Map<String, dynamic>>? productImages,
  }) async {
    try {
      final product = await _repository.createProduct(
        name: name,
        description: description,
        price: price,
        category: category,
        stockQty: stockQty,
        isFeaturedIxon: isFeaturedIxon,
        ixonMultiplier: ixonMultiplier,
        imageUrl: imageUrl,
        isFeatured: isFeatured,
        isPromo: isPromo,
        promoDiscountPercent: promoDiscountPercent,
        isPackage: isPackage,
        type: type,
      );
      
      if (modifiers != null) {
        await _repository.syncProductModifiers(product.id, modifiers);
      }
      
      if (productImages != null) {
        await _handleProductImages(product.id, productImages);
      }

      await loadProducts();
      return product;
    } catch (e) {
      rethrow;
    }
  }

  Future<Product> updateProduct({
    required String id,
    String? name,
    String? description,
    double? price,
    ProductCategory? category,
    int? stockQty,
    bool? isFeaturedIxon,
    double? ixonMultiplier,
    String? imageUrl,
    bool? isActive,
    bool? isFeatured,
    bool? isPromo,
    double? promoDiscountPercent,
    bool? isPackage,
    ProductType? type,
    List<ProductModifier>? modifiers,
    List<Map<String, dynamic>>? productImages,
  }) async {
    try {
      final product = await _repository.updateProduct(
        id: id,
        name: name,
        description: description,
        price: price,
        category: category,
        stockQty: stockQty,
        isFeaturedIxon: isFeaturedIxon,
        ixonMultiplier: ixonMultiplier,
        imageUrl: imageUrl,
        isActive: isActive,
        isFeatured: isFeatured,
        isPromo: isPromo,
        promoDiscountPercent: promoDiscountPercent,
        isPackage: isPackage,
        type: type,
      );
      
      if (modifiers != null) {
        await _repository.syncProductModifiers(id, modifiers);
      }
      
      if (productImages != null) {
        await _handleProductImages(id, productImages);
      }

      await loadProducts();
      return product;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handleProductImages(String productId, List<Map<String, dynamic>> images) async {
    // 1. Delete marked images
    final deletedImages = images.where((img) => img['isDeleted'] == true && img['id'] != null);
    for (final img in deletedImages) {
      await _repository.deleteProductImageRecord(img['id'], img['url']);
    }

    // 2. Upload and Add/Update remaining images
    final activeImages = images.where((img) => img['isDeleted'] != true).toList();
    for (int i = 0; i < activeImages.length; i++) {
      final img = activeImages[i];
      String url = img['url'];
      
      // If it's a new image with bytes, upload it
      if (img['bytes'] != null) {
        url = await _repository.uploadProductImage(img['bytes'], img['name']);
      }

      if (img['id'] == null) {
        // New record
        await _repository.addProductImage(
          productId: productId,
          imageUrl: url,
          displayOrder: i,
          isPrimary: img['isPrimary'] ?? false,
        );
      } else {
        // Update existing record
        await _repository.updateImageOrder(img['id'], i);
        if (img['isPrimary'] == true) {
          await _repository.setPrimaryImage(productId, img['id']);
        }
      }
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      await loadProducts();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreProduct(String id) async {
    try {
      await _repository.restoreProduct(id);
      await loadProducts();
    } catch (e) {
      rethrow;
    }
  }
}

final productNotifierProvider = StateNotifierProvider<ProductNotifier, AsyncValue<List<Product>>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductNotifier(repository);
});
