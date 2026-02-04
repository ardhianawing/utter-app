import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';

// CartItem model moved to models.dart


class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addProduct(Product product, {List<ProductModifier> modifiers = const []}) {
    final newItem = CartItem(product: product, selectedModifiers: modifiers);
    
    // Check if EXACT combination already exists
    final existingIndex = state.indexWhere((item) => item.uniqueKey == newItem.uniqueKey);

    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            state[i].copyWith(quantity: state[i].quantity + 1)
          else
            state[i]
      ];
    } else {
      state = [...state, newItem];
    }
  }

  void removeProduct(String productId, {int? index}) {
    if (index != null) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i != index) state[i]
      ];
    } else {
      state = state.where((item) => item.product.id != productId).toList();
    }
  }

  void updateQuantity(String productId, int newQuantity, {int? index}) {
    if (newQuantity <= 0) {
      removeProduct(productId, index: index);
      return;
    }

    state = [
      for (int i = 0; i < state.length; i++)
        if (index != null && i == index)
          state[i].copyWith(quantity: newQuantity)
        else if (index == null && state[i].product.id == productId)
          state[i].copyWith(quantity: newQuantity)
        else
          state[i]
    ];
  }

  void updateNotes(int index, String? notes) {
    if (index < 0 || index >= state.length) return;

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(notes: notes?.trim().isEmpty ?? true ? null : notes!.trim())
        else
          state[i]
    ];
  }

  void clearCart() {
    state = [];
  }

  double get totalAmount => state.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
