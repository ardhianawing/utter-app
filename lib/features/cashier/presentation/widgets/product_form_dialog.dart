import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../customer/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  final Function(Map<String, dynamic>) onSave;

  const ProductFormDialog({
    super.key,
    this.product,
    required this.onSave,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockQtyController;
  late TextEditingController _ixonMultiplierController;
  late TextEditingController _imageUrlController;

  ProductCategory? _selectedCategory;
  bool _isFeaturedIxon = false;
  bool _isFeatured = false;
  bool _isPromo = false;
  bool _isPackage = false;
  late TextEditingController _promoDiscountController;
  
  // Multiple Images State
  // Map structure: { 'id': String?, 'url': String, 'bytes': List<int>?, 'name': String?, 'isPrimary': bool, 'isDeleted': bool }
  List<Map<String, dynamic>> _productImages = [];
  bool _isLoadingImages = false;
  bool _isUploading = false;

  ProductType _selectedType = ProductType.STANDARD;
  List<ProductModifier> _modifiers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toStringAsFixed(0) ?? '',
    );
    _stockQtyController = TextEditingController(
      text: widget.product?.stockQty.toString() ?? '0',
    );
    _ixonMultiplierController = TextEditingController(
      text: widget.product?.ixonMultiplier.toString() ?? '1.0',
    );
    _imageUrlController = TextEditingController(
      text: widget.product?.imageUrl ?? '',
    );
    _promoDiscountController = TextEditingController(
      text: widget.product?.promoDiscountPercent.toStringAsFixed(0) ?? '0',
    );
    _selectedCategory = widget.product?.category;
    _isFeaturedIxon = widget.product?.isFeaturedIxon ?? false;
    _isFeatured = widget.product?.isFeatured ?? false;
    _isPromo = widget.product?.isPromo ?? false;
    _isPackage = widget.product?.isPackage ?? false;
    _selectedType = widget.product?.type ?? ProductType.STANDARD;
    _modifiers = widget.product?.modifiers != null 
        ? List<ProductModifier>.from(widget.product!.modifiers!)
        : [];

    if (widget.product != null) {
      _loadExistingImages();
    }
  }

  Future<void> _loadExistingImages() async {
    setState(() => _isLoadingImages = true);
    try {
      final repository = ProductRepository(Supabase.instance.client);
      final images = await repository.getProductImages(widget.product!.id);
      
      setState(() {
        _productImages = images.map((img) => {
          'id': img['id'],
          'url': img['image_url'],
          'isPrimary': img['is_primary'] ?? false,
          'isDeleted': false,
        }).toList();
        
        // Ensure at least the primary image from the products table is represented
        // if for some reason the product_images table is empty but image_url exists
        if (_productImages.isEmpty && widget.product!.imageUrl != null && widget.product!.imageUrl!.isNotEmpty) {
          _productImages.add({
            'url': widget.product!.imageUrl!,
            'isPrimary': true,
            'isDeleted': false,
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading images: $e');
    } finally {
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQtyController.dispose();
    _ixonMultiplierController.dispose();
    _imageUrlController.dispose();
    _promoDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Product' : 'Add New Product',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Product Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Category
                  DropdownButtonFormField<ProductCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: ProductCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Product Type
                  DropdownButtonFormField<ProductType>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Product Type *',
                      border: const OutlineInputBorder(),
                      helperText: 'RAMEN/DRINK will enable customization for customers',
                      helperStyle: TextStyle(color: Colors.blue[700], fontSize: 11),
                      prefixIcon: Icon(
                        _selectedType == ProductType.STANDARD 
                          ? Icons.inventory_2 
                          : (_selectedType == ProductType.RAMEN ? Icons.soup_kitchen : Icons.local_drink),
                        color: Colors.blue[700],
                      ),
                    ),
                    items: ProductType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price and Stock in Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (Rp) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockQtyController,
                          decoration: const InputDecoration(
                            labelText: 'Stock Qty *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final qty = int.tryParse(value);
                            if (qty == null || qty < 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Multiple Images Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.collections, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Product Gallery',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (_isLoadingImages)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Image Grid
                        if (_productImages.where((img) => !img['isDeleted']).isNotEmpty)
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _productImages.length,
                              itemBuilder: (context, index) {
                                final img = _productImages[index];
                                if (img['isDeleted']) return const SizedBox.shrink();

                                return Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: img['isPrimary'] == true 
                                          ? AppColors.successGreen 
                                          : Colors.grey[300]!,
                                      width: img['isPrimary'] == true ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Image Preview
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: img['bytes'] != null
                                            ? Image.memory(
                                                Uint8List.fromList(img['bytes']),
                                                width: 120,
                                                height: 140,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                img['url'],
                                                width: 120,
                                                height: 140,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.broken_image, size: 40),
                                              ),
                                      ),
                                      
                                      // Primary Badge
                                      if (img['isPrimary'] == true)
                                        Positioned(
                                          top: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.successGreen,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Actions Overlay
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(6),
                                              bottomRight: Radius.circular(6),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              // Set Primary
                                              IconButton(
                                                icon: Icon(
                                                  img['isPrimary'] == true ? Icons.star : Icons.star_border,
                                                  size: 18,
                                                  color: Colors.amber,
                                                ),
                                                onPressed: () => _setPrimary(index),
                                                tooltip: 'Set as primary',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              // Move Left
                                              IconButton(
                                                icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white),
                                                onPressed: index > 0 ? () => _reorderImage(index, index - 1) : null,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              // Move Right
                                              IconButton(
                                                icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white),
                                                onPressed: index < _productImages.length - 1 ? () => _reorderImage(index, index + 1) : null,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              // Delete
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                                onPressed: () => _removeImage(index),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No images added yet',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Add Image Button
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickImages,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_a_photo),
                          label: const Text('Add Images'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modifiers Management Section (Visible for Ramen/Drink)
                  if (_selectedType != ProductType.STANDARD) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue[200]!),
                        color: Colors.blue[50]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.tune, size: 20, color: Colors.blue[800]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Customization Options',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Create choices for your customers',
                                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _addModifierDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(),
                          ),
                          if (_modifiers.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(Icons.add_task, size: 40, color: Colors.blue[200]!),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No options yet.\nExample: Extra Chashu, Less Sugar, etc.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.blue[300]!, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _modifiers.length,
                              separatorBuilder: (context, index) => Divider(color: Colors.blue[100], height: 1),
                              itemBuilder: (context, index) {
                                final mod = _modifiers[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(
                                    mod.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100]!,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          mod.category,
                                          style: TextStyle(fontSize: 10, color: Colors.blue[800]!, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        mod.extraPrice > 0 ? '+Rp ${mod.extraPrice.toStringAsFixed(0)}' : 'Free / Included',
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: mod.extraPrice > 0 ? Colors.orange[800] : Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _modifiers.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // IXON Featured Toggle
                  SwitchListTile(
                    title: const Text('IXON Featured Product'),
                    subtitle: const Text('Special collaboration product with point multiplier'),
                    value: _isFeaturedIxon,
                    activeColor: AppColors.successGreen,
                    onChanged: (value) {
                      setState(() {
                        _isFeaturedIxon = value;
                      });
                    },
                  ),

                  // IXON Multiplier (shown only if featured)
                  if (_isFeaturedIxon) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ixonMultiplierController,
                      decoration: const InputDecoration(
                        labelText: 'IXON Point Multiplier *',
                        border: OutlineInputBorder(),
                        helperText: 'Range: 1.0 - 5.0',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final multiplier = double.tryParse(value);
                        if (multiplier == null || multiplier < 1.0 || multiplier > 5.0) {
                          return 'Must be between 1.0 and 5.0';
                        }
                        return null;
                      },
                    ),
                  ],

                  const Divider(height: 32),

                  // Marketing Features Section
                  const Text(
                    'Marketing Features',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Featured Menu Toggle
                  SwitchListTile(
                    title: const Text('Featured Menu'),
                    subtitle: const Text('Display in featured section on home'),
                    value: _isFeatured,
                    activeColor: AppColors.successGreen,
                    onChanged: (value) {
                      setState(() {
                        _isFeatured = value;
                      });
                    },
                  ),

                  // Promo Toggle
                  SwitchListTile(
                    title: const Text('Promo Product'),
                    subtitle: const Text('Apply discount and show promo badge'),
                    value: _isPromo,
                    activeColor: AppColors.successGreen,
                    onChanged: (value) {
                      setState(() {
                        _isPromo = value;
                      });
                    },
                  ),

                  // Promo Discount Field (shown only if promo)
                  if (_isPromo) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _promoDiscountController,
                      decoration: const InputDecoration(
                        labelText: 'Discount Percent *',
                        border: OutlineInputBorder(),
                        helperText: 'Range: 1 - 100',
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final discount = double.tryParse(value);
                        if (discount == null || discount < 1 || discount > 100) {
                          return 'Must be between 1 and 100';
                        }
                        return null;
                      },
                    ),
                  ],

                  // Package Toggle
                  SwitchListTile(
                    title: const Text('Package Deal'),
                    subtitle: const Text('Bundle package with multiple items'),
                    value: _isPackage,
                    activeColor: AppColors.successGreen,
                    onChanged: (value) {
                      setState(() {
                        _isPackage = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(isEdit ? 'Update' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          setState(() {
            _productImages.add({
              'bytes': bytes,
              'name': image.name,
              'url': '', // temp
              'isPrimary': _productImages.isEmpty,
              'isDeleted': false,
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }

  void _setPrimary(int index) {
    setState(() {
      for (int i = 0; i < _productImages.length; i++) {
        _productImages[i]['isPrimary'] = (i == index);
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      if (_productImages[index]['id'] != null) {
        _productImages[index]['isDeleted'] = true;
      } else {
        _productImages.removeAt(index);
      }
      
      // If we removed the primary, set the first non-deleted one as primary
      if (_productImages.isNotEmpty && !_productImages.any((img) => img['isPrimary'] == true && !img['isDeleted'])) {
        final firstActive = _productImages.indexWhere((img) => !img['isDeleted']);
        if (firstActive != -1) {
          _productImages[firstActive]['isPrimary'] = true;
        }
      }
    });
  }

  void _reorderImage(int oldIndex, int newIndex) {
    setState(() {
      final item = _productImages.removeAt(oldIndex);
      _productImages.insert(newIndex, item);
    });
  }

  void _addModifierDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    
    // Default categories based on product type
    final List<String> categories = _selectedType == ProductType.RAMEN 
        ? ['Topping', 'Broth', 'Choice'] 
        : ['Sugar Level', 'Ice Level', 'Topping', 'Temperature', 'Size', 'Choice'];
        
    String selectedCategory = categories.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text('Add Option'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Option Name',
                  hintText: 'e.g. Extra Chashu, Less Sugar',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Extra Price (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedCategory = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                
                final price = double.tryParse(priceCtrl.text) ?? 0;
                
                setState(() {
                  _modifiers.add(ProductModifier(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    category: selectedCategory,
                    name: nameCtrl.text,
                    extraPrice: price,
                  ));
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        final repository = ProductRepository(Supabase.instance.client);
        
        // 1. Process images and get primary URL
        String? primaryUrl;
        
        // Find if we have a primary image
        final primaryImg = _productImages.firstWhere(
          (img) => img['isPrimary'] == true && !img['isDeleted'],
          orElse: () => _productImages.isNotEmpty ? _productImages.first : {'url': ''},
        );
        
        // If primary is a new image, upload it first
        if (primaryImg['bytes'] != null) {
          primaryUrl = await repository.uploadProductImage(
            primaryImg['bytes']!,
            primaryImg['name']!,
          );
          primaryImg['url'] = primaryUrl;
          primaryImg['bytes'] = null; // Mark as uploaded
        } else {
          primaryUrl = primaryImg['url'];
        }

        // 2. Prep product data
        final data = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text),
          'category': _selectedCategory!,
          'stockQty': int.parse(_stockQtyController.text),
          'isFeaturedIxon': _isFeaturedIxon,
          'ixonMultiplier': _isFeaturedIxon
              ? double.parse(_ixonMultiplierController.text)
              : 1.0,
          'imageUrl': primaryUrl,
          'isFeatured': _isFeatured,
          'isPromo': _isPromo,
          'promoDiscountPercent': _isPromo
              ? double.parse(_promoDiscountController.text)
              : 0,
          'isPackage': _isPackage,
          'type': _selectedType,
          'modifiers': _modifiers,
        };

        // Note: The parent widget (AdminMenuPage) will call repository.create/update
        // and return the product ID. We need to handle image records after that.
        // But the current flow is widget.onSave(data) -> Navigator.pop.
        
        // We will pass the processed images back to the parent to handle them
        // correctly after product creation/update.
        data['productImages'] = _productImages;

        widget.onSave(data);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

