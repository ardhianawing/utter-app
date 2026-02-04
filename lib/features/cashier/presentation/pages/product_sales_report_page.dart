import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/order_repository.dart';
import 'package:intl/intl.dart';

class ProductSalesReportPage extends ConsumerStatefulWidget {
  const ProductSalesReportPage({super.key});

  @override
  ConsumerState<ProductSalesReportPage> createState() => _ProductSalesReportPageState();
}

class _ProductSalesReportPageState extends ConsumerState<ProductSalesReportPage> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _salesData = [];
  bool _isLoading = false;
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrderRepository(Supabase.instance.client);
      final data = await repo.getProductSalesReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _salesData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      
      switch (period) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now.add(const Duration(days: 1));
          break;
        case 'yesterday':
          _startDate = DateTime(now.year, now.month, now.day - 1);
          _endDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
          _endDate = now.add(const Duration(days: 1));
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now.add(const Duration(days: 1));
          break;
      }
    });
    _loadSalesData();
  }

  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSalesData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    final totalQuantity = _salesData.fold<int>(0, (sum, item) => sum + (item['total_quantity'] as int));
    final totalRevenue = _salesData.fold<double>(0, (sum, item) => sum + (item['total_revenue'] as double));
    final totalOnline = _salesData.fold<int>(0, (sum, item) => sum + (item['online_quantity'] as int));
    final totalPos = _salesData.fold<int>(0, (sum, item) => sum + (item['pos_quantity'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Laporan Penjualan Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalesData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periode:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PeriodChip(
                      label: 'Hari Ini',
                      value: 'today',
                      selected: _selectedPeriod == 'today',
                      onTap: () => _changePeriod('today'),
                    ),
                    _PeriodChip(
                      label: 'Kemarin',
                      value: 'yesterday',
                      selected: _selectedPeriod == 'yesterday',
                      onTap: () => _changePeriod('yesterday'),
                    ),
                    _PeriodChip(
                      label: 'Minggu Ini',
                      value: 'week',
                      selected: _selectedPeriod == 'week',
                      onTap: () => _changePeriod('week'),
                    ),
                    _PeriodChip(
                      label: 'Bulan Ini',
                      value: 'month',
                      selected: _selectedPeriod == 'month',
                      onTap: () => _changePeriod('month'),
                    ),
                    ActionChip(
                      label: const Text('Custom', style: TextStyle(fontSize: 12)),
                      onPressed: _pickCustomDateRange,
                      backgroundColor: _selectedPeriod == 'custom' ? Colors.blue : Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedPeriod == 'custom' ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Terjual',
                    value: '$totalQuantity pcs',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'POS',
                    value: '$totalPos pcs',
                    icon: Icons.store,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Online',
                    value: '$totalOnline pcs',
                    icon: Icons.delivery_dining,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _salesData.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada data penjualan',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _salesData.length,
                        itemBuilder: (context, index) {
                          final item = _salesData[index];
                          return _ProductSalesCard(
                            productName: item['product_name'],
                            category: item['category'],
                            totalQuantity: item['total_quantity'],
                            onlineQuantity: item['online_quantity'],
                            posQuantity: item['pos_quantity'],
                            revenue: item['total_revenue'],
                            basePrice: item['base_price'],
                            rank: index + 1,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: selected ? Colors.blue : Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.fromRGBO(color.red, color.green, color.blue, 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color.fromRGBO(color.red, color.green, color.blue, 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSalesCard extends StatelessWidget {
  final String productName;
  final String category;
  final int totalQuantity;
  final int onlineQuantity;
  final int posQuantity;
  final double revenue;
  final double basePrice;
  final int rank;

  const _ProductSalesCard({
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.onlineQuantity,
    required this.posQuantity,
    required this.revenue,
    required this.basePrice,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3 ? Colors.amber : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: rank <= 3 ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$totalQuantity pcs',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.blue,
                    ),
                  ),
                  if (revenue > 0)
                    Text(
                      'Rp ${revenue.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.store,
                  label: 'POS',
                  value: '$posQuantity',
                  color: Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.delivery_dining,
                  label: 'Online',
                  value: '$onlineQuantity',
                  color: Colors.orange,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.attach_money,
                  label: 'Harga',
                  value: 'Rp ${basePrice.toStringAsFixed(0)}',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
