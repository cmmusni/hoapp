import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads user roles and sets them in AppState after community selection.
class RoleLoader {
  static Future<void> loadRoles(BuildContext context) async {
    final appState = context.read<AppState>();
    final communityRepo = context.read<CommunityRepository>();
    final authRepo = context.read<AuthRepository>();

    final user = authRepo.currentUser;
    if (user == null || appState.activeCommunityId == null) return;

    try {
      final roles = await communityRepo.getUserRoles(user.id);
      appState.setUserRoles(roles);

      final isPlatformAdmin = await communityRepo.isPlatformAdmin();
      appState.setPlatformAdmin(isPlatformAdmin);

      // Check if user has a unit assigned
      final memberRows = await Supabase.instance.client
          .from('household_members')
          .select('unit_id')
          .eq('user_id', user.id)
          .eq('community_id', appState.activeCommunityId!)
          .limit(1);
      appState.setHasUnit((memberRows as List).isNotEmpty);
    } catch (e) {
      debugPrint('RoleLoader error: $e');
    }
  }
}
