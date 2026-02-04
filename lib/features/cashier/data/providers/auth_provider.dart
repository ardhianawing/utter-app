import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/models.dart';
import '../repositories/staff_repository.dart';
import 'repository_providers.dart';

// ============================================================
// AUTHENTICATION STATE
// ============================================================

class AuthState {
  final StaffProfile? currentUser;
  final bool isLoading;
  final bool isInitialCheck;
  final String? error;

  AuthState({
    this.currentUser,
    this.isLoading = false,
    this.isInitialCheck = true,
    this.error,
  });

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.role == UserRole.ADMIN;
  bool get isCashier => currentUser?.role == UserRole.CASHIER;
  bool get isKitchen => currentUser?.role == UserRole.KITCHEN;

  AuthState copyWith({
    StaffProfile? currentUser,
    bool? isLoading,
    bool? isInitialCheck,
    String? error,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      isInitialCheck: isInitialCheck ?? this.isInitialCheck,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final StaffRepository _staffRepository;

  AuthNotifier(this._staffRepository) : super(AuthState()) {
    _loadPersistedUser();
  }

  static const String _userKey = 'auth_user';

  Future<void> _loadPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        final profile = StaffProfile.fromJson(jsonDecode(userJson));
        state = state.copyWith(currentUser: profile, isInitialCheck: false);
      } catch (e) {
        prefs.remove(_userKey);
        state = state.copyWith(isInitialCheck: false);
      }
    } else {
      state = state.copyWith(isInitialCheck: false);
    }
  }

  Future<void> _persistUser(StaffProfile? profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile != null) {
      await prefs.setString(_userKey, jsonEncode(profile.toJson()));
    } else {
      await prefs.remove(_userKey);
    }
  }

  /// Login with phone and PIN
  Future<bool> login(String phone, String pin) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final profile = await _staffRepository.authenticateStaff(
        phone: phone,
        pin: pin,
      );

      if (profile == null) {
        state = AuthState(
          isLoading: false,
          error: 'Invalid phone number or PIN',
        );
        return false;
      }

      state = AuthState(
        currentUser: profile,
        isLoading: false,
      );
      await _persistUser(profile);
      return true;
    } catch (e) {
      state = AuthState(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Logout
  void logout() async {
    state = AuthState();
    await _persistUser(null);
  }

  /// Change PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    if (state.currentUser == null) return false;

    try {
      await _staffRepository.changePin(
        profileId: state.currentUser!.id,
        oldPin: oldPin,
        newPin: newPin,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Refresh current user profile info
  Future<void> refreshProfile() async {
    if (state.currentUser == null) return;

    try {
      final profile = await _staffRepository.getStaffProfile(state.currentUser!.id);
      if (profile != null) {
        state = state.copyWith(currentUser: profile);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final staffRepository = ref.watch(staffRepositoryProvider);
  return AuthNotifier(staffRepository);
});

// Convenience provider to check if user has admin access
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAdmin;
});

// Convenience provider to check if user has cashier access
final isCashierProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isCashier;
});

// Convenience provider to get current user
final currentUserProvider = Provider<StaffProfile?>((ref) {
  return ref.watch(authProvider).currentUser;
});
