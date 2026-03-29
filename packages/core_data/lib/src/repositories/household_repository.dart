import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class HouseholdRepository {
  final SupabaseClient _client = SupabaseClientManager.instance;

  /// Get all units in a community (staff only)
  Future<List<Unit>> getUnits(String communityId) async {
    final response = await _client
        .from('units')
        .select()
        .eq('community_id', communityId)
        .order('unit_no');

    return (response as List).map((item) => Unit.fromJson(item)).toList();
  }

  /// Get total member count across all units in a community
  Future<int> getTotalMemberCount(String communityId) async {
    final response = await _client
        .from('household_members')
        .select('id')
        .eq('community_id', communityId);

    return (response as List).length;
  }

  /// Get total member count for specific unit IDs
  Future<int> getMemberCountForUnits(List<String> unitIds) async {
    if (unitIds.isEmpty) return 0;

    final response = await _client
        .from('household_members')
        .select('id')
        .inFilter('unit_id', unitIds);

    return (response as List).length;
  }

  /// Get members of a unit
  Future<List<HouseholdMember>> getHouseholdMembers(String unitId) async {
    final response = await _client
        .from('household_members')
        .select()
        .eq('unit_id', unitId)
        .order('created_at');

    final members = (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (members.isEmpty) {
      return [];
    }

    // Get user IDs to fetch profile names (filter out nulls)
    final userIds = members
        .map((m) => m['user_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toList();

    if (userIds.isNotEmpty) {
      // Fetch profiles for all user IDs
      final profilesResponse = await _client
          .from('profiles')
          .select('user_id, full_name')
          .inFilter('user_id', userIds);

      // Create a map of user_id to full_name
      final profileMap = <String, String?>{};
      for (final profile in profilesResponse as List) {
        profileMap[profile['user_id'] as String] =
            profile['full_name'] as String?;
      }

      // Merge profile names into member data
      for (final member in members) {
        final userId = member['user_id'] as String?;
        if (userId != null) {
          member['user_name'] = profileMap[userId];
        }
      }
    }

    return members.map((item) => HouseholdMember.fromJson(item)).toList();
  }

  /// Get user's household (units they belong to)
  Future<List<HouseholdMember>> getMyHouseholds(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('household_members')
        .select('*, units!inner(*)')
        .eq('user_id', userId)
        .eq('community_id', communityId);

    return (response as List)
        .map((item) => HouseholdMember.fromJson(item))
        .toList();
  }

  /// Get only the units the current user belongs to
  Future<List<Unit>> getMyUnits(String communityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('household_members')
        .select('units!inner(*)')
        .eq('user_id', userId)
        .eq('community_id', communityId);

    return (response as List)
        .map((item) => Unit.fromJson(item['units'] as Map<String, dynamic>))
        .toList();
  }

  /// Add household member (staff or unit member can add)
  /// Supports both registered users (userId) and non-registered (memberName)
  Future<String> addHouseholdMember({
    required String communityId,
    required String unitId,
    String? userId,
    String? memberName,
    MemberRole? memberRole,
    String? relationship,
  }) async {
    // Validate: must have either userId or memberName, not both
    if ((userId == null && memberName == null) ||
        (userId != null && memberName != null)) {
      throw ArgumentError('Must provide either userId or memberName, not both');
    }

    final response = await _client
        .from('household_members')
        .insert({
          'community_id': communityId,
          'unit_id': unitId,
          if (userId != null) 'user_id': userId,
          if (memberName != null) 'member_name': memberName,
          'member_role': (memberRole ?? MemberRole.member).name,
          if (relationship != null) 'relationship': relationship,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update household member role
  Future<void> updateHouseholdMember({
    required String id,
    MemberRole? memberRole,
    String? relationship,
  }) async {
    final updates = <String, dynamic>{};

    if (memberRole != null) {
      updates['member_role'] = memberRole.name;
    }
    if (relationship != null) {
      updates['relationship'] = relationship;
    }

    if (updates.isEmpty) return;

    await _client.from('household_members').update(updates).eq('id', id);
  }

  /// Remove household member (staff or primary member)
  Future<void> removeHouseholdMember(String id) async {
    await _client.from('household_members').delete().eq('id', id);
  }

  /// Create unit (staff only)
  Future<String> createUnit({
    required String communityId,
    required String unitNo,
    String? buildingId,
    String? unitType,
  }) async {
    final response = await _client
        .from('units')
        .insert({
          'community_id': communityId,
          'unit_no': unitNo,
          if (buildingId != null) 'building_id': buildingId,
          if (unitType != null) 'unit_type': unitType,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update unit
  Future<void> updateUnit(String id, Map<String, dynamic> updates) async {
    await _client.from('units').update(updates).eq('id', id);
  }

  /// Delete unit (staff only)
  Future<void> deleteUnit(String id) async {
    await _client.from('units').delete().eq('id', id);
  }

  // ============ UNIT TYPES ============

  /// Get all unit types for a community
  Future<List<UnitType>> getUnitTypes(String communityId) async {
    final response = await _client
        .from('unit_types')
        .select()
        .eq('community_id', communityId)
        .order('name');

    return (response as List).map((item) => UnitType.fromJson(item)).toList();
  }

  /// Create a unit type
  Future<String> createUnitType({
    required String communityId,
    required String name,
    String? description,
  }) async {
    final response = await _client
        .from('unit_types')
        .insert({
          'community_id': communityId,
          'name': name,
          if (description != null) 'description': description,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update a unit type
  Future<void> updateUnitType({
    required String id,
    String? name,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (updates.isEmpty) return;

    await _client.from('unit_types').update(updates).eq('id', id);
  }

  /// Delete a unit type
  Future<void> deleteUnitType(String id) async {
    await _client.from('unit_types').delete().eq('id', id);
  }
}
