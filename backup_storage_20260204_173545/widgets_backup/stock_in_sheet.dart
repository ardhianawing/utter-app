import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/storage_provider.dart';
import '../../domain/models/storage_models.dart';

/// Bottom sheet for Stock In — supports existing ingredients + add new
class StockInSheet extends ConsumerStatefulWidget {
  final List<Ingredient> ingredients;
  final Ingredient? preSelected;

  const StockInSheet({super.key, required this.ingredients, this.preSelected});

  @override
  ConsumerState<StockInSheet> createState() => _StockInSheetState();
}

class _StockInSheetState extends ConsumerState<StockInSheet> {
  // Mode: pick, input, new
  String _mode = 'pick';
  Ingredient? _selected;
  String _search = '';

  // Stock in fields
  final _nettoController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _hargaController = TextEditingController();
  double? _selectedPresetNetto;

  // New ingredient fields
  final _newNameController = TextEditingController();
  final _newMinStockController = TextEditingController();
  final _newNettoController = TextEditingController();
  final _newQtyController = TextEditingController(text: '1');
  final _newHargaController = TextEditingController();
  IngredientUnit _newUnit = IngredientUnit.gram;

  @override
  void initState() {
    super.initState();
    if (widget.preSelected != null) {
      _selected = widget.preSelected;
      _mode = 'input';
    }
  }

  @override
  void dispose() {
    _nettoController.dispose();
    _qtyController.dispose();
    _hargaController.dispose();
    _newNameController.dispose();
    _newMinStockController.dispose();
    _newNettoController.dispose();
    _newQtyController.dispose();
    _newHargaController.dispose();
    super.dispose();
  }

