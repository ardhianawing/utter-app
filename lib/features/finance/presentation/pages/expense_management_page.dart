import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utter_app/core/constants/app_colors.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/models/expense_models.dart';

class ExpenseManagementPage extends ConsumerStatefulWidget {
  const ExpenseManagementPage({super.key});

  @override
  ConsumerState<ExpenseManagementPage> createState() => _ExpenseManagementPageState();
}

class _ExpenseManagementPageState extends ConsumerState<ExpenseManagementPage> {
  final _repository = ExpenseRepository(Supabase.instance.client);

  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  ExpenseSummary? _summary;
  bool _isLoading = true;

  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final categories = await _repository.getCategories();
      final expenses = await _repository.getExpenses(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );
      final summary = await _repository.getExpenseSummary(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      setState(() {
        _categories = categories;
        _expenses = expenses;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddExpenseDialog() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori belum tersedia. Jalankan migration dulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    ExpenseCategory? selectedCategory = _categories.first;
    PaymentMethod selectedPaymentMethod = PaymentMethod.CASH;
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Pengeluaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah (Rp)',
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  value: selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Metode Pembayaran',
                    border: OutlineInputBorder(),
                  ),
                  items: PaymentMethod.values.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedPaymentMethod = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Tanggal'),
                  subtitle: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                final description = descriptionController.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jumlah harus lebih dari 0'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Keterangan wajib diisi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  await _repository.createExpense(
                    categoryId: selectedCategory!.id,
                    amount: amount,
                    description: description,
                    paymentMethod: selectedPaymentMethod,
                    expenseDate: selectedDate,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Pengeluaran berhasil ditambahkan'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengeluaran'),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
              _loadData();
            },
          ),
          Center(
            child: Text(
              _getMonthLabel(_selectedMonth),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedMonth.month == DateTime.now().month &&
                    _selectedMonth.year == DateTime.now().year
                ? null
                : () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                    _loadData();
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                if (_summary != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Pengeluaran',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _summary!.formattedTotal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_summary!.expenseCount} transaksi',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expense List
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada pengeluaran bulan ini.\nTambah dengan tombol + di bawah.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: Icon(
                                    Icons.money_off,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                title: Text(
                                  expense.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(expense.category?.name ?? 'Tanpa Kategori'),
                                    Text(
                                      '${expense.expenseDate.day}/${expense.expenseDate.month}/${expense.expenseDate.year} • ${expense.paymentMethod.displayName}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  expense.formattedAmount,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppColors.primaryBlack,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pengeluaran'),
      ),
    );
  }

  String _getMonthLabel(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
