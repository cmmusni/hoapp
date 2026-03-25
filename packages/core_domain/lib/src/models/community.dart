import 'package:json_annotation/json_annotation.dart';

part 'community.g.dart';

@JsonSerializable()
class Community {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final Map<String, dynamic>? settings;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.settings,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) =>
      _$CommunityFromJson(json);

  Map<String, dynamic> toJson() => _$CommunityToJson(this);

  String? get logoUrl => settings?['logo_url'] as String?;

  String get primaryColor =>
      settings?['brand']?['primary'] as String? ?? '#215E3F';

  String get surfaceColor =>
      settings?['brand']?['surface'] as String? ?? '#ECEFF1';
}
