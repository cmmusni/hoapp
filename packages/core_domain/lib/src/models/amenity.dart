import 'package:json_annotation/json_annotation.dart';

part 'amenity.g.dart';

@JsonSerializable()
class Amenity {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  final String name;
  final Map<String, dynamic>? rules;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Amenity({
    required this.id,
    required this.communityId,
    required this.name,
    this.rules,
    required this.createdAt,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) =>
      _$AmenityFromJson(json);

  Map<String, dynamic> toJson() => _$AmenityToJson(this);

  int? get price => rules?['price'] as int?;
  String? get currency => rules?['currency'] as String?;
  String? get openTime => rules?['open'] as String?;
  String? get closeTime => rules?['close'] as String?;
  bool get allowSameDay => rules?['allow_same_day'] as bool? ?? true;
  int get maxDaysAhead => rules?['max_days_ahead'] as int? ?? 60;
  
  // Additional getters for UI compatibility
  int? get capacity => rules?['capacity'] as int?;
  double? get ratePerHour => (rules?['rate_per_hour'] as num?)?.toDouble();
  String? get description => rules?['description'] as String?;
}
