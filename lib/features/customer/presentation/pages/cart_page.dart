import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/providers/cart_provider.dart';
import '../../data/providers/order_context_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../cashier/data/repositories/order_repository.dart';
import '../../../shared/models/models.dart';
import 'payment_method_selector_page.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  String _formatPrice(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'KERANJANG SAYA',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(cartProvider.notifier).clearCart(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.red),
              label: const Text(
                'Hapus Semua',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: Colors.grey[200],
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey),
                   ),
                  const SizedBox(height: 16),
                  const Text(
                    'Wah, keranjangmu masih kosong',
                    style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Mulai Pesan Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _CartItemCard(
                        cartItem: item,
                        onQuantityChanged: (newQty) {
                          ref.read(cartProvider.notifier).updateQuantity(
                                item.product.id,
                                newQty,
                                index: index,
                              );
                        },
                        onRemove: () {
                          ref.read(cartProvider.notifier).removeProduct(item.product.id, index: index);
                        },
                        onNoteChanged: (note) {
                          ref.read(cartProvider.notifier).updateNotes(index, note);
                        },
                      );
                    },
                  ),
                ),
                const _OrderTypeSelector(),
                _CartSummary(cartItems: cartItems),
              ],
            ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;
  final Function(String?) onNoteChanged;

  const _CartItemCard({
    required this.cartItem,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onNoteChanged,
  });

  String _formatPrice(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: cartItem.product.imageUrl != null && cartItem.product.imageUrl!.isNotEmpty
                        ? Image.network(cartItem.product.imageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.grey[100], child: const Icon(Icons.fastfood, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartItem.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(cartItem.unitPrice), // Use unitPrice to account for modifiers
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Display Modifiers
                      if (cartItem.selectedModifiers.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: cartItem.selectedModifiers.map((mod) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              mod.name,
                              style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Quantity Controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyButton(Icons.remove, () => onQuantityChanged(cartItem.quantity - 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${cartItem.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      _qtyButton(Icons.add, () => onQuantityChanged(cartItem.quantity + 1)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Note Field
            Row(
              children: [
                const Icon(Icons.edit_note_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onNoteChanged,
                    controller: TextEditingController(text: cartItem.notes)..selection = TextSelection.fromPosition(TextPosition(offset: cartItem.notes?.length ?? 0)),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Tambah catatan (opsional)...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      isDense: true,
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 14, color: Colors.black87),
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  final List<CartItem> cartItems;

  const _CartSummary({required this.cartItems});

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    try {
      final cartNotifier = ref.read(cartProvider.notifier);
      final totalAmount = cartNotifier.totalAmount;
      final items = ref.read(cartProvider);
      final orderContext = ref.read(orderContextProvider);

      // 1. Show Confirmation Dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Pesanan'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daftar Pesanan:'),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name),
                                  if (item.selectedModifiers.isNotEmpty)
                                    Text(
                                      item.selectedModifiers.map((m) => m.name).join(', '),
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total (${cartNotifier.totalItems} Items)'),
                    Text(
                      'Rp ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cek Lagi', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pesan Sekarang'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Validate tableId - must be valid UUID or null
      String? validTableId = orderContext.tableId;
      if (validTableId != null) {
        // Check if it's a valid UUID format
        final uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        if (!uuidPattern.hasMatch(validTableId)) {
          validTableId = null; // Invalid UUID, treat as takeaway
        }
      }

      // Create order with dynamic context
      final order = Order(
        id: '', // Will be generated by DB
        source: OrderSource.APP,
        type: validTableId != null ? OrderType.DINE_IN : OrderType.TAKEAWAY,  // Auto-detect based on valid table
        status: OrderStatus.PENDING_PAYMENT,  // ✅ Pending until cashier confirms
        paymentMethod: PaymentMethod.CASH,  // ✅ Cash for MVP
        tableId: validTableId,  // ✅ Only use if valid UUID
        userId: orderContext.user?.id,  // ✅ From logged-in user (null if guest)
        totalAmount: totalAmount,
        pointsEarned: (totalAmount * 0.01).round(), // 1% points
        pointsRedeemed: 0,
        createdAt: DateTime.now(),
      );

      // Prepare order items with notes
      final orderItems = items.map((cartItem) {
        final subtotal = cartItem.unitPrice * cartItem.quantity;
        return {
          'product_id': cartItem.product.id,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.unitPrice,
          'subtotal': subtotal,
          'notes': cartItem.notes, // Include customer notes
          'selected_modifiers': cartItem.selectedModifiers.map((m) => m.toJson()).toList(), // Insert Modifiers
        };
      }).toList();

      final repo = OrderRepository(Supabase.instance.client);
      final orderId = await repo.createOrderWithItems(order, orderItems);

      if (context.mounted) {
        // Navigate to payment method selector
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentMethodSelectorPage(
              orderId: orderId,
              totalAmount: totalAmount,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAmount = ref.read(cartProvider.notifier).totalAmount;
    final totalItems = ref.read(cartProvider.notifier).totalItems;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($totalItems items)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rp ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _placeOrder(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlack,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'PLACE ORDER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeSelector extends ConsumerWidget {
  const _OrderTypeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderContext = ref.watch(orderContextProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipe Pesanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Show table info if dine-in
            if (orderContext.isDineIn) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.table_restaurant, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Meja #${orderContext.tableNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Toggle buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(orderContextProvider.notifier)
                          .setOrderType(OrderType.DINE_IN);
                    },
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Dine In'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: orderContext.orderType == OrderType.DINE_IN
                          ? Colors.blue.shade50
                          : null,
                      foregroundColor: orderContext.orderType == OrderType.DINE_IN
                          ? Colors.blue
                          : null,
                      side: BorderSide(
                        color: orderContext.orderType == OrderType.DINE_IN
                            ? Colors.blue
                            : Colors.grey,
                        width: orderContext.orderType == OrderType.DINE_IN ? 2 : 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(orderContextProvider.notifier)
                          .setOrderType(OrderType.TAKEAWAY);
                    },
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Takeaway'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: orderContext.orderType == OrderType.TAKEAWAY
                          ? Colors.green.shade50
                          : null,
                      foregroundColor: orderContext.orderType == OrderType.TAKEAWAY
                          ? Colors.green
                          : null,
                      side: BorderSide(
                        color: orderContext.orderType == OrderType.TAKEAWAY
                            ? Colors.green
                            : Colors.grey,
                        width: orderContext.orderType == OrderType.TAKEAWAY ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
