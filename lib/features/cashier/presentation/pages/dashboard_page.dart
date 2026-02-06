import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/shift_provider.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/shift_summary_dialog.dart';
import '../../../../features/customer/data/repositories/product_repository.dart';
import '../../../shared/models/models.dart';
import '../../../../core/widgets/common_widgets.dart';
import 'order_detail_page.dart';
import 'manual_entry_page.dart';
import 'staff_login_page.dart';
import 'admin_menu_page.dart';
import 'kitchen_display_page.dart';
import 'shift_history_page.dart';
import 'product_sales_report_page.dart';
import 'user_management_page.dart';
import 'monthly_analytics_page.dart';
import '../widgets/product_category_section.dart';
import '../../../storage/presentation/pages/storage_main_page.dart';
import '../../../../core/utils/print_service.dart';
import '../widgets/product_selection_dialog.dart';
import '../widgets/ai_assistant_drawer.dart';
import '../../../../core/constants/app_colors.dart';

// CartItem model moved to models.dart


class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final List<CartItem> _cart = [];
  final Map<String, double> _customPrices = {}; // productId -> custom price
  List<Product> _products = [];
  OrderType _orderType = OrderType.TAKEAWAY;
  PaymentMethod _paymentMethod = PaymentMethod.CASH;
  OrderSource _orderSource = OrderSource.POS_MANUAL; // Default: Dine In
  bool _isCheckingOut = false;
  final TextEditingController _customerNameController = TextEditingController();
  List<RestaurantTable> _tables = [];
  String? _selectedTableId;
  bool _useTableSelector = false;
  bool _showHistory = false;
  bool _shiftCheckDone = false;
  final TextEditingController _manualTotalController = TextEditingController();

  bool get _isOnlineFood => 
      _orderSource == OrderSource.GOFOOD || 
      _orderSource == OrderSource.GRABFOOD || 
      _orderSource == OrderSource.SHOPEEFOOD;

  // Real-time subscription
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _fetchTables();
    _setupRealtimeSubscription();
    // Check shift status after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndForceOpenShift();
    });
  }

  // Check if cashier has active shift, if not force open shift dialog
  Future<void> _checkAndForceOpenShift() async {
    if (_shiftCheckDone) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || currentUser.role == UserRole.ADMIN) {
      _shiftCheckDone = true;
      return;
    }

    // Wait a moment for UI to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Direct database query for active shift
    try {
      final response = await Supabase.instance.client
          .from('shifts')
          .select('id')
          .eq('cashier_id', currentUser.id)
          .eq('status', 'open')
          .maybeSingle();

      _shiftCheckDone = true;

      if (response == null && mounted) {
        // No active shift - force open shift dialog
        _showMandatoryOpenShiftDialog();
      }
    } catch (e) {
      debugPrint('Error checking active shift: $e');
      _shiftCheckDone = true;
    }
  }

  // Show open shift dialog that user cannot dismiss - must open shift or logout
  Future<void> _showMandatoryOpenShiftDialog() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false, // Prevent back button
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Shift Belum Dibuka'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${currentUser.name}!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Anda harus membuka shift terlebih dahulu sebelum dapat menggunakan aplikasi kasir.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan buka shift atau logout jika tidak ingin melanjutkan.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                _logout();
              },
              child: const Text('Logout'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await _showOpenShiftDialog(context);
                // After open shift dialog closes, check if shift was opened
                try {
                  final response = await Supabase.instance.client
                      .from('shifts')
                      .select('id')
                      .eq('cashier_id', currentUser.id)
                      .eq('status', 'open')
                      .maybeSingle();

                  if (response == null && mounted) {
                    // Still no shift - show the mandatory dialog again
                    _showMandatoryOpenShiftDialog();
                  }
                } catch (e) {
                  debugPrint('Error checking shift: $e');
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Buka Shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;

    // Subscribe to orders table INSERT events
    _ordersChannel = supabase
        .channel('orders-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            _handleNewOrder(payload);
          },
        )
        .subscribe();

    debugPrint('✅ Real-time subscription active for new orders');
  }

  void _handleNewOrder(PostgresChangePayload payload) {
    debugPrint('🔔 New order received: ${payload.newRecord}');

    if (!mounted) return;

    // Extract order data
    final orderData = payload.newRecord;
    final orderId = orderData['id'] as String?;
    final displayId = orderData['display_id'] as String?;
    final totalAmount = orderData['total_amount'] as num?;

    // Show compact notification at top
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Order #${displayId ?? orderId?.substring(0, 6) ?? '?'} - Rp ${totalAmount?.toStringAsFixed(0) ?? '0'}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );

    // Trigger UI refresh if showing history
    if (_showHistory) {
      setState(() {});
    }
  }

  Future<void> _fetchTables() async {
    try {
      final tables = await OrderRepository(Supabase.instance.client).getTables();
      setState(() {
        _tables = tables;
      });
    } catch (e) {
      debugPrint('Error fetching tables: $e');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _manualTotalController.dispose();
    _ordersChannel?.unsubscribe();
    debugPrint('❌ Real-time subscription closed');
    super.dispose();
  }

  Future<void> _addToCart(Product product) async {
    List<ProductModifier> selectedModifiers = [];

    // Show selection dialog for Ramen or Drinks
    if (product.type == ProductType.RAMEN || product.type == ProductType.DRINK) {
      final result = await showDialog<List<ProductModifier>>(
        context: context,
        builder: (context) => ProductSelectionDialog(product: product),
      );
      
      if (result == null) return; // Cancelled
      selectedModifiers = result;
    }

    setState(() {
      final newItem = CartItem(product: product, selectedModifiers: selectedModifiers);
      final existingIndex = _cart.indexWhere(
        (item) => item.uniqueKey == newItem.uniqueKey && item.notes == null
      );
      
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(newItem);
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cart.remove(item);
      }
    });
  }

  void _updateCartItemNote(CartItem item, String? note) {
    setState(() {
      item.notes = (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customPrices.clear();
    });
  }

  // Get price for product based on current mode
  double _getPriceForProduct(Product product) {
    // Manual entry mode - check if custom price set
    if (_orderSource == OrderSource.MANUAL_ENTRY && _customPrices.containsKey(product.id)) {
      return _customPrices[product.id]!;
    }

    // Use finalPrice which includes promo discount if applicable
    // finalPrice = price * (1 - promoDiscountPercent / 100) when isPromo is true
    return product.finalPrice;
  }

  void _setCustomPrice(String productId, double customPrice) {
    setState(() {
      _customPrices[productId] = customPrice;
    });
  }

  double _calculateTotal() {
    if (_isOnlineFood) {
      return double.tryParse(_manualTotalController.text) ?? 0;
    }
    double total = 0;
    for (var item in _cart) {
      total += item.totalPrice;
    }
    return total;
  }

  Future<void> _showPriceEditDialog(Product product) async {
    final TextEditingController priceController = TextEditingController(
      text: _getPriceForProduct(product).toStringAsFixed(0),
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Price: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Base Price: Rp ${product.price.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom Price',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final customPrice = double.tryParse(priceController.text);
                if (customPrice != null && customPrice > 0) {
                  _setCustomPrice(product.id, customPrice);
                  Navigator.of(context).pop();
                } else {
                  _showCompactSnackBar('Invalid price', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showCompactSnackBar('Cart is empty', isError: true);
      return;
    }

    if (_orderSource == OrderSource.POS_MANUAL) {
      if (!_useTableSelector && _customerNameController.text.trim().isEmpty) {
        _showCompactSnackBar('Customer Name is required', isError: true);
        return;
      }
      if (_useTableSelector && _selectedTableId == null) {
        _showCompactSnackBar('Please select a table', isError: true);
        return;
      }
    }

    double? cashReceived;
    double? cashChange;

    if (_paymentMethod == PaymentMethod.CASH) {
      final total = _calculateTotal();
      final result = await showDialog<Map<String, double>>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final controller = TextEditingController();
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final received = double.tryParse(controller.text) ?? 0;
              final change = received - total;
              
              return AlertDialog(
                title: const Text('Pembayaran Tunai'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Tagihan: Rp ${total.toStringAsFixed(0)}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Uang Tunai Diterima',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Text('Kembalian:', style: TextStyle(color: Colors.grey[600])),
                    Text('Rp ${change < 0 ? 0 : change.toStringAsFixed(0)}', 
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: change < 0 ? Colors.red : Colors.green,
                      )),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: received < total ? null : () {
                      Navigator.pop(context, {'received': received, 'change': change});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Proses Bayar'),
                  ),
                ],
              );
            }
          );
        },
      );

      if (result == null) return; // User cancelled
      cashReceived = result['received'];
      cashChange = result['change'];
    }

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final repo = OrderRepository(Supabase.instance.client);

      // Get active shift ID
      final currentUser = ref.read(currentUserProvider);
      String? shiftId;
      if (currentUser != null) {
        // Try getting from shift state first
        final shiftState = ref.read(shiftProvider(currentUser.id));
        shiftId = shiftState.activeShift?.id;
      }

      // Create order
      final order = Order(
        id: '',
        source: _orderSource,
        type: _orderType,
        status: OrderStatus.PAID,
        paymentMethod: _paymentMethod,
        tableId: _useTableSelector ? _selectedTableId : null,
        shiftId: shiftId, // Pass shift ID here
        totalAmount: _calculateTotal(),
        pointsEarned: 0,
        pointsRedeemed: 0,
        customerName: !_useTableSelector && _customerNameController.text.trim().isNotEmpty 
            ? _customerNameController.text.trim() 
            : null,
        cashReceived: cashReceived,
        cashChange: cashChange,
        createdAt: DateTime.now(),
      );

      // Create order items with correct prices
      final items = _cart.map((cartItem) {
        return {
          'product_id': cartItem.product.id,
          'quantity': cartItem.quantity,
          // If online, save unit_price as 0
          // Constraint MUST be updated to allow 0 (chk_subtotal_non_negative)
          'unit_price': _isOnlineFood ? 0 : cartItem.unitPrice,
          'subtotal': _isOnlineFood ? 0 : cartItem.totalPrice,
          'notes': cartItem.notes,
          'selected_modifiers': cartItem.selectedModifiers.map((m) => m.toJson()).toList(),
        };
      }).toList();

      final orderId = await repo.createOrderWithItems(order, items);

      if (mounted) {
        _showCompactSnackBar('Order created!', isSuccess: true);

        // Auto print receipt
        try {
          int? tableNum;
          if (_useTableSelector && _selectedTableId != null) {
            final table = _tables.firstWhere((t) => t.id == _selectedTableId);
            tableNum = table.tableNumber;
          }

          final fullOrderData = await repo.getOrder(orderId);
          await PrintService.printReceipt(
            order: fullOrderData,
            items: items.map((e) => {
              'products': {'name': _cart.firstWhere((c) => c.product.id == e['product_id']).product.name},
              'quantity': e['quantity'],
              'unit_price': e['unit_price'],
              'notes': e['notes'],
            }).toList(),
            tableNumber: tableNum,
          );
        } catch (printErr) {
          debugPrint('Error printing receipt: $printErr');
        }

        _clearCart();
        _customerNameController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showCompactSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  Future<void> _showSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Track Order'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Enter Order ID (e.g. 01290126)',
              hintText: 'Order ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _performSearch(context, searchController.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _performSearch(context, searchController.text),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSearch(BuildContext context, String query) async {
    final orderId = query.trim();
    if (orderId.isEmpty) return;
    
    try {
      final repo = OrderRepository(Supabase.instance.client);
      
      // Try fetching by Display ID first (priority)
      Order? order = await repo.getOrderByDisplayId(orderId);
      
      // If not found, try UUID (fallback)
      if (order == null && orderId.length > 8) {
         try {
           order = await repo.getOrder(orderId);
         } catch (_) {
           // Ignore UUID error, will handle as not found
         }
      }

      if (context.mounted) {
        if (order != null) {
          Navigator.pop(context); // Close dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(order: order!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #$orderId not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showCompactSnackBar('Error searching order', isError: true);
      }
    }
  }

  // Show dialog to open a new shift
  Future<void> _showOpenShiftDialog(BuildContext context) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      _showCompactSnackBar('Please login first', isError: true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OpenShiftDialog(
        cashierId: currentUser.id,
        cashierName: currentUser.name,
      ),
    );

    if (result == true && mounted) {
      _showCompactSnackBar('Shift opened!', isSuccess: true);
    }
  }

  // Show dialog to close the current shift
  Future<void> _showCloseShiftDialog(BuildContext context, Shift shift) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShiftSummaryDialog(
        shift: shift,
        cashierName: currentUser.name,
      ),
    );

    // If result is 'logout', log the user out
    if (result == 'logout' && mounted) {
      _showCompactSnackBar('Shift ditutup. Silakan logout.', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 500));
      _logout();
    }
  }

  // Logout and return to staff login
  void _logout() {
    ref.read(authProvider.notifier).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final activeShiftAsync = currentUser != null
        ? ref.watch(activeShiftProvider(currentUser.id))
        : const AsyncValue.data(null);

    // Responsive sizing
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < 1024;
    final isSmallHeight = screenHeight < 600;
    final isLargeScreen = screenWidth > 1400;
    final isMediumScreen = screenWidth > 1024 && screenWidth <= 1400;

    // Adjust incoming orders width based on screen size
    final incomingOrdersWidth = isLargeScreen ? 320.0 : (isMediumScreen ? 280.0 : 0.0);
    final showIncomingOrders = screenWidth > 1024; // Hide on small screens

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'AI Assistant',
            pageBuilder: (context, anim1, anim2) {
              return Align(
                alignment: Alignment.centerRight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(anim1),
                  child: const AiAssistantDrawer(),
                ),
              );
            },
          );
        },
        backgroundColor: AppColors.infoBlue,
        child: const Icon(Icons.psychology, color: Colors.white, size: 30),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_collab.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(currentUser?.role == UserRole.ADMIN ? 'ADMIN DASHBOARD' : 'CASHIER DASHBOARD'),
          ],
        ),
        actions: [
          // Shift Status & Management - Only for Cashiers, Admins don't need it
          if (currentUser?.role != UserRole.ADMIN)
            activeShiftAsync.when(
              data: (activeShift) {
                if (activeShift != null) {
                  // Shift is OPEN - Show status and close button
                  return Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text(
                              'Shift Open',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Close Shift',
                        onPressed: () => _showCloseShiftDialog(context, activeShift),
                      ),
                    ],
                  );
                } else {
                  // No active shift - Show open shift button
                  return TextButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Open Shift'),
                    onPressed: () => _showOpenShiftDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  );
                }
              },
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Icon(Icons.error, color: Colors.red),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Order by ID',
            onPressed: _showSearchDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.restaurant),
            tooltip: 'Kitchen Display',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KitchenDisplayPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // User info and logout
          if (currentUser != null) ...[
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentUser.role == UserRole.ADMIN
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentUser.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              tooltip: 'Account Menu',
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        currentUser.role == UserRole.ADMIN ? 'Admin' : 'Cashier',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (currentUser.phone != null)
                        Text(
                          currentUser.phone!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Cashier menu items (not shown for admin - already on dashboard)
                if (currentUser.role != UserRole.ADMIN) ...[
                  const PopupMenuDivider(),
                  // Shift History
                  const PopupMenuItem(
                    value: 'shift_history',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 20),
                        SizedBox(width: 8),
                        Text('Riwayat Shift'),
                      ],
                    ),
                  ),
                  // Product Sales Report
                  const PopupMenuItem(
                    value: 'product_report',
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, size: 20),
                        SizedBox(width: 8),
                        Text('Laporan Produk'),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'manage_menu') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminMenuPage(),
                    ),
                  );
                } else if (value == 'shift_history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShiftHistoryPage(),
                    ),
                  );
                } else if (value == 'product_report') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductSalesReportPage(),
                    ),
                  );
                } else if (value == 'monthly_analytics') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MonthlyAnalyticsPage(),
                    ),
                  );
                } else if (value == 'storage') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StorageMainPage(),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Top: Sales Summary
          FutureBuilder<Map<String, dynamic>>(
            future: OrderRepository(Supabase.instance.client).getTodaySalesSummary(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading summary: ${snapshot.error}'),
                );
              }

              final summary = snapshot.data ?? {
                'total_sales': 0.0,
                'total_orders': 0,
                'app_orders': 0,
                'pos_orders': 0,
              };

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _SummaryBox(
                      icon: Icons.monetization_on,
                      title: 'Total Sales',
                      value: 'Rp ${(summary['total_sales'] as double).toStringAsFixed(0)}',
                      color: Colors.green,
                      width: isMobile ? (screenWidth - 72) / 2 : (screenWidth - 120) / 5,
                    ),
                    _SummaryBox(
                      icon: Icons.shopping_cart,
                      title: 'Orders',
                      value: '${summary['total_orders']}',
                      color: Colors.blue,
                      width: isMobile ? (screenWidth - 72) / 2 : (screenWidth - 120) / 5,
                    ),
                    _SummaryBox(
                      icon: Icons.phone_android,
                      title: 'App',
                      value: '${summary['app_orders']}',
                      color: Colors.orange,
                      width: isMobile ? (screenWidth - 88) / 3 : (screenWidth - 120) / 5,
                    ),
                    _SummaryBox(
                      icon: Icons.point_of_sale,
                      title: 'POS',
                      value: '${summary['pos_orders']}',
                      color: Colors.purple,
                      width: isMobile ? (screenWidth - 88) / 3 : (screenWidth - 120) / 5,
                    ),
                    _SummaryBox(
                      icon: Icons.delivery_dining,
                      title: 'Online',
                      value: '${summary['online_orders'] ?? 0}',
                      color: Colors.red.shade700,
                      width: isMobile ? (screenWidth - 88) / 3 : (screenWidth - 120) / 5,
                    ),
                  ],
                ),
              );
            },
          ),
          // Bottom: Main Content (Admin vs Cashier view)
          Expanded(
            child: currentUser?.role == UserRole.ADMIN
              // ADMIN VIEW - Quick access dashboard
              ? _buildAdminDashboard(screenWidth, isMobile)
              // CASHIER VIEW - POS Interface
              : (isMobile && isSmallHeight
                  // For small heights (landscape mobile), make the whole content scrollable
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          // Menu Section (Fixed height to allow inner scroll)
                          SizedBox(
                            height: 500,
                            child: _buildMenuSection(),
                          ),
                          // Cart Section (Stacked below menu)
                          if (_cart.isNotEmpty) _buildCartSection(isMobile, screenWidth),
                        ],
                      ),
                    )
                  // For large screens/tablets, use the side-by-side or stacked layout
                  : Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Panel: Incoming Orders (Desktop/Tablet only)
                        if (showIncomingOrders)
                          SizedBox(
                            width: incomingOrdersWidth,
                            child: _buildIncomingOrdersSection(),
                          ),

                        // Center Panel: Menu
                        Expanded(
                          flex: 3,
                          child: _buildMenuSection(),
                        ),

                        // Right Panel: Cart
                        if (!isMobile || _cart.isNotEmpty)
                          _buildCartSection(isMobile, screenWidth),
                      ],
                    )),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(double screenWidth, bool isMobile) {
    return Container(
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola menu, lihat laporan, dan pantau performa bisnis',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Quick Actions Grid
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildAdminActionCard(
                  icon: Icons.restaurant_menu,
                  title: 'Kelola Menu',
                  description: 'Tambah, edit, hapus produk',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminMenuPage()),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.assessment,
                  title: 'Laporan Produk',
                  description: 'Analisis penjualan produk',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductSalesReportPage(),
                      ),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.analytics,
                  title: 'Analytics Bulanan',
                  description: 'Dashboard performa lengkap',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthlyAnalyticsPage(),
                      ),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.inventory_2,
                  title: 'Storage & Inventory',
                  description: 'Kelola bahan baku & resep',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pushNamed(context, '/storage');
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.history,
                  title: 'Riwayat Shift',
                  description: 'Lihat rekap shift kasir',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShiftHistoryPage()),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.soup_kitchen,
                  title: 'Kitchen Display',
                  description: 'Monitor dapur real-time',
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KitchenDisplayPage(),
                      ),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
                _buildAdminActionCard(
                  icon: Icons.people,
                  title: 'Kelola User',
                  description: 'Manajemen username & password',
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementPage(),
                      ),
                    );
                  },
                  width: isMobile ? screenWidth - 48 : (screenWidth - 80) / 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    required double width,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingOrdersSection() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showHistory ? 'ORDER HISTORY' : 'INCOMING ORDERS',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  icon: Icon(_showHistory ? Icons.list : Icons.history, size: 16),
                  label: Text(_showHistory ? 'Active' : 'History', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: _showHistory 
                ? OrderRepository(Supabase.instance.client).getTodayCompletedOrdersStream()
                : OrderRepository(Supabase.instance.client).getIncomingOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showHistory ? Icons.history : Icons.shopping_basket_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showHistory ? 'No completed orders today' : 'No new orders',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!;
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderSummaryCard(
                      order: order,
                      onOrderUpdated: () => setState(() {}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Order Mode Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Text(
                  'Order Mode:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isOnlineFood 
                          ? _orderSource.name 
                          : (_orderType == OrderType.DINE_IN ? 'DINE_IN' : 'TAKEAWAY'),
                      isDense: true,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'DINE_IN',
                          child: Row(
                            children: [
                              Icon(Icons.restaurant, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Dine In'),
                            ],
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'TAKEAWAY',
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag, size: 18, color: Colors.brown),
                              SizedBox(width: 8),
                              Text('Take Away'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: OrderSource.GOFOOD.name,
                          child: Row(
                            children: [
                              Icon(Icons.delivery_dining, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              const Text('GoFood'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: OrderSource.GRABFOOD.name,
                          child: Row(
                            children: [
                              Icon(Icons.delivery_dining, size: 18, color: Colors.green[700]),
                              SizedBox(width: 8),
                              const Text('GrabFood'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: OrderSource.SHOPEEFOOD.name,
                          child: Row(
                            children: [
                              Icon(Icons.delivery_dining, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              const Text('ShopeeFood'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            if (newValue == 'DINE_IN') {
                              _orderSource = OrderSource.POS_MANUAL;
                              _orderType = OrderType.DINE_IN;
                            } else if (newValue == 'TAKEAWAY') {
                              _orderSource = OrderSource.POS_MANUAL;
                              _orderType = OrderType.TAKEAWAY;
                            } else {
                              _orderSource = OrderSource.values.byName(newValue);
                              _orderType = OrderType.TAKEAWAY;
                              _paymentMethod = PaymentMethod.QRIS;
                            }
                            _manualTotalController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ProductCategorySection(
            onProductTap: (product) => _addToCart(product),
            isOnlineFood: _isOnlineFood,
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection(bool isMobile, double screenWidth) {
    return Container(
      width: isMobile ? screenWidth : 350,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey[300]!),
          top: isMobile ? BorderSide(color: Colors.grey[300]!) : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CART',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_cart.isNotEmpty)
                  TextButton(
                    onPressed: _clearCart,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          // Cart Items List - wrapped in Expanded to prevent overflow
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Cart is empty\nTap products to add',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final cartItem = _cart[index];
                      return _buildCartItemTile(cartItem);
                    },
                  ),
          ),
          // Checkout section always visible at bottom
          if (_cart.isNotEmpty) _buildCheckoutSection(),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItem cartItem) {
    final product = cartItem.product;
    final quantity = cartItem.quantity;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!_isOnlineFood)
                      Text(
                        'Rp ${cartItem.unitPrice.toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    
                    // Display Selected Modifiers (Toppings, Broth, etc)
                    if (cartItem.selectedModifiers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          cartItem.selectedModifiers.map((m) => m.name).join(', '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Quantity Controls
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 14),
                      onPressed: () => _removeFromCart(cartItem),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 14),
                      onPressed: () => _addToCart(product),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Notes section link
          InkWell(
            onTap: () => _showCartItemDialog(cartItem),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                cartItem.notes ?? 'Add notes...',
                style: TextStyle(fontSize: 11, color: cartItem.notes != null ? Colors.orange : Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCartItemDialog(CartItem cartItem) {
    final controller = TextEditingController(text: cartItem.notes);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes for ${cartItem.product.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., No spicy'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _updateCartItemNote(cartItem, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOnlineFood) ...[
             TextField(
              controller: _manualTotalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total Revenue (Aplikasi)',
                prefixText: 'Rp ',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Customer Name
            TextField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: 'Nama Pelanggan / Nomor Meja',
                hintText: 'e.g., Budi / Meja 5',
                isDense: true,
                prefixIcon: const Icon(Icons.person, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),

            // Payment Method Selection
            const Text(
              'Metode Pembayaran:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _OptionButton(
                    label: 'TUNAI',
                    isSelected: _paymentMethod == PaymentMethod.CASH,
                    onTap: () => setState(() => _paymentMethod = PaymentMethod.CASH),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionButton(
                    label: 'QRIS',
                    isSelected: _paymentMethod == PaymentMethod.QRIS,
                    onTap: () => setState(() => _paymentMethod = PaymentMethod.QRIS),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (!_isOnlineFood)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Rp ${_calculateTotal().toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCheckingOut ? null : _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

}

class _OrderSummaryCard extends ConsumerStatefulWidget {
  final Order order;
  final VoidCallback? onOrderUpdated;

  const _OrderSummaryCard({required this.order, this.onOrderUpdated});

  @override
  ConsumerState<_OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends ConsumerState<_OrderSummaryCard> {
  int? _tableNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.tableId != null) {
      _fetchTableNumber();
    }
  }

  Future<void> _fetchTableNumber() async {
    try {
      final response = await Supabase.instance.client
          .from('tables')
          .select('table_number')
          .eq('id', widget.order.tableId!)
          .single();
      if (mounted) {
        setState(() {
          _tableNumber = response['table_number'] as int?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching table: $e');
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
                    'Total Tagihan: Rp ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}',
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
                          'Rp ${change.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}',
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

  Future<void> _confirmPayment() async {
    final Map<String, dynamic> updateData = {'status': 'PAID'};

    // If payment method is CASH, show calculator
    if (widget.order.paymentMethod == PaymentMethod.CASH) {
      final result = await _showCashPaymentDialog();
      if (result == null) return; // User cancelled

      updateData['cash_received'] = result['cashReceived'];
      updateData['cash_change'] = result['cashChange'];
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', widget.order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran dikonfirmasi!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onOrderUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _printOrderReceipt() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrderRepository(Supabase.instance.client);
      
      // Fetch latest order data (to get status and cash details if updated)
      final latestOrder = await repo.getOrder(widget.order.id);
      final itemsResponse = await repo.getOrderItemsWithProducts(widget.order.id);
      
      await PrintService.printReceipt(
        order: latestOrder,
        items: itemsResponse,
        tableNumber: _tableNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeOrder() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrderRepository(Supabase.instance.client);
      await repo.completeOrder(widget.order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan diselesaikan! ✅'),
            backgroundColor: Colors.blue,
          ),
        );
        widget.onOrderUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isPendingPayment = widget.order.status == OrderStatus.PENDING_PAYMENT;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(order: widget.order),
            ),
          );
          
          // If result is true (order completed/cancelled), verify state
          if (result == true && context.mounted) {
             widget.onOrderUpdated?.call();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${widget.order.displayId ?? widget.order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${widget.order.type.name}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Text(' • '),
                            Text(
                              'Rp ${widget.order.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPendingPayment ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPendingPayment ? 'Menunggu' : 'Lunas',
                      style: TextStyle(
                        color: isPendingPayment ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              // Table number or Customer Name (Prominent Identifiers)
              if (_tableNumber != null || widget.order.customerName != null) ...[
                const SizedBox(height: 8),
                if (_tableNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_restaurant, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'SERVE TO TABLE: $_tableNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.order.status == OrderStatus.SERVED)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'SUDAH DISAJIKAN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.order.customerName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'CALL NAME: ${widget.order.customerName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // Action Buttons
              const SizedBox(height: 12),
              Row(
                children: [
                  // Always show Print Receipt button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _printOrderReceipt,
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Cetak Nota', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  
                  // Show Confirm Payment only if pending
                  if (isPendingPayment) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _confirmPayment,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 16),
                        label: const Text('Konfirmasi Bayar', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Show Complete button if served OR if it's an online food order already paid/ready
              if (widget.order.status == OrderStatus.SERVED || 
                  ((widget.order.source == OrderSource.GOFOOD || 
                    widget.order.source == OrderSource.GRABFOOD || 
                    widget.order.source == OrderSource.SHOPEEFOOD) && 
                   (widget.order.status == OrderStatus.PAID || widget.order.status == OrderStatus.READY))) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _completeOrder,
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('Selesaikan & Arsipkan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final double width;

  const _SummaryBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
