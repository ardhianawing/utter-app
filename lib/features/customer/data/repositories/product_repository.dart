import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/models.dart';

class ProductRepository {
  final SupabaseClient _supabase;

  ProductRepository(this._supabase);

  Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, modifiers:product_modifiers(*)') // Join with modifiers
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      // In a real app, handle error properly
      throw Exception('Failed to load products: $e');
    }
  }

  Future<List<Product>> getProductsByCategory(ProductCategory category) async {
    final response = await _supabase
        .from('products')
        .select('*, modifiers:product_modifiers(*)')
        .eq('category', category.name)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((json) => Product.fromJson(json))
        .toList();
  }

  Future<Product?> getProductById(String id) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, modifiers:product_modifiers(*)')
          .eq('id', id)
          .single();

      return Product.fromJson(response);
    } catch (e) {
      return null;
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
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .insert({
            'name': name,
            'description': description,
            'price': price,
            'category': category.name,
            'stock_qty': stockQty,
            'is_featured_ixon': isFeaturedIxon,
            'ixon_multiplier': ixonMultiplier,
            'image_url': imageUrl,
            'is_active': true,
            'is_featured': isFeatured,
            'is_promo': isPromo,
            'promo_discount_percent': promoDiscountPercent,
            'is_package': isPackage,
            'type': type.name,
          })
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create product: $e');
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
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (price != null) updateData['price'] = price;
      if (category != null) updateData['category'] = category.name;
      if (stockQty != null) updateData['stock_qty'] = stockQty;
      if (isFeaturedIxon != null) updateData['is_featured_ixon'] = isFeaturedIxon;
      if (ixonMultiplier != null) updateData['ixon_multiplier'] = ixonMultiplier;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (isActive != null) updateData['is_active'] = isActive;
      if (isFeatured != null) updateData['is_featured'] = isFeatured;
      if (isPromo != null) updateData['is_promo'] = isPromo;
      if (promoDiscountPercent != null) updateData['promo_discount_percent'] = promoDiscountPercent;
      if (isPackage != null) updateData['is_package'] = isPackage;
      if (type != null) updateData['type'] = type.name;

      final response = await _supabase
          .from('products')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      // Soft delete - set is_active to false instead of hard delete
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> restoreProduct(String id) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to restore product: $e');
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, modifiers:product_modifiers(*)')
          .eq('is_active', true)
          .ilike('name', '%$query%')
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Upload image to Supabase Storage and return public URL
  Future<String> uploadProductImage(List<int> imageBytes, String fileName) async {
    try {
      // Generate unique filename
      final uuid = const Uuid();
      final uniqueId = uuid.v4();
      final extension = fileName.split('.').last;
      final uniqueFileName = 'product_$uniqueId.$extension';

      // Upload to Supabase Storage bucket 'product-images'
      final path = await _supabase.storage
          .from('product-images')
          .uploadBinary(
            uniqueFileName,
            Uint8List.fromList(imageBytes),
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('product-images')
          .getPublicUrl(uniqueFileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete image from Supabase Storage
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;

      await _supabase.storage
          .from('product-images')
          .remove([fileName]);
    } catch (e) {
      // Ignore error if image doesn't exist
      print('Failed to delete image: $e');
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // PRODUCT IMAGES MANAGEMENT (Multiple Images per Product)
  // ============================================================

  /// Get all images for a product
  Future<List<Map<String, dynamic>>> getProductImages(String productId) async {
    try {
      final response = await _supabase
          .from('product_images')
          .select()
          .eq('product_id', productId)
          .order('display_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get product images: $e');
    }
  }

  /// Add image to product
  Future<Map<String, dynamic>> addProductImage({
    required String productId,
    required String imageUrl,
    int displayOrder = 0,
    bool isPrimary = false,
  }) async {
    try {
      final response = await _supabase
          .from('product_images')
          .insert({
            'product_id': productId,
            'image_url': imageUrl,
            'display_order': displayOrder,
            'is_primary': isPrimary,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to add product image: $e');
    }
  }

  /// Delete product image record (also removes from storage)
  Future<void> deleteProductImageRecord(String imageId, String imageUrl) async {
    try {
      // Delete from database
      await _supabase
          .from('product_images')
          .delete()
          .eq('id', imageId);

      // Delete from storage
      await deleteProductImage(imageUrl);
    } catch (e) {
      throw Exception('Failed to delete product image: $e');
    }
  }

  /// Update image display order
  Future<void> updateImageOrder(String imageId, int newOrder) async {
    try {
      await _supabase
          .from('product_images')
          .update({'display_order': newOrder})
          .eq('id', imageId);
    } catch (e) {
      throw Exception('Failed to update image order: $e');
    }
  }

  /// Set primary image for product
  Future<void> setPrimaryImage(String productId, String imageId) async {
    try {
      // First, unset all primary flags for this product
      await _supabase
          .from('product_images')
          .update({'is_primary': false})
          .eq('product_id', productId);

      // Then set the selected image as primary
      await _supabase
          .from('product_images')
          .update({'is_primary': true})
          .eq('id', imageId);
    } catch (e) {
      throw Exception('Failed to set primary image: $e');
    }
  }
  // ============================================================
  // PRODUCT MODIFIERS MANAGEMENT
  // ============================================================

  Future<void> syncProductModifiers(String productId, List<ProductModifier> modifiers) async {
    try {
      // Simple approach: delete existing and insert new ones
      // In a more complex app, we might want to update existing IDs
      await _supabase
          .from('product_modifiers')
          .delete()
          .eq('product_id', productId);

      if (modifiers.isNotEmpty) {
        final data = modifiers.map((m) => {
          'product_id': productId,
          'category': m.category,
          'name': m.name,
          'extra_price': m.extraPrice,
        }).toList();

        await _supabase.from('product_modifiers').insert(data);
      }
    } catch (e) {
      throw Exception('Failed to sync modifiers: $e');
    }
  }

  Future<void> addModifier(String productId, ProductModifier modifier) async {
    try {
      await _supabase.from('product_modifiers').insert({
        'product_id': productId,
        'category': modifier.category,
        'name': modifier.name,
        'extra_price': modifier.extraPrice,
      });
    } catch (e) {
      throw Exception('Failed to add modifier: $e');
    }
  }

  Future<void> deleteModifier(String modifierId) async {
    try {
      await _supabase
          .from('product_modifiers')
          .delete()
          .eq('id', modifierId);
    } catch (e) {
      throw Exception('Failed to delete modifier: $e');
    }
  }
}