  List<Ingredient> get _filteredIngredients {
    if (_search.isEmpty) return widget.ingredients;
    return widget.ingredients
        .where((i) => i.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  double get _totalNetto {
    final netto = double.tryParse(_nettoController.text) ?? 0;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    return netto * qty;
  }

  double get _costPerUnit {
    final harga = double.tryParse(_hargaController.text) ?? 0;
    return _totalNetto > 0 ? harga / _totalNetto : 0;
  }

  double get _newTotalNetto {
    final netto = double.tryParse(_newNettoController.text) ?? 0;
    final qty = int.tryParse(_newQtyController.text) ?? 0;
    return netto * qty;
  }

  double get _newCostPerUnit {
    final harga = double.tryParse(_newHargaController.text) ?? 0;
    return _newTotalNetto > 0 ? harga / _newTotalNetto : 0;
  }

  bool get _canSubmitExisting {
    return _nettoController.text.isNotEmpty &&
        _qtyController.text.isNotEmpty &&
        _hargaController.text.isNotEmpty &&
        _totalNetto > 0;
  }

  bool get _canSubmitNew {
    return _newNameController.text.isNotEmpty &&
        _newNettoController.text.isNotEmpty &&
        _newQtyController.text.isNotEmpty &&
        _newHargaController.text.isNotEmpty &&
        _newTotalNetto > 0;
  }

  @override
  Widget build(BuildContext context) {
    final operationState = ref.watch(stockOperationProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(),

          const Divider(height: 1),

          // Content
          Flexible(
            child: _mode == 'pick'
                ? _buildPickMode()
                : _mode == 'input'
                    ? _buildInputMode(operationState)
                    : _buildNewMode(operationState),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Stock In';
    String subtitle = 'Pilih bahan atau tambah baru';
    if (_mode == 'input') subtitle = _selected?.name ?? '';
    if (_mode == 'new') {
      title = 'Bahan Baru + Stock In';
      subtitle = 'Langsung input stok awal';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Row(
        children: [
          if (_mode != 'pick')
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() {
                _mode = 'pick';
                _selected = null;
                _resetFields();
              }),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── PICK MODE ──
  Widget _buildPickMode() {
    final hasNoResults = _search.length >= 2 && _filteredIngredients.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari bahan atau merk...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              border: InputBorder.none,
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 12),

        // Add New button
        _buildAddNewButton(hasNoResults),
        const SizedBox(height: 12),

        // Ingredient list
        ..._filteredIngredients.map(_buildIngredientOption),
      ],
    );
  }

  Widget _buildAddNewButton(bool highlighted) {
    return InkWell(
      onTap: () => setState(() {
        _mode = 'new';
        _newNameController.text = _search;
      }),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.successGreen.withOpacity(0.05) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: highlighted ? AppColors.successGreen.withOpacity(0.3) : const Color(0xFFD1D5DB),
            style: BorderStyle.solid,
            width: highlighted ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: highlighted ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlighted ? 'Tambah "$_search"' : 'Tambah Bahan Baru',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Merk baru atau bahan yang belum terdaftar',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientOption(Ingredient ing) {
    final status = _getStockStatus(ing);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() {
          _selected = ing;
          _mode = 'input';
          _resetFields();
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'Stok: ${_formatStock(ing.currentStock)} ${ing.unit.displayName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── INPUT MODE (existing ingredient) ──
  Widget _buildInputMode(StockOperationState operationState) {
    final ing = _selected!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Current stock info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stok saat ini', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatStock(ing.currentStock)} ${ing.unit.displayName}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Netto per kemasan
              _buildLabel('Netto per kemasan'),
              const SizedBox(height: 8),
              // TODO: Add preset buttons here when netto presets are implemented in the model
              // For now, always show custom input
              _buildInputWithUnit(
                controller: _nettoController,
                unit: ing.unit.displayName,
                placeholder: 'Contoh: 1000',
              ),
              const SizedBox(height: 20),

              // Jumlah kemasan
              _buildLabel('Jumlah kemasan'),
              const SizedBox(height: 8),
              _buildQtyRow(_qtyController),
              const SizedBox(height: 20),

              // Total harga beli
              _buildLabel('Total harga beli'),
              const SizedBox(height: 8),
              _buildInputWithPrefix(
                controller: _hargaController,
                prefix: 'Rp',
              ),
              const SizedBox(height: 24),

              // Summary
              if (_nettoController.text.isNotEmpty && _qtyController.text.isNotEmpty)
                _buildSummary(
                  totalNetto: _totalNetto,
                  unit: ing.unit.displayName,
                  stockAfter: ing.currentStock + _totalNetto,
                  costPerUnit: _costPerUnit,
                ),
            ],
          ),
        ),

        // Submit button
        _buildSubmitButton(
          enabled: _canSubmitExisting && !operationState.isLoading,
          loading: operationState.isLoading,
          label: 'Simpan Stock In',
          onPressed: _submitStockIn,
        ),
      ],
    );
  }

  // ── NEW MODE (add new ingredient + stock in) ──
  Widget _buildNewMode(StockOperationState operationState) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Section: Info Bahan
              _buildSectionLabel('Info Bahan'),
              const SizedBox(height: 12),

              _buildLabel('Nama bahan / merk'),
              const SizedBox(height: 6),
              TextField(
                controller: _newNameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contoh: Susu UHT Indomilk',
                  hintStyle: TextStyle(color: Colors.grey[300]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Unit selection
              _buildLabel('Satuan'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: IngredientUnit.values.map((u) {
                  final selected = _newUnit == u;
                  return ChoiceChip(
                    label: Text(u.displayName),
                    selected: selected,
                    onSelected: (_) => setState(() => _newUnit = u),
                    selectedColor: AppColors.primaryBlack,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: selected ? AppColors.primaryBlack : const Color(0xFFE5E7EB)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Min stock
              _buildLabel('Stok minimum'),
              Text('Alert ketika di bawah ini', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(height: 6),
              _buildInputWithUnit(
                controller: _newMinStockController,
                unit: _newUnit.displayName,
                placeholder: 'Contoh: 2000',
              ),
              const SizedBox(height: 24),

              // Section: Stok Masuk Pertama
              _buildSectionLabel('Stok Masuk Pertama'),
              const SizedBox(height: 12),

              _buildLabel('Netto per kemasan'),
              const SizedBox(height: 6),
              _buildInputWithUnit(
                controller: _newNettoController,
                unit: _newUnit.displayName,
                placeholder: 'Contoh: 1000',
              ),
              Text(
                'Netto ini akan disimpan sebagai preset',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),

              _buildLabel('Jumlah kemasan'),
              const SizedBox(height: 6),
              _buildQtyRow(_newQtyController),
              const SizedBox(height: 16),

              _buildLabel('Total harga beli'),
              const SizedBox(height: 6),
              _buildInputWithPrefix(controller: _newHargaController, prefix: 'Rp'),
              const SizedBox(height: 24),

              if (_newNettoController.text.isNotEmpty && _newQtyController.text.isNotEmpty)
                _buildNewSummary(),
            ],
          ),
        ),

        _buildSubmitButton(
          enabled: _canSubmitNew && !operationState.isLoading,
          loading: operationState.isLoading,
          label: 'Tambah Bahan + Stock In',
          onPressed: _submitNewIngredient,
        ),
      ],
    );
  }

  // ── Shared UI Components ──

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));
  }

