import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/providers/shift_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/print_service.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late OrderStatus _currentStatus;
  List<Map<String, dynamic>>? _orderItems;
  bool _isLoading = true;
  int? _tableNumber;

  // Helper for compact snackbar notifications
  void _showCompactSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? Colors.red[700] : (isSuccess ? Colors.green[700] : Colors.grey[800]),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _loadOrderItems();
    if (widget.order.tableId != null) {
      _loadTableInfo();
    }
  }

  Future<void> _loadTableInfo() async {
    try {
      final response = await Supabase.instance.client
          .from('tables')
          .select('table_number')
          .eq('id', widget.order.tableId!)
          .single();
      setState(() {
        _tableNumber = response['table_number'] as int?;
      });
    } catch (e) {
      debugPrint('Error fetching table: $e');
    }
  }

  Future<void> _loadOrderItems() async {
    try {
      final repo = OrderRepository(Supabase.instance.client);
      final items = await repo.getOrderItemsWithProducts(widget.order.id);
      setState(() {
        _orderItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _confirmPayment() async {
    // Get current user and active shift directly from database
    final currentUser = ref.read(currentUserProvider);
    String? shiftId;

    if (currentUser != null) {
      try {
        // Query active shift directly from database
        final shiftResponse = await Supabase.instance.client
            .from('shifts')
            .select('id')
            .eq('cashier_id', currentUser.id)
            .eq('status', 'open')
            .order('start_time', ascending: false)
            .limit(1)
            .maybeSingle();

        if (shiftResponse != null) {
          shiftId = shiftResponse['id'] as String;
          debugPrint('✅ Found active shift: $shiftId');
        } else {
          debugPrint('⚠️ No active shift found for cashier ${currentUser.id}');
        }
      } catch (e) {
        debugPrint('❌ Error getting active shift: $e');
      }
    }

    // If payment method is CASH, show cash calculator dialog
    if (widget.order.paymentMethod == PaymentMethod.CASH) {
      final result = await _showCashPaymentDialog();
      if (result == null) return; // User cancelled

      final cashReceived = result['cashReceived'] as double;
      final cashChange = result['cashChange'] as double;

      try {
        final repo = OrderRepository(Supabase.instance.client);

        // Update order with cash details, status, and shift_id
        final updateData = {
          'status': 'PAID',
          'cash_received': cashReceived,
          'cash_change': cashChange,
        };

        // Add shift_id if available
        if (shiftId != null) {
          updateData['shift_id'] = shiftId;
        }

        await Supabase.instance.client
            .from('orders')
            .update(updateData)
            .eq('id', widget.order.id);

        setState(() {
          _currentStatus = OrderStatus.PAID;
        });

        _showCompactSnackBar('Pembayaran dikonfirmasi', isSuccess: true);
      } catch (e) {
        _showCompactSnackBar('Error: $e', isError: true);
      }
    } else {
      // For QRIS/DEBIT, update status and shift_id
      _updateStatusWithShift(OrderStatus.PAID, shiftId);
    }
  }

  Future<Map<String, double>?> _showCashPaymentDialog() async {
    final total = widget.order.totalAmount;
    final controller = TextEditingController();

    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final received = double.tryParse(controller.text) ?? 0;
            final change = received - total;

            return AlertDialog(
              title: const Text('💵 Pembayaran Tunai'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Tagihan: Rp ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Uang Diterima',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: change >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kembalian:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rp ${change.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: change >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: change >= 0
                      ? () => Navigator.pop(context, {
                            'cashReceived': received,
                            'cashChange': change,
                          })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Konfirmasi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    try {
      final repo = OrderRepository(Supabase.instance.client);
      await repo.updateOrderStatus(widget.order.id, newStatus);

      setState(() {
        _currentStatus = newStatus;
      });

      _showCompactSnackBar('Status: ${newStatus.name}', isSuccess: true);

      if (newStatus == OrderStatus.COMPLETED || newStatus == OrderStatus.CANCELLED) {
        Navigator.pop(context, true); // Return true to indicate order finished
      }
    } catch (e) {
      _showCompactSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _updateStatusWithShift(OrderStatus newStatus, String? shiftId) async {
    try {
      // Update status and shift_id
      final updateData = {'status': newStatus.name};
      if (shiftId != null) {
        updateData['shift_id'] = shiftId;
      }

      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', widget.order.id);

      setState(() {
        _currentStatus = newStatus;
      });

      _showCompactSnackBar('Status: ${newStatus.name}', isSuccess: true);

      if (newStatus == OrderStatus.COMPLETED || newStatus == OrderStatus.CANCELLED) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showCompactSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _showCancelDialog() async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Customer changed mind',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final repo = OrderRepository(Supabase.instance.client);
        await repo.cancelOrder(
          widget.order.id,
          reasonController.text.trim().isEmpty
              ? 'No reason provided'
              : reasonController.text.trim(),
        );

        setState(() => _currentStatus = OrderStatus.CANCELLED);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    reasonController.dispose();
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.PENDING_PAYMENT:
        return AppColors.statusPending;
      case OrderStatus.PAID:
        return AppColors.statusPaid;
      case OrderStatus.PREPARING:
        return Colors.orange;
      case OrderStatus.READY:
        return Colors.green;
      case OrderStatus.SERVED:
        return Colors.blue;
      case OrderStatus.COMPLETED:
        return AppColors.statusCompleted;
      case OrderStatus.CANCELLED:
        return AppColors.statusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.displayId ?? widget.order.id.substring(0, 8)}'),
        actions: [
          if (_orderItems != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Cetak Struk',
              onPressed: () async {
                try {
                  await PrintService.printReceipt(
                    order: widget.order,
                    items: _orderItems!,
                    tableNumber: _tableNumber,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mencetak: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Order Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_currentStatus),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currentStatus.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            label: 'Type',
                            value: widget.order.type.name,
                          ),
                          _InfoRow(
                            label: 'Source',
                            value: widget.order.source.name,
                          ),
                          _InfoRow(
                            label: 'Payment',
                            value: widget.order.paymentMethod.name,
                          ),
                          if (widget.order.type == OrderType.DINE_IN && _tableNumber != null)
                            _InfoRow(
                              label: 'Table',
                              value: 'Meja #$_tableNumber',
                            ),
                          _InfoRow(
                            label: 'Time',
                            value: _formatTime(widget.order.createdAt),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Items
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_orderItems == null || _orderItems!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No items found'),
                      ),
                    )
                  else
                    ..._orderItems!.map((item) {
                      final productName = item['products']?['name'] ?? 'Unknown Product';
                      final quantity = item['quantity'] as int;
                      final unitPrice = (item['unit_price'] as num).toDouble();
                      final subtotal = (item['subtotal'] as num).toDouble();
                      final notes = item['notes'] as String?;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.accentGray,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              title: Text(
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Rp ${unitPrice.toStringAsFixed(0)} × $quantity',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (item['selected_modifiers'] != null && (item['selected_modifiers'] as List).isNotEmpty) ...[
                                      const TextSpan(
                                        text: '\nDetail: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: (item['selected_modifiers'] as List)
                                            .map((m) => m['name'] ?? m['id'] ?? '')
                                            .join(', '),
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (notes != null && notes.isNotEmpty) ...[
                                      const TextSpan(
                                        text: '\nNote: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: notes,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ), 
                              trailing: Text(
                                'Rp ${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Total
                  Card(
                    color: AppColors.primaryBlack,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rp ${widget.order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status Update Buttons
                  const Text(
                    'Update Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusButtons() {
    // Show read-only message if completed or cancelled
    if (_currentStatus == OrderStatus.COMPLETED ||
        _currentStatus == OrderStatus.CANCELLED) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _currentStatus == OrderStatus.COMPLETED
                  ? Icons.check_circle
                  : Icons.cancel,
              color: _currentStatus == OrderStatus.COMPLETED
                  ? AppColors.successGreen
                  : AppColors.errorRed,
            ),
            const SizedBox(width: 12),
            Text(
              _currentStatus == OrderStatus.COMPLETED
                  ? 'Order has been completed'
                  : 'Order has been cancelled',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // PENDING_PAYMENT: Show confirm payment button
    if (_currentStatus == OrderStatus.PENDING_PAYMENT) {
      return Column(
        children: [
          _StatusButton(
            label: 'Konfirmasi Pembayaran',
            color: Colors.green,
            icon: Icons.check_circle,
            onPressed: _confirmPayment, // Use cash calculator dialog
          ),
          _StatusButton(
            label: 'Batalkan Pesanan',
            color: AppColors.errorRed,
            icon: Icons.cancel,
            onPressed: () => _updateStatus(OrderStatus.CANCELLED),
          ),
        ],
      );
    }

    // PAID: Show complete order button + cancel
    return Column(
      children: [
        _StatusButton(
          label: 'Selesaikan Pesanan',
          color: Colors.blue,
          icon: Icons.done_all,
          onPressed: () => _updateStatus(OrderStatus.COMPLETED),
        ),
        _StatusButton(
          label: 'Batalkan Pesanan',
          color: Colors.red,
          icon: Icons.cancel,
          onPressed: _showCancelDialog,
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
