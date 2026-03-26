import 'package:json_annotation/json_annotation.dart';

part 'user_role.g.dart';

enum Role {
  @JsonValue('community_admin')
  communityAdmin,
  @JsonValue('hoa_officer')
  hoaOfficer,
  @JsonValue('guard')
  guard,
  @JsonValue('resident')
  resident,
  @JsonValue('maintenance')
  maintenance,
}

@JsonSerializable()
class UserRole {
  final int id;

  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'community_id')
  final String communityId;

  final Role role;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  UserRole({
    required this.id,
    required this.userId,
    required this.communityId,
    required this.role,
    required this.createdAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) =>
      _$UserRoleFromJson(json);

  Map<String, dynamic> toJson() => _$UserRoleToJson(this);

  bool get isStaff => role == Role.communityAdmin || role == Role.hoaOfficer;

  bool get isAdmin => role == Role.communityAdmin;

  // Getters for UI compatibility
  String? get unitNumber => null; // Would need to join with units table
  String? get unitId => null; // Not in current schema
}
