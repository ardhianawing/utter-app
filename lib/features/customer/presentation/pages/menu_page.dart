import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/cart_provider.dart';
import '../../data/providers/order_context_provider.dart';
import '../../../cashier/data/providers/product_provider.dart';
import '../../../shared/models/models.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/constants/app_colors.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

class MenuPage extends ConsumerStatefulWidget {
  final String? tableId;
  final int? tableNumber;

  const MenuPage({
    super.key,
    this.tableId,
    this.tableNumber,
  });

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Set table context if provided from deep link
    if (widget.tableId != null && widget.tableNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(orderContextProvider.notifier).setTableContext(
          widget.tableId!,
          widget.tableNumber!,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to get total quantity for a product ID
  int _getTotalQuantity(List<CartItem> cartItems, String productId) {
    return cartItems
        .where((item) => item.product.id == productId)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productNotifierProvider);
    final cartItems = ref.watch(cartProvider);
    final totalItems = ref.watch(cartProvider.notifier).totalItems;
    final totalAmount = ref.watch(cartProvider.notifier).totalAmount;
    final orderContext = ref.watch(orderContextProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                   Image.asset(
                    'assets/images/logo_collab.png',
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UTTER MENU',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (orderContext.isDineIn)
                        Text(
                          'Meja #${orderContext.tableNumber}',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.normal,
                            color: AppColors.successGreen,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.black),
                onPressed: () {},
              ),
            ],
          ),

          // Search & Filter Section
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Cari menu favorit...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category Tabs
                  SliverCategorySelector(
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (category) {
                      setState(() {
                        if (_selectedCategory == category) {
                          _selectedCategory = null;
                        } else {
                          _selectedCategory = category;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Products Grid
          productsAsync.when(
            data: (products) {
              // Apply Filtering
              final filteredProducts = products.where((p) {
                final matchesCategory = _selectedCategory == null || 
                    p.category.toString().split('.').last == _selectedCategory;
                final matchesSearch = _searchQuery.isEmpty || 
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchesCategory && matchesSearch;
              }).toList();

              // Sort
              filteredProducts.sort((a, b) {
                int score(Product p) {
                  int s = 0;
                  if (p.isPromo) s += 3;
                  if (p.isPackage) s += 2;
                  if (p.isFeatured) s += 1;
                  return s;
                }
                return score(b).compareTo(score(a));
              });

              if (filteredProducts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Menu tidak ditemukan', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              final specialOffers = filteredProducts.where((p) => p.isPromo || p.isFeatured || p.isPackage).toList();
              final allMenus = filteredProducts.where((p) => !(p.isPromo || p.isFeatured || p.isPackage)).toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (specialOffers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'REKOMENDASI & PROMO',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: specialOffers.length,
                        itemBuilder: (context, index) {
                          final product = specialOffers[index];
                          final qty = _getTotalQuantity(cartItems, product.id);
                          return GestureDetector(
                            onTap: () => _showProductDetail(product),
                            child: ProductCard(
                              productName: product.name,
                              price: product.price,
                              imageUrl: product.imageUrl,
                              isFeaturedIxon: product.isFeaturedIxon,
                              isFeatured: product.isFeatured,
                              isPromo: product.isPromo,
                              promoDiscountPercent: product.promoDiscountPercent,
                              isPackage: product.isPackage,
                              quantity: qty,
                            ),
                          );
                        },
                      ),
                    ],
                    
                    const Padding(
                      padding: EdgeInsets.only(top: 32, bottom: 12),
                      child: Text(
                        'SEMUA MENU',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.1,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: allMenus.length,
                      itemBuilder: (context, index) {
                        final product = allMenus[index];
                        final qty = _getTotalQuantity(cartItems, product.id);
                        return GestureDetector(
                          onTap: () => _showProductDetail(product),
                          child: ProductCard(
                            productName: product.name,
                            price: product.price,
                            imageUrl: product.imageUrl,
                            isFeaturedIxon: product.isFeaturedIxon,
                            isFeatured: product.isFeatured,
                            isPromo: product.isPromo,
                            promoDiscountPercent: product.promoDiscountPercent,
                            isPackage: product.isPackage,
                            quantity: qty,
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      // Bottom Premium Checkout Bar
      bottomSheet: cartItems.isNotEmpty
          ? PremiumBottomBar(
              itemCount: totalItems,
              totalAmount: totalAmount,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
            )
          : null,
    );
  }

  void _showProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }
}

class SliverCategorySelector extends StatelessWidget {
  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  const SliverCategorySelector({
    super.key, 
    required this.selectedCategory, 
    required this.onCategorySelected
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'label': 'COFFEE', 'value': 'BEVERAGE_COFFEE'},
      {'label': 'NON-COFFEE', 'value': 'BEVERAGE_NON_COFFEE'},
      {'label': 'FOOD', 'value': 'FOOD'},
      {'label': 'SNACK', 'value': 'SNACK'},
      {'label': 'OTHER', 'value': 'OTHER'},
    ];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onCategorySelected(cat['value']),
              selectedColor: Colors.black,
              backgroundColor: Colors.grey[200],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}

class PremiumBottomBar extends StatelessWidget {
  final int itemCount;
  final double totalAmount;
  final VoidCallback onPressed;

  const PremiumBottomBar({
    super.key,
    required this.itemCount,
    required this.totalAmount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount Items',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'Rp ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'LIHAT KERANJANG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
