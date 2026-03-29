import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application state management
class AppState extends ChangeNotifier {
  static const String _keyActiveCommunityId = 'active_community_id';
  static const String _keyActiveCommunitySlug = 'active_community_slug';

  String? _activeCommunityId;
  String? _activeCommunitySlug;
  Community? _activeCommunity;
  List<UserRole>? _userRoles;
  bool _isPlatformAdmin = false;
  bool _hasUnit = false;

  String? get activeCommunityId => _activeCommunityId;
  String? get activeCommunitySlug => _activeCommunitySlug;
  Community? get activeCommunity => _activeCommunity;
  List<UserRole>? get userRoles => _userRoles;
  bool get isPlatformAdmin => _isPlatformAdmin;
  bool get hasUnit => _hasUnit;

  UserRole? get activeRole {
    if (_activeCommunityId == null || _userRoles == null) return null;
    try {
      return _userRoles!.firstWhere(
        (r) => r.communityId == _activeCommunityId,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isStaff => activeRole?.isStaff ?? false;
  bool get isAdmin => activeRole?.isAdmin ?? false;
  bool get isResident => activeRole?.role == Role.resident;
  bool get isGuard => activeRole?.role == Role.guard;
  bool get isMaintenance => activeRole?.role == Role.maintenance;

  /// Plan-based feature access
  bool get isProfessional => _activeCommunity?.isProfessional ?? false;
  bool get isEnterprise => _activeCommunity?.isEnterprise ?? false;

  Future<void> setActiveCommunity(String communityId, String slug) async {
    _activeCommunityId = communityId;
    _activeCommunitySlug = slug;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveCommunityId, communityId);
    await prefs.setString(_keyActiveCommunitySlug, slug);

    notifyListeners();
  }

  Future<void> loadLastActiveCommunity() async {
    final prefs = await SharedPreferences.getInstance();
    _activeCommunityId = prefs.getString(_keyActiveCommunityId);
    _activeCommunitySlug = prefs.getString(_keyActiveCommunitySlug);

    notifyListeners();
  }

  Future<void> clearActiveCommunity() async {
    _activeCommunityId = null;
    _activeCommunitySlug = null;
    _activeCommunity = null;
    _userRoles = null;
    _hasUnit = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveCommunityId);
    await prefs.remove(_keyActiveCommunitySlug);

    notifyListeners();
  }

  void setActiveCommunityData(Community community) {
    _activeCommunity = community;
    notifyListeners();
  }

  void setUserRoles(List<UserRole> roles) {
    _userRoles = roles;
    notifyListeners();
  }

  void setPlatformAdmin(bool value) {
    _isPlatformAdmin = value;
    notifyListeners();
  }

  void setHasUnit(bool value) {
    _hasUnit = value;
    notifyListeners();
  }

  int _badgeRefreshVersion = 0;
  int get badgeRefreshVersion => _badgeRefreshVersion;

  void requestBadgeRefresh() {
    _badgeRefreshVersion++;
    notifyListeners();
  }
}
