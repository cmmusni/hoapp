import 'package:json_annotation/json_annotation.dart';

part 'household_member.g.dart';

enum MemberRole {
  @JsonValue('primary')
  primary,
  @JsonValue('member')
  member,
  @JsonValue('child')
  child,
  @JsonValue('tenant')
  tenant,
  @JsonValue('other')
  other,
}

@JsonSerializable()
class HouseholdMember {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'unit_id')
  final String unitId;
  
  @JsonKey(name: 'user_id')
  final String? userId;
  
  @JsonKey(name: 'member_name')
  final String? memberName;
  
  @JsonKey(name: 'member_role')
  final MemberRole memberRole;
  
  final String? relationship;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  // Joined from profiles table (for registered users)
  @JsonKey(name: 'user_name')
  final String? userName;

  // Computed: returns memberName for non-registered, userName for registered
  String get displayName => memberName ?? userName ?? 'Unknown';

  HouseholdMember({
    required this.id,
    required this.communityId,
    required this.unitId,
    this.userId,
    this.memberName,
    required this.memberRole,
    this.relationship,
    required this.createdAt,
    this.userName,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      _$HouseholdMemberFromJson(json);

  Map<String, dynamic> toJson() => _$HouseholdMemberToJson(this);
  
  // Alias for UI compatibility
  MemberRole get role => memberRole;
  String? get fullName => null; // Would need to join with profiles table
  DateTime? get dateOfBirth => null; // Not in current schema
}
