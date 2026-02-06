import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatRibuan(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String _getUnitLabel(IngredientUnit unit) {
    switch (unit) {
      case IngredientUnit.gram:
        return 'Gram (g)';
      case IngredientUnit.kg:
        return 'Kilogram (kg)';
      case IngredientUnit.ml:
        return 'Mililiter (ml)';
      case IngredientUnit.liter:
        return 'Liter (L)';
      case IngredientUnit.pcs:
        return 'Pieces (pcs)';
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _currentStockController = TextEditingController(
      text: _formatNumber(widget.ingredient?.currentStock),
    );
    _costPerUnitController = TextEditingController(
      text: widget.ingredient?.costPerUnit != null && widget.ingredient!.costPerUnit > 0
        ? _formatRibuan(widget.ingredient!.costPerUnit)
        : '',
    );
    _minStockController = TextEditingController(
      text: _formatNumber(widget.ingredient?.minStock),
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
                      isEditing ? 'Edit Bahan' : 'Tambah Bahan',
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
                    labelText: 'Nama Bahan *',
                    hintText: 'cth: Biji Kopi Arabika',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan nama bahan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Unit
                DropdownButtonFormField<IngredientUnit>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Satuan *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: IngredientUnit.values.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(_getUnitLabel(unit)),
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
                      labelText: 'Stok Awal',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.inventory),
                      suffixText: _selectedUnit.displayName,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final num = double.tryParse(value);
                        if (num == null || num < 0) {
                          return 'Masukkan angka yang valid';
                        }
                      }
                      return null;
                    },
                  ),
                if (!isEditing) const SizedBox(height: 16),

                // Cost per Unit
                TextFormField(
                  controller: _costPerUnitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Harga per ${_selectedUnit.displayName} (Rp)',
                    hintText: '25.000',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payments_outlined),
                    prefixText: 'Rp  ',
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) return;
                    final cleanValue = value.replaceAll('.', '');
                    final number = double.tryParse(cleanValue);
                    if (number != null) {
                      final formatted = _formatRibuan(number);
                      if (formatted != value) {
                        _costPerUnitController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    }
                  },
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final cleanValue = value.replaceAll('.', '');
                      final num = double.tryParse(cleanValue);
                      if (num == null || num < 0) {
                        return 'Masukkan harga yang valid';
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
                    labelText: 'Stok Minimum (Alert)',
                    hintText: '10',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.warning_amber),
                    suffixText: _selectedUnit.displayName,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final num = double.tryParse(value);
                      if (num == null || num < 0) {
                        return 'Masukkan angka yang valid';
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
                    labelText: 'Nama Supplier (Opsional)',
                    hintText: 'cth: PT Kopi Nusantara',
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
                      child: const Text('Batal'),
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
                          : Text(isEditing ? 'Simpan' : 'Tambah'),
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
          ? double.parse(_costPerUnitController.text.replaceAll('.', ''))
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
