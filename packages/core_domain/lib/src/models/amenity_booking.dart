import 'package:json_annotation/json_annotation.dart';

part 'amenity_booking.g.dart';

enum BookingStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable()
class AmenityBooking {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'amenity_id')
  final String amenityId;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  @JsonKey(name: 'unit_id')
  final String unitId;
  
  @JsonKey(name: 'time_range')
  final String timeRange;
  
  final BookingStatus status;
  final String? notes;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  AmenityBooking({
    required this.id,
    required this.communityId,
    required this.amenityId,
    required this.userId,
    required this.unitId,
    required this.timeRange,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory AmenityBooking.fromJson(Map<String, dynamic> json) =>
      _$AmenityBookingFromJson(json);

  Map<String, dynamic> toJson() => _$AmenityBookingToJson(this);
  
  // Computed properties for UI compatibility
  DateTime? get bookingDate {
    // Parse timeRange which is a tstzrange like '[2024-01-01 08:00,2024-01-01 17:00)'
    final match = RegExp(r'\[(\d{4}-\d{2}-\d{2})').firstMatch(timeRange);
    if (match != null) {
      return DateTime.tryParse(match.group(1)!);
    }
    return null;
  }
  
  DateTime? get startTime {
    final match = RegExp(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})').firstMatch(timeRange);
    if (match != null) {
      return DateTime.tryParse(match.group(1)!);
    }
    return null;
  }
  
  DateTime? get endTime {
    final match = RegExp(r',(\d{4}-\d{2}-\d{2} \d{2}:\d{2})').firstMatch(timeRange);
    if (match != null) {
      return DateTime.tryParse(match.group(1)!);
    }
    return null;
  }
  
  String? get unitNumber => null; // Would need to join with units table
}
