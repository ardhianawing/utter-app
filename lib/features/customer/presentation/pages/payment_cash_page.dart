import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/providers/cart_provider.dart';
import '../../data/providers/order_context_provider.dart';

class PaymentCashPage extends ConsumerStatefulWidget {
  final String orderId;
  final double totalAmount;

  const PaymentCashPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  @override
  ConsumerState<PaymentCashPage> createState() => _PaymentCashPageState();
}

class _PaymentCashPageState extends ConsumerState<PaymentCashPage> {
  Timer? _statusCheckTimer;
  bool _isChecking = false;
  String _currentStatus = 'PENDING_PAYMENT';

  @override
  void initState() {
    super.initState();
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('id', widget.orderId)
          .single();

      final status = response['status'] as String;
      setState(() => _currentStatus = status);

      if (status == 'PAID') {
        _onPaymentConfirmed();
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _onPaymentConfirmed() {
    _statusCheckTimer?.cancel();
    if (!mounted) return;

    ref.read(cartProvider.notifier).clearCart();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Dikonfirmasi!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Pesanan Anda sedang diproses', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.of(context).pop(); 
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderContext = ref.watch(orderContextProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order number
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Nomor Pesanan',
                        style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.orderId.substring(0, 8).toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.blue.shade900, // Explicit color for Dark Mode
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Total amount
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.payment, color: Colors.green),
                  title: const Text('Total Pembayaran', style: TextStyle(color: Colors.black87)),
                  trailing: Text(
                    'Rp ${widget.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Payment instructions (FIXED COLORS FOR DARK MODE)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Cara Pembayaran',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _instructionStep('1. Tunjukkan nomor pesanan di atas ke kasir'),
                    _instructionStep('2. Lakukan pembayaran di kasir'),
                    _instructionStep('3. Tunggu konfirmasi pembayaran'),
                    _instructionStep('4. Pesanan akan segera diproses'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    if (_isChecking)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _currentStatus == 'PAID' ? Icons.check_circle : Icons.pending,
                        color: _currentStatus == 'PAID' ? Colors.green : Colors.orange,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentStatus == 'PAID'
                            ? 'Pembayaran telah dikonfirmasi!'
                            : 'Menunggu konfirmasi pembayaran dari kasir...',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              OutlinedButton(
                onPressed: _showCancelDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Batalkan Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructionStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tidak')),
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('orders')
                    .update({'status': 'CANCELLED'})
                    .eq('id', widget.orderId);
                if (mounted) {
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop(); 
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}
