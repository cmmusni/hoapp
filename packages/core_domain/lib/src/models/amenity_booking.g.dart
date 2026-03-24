// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amenity_booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AmenityBooking _$AmenityBookingFromJson(Map<String, dynamic> json) =>
    AmenityBooking(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      amenityId: json['amenity_id'] as String,
      userId: json['user_id'] as String,
      unitId: json['unit_id'] as String,
      timeRange: json['time_range'] as String,
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AmenityBookingToJson(AmenityBooking instance) =>
    <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'amenity_id': instance.amenityId,
      'user_id': instance.userId,
      'unit_id': instance.unitId,
      'time_range': instance.timeRange,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'pending',
  BookingStatus.confirmed: 'confirmed',
  BookingStatus.cancelled: 'cancelled',
};
