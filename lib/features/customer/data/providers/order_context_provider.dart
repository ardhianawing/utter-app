import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utter_app/features/shared/models/models.dart';

/// Order context holds information about the current order being placed
class OrderContext {
  final String? tableId;
  final int? tableNumber;
  final User? user;
  final OrderType orderType;

  OrderContext({
    this.tableId,
    this.tableNumber,
    this.user,
    this.orderType = OrderType.TAKEAWAY,
  });

  /// Check if this is a dine-in order
  bool get isDineIn => tableId != null;

  /// Check if user is logged in
  bool get isLoggedIn => user != null;

  /// Copy with method for partial updates
  OrderContext copyWith({
    String? tableId,
    int? tableNumber,
    User? user,
    OrderType? orderType,
  }) {
    return OrderContext(
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      user: user ?? this.user,
      orderType: orderType ?? this.orderType,
    );
  }

  /// Clear table information (for switching to takeaway)
  OrderContext clearTable() {
    return OrderContext(
      tableId: null,
      tableNumber: null,
      user: user,
      orderType: OrderType.TAKEAWAY,
    );
  }
}

/// StateNotifier for managing order context
class OrderContextNotifier extends StateNotifier<OrderContext> {
  OrderContextNotifier() : super(OrderContext());

  /// Set table context from QR scan
  void setTableContext(String tableId, int tableNumber) {
    state = state.copyWith(
      tableId: tableId,
      tableNumber: tableNumber,
      orderType: OrderType.DINE_IN,
    );
  }

  /// Set user information
  void setUser(User user) {
    state = state.copyWith(user: user);
  }

  /// Switch order type
  void setOrderType(OrderType type) {
    if (type == OrderType.TAKEAWAY) {
      // Clear table info when switching to takeaway
      state = state.clearTable();
    } else {
      state = state.copyWith(orderType: type);
    }
  }

  /// Clear all context for new order
  void reset() {
    state = OrderContext();
  }
}

/// Provider for order context
final orderContextProvider =
    StateNotifierProvider<OrderContextNotifier, OrderContext>((ref) {
  return OrderContextNotifier();
});
