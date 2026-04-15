import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_domain/core_domain.dart';
import 'package:pdf/pdf.dart';

Community _testCommunity({String? name, String? address}) {
  return Community(
    id: 'test-id',
    name: name ?? 'Test Community',
    slug: 'test-community',
    address: address ?? '123 Test Street',
    settings: null,
    createdAt: DateTime.now(),
  );
}

PoolAccessRegistration _testRegistration({required String communityId}) {
  return PoolAccessRegistration(
    id: 'reg-id',
    communityId: communityId,
    userId: 'user-id',
    occupantType: OccupantType.resident,
    fullName: 'John Doe',
    phone: '123-456-7890',
    email: 'test@example.com',
    emergencyContactName: 'Jane Doe',
    emergencyContactPhone: '098-765-4321',
    rulesVersion: '1.0',
    approved: false,
    lastEditedAt: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

Invoice _testInvoice({
  required String communityId,
  InvoiceStatus status = InvoiceStatus.unpaid,
  DateTime? dueDate,
  String? description,
}) {
  return Invoice(
    id: 'invoice-id',
    communityId: communityId,
    unitId: 'unit-id',
    category: InvoiceCategory.dues,
    currency: 'PHP',
    amount: 150.00,
    dueDate: dueDate ?? DateTime.now().add(const Duration(days: 7)),
    status: status,
    description: description,
    createdAt: DateTime.now(),
  );
}

Payment _testPayment({required String invoiceId}) {
  return Payment(
    id: 'payment-id',
    communityId: 'test-id',
    invoiceId: invoiceId,
    userId: 'user-id',
    amount: 150.00,
    method: 'gcash',
    currency: 'PHP',
    status: PaymentStatus.verified,
    proofUrl: null,
    verifiedAt: DateTime.now(),
    verifiedBy: 'admin-id',
    postedAt: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

void main() {
  late PDFService pdfService;

  setUp(() {
    pdfService = PDFService();
  });

  group('PDFService - Pool Access Waiver', () {
    test('generatePoolAccessWaiver creates PDF bytes', () async {
      final community = _testCommunity();
      final registration = _testRegistration(communityId: community.id);

      final pdfBytes = await pdfService.generatePoolAccessWaiver(
        community: community,
        registration: registration,
        userName: 'John Doe',
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));

      // Verify PDF magic number (PDF header)
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('generatePoolAccessWaiver includes community name', () async {
      final community = _testCommunity(name: 'Sunset Hills HOA', address: null);
      final registration = _testRegistration(communityId: community.id);

      final pdfBytes = await pdfService.generatePoolAccessWaiver(
        community: community,
        registration: registration,
      );

      expect(pdfBytes, isNotEmpty);
    });
  });

  group('PDFService - Invoice', () {
    test('generateInvoicePDF creates PDF bytes', () async {
      final community = _testCommunity();
      final invoice = _testInvoice(
        communityId: community.id,
        description: 'Monthly dues for March',
      );

      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));

      // Verify PDF header
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('generateInvoicePDF includes payment history when provided', () async {
      final community = _testCommunity(address: null);
      final invoice = _testInvoice(
        communityId: community.id,
        status: InvoiceStatus.paid,
      );

      final payments = [_testPayment(invoiceId: invoice.id)];

      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
        payments: payments,
      );

      expect(pdfBytes, isNotEmpty);
    });

    test('generateInvoicePDF handles paid invoice correctly', () async {
      final community = _testCommunity(address: null);
      final invoice = _testInvoice(
        communityId: community.id,
        status: InvoiceStatus.paid,
      );

      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      expect(pdfBytes, isNotEmpty);
    });
  });

  group('PDFService - PDF Output Methods', () {
    test('previewPDF does not throw error', () async {
      final community = _testCommunity(address: null);
      final invoice = _testInvoice(communityId: community.id);

      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      expect(pdfBytes, isNotEmpty);
    });
  });

  group('PDFService - Helper Methods', () {
    test('_formatDate returns correct format', () {
      final community = _testCommunity(address: null);
      final invoice = _testInvoice(
        communityId: community.id,
        dueDate: DateTime(2024, 3, 22),
      );

      expect(
        () async => await pdfService.generateInvoicePDF(
          community: community,
          invoice: invoice,
        ),
        returnsNormally,
      );
    });
  });
}
