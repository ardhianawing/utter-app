import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/product_provider.dart';

class ProductCategorySection extends ConsumerWidget {
  final Function(Product) onProductTap;
  final bool isOnlineFood;

  const ProductCategorySection({
    super.key,
    required this.onProductTap,
    this.isOnlineFood = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productNotifierProvider);

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Text('No products available'),
          );
        }

        // Group products by category
        final categoryGroups = <ProductCategory, List<Product>>{};
        for (var product in products) {
          if (!categoryGroups.containsKey(product.category)) {
            categoryGroups[product.category] = [];
          }
          categoryGroups[product.category]!.add(product);
        }

        // Identify "Special Offers" (Featured, Promo, Package)
        final specialOffers = products.where((p) => p.isFeatured || p.isPromo || p.isPackage).toList();

        // Sort categories in desired order
        final orderedCategories = [
          ProductCategory.BEVERAGE_COFFEE,
          ProductCategory.BEVERAGE_NON_COFFEE,
          ProductCategory.FOOD,
          ProductCategory.SNACK,
          ProductCategory.OTHER,
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Special Offers Section
            if (specialOffers.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PROMO & FAVORIT (SPECIAL OFFERS)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.1,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 180,
                margin: const EdgeInsets.only(bottom: 24),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: specialOffers.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      child: _ProductCard(
                        product: specialOffers[index],
                        onTap: () => onProductTap(specialOffers[index]),
                        isOnlineFood: isOnlineFood,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 32),
            ],

            const Padding(
              padding: EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                'SEMUA KATEGORI',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                ),
              ),
            ),

            ...orderedCategories.map((category) {
              final categoryProducts = categoryGroups[category] ?? [];
              if (categoryProducts.isEmpty) return const SizedBox.shrink();

              return _CategoryExpansionTile(
                category: category,
                products: categoryProducts,
                onProductTap: onProductTap,
                isOnlineFood: isOnlineFood,
              );
            }).toList(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(productNotifierProvider.notifier).loadProducts();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryExpansionTile extends StatelessWidget {
  final ProductCategory category;
  final List<Product> products;
  final Function(Product) onProductTap;
  final bool isOnlineFood;

  const _CategoryExpansionTile({
    required this.category,
    required this.products,
    required this.onProductTap,
    this.isOnlineFood = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          category.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text('${products.length} items'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid: adjust columns based on width
                int crossAxisCount = 2;
                if (constraints.maxWidth > 800) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 600) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => onProductTap(product),
                      isOnlineFood: isOnlineFood,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isOnlineFood;

  const _ProductCard({
    required this.product,
    required this.onTap,
    this.isOnlineFood = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image with Badges
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Image
                  product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.fastfood,
                                size: 48,
                                color: Colors.grey,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.fastfood,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),

                  // Promo Badge (Top Left)
                  if (product.isPromo)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.promoDiscountPercent.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Featured Badge (Top Right)
                  if (product.isFeatured)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Package Badge (Bottom Center)
                  if (product.isPackage)
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PACKAGE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price Display (Hidden for Online Food)
                        if (!isOnlineFood)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Original price (strikethrough if promo)
                                if (product.isPromo)
                                  Text(
                                    'Rp ${product.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                // Final price (discounted or normal)
                                Text(
                                  'Rp ${product.finalPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: product.isPromo ? Colors.red : AppColors.successGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()), // Placeholder to keep layout
                        // IXON Badge
                        if (product.isFeaturedIxon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 10, color: Colors.orange),
                                SizedBox(width: 2),
                                Text(
                                  'IXON',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
