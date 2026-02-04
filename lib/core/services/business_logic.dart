import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/shared/models/models.dart';

// Providers for business logic
final loyaltyProvider = Provider((ref) => LoyaltyService());

class LoyaltyService {
  int calculateLoyaltyPoints({
    required List<Map<String, dynamic>> cartItems,
    required User? user,
  }) {
    if (user == null) return 0;

    double totalPoints = 0;

    for (var item in cartItems) {
      final bool isFeaturedIxon = item['product'].isFeaturedIxon;
      final double multiplier = isFeaturedIxon ? 2.0 : 1.0;
      
      // Assume points = 1% of subtotal * multiplier
      final double itemPoints = (item['subtotal'] / 100) * multiplier;
      totalPoints += itemPoints;
    }

    // Apply tier bonus
    if (user.tierLevel == UserTier.IXON_ELITE) {
      totalPoints *= 1.2;
    }

    return totalPoints.round();
  }
}

class OrderService {
  // In a real app, this would interact with Supabase
  Future<String> submitOrder({
    required List<Map<String, dynamic>> cartItems,
    required User? user,
    required OrderType orderType,
    required String? tableId,
    required PaymentMethod paymentMethod,
    required OrderSource source,
  }) async {
    // 1. Validate stock (mock)
    // 2. Calculate totals
    // 3. Create order in DB (mock)
    // 4. Return order ID
    await Future.delayed(const Duration(seconds: 2));
    return 'ORDER-${DateTime.now().millisecondsSinceEpoch}';
  }
}

final orderServiceProvider = Provider((ref) => OrderService());
