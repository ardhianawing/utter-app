import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/order_repository.dart';
import '../repositories/shift_repository.dart';
import '../repositories/staff_repository.dart';
import '../../../customer/data/repositories/product_repository.dart';
import '../../../storage/data/repositories/storage_repository.dart';

// ============================================================
// SUPABASE CLIENT PROVIDER
// ============================================================

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ============================================================
// REPOSITORY PROVIDERS
// ============================================================

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return OrderRepository(supabase);
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ShiftRepository(supabase);
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return StaffRepository(supabase);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProductRepository(supabase);
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return StorageRepository(supabase);
});
