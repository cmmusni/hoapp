import 'package:json_annotation/json_annotation.dart';

part 'pool_swimmer.g.dart';

@JsonSerializable()
class PoolSwimmer {
  final String id;

  @JsonKey(name: 'registration_id')
  final String registrationId;

  @JsonKey(name: 'full_name')
  final String fullName;

  final DateTime? birthdate;

  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  PoolSwimmer({
    required this.id,
    required this.registrationId,
    required this.fullName,
    this.birthdate,
    required this.sortOrder,
    required this.createdAt,
  });

  factory PoolSwimmer.fromJson(Map<String, dynamic> json) =>
      _$PoolSwimmerFromJson(json);

  Map<String, dynamic> toJson() => _$PoolSwimmerToJson(this);

  int? get age {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      years--;
    }
    return years;
  }
}
