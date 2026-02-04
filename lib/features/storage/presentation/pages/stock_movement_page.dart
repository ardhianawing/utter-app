import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';
import '../widgets/movement_list_tile.dart';

class StockMovementPage extends ConsumerStatefulWidget {
  final String? ingredientId;

  const StockMovementPage({super.key, this.ingredientId});

  @override
  ConsumerState<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends ConsumerState<StockMovementPage> {
  MovementType? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final movementsAsync = widget.ingredientId != null
        ? ref.watch(ingredientMovementsProvider(widget.ingredientId!))
        : ref.watch(stockMovementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Movements'),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (widget.ingredientId != null) {
                ref.invalidate(ingredientMovementsProvider(widget.ingredientId!));
              } else {
                ref.invalidate(stockMovementsStreamProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Filters
          if (_selectedType != null || _startDate != null || _endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedType != null)
                          Chip(
                            label: Text(_selectedType!.displayName),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _selectedType = null),
                          ),
                        if (_startDate != null)
                          Chip(
                            label: Text('From: ${_formatDate(_startDate!)}'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _startDate = null),
                          ),
                        if (_endDate != null)
                          Chip(
                            label: Text('To: ${_formatDate(_endDate!)}'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _endDate = null),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedType = null;
                      _startDate = null;
                      _endDate = null;
                    }),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Movement List
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                // Apply local filters
                var filtered = movements;
                if (_selectedType != null) {
                  filtered = filtered.where((m) => m.movementType == _selectedType).toList();
                }
                if (_startDate != null) {
                  filtered = filtered.where((m) => m.createdAt.isAfter(_startDate!)).toList();
                }
                if (_endDate != null) {
                  filtered = filtered.where((m) => m.createdAt.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No movements found',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final groupedMovements = _groupByDate(filtered);

                return ListView.builder(
                  itemCount: groupedMovements.length,
                  itemBuilder: (context, index) {
                    final entry = groupedMovements.entries.elementAt(index);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        ...entry.value.map((movement) => MovementListTile(
                          movement: movement,
                          onTap: () => _showMovementDetails(context, movement),
                        )),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(stockMovementsStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<StockMovement>> _groupByDate(List<StockMovement> movements) {
    final grouped = <String, List<StockMovement>>{};
    for (final movement in movements) {
      final dateKey = _formatDateKey(movement.createdAt);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(movement);
    }
    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final movementDate = DateTime(date.year, date.month, date.day);

    if (movementDate == today) {
      return 'Today';
    } else if (movementDate == yesterday) {
      return 'Yesterday';
    } else {
      return _formatDate(date);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Movements',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Movement Type Filter
              const Text(
                'Movement Type',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedType == null,
                    onSelected: (_) {
                      setModalState(() => _selectedType = null);
                      setState(() {});
                    },
                  ),
                  ...MovementType.values.map((type) => FilterChip(
                    label: Text(type.displayName),
                    selected: _selectedType == type,
                    onSelected: (_) {
                      setModalState(() => _selectedType = type);
                      setState(() {});
                    },
                    selectedColor: _getMovementColor(type).withOpacity(0.2),
                  )),
                ],
              ),

              const SizedBox(height: 24),

              // Date Range Filter
              const Text(
                'Date Range',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => _startDate = picked);
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_startDate != null ? _formatDate(_startDate!) : 'Start Date'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => _endDate = picked);
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_endDate != null ? _formatDate(_endDate!) : 'End Date'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlack,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovementDetails(BuildContext context, StockMovement movement) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getMovementColor(movement.movementType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMovementIcon(movement.movementType),
                    color: _getMovementColor(movement.movementType),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.movementType.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        movement.ingredient?.name ?? 'Unknown Ingredient',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Quantity', movement.quantityDisplay),
            if (movement.unitCost != null)
              _buildDetailRow('Unit Cost', 'Rp ${movement.unitCost!.toStringAsFixed(2)}'),
            if (movement.totalCost != null)
              _buildDetailRow('Total Cost', 'Rp ${movement.totalCost!.toStringAsFixed(0)}'),
            if (movement.referenceType != null)
              _buildDetailRow('Reference', movement.referenceType!.displayName),
            _buildDetailRow('Date', _formatDateTime(movement.createdAt)),
            if (movement.notes != null && movement.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(movement.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getMovementColor(MovementType type) {
    switch (type) {
      case MovementType.STOCK_IN:
        return AppColors.successGreen;
      case MovementType.AUTO_DEDUCT:
        return AppColors.infoBlue;
      case MovementType.ADJUSTMENT:
        return AppColors.warningYellow;
    }
  }

  IconData _getMovementIcon(MovementType type) {
    switch (type) {
      case MovementType.STOCK_IN:
        return Icons.add_box;
      case MovementType.AUTO_DEDUCT:
        return Icons.shopping_cart;
      case MovementType.ADJUSTMENT:
        return Icons.tune;
    }
  }
}
