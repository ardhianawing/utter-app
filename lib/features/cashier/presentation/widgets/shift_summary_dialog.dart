import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/shift_provider.dart';
import '../../../../core/utils/print_service.dart';

/// End-of-Shift Summary Dialog
/// Redesigned for clarity: separates Revenue from Cash Reconciliation
class ShiftSummaryDialog extends ConsumerStatefulWidget {
  final Shift shift;
  final String cashierName;

  const ShiftSummaryDialog({
    super.key,
    required this.shift,
    required this.cashierName,
  });

  @override
  ConsumerState<ShiftSummaryDialog> createState() => _ShiftSummaryDialogState();
}

class _ShiftSummaryDialogState extends ConsumerState<ShiftSummaryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isClosing = false;

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _closeShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isClosing = true);

    final actualCash = double.parse(_actualCashController.text);
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    final shiftNotifier = ref.read(shiftProvider(widget.shift.cashierId).notifier);
    final success = await shiftNotifier.closeShift(actualCash, notes: notes);

    setState(() => _isClosing = false);

    if (success && mounted) {
      // Pop with 'logout' to indicate user should be logged out
      Navigator.of(context).pop('logout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftSummary = ref.watch(shiftSummaryProvider(widget.shift.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ========== HEADER ==========
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'LAPORAN AKHIR SHIFT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Shift #${widget.shift.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),

            // ========== CONTENT ==========
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: shiftSummary.when(
                    data: (summary) {
                      if (summary == null) return const Text('No data');
                      final s = summary.shift;

                      // Calculate values
                      final totalRevenue = s.totalSales; // Cash + QRIS + Debit
                      final expectedCash = s.expectedCash ??
                          (s.startingCash + s.totalCashReceived);
                      final cashToDeposit = s.totalCashReceived; // Only cash sales
                      final cashToLeave = s.startingCash; // Modal stays

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ========== SHIFT INFO ==========
                          _buildSectionHeader('INFO SHIFT', Icons.access_time),
                          _buildInfoCard([
                            _buildInfoRow('Kasir', widget.cashierName),
                            _buildInfoRow('Mulai', _formatDateTime(widget.shift.startTime)),
                            _buildInfoRow('Selesai', _formatDateTime(DateTime.now())),
                            _buildInfoRow('Durasi', widget.shift.durationFormatted),
                            _buildInfoRow('Total Transaksi', '${summary.orderCount} order'),
                          ]),

                          const SizedBox(height: 20),

                          // ========== REVENUE SUMMARY ==========
                          _buildSectionHeader('PENDAPATAN (Revenue)', Icons.trending_up, color: Colors.green),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              children: [
                                _buildMoneyRow('Penjualan Tunai', s.totalCashReceived, icon: Icons.payments, color: Colors.green[700]!),
                                _buildMoneyRow('Penjualan QRIS', s.totalQrisReceived, icon: Icons.qr_code, color: Colors.blue[700]!),
                                _buildMoneyRow('Penjualan Debit', s.totalDebitReceived, icon: Icons.credit_card, color: Colors.orange[700]!),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL PENDAPATAN',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Rp ${_formatNumber(totalRevenue)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ========== CASH RECONCILIATION ==========
                          _buildSectionHeader('REKONSILIASI KAS (Uang Fisik)', Icons.account_balance_wallet, color: Colors.blue),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              children: [
                                _buildCalculationRow('Modal Awal', s.startingCash, isFirst: true),
                                _buildCalculationRow('+ Uang Diterima', s.totalCashReceived, isPositive: true),
                                // Note: We need to calculate change given
                                // For now, expectedCash already accounts for this
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'SEHARUSNYA DI LACI',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Rp ${_formatNumber(expectedCash)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Actual Cash Input
                                TextFormField(
                                  controller: _actualCashController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Hasil Hitung Manual',
                                    prefixText: 'Rp ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    helperText: 'Hitung uang fisik di laci kasir',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Masukkan jumlah uang hasil hitung';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Difference Calculator
                                ValueListenableBuilder(
                                  valueListenable: _actualCashController,
                                  builder: (context, value, child) {
                                    final actualCash = double.tryParse(value.text) ?? 0;
                                    final difference = actualCash - expectedCash;

                                    if (value.text.isEmpty) return const SizedBox.shrink();

                                    final isMatch = difference == 0;
                                    final isOver = difference > 0;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMatch
                                            ? Colors.green[100]
                                            : (isOver ? Colors.orange[100] : Colors.red[100]),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isMatch
                                                ? Icons.check_circle
                                                : (isOver ? Icons.arrow_upward : Icons.arrow_downward),
                                            color: isMatch
                                                ? Colors.green[700]
                                                : (isOver ? Colors.orange[700] : Colors.red[700]),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isMatch
                                                  ? 'COCOK - Tidak ada selisih'
                                                  : (isOver
                                                      ? 'LEBIH Rp ${_formatNumber(difference)}'
                                                      : 'KURANG Rp ${_formatNumber(-difference)}'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isMatch
                                                    ? Colors.green[700]
                                                    : (isOver ? Colors.orange[700] : Colors.red[700]),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ========== DEPOSIT & LEAVE ==========
                          _buildSectionHeader('SETOR & TINGGAL', Icons.swap_horiz, color: Colors.purple),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Column(
                              children: [
                                // Deposit to Owner
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.arrow_upward, color: Colors.green[700], size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'SETOR KE OWNER',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            Text(
                                              'Rp ${_formatNumber(cashToDeposit)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                            const Text(
                                              'Pendapatan tunai hari ini',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Leave for Next Shift
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.savings, color: Colors.blue[700], size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'TINGGAL DI LACI',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            Text(
                                              'Rp ${_formatNumber(cashToLeave)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                            const Text(
                                              'Modal untuk shift berikutnya',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ========== TOP PRODUCTS ==========
                          if (summary.topProducts.isNotEmpty) ...[
                            _buildSectionHeader('PRODUK TERLARIS', Icons.star, color: Colors.amber),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Column(
                                children: summary.topProducts.take(5).map((product) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.amber[200],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${product.totalQuantity}x',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            product.productName,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          'Rp ${_formatNumber(product.totalRevenue)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ========== NOTES ==========
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Catatan (Opsional)',
                              hintText: 'Masalah atau catatan khusus...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ),

            // ========== ACTIONS ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _isClosing ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  shiftSummary.when(
                    data: (summary) => summary != null
                        ? IconButton(
                            icon: const Icon(Icons.print),
                            tooltip: 'Cetak Laporan',
                            onPressed: () => PrintService.printShiftReport(
                              shift: summary.shift,
                              summary: summary,
                              cashierName: widget.cashierName,
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isClosing ? null : _closeShift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: _isClosing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.lock),
                    label: const Text('TUTUP SHIFT'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color ?? Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, double amount, {required IconData icon, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, double amount, {bool isFirst = false, bool isPositive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isPositive ? Colors.green[700] : Colors.grey[700],
            ),
          ),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: isPositive ? Colors.green[700] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
