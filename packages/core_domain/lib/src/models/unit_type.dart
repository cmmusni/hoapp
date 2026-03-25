import 'package:json_annotation/json_annotation.dart';

part 'unit_type.g.dart';

@JsonSerializable()
class UnitType {
  final String id;

  @JsonKey(name: 'community_id')
  final String communityId;

  final String name;

  final String? description;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  UnitType({
    required this.id,
    required this.communityId,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory UnitType.fromJson(Map<String, dynamic> json) =>
      _$UnitTypeFromJson(json);

  Map<String, dynamic> toJson() => _$UnitTypeToJson(this);
}
