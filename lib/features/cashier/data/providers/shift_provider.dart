import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../repositories/shift_repository.dart';
import 'repository_providers.dart';

// ============================================================
// SHIFT STATE PROVIDER
// ============================================================

class ShiftState {
  final Shift? activeShift;
  final bool isLoading;
  final String? error;

  ShiftState({
    this.activeShift,
    this.isLoading = false,
    this.error,
  });

  ShiftState copyWith({
    Shift? activeShift,
    bool? isLoading,
    String? error,
  }) {
    return ShiftState(
      activeShift: activeShift ?? this.activeShift,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftRepository _shiftRepository;
  final String cashierId;

  ShiftNotifier(this._shiftRepository, this.cashierId) : super(ShiftState()) {
    _loadActiveShift();
  }

  Future<void> _loadActiveShift() async {
    state = state.copyWith(isLoading: true);
    try {
      final shift = await _shiftRepository.getActiveShift(cashierId);
      state = ShiftState(activeShift: shift, isLoading: false);
    } catch (e) {
      state = ShiftState(isLoading: false, error: e.toString());
    }
  }

  Future<bool> openShift(double startingCash) async {
    state = state.copyWith(isLoading: true);
    try {
      final shift = await _shiftRepository.openShift(
        cashierId: cashierId,
        startingCash: startingCash,
      );
      state = ShiftState(activeShift: shift, isLoading: false);
      return true;
    } catch (e) {
      state = ShiftState(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> closeShift(double endingCash, {String? notes}) async {
    if (state.activeShift == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      await _shiftRepository.closeShift(
        shiftId: state.activeShift!.id,
        endingCash: endingCash,
        notes: notes,
      );
      state = ShiftState(activeShift: null, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void refresh() {
    _loadActiveShift();
  }
}

// Provider for shift state (requires cashier ID)
final shiftProvider = StateNotifierProvider.family<ShiftNotifier, ShiftState, String>(
  (ref, cashierId) {
    final shiftRepository = ref.watch(shiftRepositoryProvider);
    return ShiftNotifier(shiftRepository, cashierId);
  },
);

// Provider for shift summary
final shiftSummaryProvider = FutureProvider.family<ShiftSummary?, String>(
  (ref, shiftId) async {
    final shiftRepository = ref.watch(shiftRepositoryProvider);
    return await shiftRepository.getShiftSummary(shiftId);
  },
);

// Convenience provider to get active shift
final activeShiftProvider = Provider.family<AsyncValue<Shift?>, String>(
  (ref, cashierId) {
    final shiftState = ref.watch(shiftProvider(cashierId));

    if (shiftState.isLoading) {
      return const AsyncValue.loading();
    } else if (shiftState.error != null) {
      return AsyncValue.error(shiftState.error!, StackTrace.current);
    } else {
      return AsyncValue.data(shiftState.activeShift);
    }
  },
);
