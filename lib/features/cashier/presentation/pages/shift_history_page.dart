import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/print_service.dart';
import '../../data/repositories/shift_repository.dart';

class ShiftHistoryPage extends ConsumerStatefulWidget {
  const ShiftHistoryPage({super.key});

  @override
  ConsumerState<ShiftHistoryPage> createState() => _ShiftHistoryPageState();
}

class _ShiftHistoryPageState extends ConsumerState<ShiftHistoryPage> {
  final ShiftRepository _repo = ShiftRepository(Supabase.instance.client);

  List<Shift> _shifts = [];
  List<Map<String, dynamic>> _cashiers = [];
  bool _isLoading = true;

  // Filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _selectedCashierId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load cashiers for filter
      final cashiersResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .or('role.eq.CASHIER,role.eq.ADMIN');

      _cashiers = List<Map<String, dynamic>>.from(cashiersResponse);

      // Load shifts
      await _loadShifts();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadShifts() async {
    try {
      // Build filter query first, then apply order
      var filterQuery = Supabase.instance.client
          .from('shifts')
          .select('''
            *,
            profiles:cashier_id (name)
          ''')
          .gte('start_time', _startDate.toIso8601String())
          .lte('start_time', _endDate.add(const Duration(days: 1)).toIso8601String());

      if (_selectedCashierId != null) {
        filterQuery = filterQuery.eq('cashier_id', _selectedCashierId!);
      }

      // Apply order last
      final response = await filterQuery.order('start_time', ascending: false);

      setState(() {
        _shifts = (response as List).map((json) {
          final shift = Shift.fromJson(json);
          // Store cashier name in a map for display
          return shift;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.successGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadShifts();
    }
  }

  void _showShiftDetail(Shift shift) async {
    // Load full shift summary
    try {
      final summary = await _repo.getShiftSummary(shift.id);
      if (summary == null || !mounted) return;

      // Get cashier name
      final cashierResponse = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', shift.cashierId)
          .single();
      final cashierName = cashierResponse['name'] as String;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => _ShiftDetailDialog(
          shift: summary.shift,
          summary: summary,
          cashierName: cashierName,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading shift detail: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RIWAYAT SHIFT'),
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ========== FILTERS ==========
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                // Date Range Filter
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Cashier Filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCashierId,
                        hint: const Text('Semua Kasir', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Kasir', style: TextStyle(fontSize: 13)),
                          ),
                          ..._cashiers.map((c) => DropdownMenuItem<String?>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String, style: const TextStyle(fontSize: 13)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCashierId = value);
                          _loadShifts();
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Refresh Button
                IconButton(
                  onPressed: _loadShifts,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // ========== SUMMARY CARDS ==========
          if (!_isLoading && _shifts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Total Shift',
                    '${_shifts.length}',
                    Icons.access_time,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Revenue',
                    'Rp ${_formatNumber(_shifts.fold(0.0, (sum, s) => sum + s.totalSales))}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Rata-rata/Shift',
                    'Rp ${_formatNumber(_shifts.isEmpty ? 0 : _shifts.fold(0.0, (sum, s) => sum + s.totalSales) / _shifts.length)}',
                    Icons.analytics,
                    Colors.orange,
                  ),
                ],
              ),
            ),

          // ========== SHIFT LIST ==========
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data shift',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _shifts.length,
                        itemBuilder: (context, index) {
                          final shift = _shifts[index];
                          return _buildShiftCard(shift);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(Shift shift) {
    final isClosed = shift.status == 'closed';
    final difference = shift.cashDifference ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showShiftDetail(shift),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isClosed ? Colors.grey[200] : Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isClosed ? 'CLOSED' : 'OPEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isClosed ? Colors.grey[700] : Colors.green[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Shift #${shift.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(shift.startTime),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Info Row
              Row(
                children: [
                  // Time
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(shift.startTime)} - ${shift.endTime != null ? _formatTime(shift.endTime!) : 'Now'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  // Duration
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.timelapse, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          shift.durationFormatted,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Revenue & Cash
              Row(
                children: [
                  // Total Revenue
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pendapatan', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatNumber(shift.totalSales)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Payment Breakdown
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPaymentChip('Cash', shift.totalCashReceived, Colors.green),
                        _buildPaymentChip('QRIS', shift.totalQrisReceived, Colors.blue),
                        _buildPaymentChip('Debit', shift.totalDebitReceived, Colors.orange),
                      ],
                    ),
                  ),

                  // Difference (if closed)
                  if (isClosed && shift.endingCash != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: difference == 0
                            ? Colors.green[50]
                            : (difference > 0 ? Colors.orange[50] : Colors.red[50]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Selisih',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          Text(
                            difference == 0
                                ? 'COCOK'
                                : (difference > 0
                                    ? '+${_formatNumber(difference)}'
                                    : '-${_formatNumber(-difference)}'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: difference == 0
                                  ? Colors.green[700]
                                  : (difference > 0 ? Colors.orange[700] : Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // View Detail Button
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showShiftDetail(shift),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Lihat Detail'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(
          _formatNumber(amount),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

// ========== SHIFT DETAIL DIALOG ==========
class _ShiftDetailDialog extends StatelessWidget {
  final Shift shift;
  final ShiftSummary summary;
  final String cashierName;

  const _ShiftDetailDialog({
    required this.shift,
    required this.summary,
    required this.cashierName,
  });

  @override
  Widget build(BuildContext context) {
    final s = shift;
    final expectedCash = s.expectedCash ?? (s.startingCash + s.totalCashReceived);
    final difference = s.endingCash != null ? s.endingCash! - expectedCash : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETAIL LAPORAN SHIFT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Shift #${s.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white),
                    tooltip: 'Cetak',
                    onPressed: () => PrintService.printShiftReport(
                      shift: s,
                      summary: summary,
                      cashierName: cashierName,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shift Info
                    _buildSection('INFO SHIFT', [
                      _buildRow('Kasir', cashierName),
                      _buildRow('Mulai', _formatDateTime(s.startTime)),
                      _buildRow('Selesai', s.endTime != null ? _formatDateTime(s.endTime!) : '-'),
                      _buildRow('Durasi', s.durationFormatted),
                      _buildRow('Total Order', '${summary.orderCount}'),
                    ]),

                    const SizedBox(height: 16),

                    // Revenue
                    _buildSection('PENDAPATAN', [
                      _buildMoneyRow('Penjualan Tunai', s.totalCashReceived, Colors.green),
                      _buildMoneyRow('Penjualan QRIS', s.totalQrisReceived, Colors.blue),
                      _buildMoneyRow('Penjualan Debit', s.totalDebitReceived, Colors.orange),
                      const Divider(),
                      _buildMoneyRow('TOTAL PENDAPATAN', s.totalSales, Colors.green, bold: true),
                    ], color: Colors.green),

                    const SizedBox(height: 16),

                    // Cash Reconciliation
                    _buildSection('REKONSILIASI KAS', [
                      _buildMoneyRow('Modal Awal', s.startingCash, Colors.grey),
                      _buildMoneyRow('+ Uang Diterima', s.totalCashReceived, Colors.green),
                      const Divider(),
                      _buildMoneyRow('Seharusnya di Laci', expectedCash, Colors.blue, bold: true),
                      if (s.endingCash != null) ...[
                        _buildMoneyRow('Hasil Hitung', s.endingCash!, Colors.grey),
                        _buildDifferenceRow(difference),
                      ],
                    ], color: Colors.blue),

                    const SizedBox(height: 16),

                    // Deposit & Leave
                    _buildSection('SETOR & TINGGAL', [
                      _buildMoneyRow('Setor ke Owner', s.totalCashReceived, Colors.green, bold: true),
                      Text('(Pendapatan tunai)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildMoneyRow('Tinggal di Laci', s.startingCash, Colors.blue, bold: true),
                      Text('(Modal shift berikutnya)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ], color: Colors.purple),

                    // Notes
                    if (s.notes != null && s.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSection('CATATAN', [
                        Text(s.notes!, style: const TextStyle(fontSize: 13)),
                      ], color: Colors.grey),
                    ],

                    // Top Products
                    if (summary.topProducts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSection('PRODUK TERLARIS', [
                        ...summary.topProducts.take(5).map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${p.totalQuantity}x',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p.productName, style: const TextStyle(fontSize: 13))),
                              Text(
                                'Rp ${_formatNumber(p.totalRevenue)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                      ], color: Colors.amber),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color ?? Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? Colors.black : Colors.grey[700],
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceRow(double difference) {
    final isMatch = difference == 0;
    final isOver = difference > 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMatch
            ? Colors.green[100]
            : (isOver ? Colors.orange[100] : Colors.red[100]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMatch ? Icons.check_circle : (isOver ? Icons.arrow_upward : Icons.arrow_downward),
            size: 18,
            color: isMatch
                ? Colors.green[700]
                : (isOver ? Colors.orange[700] : Colors.red[700]),
          ),
          const SizedBox(width: 8),
          Text(
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
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
