import 'package:flutter/material.dart';
import '../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';

class ProductSelectionDialog extends StatefulWidget {
  final Product product;

  const ProductSelectionDialog({super.key, required this.product});

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final Map<String, ProductModifier> _selectedModifiers = {};
  
  // Logic to group modifiers by category
  Map<String, List<ProductModifier>> get _modifierGroups {
    final groups = <String, List<ProductModifier>>{};
    final modifiers = widget.product.availableModifiers ?? [];
    
    for (var m in modifiers) {
      if (!groups.containsKey(m.category)) {
        groups[m.category] = [];
      }
      groups[m.category]!.add(m);
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    // Pre-select defaults if applicable (e.g. Normal Sugar, Hot)
    final groups = _modifierGroups;
    groups.forEach((category, modifiers) {
      // Find 'Normal' or 'Hot' as default if they exist
      try {
        final defaultMod = modifiers.firstWhere(
          (m) => m.name.toLowerCase().contains('normal') || m.name.toLowerCase().contains('hot'),
          orElse: () => modifiers.first,
        );
        _selectedModifiers[category] = defaultMod;
      } catch (e) {
        if (modifiers.isNotEmpty) {
          _selectedModifiers[category] = modifiers.first;
        }
      }
    });
  }

  double get _calculateCurrentPrice {
    if (widget.product.type == ProductType.RAMEN) {
      // Ramen price is purely from the Topping modifier
      final topping = _selectedModifiers.values.firstWhere(
        (m) => m.category.toLowerCase() == 'topping',
        orElse: () => ProductModifier(id: '', category: '', name: '', extraPrice: 0),
      );
      return topping.extraPrice;
    }
    
    double total = widget.product.finalPrice;
    for (var m in _selectedModifiers.values) {
      total += m.extraPrice;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _modifierGroups;
    final isRamen = widget.product.type == ProductType.RAMEN;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product.name),
          Text(
            isRamen ? 'Setel Kuah & Topping' : 'Atur Varian',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: groups.entries.map((entry) {
              final category = entry.key;
              final options = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = _selectedModifiers[category]?.id == option.id;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(option.name),
                              if (option.extraPrice > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(+Rp ${option.extraPrice.toStringAsFixed(0)})',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: isSelected ? Colors.white70 : Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else if (isRamen && option.category.toLowerCase() == 'broth') ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(Gratis)',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: isSelected ? Colors.white70 : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedModifiers[category] = option;
                              });
                            }
                          },
                          selectedColor: AppColors.primaryBlack,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Harga', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    'Rp ${_calculateCurrentPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.successGreen),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Check if all categories are selected
                    if (_selectedModifiers.length < groups.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Silakan lengkapi pilihan semua kategori')),
                      );
                      return;
                    }
                    Navigator.pop(context, _selectedModifiers.values.toList());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlack,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('TAMBAH'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
