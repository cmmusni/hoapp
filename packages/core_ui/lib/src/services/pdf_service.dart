import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:core_domain/core_domain.dart';

/// Service for generating PDF documents
class PDFService {
  /// Generate pool access waiver PDF
  Future<Uint8List> generatePoolAccessWaiver({
    required Community community,
    required PoolAccess registration,
    String? userName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  community.name,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'SWIMMING POOL ACCESS WAIVER',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Registration information
              pw.Text(
                'REGISTRATION INFORMATION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildInfoRow('Name:', userName ?? 'N/A'),
              // TODO: Add phoneNumber field to PoolAccessRegistration model
              // _buildInfoRow('Phone:', registration.phoneNumber),
              _buildInfoRow('Email:', registration.email),
              _buildInfoRow('Date:', _formatDate(DateTime.now())),
              pw.SizedBox(height: 20),

              // Emergency contact
              pw.Text(
                'EMERGENCY CONTACT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildInfoRow('Name:', registration.emergencyContactName),
              // TODO: Add emergencyContactRelationship field to PoolAccessRegistration model
              // _buildInfoRow('Relationship:', registration.emergencyContactRelationship),
              _buildInfoRow('Phone:', registration.emergencyContactPhone),
              pw.SizedBox(height: 20),

              // Waiver text
              pw.Text(
                'WAIVER AND RELEASE OF LIABILITY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                _getWaiverText(),
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 30),

              // Signature line
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 200,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(width: 1),
                          ),
                        ),
                        child: pw.SizedBox(height: 30),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Signature', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(width: 1),
                          ),
                        ),
                        child: pw.SizedBox(height: 30),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Date', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate invoice PDF
  Future<Uint8List> generateInvoicePDF({
    required Community community,
    required Invoice invoice,
    List<Payment>? payments,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        community.name,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (community.address != null)
                        pw.Text(community.address!, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('#${invoice.id.substring(0, 8)}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Bill to
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              // TODO: unitNumber field doesn't exist on Invoice model - use unitId instead
              // pw.Text('Unit ${invoice.unitNumber ?? 'N/A'}'),
              pw.Text('Invoice #${invoice.id.substring(0, 8)}'),
              pw.SizedBox(height: 20),

              // Invoice details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Invoice Date:', _formatDate(invoice.createdAt)),
                      _buildInfoRow('Due Date:', _formatDate(invoice.dueDate)),
                      // TODO: type doesn't exist, use category
                      // _buildInfoRow('Type:', _formatInvoiceType(invoice.type)),
                      _buildInfoRow('Category:', invoice.category.name),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      // TODO: paidAt doesn't exist, use status
                      color: invoice.status == InvoiceStatus.paid ? PdfColors.green100 : PdfColors.orange100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      invoice.status == InvoiceStatus.paid ? 'PAID' : 'UNPAID',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: invoice.status == InvoiceStatus.paid ? PdfColors.green800 : PdfColors.orange800,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Amount
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Amount Due',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₱${invoice.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // TODO: notes field doesn't exist on Invoice
              // if (invoice.notes != null) ...[
              //   pw.SizedBox(height: 20),
              //   pw.Text(
              //     'Notes',
              //     style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              //   ),
              //   pw.Text(invoice.notes!),
              // ],

              if (payments != null && payments.isNotEmpty) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'PAYMENT HISTORY',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                ...payments.map((payment) => pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      margin: const pw.EdgeInsets.only(bottom: 5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('₱${payment.amount.toStringAsFixed(2)} via ${payment.method}'),
                          pw.Text(
                            payment.verifiedAt != null ? 'Verified' : 'Pending',
                            style: pw.TextStyle(
                              color: payment.verifiedAt != null
                                  ? PdfColors.green
                                  : PdfColors.orange,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Thank you for your payment',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Preview and print PDF
  Future<void> previewPDF(Uint8List pdfBytes, String filename) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: filename,
    );
  }

  /// Share PDF
  Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  /// Save PDF to file (web download)
  Future<void> downloadPDF(Uint8List pdfBytes, String filename) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: filename,
    );
  }

  // Helper methods
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatInvoiceType(String type) {
    switch (type) {
      case 'monthly_dues':
        return 'Monthly Association Dues';
      case 'amenity_booking':
        return 'Amenity Booking Fee';
      case 'other':
        return 'Other Charges';
      default:
        return type;
    }
  }

  String _getWaiverText() {
    return '''
I, the undersigned, acknowledge that I am voluntarily participating in the use of the swimming pool facilities provided by this homeowners association. I understand and accept that swimming and the use of pool facilities involve inherent risks, including but not limited to the risk of injury or death.

In consideration of being permitted to use the swimming pool facilities, I hereby:

1. WAIVE, RELEASE, AND DISCHARGE the homeowners association, its officers, directors, employees, and agents from any and all liability, claims, demands, actions, and causes of action whatsoever arising out of or related to any loss, damage, or injury, including death, that may be sustained by me while using the pool facilities.

2. AGREE TO INDEMNIFY AND HOLD HARMLESS the homeowners association from any loss, liability, damage, or costs that may incur due to my use of the pool facilities.

3. ACKNOWLEDGE that I am in good physical condition and have no medical condition that would prevent me from safely using the pool facilities.

4. AGREE to follow all posted rules and regulations regarding the use of the pool facilities.

5. UNDERSTAND that the information provided in this registration, including emergency contact details, will be used in case of emergency.

I have read this waiver and release of liability and fully understand its contents. I voluntarily agree to the terms and conditions stated above.
''';
  }
}
