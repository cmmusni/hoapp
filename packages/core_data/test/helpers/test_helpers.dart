import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_domain/core_domain.dart';

/// Test helpers and utilities for HOApp tests

/// Create a mock Community for testing
Community createMockCommunity({
  String? id,
  String? name,
  String? slug,
}) {
  return Community(
    id: id ?? 'test-community-id',
    name: name ?? 'Test Community',
    slug: slug ?? 'test-community',
    address: '123 Test Street',
    settings: {
      'primaryColor': '#215E3F',
      'logoUrl': 'https://example.com/logo.png',
    },
    createdAt: DateTime.now(),
  );
}

/// Create a mock Announcement for testing
Announcement createMockAnnouncement({
  String? id,
  String? communityId,
  String? title,
  bool pinned = false,
}) {
  return Announcement(
    id: id ?? 'test-announcement-id',
    communityId: communityId ?? 'test-community-id',
    title: title ?? 'Test Announcement',
    body: 'This is a test announcement body',
    pinned: pinned,
    publishAt: DateTime.now(),
    createdBy: 'test-user-id',
    createdAt: DateTime.now(),
  );
}

/// Create a mock Invoice for testing
Invoice createMockInvoice({
  String? id,
  String? communityId,
  double amount = 150.0,
  InvoiceStatus status = InvoiceStatus.unpaid,
}) {
  return Invoice(
    id: id ?? 'test-invoice-id',
    communityId: communityId ?? 'test-community-id',
    unitId: 'test-unit-id',
    category: InvoiceCategory.dues,
    currency: 'PHP',
    amount: amount,
    dueDate: DateTime.now().add(const Duration(days: 7)),
    status: status,
    createdAt: DateTime.now(),
  );
}

/// Create a mock Payment for testing
Payment createMockPayment({
  String? id,
  String? invoiceId,
  double amount = 150.0,
  PaymentStatus status = PaymentStatus.submitted,
}) {
  return Payment(
    id: id ?? 'test-payment-id',
    communityId: 'test-community-id',
    invoiceId: invoiceId ?? 'test-invoice-id',
    userId: 'test-user-id',
    amount: amount,
    method: 'gcash',
    currency: 'PHP',
    status: status,
    proofUrl: 'https://example.com/proof.jpg',
    verifiedAt: status == PaymentStatus.verified ? DateTime.now() : null,
    verifiedBy: status == PaymentStatus.verified ? 'admin-id' : null,
    postedAt: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

/// Create a mock Ticket for testing
Ticket createMockTicket({
  String? id,
  String? communityId,
  TicketType type = TicketType.general,
  TicketStatus status = TicketStatus.open,
}) {
  return Ticket(
    id: id ?? 'test-ticket-id',
    communityId: communityId ?? 'test-community-id',
    createdBy: 'test-user-id',
    type: type,
    status: status,
    createdAt: DateTime.now(),
  );
}

/// Create a mock Message for testing
Message createMockMessage({
  String? id,
  String? ticketId,
  String? body,
}) {
  return Message(
    id: id ?? 'test-message-id',
    ticketId: ticketId ?? 'test-ticket-id',
    senderUserId: 'test-user-id',
    body: body ?? 'Test message body',
    createdAt: DateTime.now(),
  );
}

/// Create a mock Violation for testing
Violation createMockViolation({
  String? id,
  String? communityId,
  ViolationStatus status = ViolationStatus.newStatus,
  bool anonymous = false,
}) {
  return Violation(
    id: id ?? 'test-violation-id',
    communityId: communityId ?? 'test-community-id',
    title: 'Test Violation',
    body: 'Test violation description',
    reporterUserId: anonymous ? null : 'test-user-id',
    status: status,
    staffNotes: null,
    createdAt: DateTime.now(),
  );
}

/// Create a mock Amenity for testing
Amenity createMockAmenity({
  String? id,
  String? communityId,
  String? name,
  int capacity = 10,
  double ratePerHour = 100.0,
}) {
  return Amenity(
    id: id ?? 'test-amenity-id',
    communityId: communityId ?? 'test-community-id',
    name: name ?? 'Test Pool',
    rules: {
      'description': 'Test pool description',
      'capacity': capacity,
      'rate_per_hour': ratePerHour,
    },
    createdAt: DateTime.now(),
  );
}

/// Create a mock AmenityBooking for testing
AmenityBooking createMockAmenityBooking({
  String? id,
  String? amenityId,
  DateTime? bookingDate,
}) {
  final date = bookingDate ?? DateTime.now().add(const Duration(days: 1));
  final start = DateTime(date.year, date.month, date.day, 9, 0);
  final end = DateTime(date.year, date.month, date.day, 11, 0);
  return AmenityBooking(
    id: id ?? 'test-booking-id',
    communityId: 'test-community-id',
    amenityId: amenityId ?? 'test-amenity-id',
    userId: 'test-user-id',
    unitId: 'test-unit-id',
    timeRange: '[$start,$end)',
    status: BookingStatus.pending,
    createdAt: DateTime.now(),
  );
}

/// Create a mock PoolAccess for testing
PoolAccessRegistration createMockPoolAccess({
  String? id,
  String? communityId,
  bool approved = false,
}) {
  return PoolAccessRegistration(
    id: id ?? 'test-pool-access-id',
    communityId: communityId ?? 'test-community-id',
    userId: 'test-user-id',
    occupantType: OccupantType.resident,
    fullName: 'John Doe',
    phone: '123-456-7890',
    email: 'test@example.com',
    emergencyContactName: 'Jane Doe',
    emergencyContactPhone: '098-765-4321',
    rulesVersion: '1.0',
    approved: approved,
    approvedBy: approved ? 'admin-id' : null,
    approvedAt: approved ? DateTime.now() : null,
    lastEditedAt: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

/// Create a mock Unit for testing
Unit createMockUnit({
  String? id,
  String? communityId,
  String? unitNo,
}) {
  return Unit(
    id: id ?? 'test-unit-id',
    communityId: communityId ?? 'test-community-id',
    unitNo: unitNo ?? '101',
    createdAt: DateTime.now(),
  );
}

/// Create a mock HouseholdMember for testing
HouseholdMember createMockHouseholdMember({
  String? id,
  String? unitId,
  String? memberName,
  MemberRole memberRole = MemberRole.primary,
}) {
  return HouseholdMember(
    id: id ?? 'test-member-id',
    communityId: 'test-community-id',
    unitId: unitId ?? 'test-unit-id',
    userId: null,
    memberName: memberName ?? 'John Doe',
    memberRole: memberRole,
    createdAt: DateTime.now(),
  );
}

/// Create a mock UserRole for testing
UserRole createMockUserRole({
  int? id,
  String? communityId,
  Role role = Role.resident,
}) {
  return UserRole(
    id: id ?? 1,
    communityId: communityId ?? 'test-community-id',
    userId: 'test-user-id',
    role: role,
    createdAt: DateTime.now(),
  );
}

/// Pump and settle with timeout to avoid hanging tests
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await tester.pumpAndSettle(timeout);
}

/// Wait for condition with timeout
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (!condition()) {
    if (DateTime.now().isAfter(endTime)) {
      throw TimeoutException('Condition not met within timeout');
    }
    await Future.delayed(pollInterval);
  }
}

/// Custom matcher for testing Supabase exceptions
class IsSupabaseException extends Matcher {
  @override
  bool matches(dynamic item, Map matchState) {
    return item is PostgrestException || item is StorageException;
  }

  @override
  Description describe(Description description) {
    return description.add('is a Supabase exception');
  }
}

Matcher isSupabaseException() => IsSupabaseException();

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
