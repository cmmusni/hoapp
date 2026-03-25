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
  String? unitNumber,
  double amount = 150.0,
  bool paid = false,
}) {
  return Invoice(
    id: id ?? 'test-invoice-id',
    communityId: communityId ?? 'test-community-id',
    unitId: 'test-unit-id',
    unitNumber: unitNumber ?? '101',
    type: 'monthly_dues',
    amount: amount,
    dueDate: DateTime.now().add(const Duration(days: 7)),
    notes: null,
    paidAt: paid ? DateTime.now() : null,
    createdAt: DateTime.now(),
  );
}

/// Create a mock Payment for testing
Payment createMockPayment({
  String? id,
  String? invoiceId,
  double amount = 150.0,
  bool verified = false,
}) {
  return Payment(
    id: id ?? 'test-payment-id',
    invoiceId: invoiceId ?? 'test-invoice-id',
    amount: amount,
    method: 'gcash',
    referenceNumber: 'REF123456',
    proofUrl: 'https://example.com/proof.jpg',
    verifiedAt: verified ? DateTime.now() : null,
    verifiedBy: verified ? 'admin-id' : null,
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
  ViolationStatus status = ViolationStatus.newViolation,
  bool anonymous = false,
}) {
  return Violation(
    id: id ?? 'test-violation-id',
    communityId: communityId ?? 'test-community-id',
    reportedBy: anonymous ? null : 'test-user-id',
    unitNumber: '101',
    description: 'Test violation description',
    location: 'Building A',
    photoUrl: null,
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
    description: 'Test pool description',
    capacity: capacity,
    ratePerHour: ratePerHour,
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
  return AmenityBooking(
    id: id ?? 'test-booking-id',
    amenityId: amenityId ?? 'test-amenity-id',
    unitId: 'test-unit-id',
    unitNumber: '101',
    bookingDate: date,
    startTime: DateTime(date.year, date.month, date.day, 9, 0),
    endTime: DateTime(date.year, date.month, date.day, 11, 0),
    totalCost: 200.0,
    createdBy: 'test-user-id',
    createdAt: DateTime.now(),
  );
}

/// Create a mock PoolAccess for testing
PoolAccess createMockPoolAccess({
  String? id,
  String? communityId,
  bool approved = false,
}) {
  return PoolAccess(
    id: id ?? 'test-pool-access-id',
    communityId: communityId ?? 'test-community-id',
    userId: 'test-user-id',
    phoneNumber: '123-456-7890',
    email: 'test@example.com',
    emergencyContactName: 'Jane Doe',
    emergencyContactRelationship: 'Spouse',
    emergencyContactPhone: '098-765-4321',
    signedDocumentUrl: null,
    approvedAt: approved ? DateTime.now() : null,
    approvedBy: approved ? 'admin-id' : null,
    createdAt: DateTime.now(),
  );
}

/// Create a mock Unit for testing
Unit createMockUnit({
  String? id,
  String? communityId,
  String? unitNumber,
}) {
  return Unit(
    id: id ?? 'test-unit-id',
    communityId: communityId ?? 'test-community-id',
    unitNumber: unitNumber ?? '101',
    floor: 1,
    ownerName: 'John Doe',
    createdAt: DateTime.now(),
  );
}

/// Create a mock HouseholdMember for testing
HouseholdMember createMockHouseholdMember({
  String? id,
  String? unitId,
  String? fullName,
  HouseholdRole role = HouseholdRole.primary,
}) {
  return HouseholdMember(
    id: id ?? 'test-member-id',
    unitId: unitId ?? 'test-unit-id',
    userId: null,
    fullName: fullName ?? 'John Doe',
    role: role,
    dateOfBirth: DateTime(1990, 1, 1),
    createdAt: DateTime.now(),
  );
}

/// Create a mock UserRole for testing
UserRole createMockUserRole({
  String? id,
  String? communityId,
  String role = 'resident',
}) {
  return UserRole(
    id: id ?? 'test-role-id',
    communityId: communityId ?? 'test-community-id',
    userId: 'test-user-id',
    role: role,
    unitId: role == 'resident' ? 'test-unit-id' : null,
    unitNumber: role == 'resident' ? '101' : null,
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
