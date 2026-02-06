import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';

class StaffRepository {
  final SupabaseClient _supabase;

  StaffRepository(this._supabase);

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  /// Authenticate staff member using username/phone and PIN
  Future<StaffProfile?> authenticateStaff({
    required String identifier,
    required String pin,
  }) async {
    try {
      // Try to find user by username first, then by phone
      var response = await _supabase
          .from('profiles')
          .select()
          .eq('username', identifier)
          .eq('pin', pin)
          .eq('is_active', true)
          .maybeSingle();

      // If not found by username, try by phone
      if (response == null) {
        response = await _supabase
            .from('profiles')
            .select()
            .eq('phone', identifier)
            .eq('pin', pin)
            .eq('is_active', true)
            .maybeSingle();
      }

      if (response == null) return null;

      return StaffProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to authenticate staff: $e');
    }
  }

  /// Get staff profile by ID
  Future<StaffProfile?> getStaffProfile(String profileId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', profileId)
          .single();

      return StaffProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get staff profile: $e');
    }
  }

  /// Get all staff members (for admin)
  Future<List<StaffProfile>> getAllStaff() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => StaffProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get staff list: $e');
    }
  }

  /// Get all cashiers (for shift assignment)
  Future<List<StaffProfile>> getAllCashiers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'cashier')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => StaffProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get cashiers: $e');
    }
  }

  // ============================================================
  // STAFF MANAGEMENT (Admin Only)
  // ============================================================

  /// Create a new staff profile
  Future<StaffProfile> createStaffProfile({
    required String name,
    required UserRole role,
    required String phone,
    required String pin,
  }) async {
    try {
      final response = await _supabase
          .from('profiles')
          .insert({
            'name': name,
            'role': role.toString().split('.').last.toLowerCase(),
            'phone': phone,
            'pin': pin,
            'is_active': true,
          })
          .select()
          .single();

      return StaffProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create staff profile: $e');
    }
  }

  /// Update staff profile
  Future<void> updateStaffProfile({
    required String profileId,
    String? name,
    UserRole? role,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (role != null) updateData['role'] = role.toString().split('.').last.toLowerCase();
      if (phone != null) updateData['phone'] = phone;
      if (pin != null) updateData['pin'] = pin;
      if (isActive != null) updateData['is_active'] = isActive;

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', profileId);
    } catch (e) {
      throw Exception('Failed to update staff profile: $e');
    }
  }

  /// Deactivate staff member (soft delete)
  Future<void> deactivateStaff(String profileId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_active': false})
          .eq('id', profileId);
    } catch (e) {
      throw Exception('Failed to deactivate staff: $e');
    }
  }

  /// Activate staff member
  Future<void> activateStaff(String profileId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_active': true})
          .eq('id', profileId);
    } catch (e) {
      throw Exception('Failed to activate staff: $e');
    }
  }

  /// Change PIN for staff member
  Future<void> changePin({
    required String profileId,
    required String oldPin,
    required String newPin,
  }) async {
    try {
      // Verify old PIN first
      final response = await _supabase
          .from('profiles')
          .select('pin')
          .eq('id', profileId)
          .single();

      if (response['pin'] != oldPin) {
        throw Exception('Invalid old PIN');
      }

      // Update to new PIN
      await _supabase
          .from('profiles')
          .update({'pin': newPin})
          .eq('id', profileId);
    } catch (e) {
      throw Exception('Failed to change PIN: $e');
    }
  }
}
