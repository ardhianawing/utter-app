import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';
import '../../data/providers/cart_provider.dart';
import '../../data/repositories/product_repository.dart';
import '../../../../core/constants/app_colors.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1;
  int _currentImageIndex = 0;
  List<Map<String, dynamic>> _images = [];
  bool _isLoadingImages = true;
  
  // State for modifiers
  // Map<CategoryName, SelectedModifier>
  final Map<String, ProductModifier> _selectedModifiers = {};

  // Grouped modifiers from product
  Map<String, List<ProductModifier>> _groupedModifiers = {};

  @override
  void initState() {
    super.initState();
    _groupModifiers();
    _loadImages();
  }

  void _groupModifiers() {
    if (widget.product.availableModifiers == null) return;
    
    for (var mod in widget.product.availableModifiers!) {
      if (!_groupedModifiers.containsKey(mod.category)) {
        _groupedModifiers[mod.category] = [];
      }
      _groupedModifiers[mod.category]!.add(mod);
    }

    // Auto-select first option for each category
    _groupedModifiers.forEach((category, mods) {
      if (mods.length == 1) {
        _selectedModifiers[category] = mods.first;
      }
    });
  }

  double get _calculateTotalPrice {
    double total = widget.product.finalPrice;
    for (var modifier in _selectedModifiers.values) {
      total += modifier.extraPrice;
    }
    return total;
  }

  void _selectModifier(String category, ProductModifier modifier) {
    setState(() {
      _selectedModifiers[category] = modifier;
    });
  }

  Future<void> _loadImages() async {
    try {
      final repository = ProductRepository(Supabase.instance.client);
      final images = await repository.getProductImages(widget.product.id);
      setState(() {
        _images = images;
        _isLoadingImages = false;
      });
    } catch (e) {
      setState(() => _isLoadingImages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collect all displayable images
    final displayImages = <String>[];
    if (widget.product.imageUrl != null) displayImages.add(widget.product.imageUrl!);
    for (var img in _images) {
      if (img['image_url'] != widget.product.imageUrl) {
        displayImages.add(img['image_url']);
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image Carousel Header
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (displayImages.isNotEmpty)
                    PageView.builder(
                      itemCount: displayImages.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          displayImages[index],
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  else
                    Container(
                      color: AppColors.accentGray,
                      child: const Center(
                        child: Icon(Icons.fastfood, size: 80, color: Colors.grey),
                      ),
                    ),
                  
                  // Image Indicator
                  if (displayImages.length > 1)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          displayImages.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? AppColors.successGreen
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Product Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Badges
                            Row(
                              children: [
                                if (widget.product.isFeaturedIxon)
                                  _buildBadge('IXON', AppColors.xtonSilver, Colors.black),
                                if (widget.product.isFeatured)
                                  _buildBadge('FEATURED', Colors.amber, Colors.black),
                                if (widget.product.isPromo)
                                  _buildBadge('${widget.product.promoDiscountPercent.toStringAsFixed(0)}% OFF', Colors.red, Colors.white),
                                if (widget.product.isPackage)
                                  _buildBadge('PACKAGE', Colors.purple, Colors.white),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.product.category.displayName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.product.isPromo)
                            Text(
                              'Rp ${widget.product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            'Rp ${_calculateTotalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description.isNotEmpty 
                      ? widget.product.description 
                      : 'No description available.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  
                  // Modifiers Section
                  if (_groupedModifiers.isNotEmpty) ...[
                    const Divider(height: 32),
                    ..._groupedModifiers.entries.map((entry) {
                      final category = entry.key;
                      final modifiers = entry.value;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: modifiers.map((mod) {
                              final isSelected = _selectedModifiers[category]?.id == mod.id;
                              return ChoiceChip(
                                label: Text(
                                  '${mod.name} ${mod.extraPrice > 0 ? '(+Rp ${mod.extraPrice.toStringAsFixed(0)})' : (mod.category.toLowerCase() == 'broth' ? '(Gratis)' : '')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) _selectModifier(category, mod);
                                },
                                selectedColor: AppColors.successGreen,
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: isSelected 
                                      ? BorderSide.none 
                                      : BorderSide(color: Colors.grey[300]!),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 100), // Space for bottom action bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Quantity Selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Add to Cart Button
            Expanded(
              child: ElevatedButton(
                onPressed: _isSelectionComplete() ? () {
                  for (int i = 0; i < _quantity; i++) {
                    ref.read(cartProvider.notifier).addProduct(
                      widget.product,
                      modifiers: _selectedModifiers.values.toList(),
                    );
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added $_quantity ${widget.product.name} to cart'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSelectionComplete() ? AppColors.successGreen : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  bool _isSelectionComplete() {
    if (_groupedModifiers.isEmpty) return true;
    return _groupedModifiers.keys.every((category) => _selectedModifiers.containsKey(category));
  }
}
