import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/storage_models.dart';

class IngredientFormDialog extends StatefulWidget {
  final Ingredient? ingredient;
  final Function(Map<String, dynamic>) onSave;

  const IngredientFormDialog({
    super.key,
    this.ingredient,
    required this.onSave,
  });

  @override
  State<IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends State<IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _currentStockController;
  late TextEditingController _costPerUnitController;
  late TextEditingController _minStockController;
  late TextEditingController _supplierNameController;
  IngredientUnit _selectedUnit = IngredientUnit.gram;
  bool _isLoading = false;

  bool get isEditing => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _currentStockController = TextEditingController(
      text: widget.ingredient?.currentStock.toStringAsFixed(2) ?? '',
    );
    _costPerUnitController = TextEditingController(
      text: widget.ingredient?.costPerUnit.toStringAsFixed(2) ?? '',
    );
    _minStockController = TextEditingController(
      text: widget.ingredient?.minStock.toStringAsFixed(2) ?? '',
    );
    _supplierNameController = TextEditingController(
      text: widget.ingredient?.supplierName ?? '',
    );
    _selectedUnit = widget.ingredient?.unit ?? IngredientUnit.gram;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentStockController.dispose();
    _costPerUnitController.dispose();
    _minStockController.dispose();
    _supplierNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.add_box,
                      color: AppColors.primaryBlack,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Ingredient' : 'Add Ingredient',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g., Arabica Coffee Beans',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter ingredient name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Unit
                DropdownButtonFormField<IngredientUnit>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: IngredientUnit.values.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedUnit = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Current Stock (only for new ingredients)
                if (!isEditing)
                  TextFormField(
                    controller: _currentStockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Initial Stock',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.inventory),
                      suffixText: _selectedUnit.displayName,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final num = double.tryParse(value);
                        if (num == null || num < 0) {
                          return 'Please enter a valid number';
                        }
                      }
                      return null;
                    },
                  ),
                if (!isEditing) const SizedBox(height: 16),

                // Cost per Unit
                TextFormField(
                  controller: _costPerUnitController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cost per Unit (Rp)',
                    hintText: '0',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'per ${_selectedUnit.displayName}',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final num = double.tryParse(value);
                      if (num == null || num < 0) {
                        return 'Please enter a valid cost';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Minimum Stock
                TextFormField(
                  controller: _minStockController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Minimum Stock (Alert Threshold)',
                    hintText: '0',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.warning_amber),
                    suffixText: _selectedUnit.displayName,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final num = double.tryParse(value);
                      if (num == null || num < 0) {
                        return 'Please enter a valid number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Supplier Name
                TextFormField(
                  controller: _supplierNameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name (Optional)',
                    hintText: 'e.g., PT Kopi Nusantara',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Save' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'unit': _selectedUnit,
      'currentStock': _currentStockController.text.isNotEmpty
          ? double.parse(_currentStockController.text)
          : 0.0,
      'costPerUnit': _costPerUnitController.text.isNotEmpty
          ? double.parse(_costPerUnitController.text)
          : 0.0,
      'minStock': _minStockController.text.isNotEmpty
          ? double.parse(_minStockController.text)
          : 0.0,
      'supplierName': _supplierNameController.text.isNotEmpty
          ? _supplierNameController.text.trim()
          : null,
    };

    widget.onSave(data);
  }
}
