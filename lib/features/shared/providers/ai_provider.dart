import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utter_app/core/services/ai_service.dart';
import 'package:utter_app/features/customer/data/repositories/product_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/order_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/shift_repository.dart';
import 'package:utter_app/features/storage/data/repositories/storage_repository.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final supabase = Supabase.instance.client;
  return AiService(
    ProductRepository(supabase),
    OrderRepository(supabase),
    ShiftRepository(supabase),
    StorageRepository(supabase),
  );
});

final aiChatHistoryProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final aiIsLoadingProvider = StateProvider<bool>((ref) => false);
