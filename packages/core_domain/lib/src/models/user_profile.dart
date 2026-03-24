import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'community_id')
  final String communityId;

  @JsonKey(name: 'full_name')
  final String? fullName;

  final String? email;

  final String? phone;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  UserProfile({
    required this.userId,
    required this.communityId,
    this.fullName,
    this.email,
    this.phone,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
