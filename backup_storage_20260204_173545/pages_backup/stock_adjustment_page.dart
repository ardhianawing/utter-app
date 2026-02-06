import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

class StockAdjustmentPage extends ConsumerStatefulWidget {
  final Ingredient? preSelectedIngredient;

  const StockAdjustmentPage({super.key, this.preSelectedIngredient});

  @override
  ConsumerState<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends ConsumerState<StockAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  Ingredient? _selectedIngredient;
  final _newStockController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showDifference = false;

  @override
  void initState() {
    super.initState();
    _selectedIngredient = widget.preSelectedIngredient;
    if (_selectedIngredient != null) {
      _newStockController.text = _selectedIngredient!.currentStock.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _newStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _stockDifference {
    if (_selectedIngredient == null) return 0;
    final newStock = double.tryParse(_newStockController.text) ?? 0;
    return newStock - _selectedIngredient!.currentStock;
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsStreamProvider);
    final operationState = ref.watch(stockOperationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
        backgroundColor: AppColors.warningYellow,
        foregroundColor: AppColors.primaryBlack,
      ),
      body: ingredientsAsync.when(
        data: (ingredients) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Warning Card
              Card(
                color: AppColors.warningYellow.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warningYellow),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Stock adjustments should only be used for inventory corrections (e.g., after physical stock count).',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
                            child: Text('${ingredient.name} (${ingredient.stockDisplay})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedIngredient = value;
                            if (value != null) {
                              _newStockController.text = value.currentStock.toStringAsFixed(2);
                              _showDifference = false;
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
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Current Stock', _selectedIngredient!.stockDisplay),
                        _buildInfoRow('Minimum Stock', '${_selectedIngredient!.minStock} ${_selectedIngredient!.unit.displayName}'),
                        _buildInfoRow('Cost per Unit', _selectedIngredient!.costDisplay),
                        _buildInfoRow(
                          'Status',
                          _selectedIngredient!.isLowStock ? 'Low Stock' : 'Normal',
                          color: _selectedIngredient!.isLowStock
                              ? AppColors.errorRed
                              : AppColors.successGreen,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // New Stock Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjustment Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newStockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'New Stock Level',
                          hintText: 'Enter actual stock quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.inventory),
                          suffixText: _selectedIngredient?.unit.displayName ?? '',
                        ),
                        onChanged: (_) => setState(() => _showDifference = true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter new stock level';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty < 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
                      ),

                      // Show difference
                      if (_showDifference && _selectedIngredient != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _stockDifference >= 0
                                ? AppColors.successGreen.withOpacity(0.1)
                                : AppColors.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _stockDifference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                color: _stockDifference >= 0
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Difference: ${_stockDifference >= 0 ? '+' : ''}${_stockDifference.toStringAsFixed(2)} ${_selectedIngredient!.unit.displayName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _stockDifference >= 0
                                      ? AppColors.successGreen
                                      : AppColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Reason for Adjustment *',
                          hintText: 'e.g., Physical stock count, Damaged goods, etc.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.notes),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please provide a reason for this adjustment';
                          }
                          return null;
                        },
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
                  onPressed: operationState.isLoading ? null : _submitAdjustment,
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
                  label: Text(operationState.isLoading ? 'Processing...' : 'Apply Adjustment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warningYellow,
                    foregroundColor: AppColors.primaryBlack,
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

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    // Confirm if stock is being reduced significantly
    if (_stockDifference < -10) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Adjustment'),
          content: Text(
            'You are about to reduce stock by ${_stockDifference.abs().toStringAsFixed(2)} ${_selectedIngredient!.unit.displayName}. '
            'Are you sure this is correct?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final newStock = double.parse(_newStockController.text);
    final notes = _notesController.text;

    final success = await ref.read(stockOperationProvider.notifier).adjustStock(
      ingredientId: _selectedIngredient!.id,
      newStockLevel: newStock,
      notes: notes,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock adjusted successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(stockOperationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to adjust stock'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
