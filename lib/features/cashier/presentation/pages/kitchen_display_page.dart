import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/providers/auth_provider.dart';

class KitchenDisplayPage extends ConsumerStatefulWidget {
  const KitchenDisplayPage({super.key});

  @override
  ConsumerState<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends ConsumerState<KitchenDisplayPage> {
  final _repository = OrderRepository(Supabase.instance.client);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_utter.png',
              height: 32,
              fit: BoxFit.contain,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Text(
              'KITCHEN DISPLAY SYSTEM',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(currentUserProvider);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        user?.name.toUpperCase() ?? 'KITCHEN STAFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        'CHEF / KITCHEN',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _TimerWidget(),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Column 1: NEW ORDERS (PAID)
          _KitchenColumn(
            title: 'NEW ORDERS',
            color: const Color(0xFFEF4444), // Red 500
            icon: Icons.new_releases,
            stream: _repository.getKitchenQueueStream(),
            statusFilter: (order) => order.status == OrderStatus.PAID,
            repository: _repository,
          ),
          
          // Column 2: PREPARING
          _KitchenColumn(
            title: 'PREPARING',
            color: const Color(0xFFF59E0B), // Amber 500
            icon: Icons.restaurant,
            stream: _repository.getKitchenQueueStream(),
            statusFilter: (order) => order.status == OrderStatus.PREPARING,
            repository: _repository,
          ),

          // Column 3: READY / PICKUP
          _KitchenColumn(
            title: 'READY TO SERVE',
            color: const Color(0xFF10B981), // Emerald 500
            icon: Icons.check_circle,
            stream: _repository.getReadyOrdersStream(),
            statusFilter: (order) => true, // Already filtered by stream
            repository: _repository,
          ),
        ],
      ),
    );
  }
}

class _TimerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _KitchenColumn extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Stream<List<Order>> stream;
  final bool Function(Order) statusFilter;
  final OrderRepository repository;

  const _KitchenColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.stream,
    required this.statusFilter,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: color.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<List<Order>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.where(statusFilter).length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Order>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final orders = snapshot.data!.where(statusFilter).toList();
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 64, color: Colors.white.withOpacity(0.05)),
                          const SizedBox(height: 16),
                          Text(
                            'NO ORDERS',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.1),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _KitchenOrderCard(
                        key: ValueKey(orders[index].id),
                        order: orders[index],
                        repository: repository,
                        accentColor: color,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenOrderCard extends StatefulWidget {
  final Order order;
  final OrderRepository repository;
  final Color accentColor;

  const _KitchenOrderCard({
    super.key,
    required this.order,
    required this.repository,
    required this.accentColor,
  });

  @override
  State<_KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<_KitchenOrderCard> {
  List<Map<String, dynamic>>? _items;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await widget.repository.getOrderItemsWithProducts(widget.order.id);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.order.timeSinceOrder;
    final isOverdue = elapsed.inMinutes >= 15;
    final isDineIn = widget.order.type == OrderType.DINE_IN;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.displayId ?? '#${widget.order.id.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isDineIn ? Icons.restaurant : Icons.shopping_bag,
                            size: 14,
                            color: isDineIn ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDineIn ? 'DINE-IN' : 'TAKEAWAY',
                            style: TextStyle(
                              color: isDineIn ? Colors.blue : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildTimerBadge(elapsed, isOverdue),
                ],
              ),
            ),
            
            // Customer Info (if any)
            if (widget.order.customerName != null || widget.order.tableId != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Row(
                  children: [
                    if (widget.order.customerName != null) ...[
                      const Icon(Icons.person, size: 16, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        widget.order.customerName!.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: Colors.white10, height: 1),
            ),

            // Items List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _items == null
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()))
                  : Column(
                      children: _items!.map((item) => _buildItemRow(item)).toList(),
                    ),
            ),

            // Order Notes
            if (widget.order.notes != null && widget.order.notes!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.order.notes!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Action Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerBadge(Duration elapsed, bool isOverdue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final qty = item['quantity'] as int;
    final name = item['products']?['name'] ?? 'Unknown';
    final notes = item['notes'] as String?;
    final selectedModifiers = item['selected_modifiers'] as List?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$qty',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                // Display Modifiers (Toppings, Broth, etc)
                if (selectedModifiers != null && selectedModifiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: selectedModifiers.map((m) {
                        final modName = m is Map ? (m['name'] ?? m['id'] ?? '') : m.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withOpacity(0.5)),
                          ),
                          child: Text(
                            modName,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (notes != null && notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '⭐ $notes',
                      style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    String label;
    IconData icon;
    Color color;
    Future<void> Function() action;

    if (widget.order.status == OrderStatus.PAID) {
      label = 'START PREPARING';
      icon = Icons.play_arrow;
      color = Colors.orange;
      action = () => widget.repository.startPreparation(widget.order.id);
    } else if (widget.order.status == OrderStatus.PREPARING) {
      label = 'MARK AS READY';
      icon = Icons.check_circle;
      color = Colors.green;
      action = () => widget.repository.markAsReady(widget.order.id);
    } else {
      label = 'MARK AS SERVED';
      icon = Icons.done_all;
      color = Colors.blue;
      action = () => widget.repository.markAsServed(widget.order.id);
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () async {
          setState(() => _isLoading = true);
          try {
            await action();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        icon: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon),
        label: Text(
          _isLoading ? 'UPDATING...' : label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }
}
