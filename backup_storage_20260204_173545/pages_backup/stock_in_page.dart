import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

class StockInPage extends ConsumerStatefulWidget {
  final Ingredient? preSelectedIngredient;

  const StockInPage({super.key, this.preSelectedIngredient});

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final _formKey = GlobalKey<FormState>();
  Ingredient? _selectedIngredient;
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIngredient = widget.preSelectedIngredient;
    if (_selectedIngredient != null) {
      _costController.text = _selectedIngredient!.costPerUnit.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final operationState = ref.watch(stockOperationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock In'),
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
      ),
      body: ingredientsAsync.when(
        data: (ingredients) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Select Ingredient
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Ingredient',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Ingredient>(
                        value: _selectedIngredient,
                        decoration: InputDecoration(
                          hintText: 'Choose ingredient',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.inventory_2),
                        ),
                        items: ingredients.map((ingredient) {
                          return DropdownMenuItem(
                            value: ingredient,
                            child: Text('${ingredient.name} (${ingredient.unit.displayName})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedIngredient = value;
                            if (value != null) {
                              _costController.text = value.costPerUnit.toStringAsFixed(2);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select an ingredient';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Current Stock Info
              if (_selectedIngredient != null)
                Card(
                  color: AppColors.infoBlue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.infoBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Stock',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.infoBlue,
                                ),
                              ),
                              Text(
                                _selectedIngredient!.stockDisplay,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedIngredient!.isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Quantity Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          hintText: 'Enter quantity to add',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.add_box),
                          suffixText: _selectedIngredient?.unit.displayName ?? '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Unit Cost (Rp)',
                          hintText: 'Cost per unit',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText: 'per ${_selectedIngredient?.unit.displayName ?? 'unit'}',
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final cost = double.tryParse(value);
                            if (cost == null || cost < 0) {
                              return 'Please enter a valid cost';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Add any notes about this stock',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary
              if (_selectedIngredient != null && _quantityController.text.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          'Current Stock',
                          _selectedIngredient!.stockDisplay,
                        ),
                        _buildSummaryRow(
                          'Adding',
                          '+${_quantityController.text} ${_selectedIngredient!.unit.displayName}',
                          color: AppColors.successGreen,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'New Stock',
                          '${(_selectedIngredient!.currentStock + (double.tryParse(_quantityController.text) ?? 0)).toStringAsFixed(2)} ${_selectedIngredient!.unit.displayName}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: operationState.isLoading ? null : _submitStockIn,
                  icon: operationState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(operationState.isLoading ? 'Processing...' : 'Add Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitStockIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    final quantity = double.parse(_quantityController.text);
    final cost = _costController.text.isNotEmpty
        ? double.parse(_costController.text)
        : null;
    final notes = _notesController.text.isNotEmpty
        ? _notesController.text
        : null;

    final success = await ref.read(stockOperationProvider.notifier).addStock(
      ingredientId: _selectedIngredient!.id,
      quantity: quantity,
      unitCost: cost,
      notes: notes,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock added successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(stockOperationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to add stock'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
