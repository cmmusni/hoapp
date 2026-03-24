// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ticket _$TicketFromJson(Map<String, dynamic> json) => Ticket(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      unitId: json['unit_id'] as String?,
      createdBy: json['created_by'] as String,
      type: $enumDecode(_$TicketTypeEnumMap, json['type']),
      status: $enumDecode(_$TicketStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TicketToJson(Ticket instance) => <String, dynamic>{
      'id': instance.id,
      'community_id': instance.communityId,
      'unit_id': instance.unitId,
      'created_by': instance.createdBy,
      'type': _$TicketTypeEnumMap[instance.type]!,
      'status': _$TicketStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$TicketTypeEnumMap = {
  TicketType.billing: 'billing',
  TicketType.general: 'general',
  TicketType.repair: 'repair',
};

const _$TicketStatusEnumMap = {
  TicketStatus.open: 'open',
  TicketStatus.closed: 'closed',
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String,
      attachments: json['attachments'] as List<dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'sender_user_id': instance.senderUserId,
      'body': instance.body,
      'attachments': instance.attachments,
      'created_at': instance.createdAt.toIso8601String(),
    };
