import 'package:json_annotation/json_annotation.dart';

part 'unit.g.dart';

@JsonSerializable()
class Unit {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'building_id')
  final String? buildingId;
  
  @JsonKey(name: 'unit_no')
  final String unitNo;
  
  @JsonKey(name: 'unit_type')
  final String? unitType;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Unit({
    required this.id,
    required this.communityId,
    this.buildingId,
    required this.unitNo,
    this.unitType,
    required this.createdAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  Map<String, dynamic> toJson() => _$UnitToJson(this);
  
  // Alias for UI compatibility
  String get unitNumber => unitNo;
  String? get ownerName => null; // Would need to join with profiles table
  int? get floor => null; // Not in current schema
}