  Widget _buildSectionLabel(String text) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1),
      ),
    );
  }

  Widget _buildInputWithUnit({
    required TextEditingController controller,
    required String unit,
    String placeholder = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey[300]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Text(unit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Widget _buildInputWithPrefix({required TextEditingController controller, required String prefix}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Text(prefix, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey[300]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyRow(TextEditingController controller) {
    return Row(
      children: [
        _buildQtyButton(Icons.remove, () {
          final current = int.tryParse(controller.text) ?? 1;
          if (current > 1) {
            controller.text = '${current - 1}';
            setState(() {});
          }
        }),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        _buildQtyButton(Icons.add, () {
          final current = int.tryParse(controller.text) ?? 0;
          controller.text = '${current + 1}';
          setState(() {});
        }),
        const SizedBox(width: 12),
        Text('kemasan', style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryBlack),
      ),
    );
  }

  Widget _buildSummary({
    required double totalNetto,
    required String unit,
    required double stockAfter,
    required double costPerUnit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.05),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total masuk', '+${_formatStock(totalNetto)} $unit'),
          const SizedBox(height: 6),
          _buildSummaryRow('Stok setelah', '${_formatStock(stockAfter)} $unit'),
          if (costPerUnit > 0 && _hargaController.text.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            _buildSummaryRow(
              'Cost / $unit',
              'Rp ${costPerUnit < 1 ? costPerUnit.toStringAsFixed(3) : _formatStock(costPerUnit)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.05),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Bahan baru', _newNameController.text.isEmpty ? '—' : _newNameController.text),
          const SizedBox(height: 6),
          _buildSummaryRow('Stok awal', '${_formatStock(_newTotalNetto)} ${_newUnit.displayName}'),
          if (_newCostPerUnit > 0 && _newHargaController.text.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            _buildSummaryRow(
              'Cost / ${_newUnit.displayName}',
              'Rp ${_newCostPerUnit < 1 ? _newCostPerUnit.toStringAsFixed(3) : _formatStock(_newCostPerUnit)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSubmitButton({
    required bool enabled,
    required bool loading,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlack,
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.grey[400],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── Actions ──

  Future<void> _submitStockIn() async {
    final ing = _selected!;
    final success = await ref.read(stockOperationProvider.notifier).addStock(
      ingredientId: ing.id,
      quantity: _totalNetto,
      unitCost: _costPerUnit,
      notes: 'Stock In: ${_qtyController.text}x ${_nettoController.text}${ing.unit.displayName}',
    );

    if (success && mounted) {
      ref.invalidate(ingredientsStreamProvider);
      ref.invalidate(stockMovementsStreamProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ +${_formatStock(_totalNetto)} ${ing.unit.displayName} ${ing.name}'),
          backgroundColor: AppColors.primaryBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _submitNewIngredient() async {
    // Step 1: Create ingredient
    final success = await ref.read(ingredientNotifierProvider.notifier).createIngredient(
      name: _newNameController.text.trim(),
      unit: _newUnit,
      currentStock: _newTotalNetto,
      costPerUnit: _newCostPerUnit,
      minStock: double.tryParse(_newMinStockController.text) ?? 0,
    );

    if (success && mounted) {
      ref.invalidate(ingredientsStreamProvider);
      ref.invalidate(stockMovementsStreamProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_newNameController.text} ditambahkan — stok awal ${_formatStock(_newTotalNetto)} ${_newUnit.displayName}'),
          backgroundColor: AppColors.primaryBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _resetFields() {
    _nettoController.clear();
    _qtyController.text = '1';
    _hargaController.clear();
    _selectedPresetNetto = null;
  }

  // ── Helpers ──

  _StockStatus _getStockStatus(Ingredient ing) {
    if (ing.isOutOfStock) return _StockStatus(AppColors.errorRed, 'Habis');
    if (ing.isLowStock) return _StockStatus(AppColors.warningYellow, 'Low');
    return _StockStatus(AppColors.successGreen, 'Aman');
  }

  String _formatStock(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

class _StockStatus {
  final Color color;
  final String label;
  const _StockStatus(this.color, this.label);
}
