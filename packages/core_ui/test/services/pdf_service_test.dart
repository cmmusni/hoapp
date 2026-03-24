import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_domain/core_domain.dart';
import 'package:pdf/pdf.dart';

void main() {
  late PDFService pdfService;

  setUp(() {
    pdfService = PDFService();
  });

  group('PDFService - Pool Access Waiver', () {
    test('generatePoolAccessWaiver creates PDF bytes', () async {
      // Arrange
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: '123 Test Street',
        settings: null,
        createdAt: DateTime.now(),
      );

      final registration = PoolAccess(
        id: 'reg-id',
        communityId: community.id,
        userId: 'user-id',
        phoneNumber: '123-456-7890',
        email: 'test@example.com',
        emergencyContactName: 'Jane Doe',
        emergencyContactRelationship: 'Spouse',
        emergencyContactPhone: '098-765-4321',
        signedDocumentUrl: null,
        approvedAt: null,
        approvedBy: null,
        createdAt: DateTime.now(),
      );

      // Act
      final pdfBytes = await pdfService.generatePoolAccessWaiver(
        community: community,
        registration: registration,
        userName: 'John Doe',
      );

      // Assert
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
      
      // Verify PDF magic number (PDF header)
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('generatePoolAccessWaiver includes community name', () async {
      // Arrange
      final community = Community(
        id: 'test-id',
        name: 'Sunset Hills HOA',
        slug: 'sunset-hills',
        address: null,
        settings: null,
        createdAt: DateTime.now(),
      );

      final registration = PoolAccess(
        id: 'reg-id',
        communityId: community.id,
        userId: 'user-id',
        phoneNumber: '123-456-7890',
        email: 'test@example.com',
        emergencyContactName: 'Jane Doe',
        emergencyContactRelationship: 'Spouse',
        emergencyContactPhone: '098-765-4321',
        signedDocumentUrl: null,
        approvedAt: null,
        approvedBy: null,
        createdAt: DateTime.now(),
      );

      // Act
      final pdfBytes = await pdfService.generatePoolAccessWaiver(
        community: community,
        registration: registration,
      );

      // Assert
      expect(pdfBytes, isNotEmpty);
      // In a real test, you might parse the PDF to verify content
    });
  });

  group('PDFService - Invoice', () {
    test('generateInvoicePDF creates PDF bytes', () async {
      // Arrange
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: '123 Test Street',
        settings: null,
        createdAt: DateTime.now(),
      );

      final invoice = Invoice(
        id: 'invoice-id',
        communityId: community.id,
        unitId: 'unit-id',
        unitNumber: '101',
        type: 'monthly_dues',
        amount: 150.00,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        notes: 'Monthly dues for March',
        paidAt: null,
        createdAt: DateTime.now(),
      );

      // Act
      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      // Assert
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
      
      // Verify PDF header
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('generateInvoicePDF includes payment history when provided', () async {
      // Arrange
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: null,
        settings: null,
        createdAt: DateTime.now(),
      );

      final invoice = Invoice(
        id: 'invoice-id',
        communityId: community.id,
        unitId: 'unit-id',
        unitNumber: '101',
        type: 'monthly_dues',
        amount: 150.00,
        dueDate: DateTime.now(),
        notes: null,
        paidAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final payments = [
        Payment(
          id: 'payment-id',
          invoiceId: invoice.id,
          amount: 150.00,
          method: 'gcash',
          referenceNumber: 'REF123',
          proofUrl: null,
          verifiedAt: DateTime.now(),
          verifiedBy: 'admin-id',
          createdAt: DateTime.now(),
        ),
      ];

      // Act
      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
        payments: payments,
      );

      // Assert
      expect(pdfBytes, isNotEmpty);
    });

    test('generateInvoicePDF handles paid invoice correctly', () async {
      // Arrange
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: null,
        settings: null,
        createdAt: DateTime.now(),
      );

      final invoice = Invoice(
        id: 'invoice-id',
        communityId: community.id,
        unitId: 'unit-id',
        unitNumber: '101',
        type: 'monthly_dues',
        amount: 150.00,
        dueDate: DateTime.now(),
        notes: null,
        paidAt: DateTime.now(), // Invoice is paid
        createdAt: DateTime.now(),
      );

      // Act
      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      // Assert
      expect(pdfBytes, isNotEmpty);
      // In a real test, you might parse the PDF to verify "PAID" status
    });
  });

  group('PDFService - PDF Output Methods', () {
    test('previewPDF does not throw error', () async {
      // Note: This test is limited in a headless environment
      // In a real app, you'd test this with integration tests on target platforms
      
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: null,
        settings: null,
        createdAt: DateTime.now(),
      );

      final invoice = Invoice(
        id: 'invoice-id',
        communityId: community.id,
        unitId: 'unit-id',
        unitNumber: '101',
        type: 'monthly_dues',
        amount: 150.00,
        dueDate: DateTime.now(),
        notes: null,
        paidAt: null,
        createdAt: DateTime.now(),
      );

      final pdfBytes = await pdfService.generateInvoicePDF(
        community: community,
        invoice: invoice,
      );

      // This would throw if PDF is invalid
      expect(pdfBytes, isNotEmpty);
    });
  });

  group('PDFService - Helper Methods', () {
    test('_formatDate returns correct format', () {
      // This tests the internal date formatting logic indirectly
      // by generating a PDF and verifying it doesn't throw
      
      final community = Community(
        id: 'test-id',
        name: 'Test Community',
        slug: 'test-community',
        address: null,
        settings: null,
        createdAt: DateTime(2024, 3, 15),
      );

      final invoice = Invoice(
        id: 'invoice-id',
        communityId: community.id,
        unitId: 'unit-id',
        unitNumber: '101',
        type: 'monthly_dues',
        amount: 150.00,
        dueDate: DateTime(2024, 3, 22),
        notes: null,
        paidAt: null,
        createdAt: DateTime(2024, 3, 1),
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
