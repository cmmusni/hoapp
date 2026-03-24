import 'package:json_annotation/json_annotation.dart';

part 'ticket.g.dart';

enum TicketType {
  @JsonValue('billing')
  billing,
  @JsonValue('general')
  general,
  @JsonValue('repair')
  repair,
}

enum TicketStatus {
  @JsonValue('open')
  open,
  @JsonValue('closed')
  closed,
}

@JsonSerializable()
class Ticket {
  final String id;
  
  @JsonKey(name: 'community_id')
  final String communityId;
  
  @JsonKey(name: 'unit_id')
  final String? unitId;
  
  @JsonKey(name: 'created_by')
  final String createdBy;
  
  final TicketType type;
  final TicketStatus status;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Ticket({
    required this.id,
    required this.communityId,
    this.unitId,
    required this.createdBy,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) =>
      _$TicketFromJson(json);

  Map<String, dynamic> toJson() => _$TicketToJson(this);
}

@JsonSerializable()
class Message {
  final String id;
  
  @JsonKey(name: 'ticket_id')
  final String ticketId;
  
  @JsonKey(name: 'sender_user_id')
  final String senderUserId;
  
  final String body;
  final List<dynamic>? attachments;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Message({
    required this.id,
    required this.ticketId,
    required this.senderUserId,
    required this.body,
    this.attachments,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
