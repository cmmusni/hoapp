import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
                      pw.Text('Signature',
                          style: const pw.TextStyle(fontSize: 10)),
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
                        pw.Text(community.address!,
                            style: const pw.TextStyle(fontSize: 10)),
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
                      _buildInfoRow(
                          'Invoice Date:', _formatDate(invoice.createdAt)),
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
                      color: invoice.status == InvoiceStatus.paid
                          ? PdfColors.green100
                          : PdfColors.orange100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      invoice.status == InvoiceStatus.paid ? 'PAID' : 'UNPAID',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: invoice.status == InvoiceStatus.paid
                            ? PdfColors.green800
                            : PdfColors.orange800,
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
                          pw.Text(
                              '₱${payment.amount.toStringAsFixed(2)} via ${payment.method}'),
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
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Official Receipt (OR) PDF using the community's template config.
  ///
  /// Template style is determined by [styleOverride] if provided, otherwise
  /// by `community.settings['or_template']['style']`:
  /// - `'detailed'` (default) – full billing statement with info tables and line items
  /// - `'acknowledgement'` – simple checkbox-style receipt (like Elevé physical form)
  Future<Uint8List> generateOfficialReceipt({
    required Community community,
    required Invoice invoice,
    required List<InvoiceLineItem> lineItems,
    required String unitNo,
    String? ownerName,
    String? preparedBy,
    String? approvedBy,
    String? receivedBy,
    String? arNumber,
    String? paymentType,
    String? logoUrl,
    String? styleOverride,
  }) async {
    final orConfig = community.orTemplate;
    final effectiveStyle = styleOverride ?? orConfig.style;

    // Fetch logo bytes from URL if provided
    Uint8List? logoBytes;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoBytes = response.bodyBytes;
        }
      } catch (_) {}
    }

    // Route to the appropriate template style
    if (effectiveStyle == 'acknowledgement') {
      return _buildAcknowledgementReceipt(
        community: community,
        orConfig: orConfig,
        invoice: invoice,
        lineItems: lineItems,
        unitNo: unitNo,
        ownerName: ownerName,
        receivedBy: receivedBy,
        arNumber: arNumber,
        paymentType: paymentType,
        logoBytes: logoBytes,
      );
    }

    // ── Detailed billing statement style (default) ──
    final pdf = pw.Document();
    final currencyFmt = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('MMMM d, yyyy');
    final shortDateFmt = DateFormat('d-MMM-yy');

    final brandGreen = PdfColor.fromHex(community.primaryColor);
    final lightGrey = PdfColor.fromHex('#E8E8E8');
    final borderColor = PdfColors.grey400;
    const bw = 0.5; // border width

    // Category title — for multi-category, use description or "BILLING STATEMENT"
    String categoryTitle;
    final hasMultipleCategories =
        lineItems.isNotEmpty && lineItems.any((i) => i.category != null);
    if (hasMultipleCategories) {
      // Check if any line item is water
      final hasWater = lineItems.any((i) => i.category == 'water');
      if (hasWater) {
        categoryTitle = 'WATER BILLING';
      } else {
        categoryTitle =
            invoice.description?.toUpperCase() ?? 'BILLING STATEMENT';
      }
    } else {
      switch (invoice.category) {
        case InvoiceCategory.water:
          categoryTitle = 'WATER BILLING';
          break;
        case InvoiceCategory.dues:
          categoryTitle = 'MONTHLY DUES';
          break;
        case InvoiceCategory.amenity:
          categoryTitle = 'AMENITY BILLING';
          break;
        case InvoiceCategory.insurance:
          categoryTitle = 'INSURANCE BILLING';
          break;
        default:
          categoryTitle = 'BILLING STATEMENT';
      }
    }

    // Extract water-specific metadata if present
    final meta = invoice.metadata ?? {};
    final previousReading = meta['previous_reading']?.toString();
    final presentReading = meta['present_reading']?.toString();
    final consumption = meta['consumption']?.toString();
    final dateOfReading = meta['date_of_reading'] as String?;
    final previousBalance = meta['previous_balance'];

    // Styles
    final boldS = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
    final normalS = const pw.TextStyle(fontSize: 7);
    final smallS = const pw.TextStyle(fontSize: 6.5);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          final w = <pw.Widget>[];

          // ═══════════════════════════════════
          // HEADER: Logo area + Date
          // ═══════════════════════════════════
          w.add(pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Community logo + name
              if (logoBytes != null)
                pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 40,
                  fit: pw.BoxFit.contain,
                )
              else
                pw.Text(
                  community.name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: brandGreen,
                    letterSpacing: 2,
                  ),
                ),
              pw.Spacer(),
              // Right: Date
              pw.Text(
                'Date: ${dateFmt.format(invoice.createdAt)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: brandGreen,
                ),
              ),
            ],
          ));

          w.add(pw.SizedBox(height: 4));

          // Centered billing title
          w.add(pw.Center(
            child: pw.Text(
              categoryTitle,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ));

          w.add(pw.SizedBox(height: 4));

          // ═══════════════════════════════════
          // INFO TABLE (6 columns)
          // ═══════════════════════════════════
          final infoRows = <pw.TableRow>[];

          // Determine if this invoice has water billing content
          final isWaterInvoice = invoice.category == InvoiceCategory.water ||
              (hasMultipleCategories &&
                  lineItems.any((i) => i.category == 'water'));

          // For multi-category with water, find the water line item's period
          InvoiceLineItem? waterLineEntry;
          if (hasMultipleCategories) {
            final wItems =
                lineItems.where((i) => i.category == 'water').toList();
            if (wItems.isNotEmpty) waterLineEntry = wItems.first;
          }

          // Row 1: Owner | name | Date of Reading | date | Payment Due Date | date
          infoRows.add(pw.TableRow(children: [
            _tc('Owner', bold: true, bg: lightGrey),
            _tc(ownerName ?? '-'),
            _tc(dateOfReading != null ? 'Date of Reading' : 'Invoice Date',
                bold: true, bg: lightGrey),
            _tc(dateOfReading ?? shortDateFmt.format(invoice.createdAt)),
            _tc('Payment Due\nDate', bold: true, bg: lightGrey),
            _tc(shortDateFmt.format(invoice.dueDate)),
          ]));

          // Row 2: Unit No. | no | Previous Reading | val | Present Reading | val
          if (isWaterInvoice && previousReading != null) {
            infoRows.add(pw.TableRow(children: [
              _tc('Unit No.', bold: true, bg: lightGrey),
              _tc(unitNo),
              _tc('Previous Reading', bold: true, bg: lightGrey),
              _tc(previousReading, align: pw.TextAlign.right),
              _tc('Present Reading', bold: true, bg: lightGrey),
              _tc(presentReading ?? '-', align: pw.TextAlign.right),
            ]));
          } else {
            infoRows.add(pw.TableRow(children: [
              _tc('Unit No.', bold: true, bg: lightGrey),
              _tc(unitNo),
              _tc('Category', bold: true, bg: lightGrey),
              _tc(hasMultipleCategories
                  ? (invoice.description ?? _categoryName(invoice.category))
                  : _categoryName(invoice.category)),
              _tc('Status', bold: true, bg: lightGrey),
              _tc(invoice.status == InvoiceStatus.paid
                  ? 'PAID'
                  : invoice.isOverdue
                      ? 'OVERDUE'
                      : 'UNPAID'),
            ]));
          }

          // Row 3: Period Covered | dates | Consumption | val | Amount | val
          // Use water line item period if available, else invoice period
          final effectivePeriodStart =
              waterLineEntry?.periodStart ?? invoice.periodStart;
          final effectivePeriodEnd =
              waterLineEntry?.periodEnd ?? invoice.periodEnd;

          if (effectivePeriodStart != null && effectivePeriodEnd != null) {
            final periodStr =
                '${DateFormat('MMM d').format(effectivePeriodStart)} to ${DateFormat('MMM d, yyyy').format(effectivePeriodEnd)}';

            if (isWaterInvoice && consumption != null) {
              // Water-specific: show consumption & amount in reading row
              final waterAmt = waterLineEntry?.amount ?? invoice.amount;
              final waterAmount = meta['water_amount']?.toString() ??
                  currencyFmt.format(waterAmt);
              infoRows.add(pw.TableRow(children: [
                _tc('Period Covered', bold: true, bg: lightGrey),
                _tc(periodStr),
                _tc('Consumption', bold: true, bg: lightGrey),
                _tc(consumption, align: pw.TextAlign.right),
                _tc('Amount', bold: true, bg: lightGrey),
                _tc(waterAmount, align: pw.TextAlign.right),
              ]));
            } else {
              infoRows.add(pw.TableRow(children: [
                _tc('Period Covered', bold: true, bg: lightGrey),
                _tc(periodStr),
                _tc('Month', bold: true, bg: lightGrey),
                _tc(DateFormat('MMMM').format(effectivePeriodStart)),
                _tc(''),
                _tc(''),
              ]));
            }
          }

          // Row 4: Month (for water) or empty
          if (isWaterInvoice &&
              effectivePeriodStart != null &&
              consumption != null) {
            infoRows.add(pw.TableRow(children: [
              _tc('Month', bold: true, bg: lightGrey),
              _tc(DateFormat('MMMM').format(effectivePeriodStart)),
              _tc(''),
              _tc(''),
              _tc(''),
              _tc(''),
            ]));
          }

          // Row 5: Previous Balance | | Total Amount | | | amount
          if (isWaterInvoice) {
            final prevBal = previousBalance != null
                ? currencyFmt.format((previousBalance as num).toDouble())
                : '';
            // Find water sub-total from line items or use invoice amount
            final waterTotal = waterLineEntry?.amount ??
                lineItems
                    .where((i) =>
                        i.label.toLowerCase().contains('water') ||
                        i.category == 'water')
                    .fold<double>(0, (s, i) => s + i.amount);
            final waterSubTotal = waterTotal > 0 ? waterTotal : invoice.amount;

            infoRows.add(pw.TableRow(children: [
              _tc('Previous Balance', bold: true, bg: lightGrey),
              _tc(prevBal),
              _tc('Total Amount', bold: true, bg: lightGrey),
              _tc(''),
              _tc(''),
              _tc(currencyFmt.format(waterSubTotal),
                  align: pw.TextAlign.right, bold: true),
            ]));
          }

          w.add(pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: bw),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(0.8),
            },
            children: infoRows,
          ));

          w.add(pw.SizedBox(height: 8));

          // ═══════════════════════════════════
          // LINE ITEMS / BILLING DETAILS
          // ═══════════════════════════════════
          if (lineItems.isNotEmpty) {
            // Check if line items have category data (multi-category invoices)
            final hasCategories = lineItems.any((i) => i.category != null);

            if (hasCategories) {
              // Group line items by category
              final waterItems =
                  lineItems.where((i) => i.category == 'water').toList();
              final duesItems =
                  lineItems.where((i) => i.category == 'dues').toList();
              final otherCatItems = lineItems
                  .where((i) => i.category != 'water' && i.category != 'dues')
                  .toList();

              // WATER section: show water amount in info table style
              if (waterItems.isNotEmpty) {
                final waterTotal =
                    waterItems.fold<double>(0, (s, i) => s + i.amount);
                final wItem = waterItems.first;
                final wPeriod = (wItem.periodStart != null &&
                        wItem.periodEnd != null)
                    ? '${DateFormat('MMM d').format(wItem.periodStart!)} to ${DateFormat('MMM d, yyyy').format(wItem.periodEnd!)}'
                    : '';

                // If there's water metadata on invoice, show readings table
                if (consumption != null && previousReading != null) {
                  // Already shown in the main info table above
                } else if (wPeriod.isNotEmpty) {
                  // Show a simple water info row
                  w.add(pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: bw),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.3),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.3),
                      3: const pw.FlexColumnWidth(0.8),
                    },
                    children: [
                      pw.TableRow(children: [
                        _tc('Water Period', bold: true, bg: lightGrey),
                        _tc(wPeriod),
                        _tc('Water Amount', bold: true, bg: lightGrey),
                        _tc(currencyFmt.format(waterTotal),
                            align: pw.TextAlign.right, bold: true),
                      ]),
                    ],
                  ));
                  w.add(pw.SizedBox(height: 4));
                }
              }

              // MONTHLY DUES section
              if (duesItems.isNotEmpty) {
                w.add(pw.Center(
                  child: pw.Text(
                    'MONTHLY DUES',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ));
                w.add(pw.SizedBox(height: 3));

                final duesRows = <pw.TableRow>[];
                for (final item in duesItems) {
                  final desc = item.description ?? 'Monthly dues';
                  final periodStr = (item.periodStart != null &&
                          item.periodEnd != null)
                      ? '${shortDateFmt.format(item.periodStart!)} - ${shortDateFmt.format(item.periodEnd!)}'
                      : '';
                  duesRows.add(pw.TableRow(children: [
                    _tc(desc),
                    _tc(periodStr),
                    _tc('Monthly dues'),
                    _tc(currencyFmt.format(item.amount),
                        align: pw.TextAlign.right),
                  ]));
                }

                w.add(pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: bw),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: duesRows,
                ));
                w.add(pw.SizedBox(height: 4));
              }

              // Other category items (amenity, insurance, other)
              if (otherCatItems.isNotEmpty) {
                for (final item in otherCatItems) {
                  final catName = _categoryName(
                    InvoiceCategory.values.firstWhere(
                      (c) => c.name == item.category,
                      orElse: () => InvoiceCategory.other,
                    ),
                  );
                  w.add(pw.Center(
                    child: pw.Text(
                      catName.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ));
                  w.add(pw.SizedBox(height: 3));

                  final periodStr = (item.periodStart != null &&
                          item.periodEnd != null)
                      ? '${shortDateFmt.format(item.periodStart!)} - ${shortDateFmt.format(item.periodEnd!)}'
                      : '';
                  w.add(pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: bw),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(children: [
                        _tc(item.description ?? catName),
                        _tc(periodStr),
                        _tc(currencyFmt.format(item.amount),
                            align: pw.TextAlign.right),
                      ]),
                    ],
                  ));
                  w.add(pw.SizedBox(height: 4));
                }
              }
            } else {
              // Legacy layout: separate water vs dues by label keywords
              final waterItems = <InvoiceLineItem>[];
              final otherItems = <InvoiceLineItem>[];
              for (final item in lineItems) {
                final lbl = item.label.toLowerCase();
                if (lbl.contains('water') ||
                    lbl.contains('reading') ||
                    lbl.contains('consumption')) {
                  waterItems.add(item);
                } else {
                  otherItems.add(item);
                }
              }

              if (otherItems.isNotEmpty) {
                w.add(pw.Center(
                  child: pw.Text(
                    'MONTHLY DUES',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ));
                w.add(pw.SizedBox(height: 3));

                final duesRows = <pw.TableRow>[];
                for (final item in otherItems) {
                  duesRows.add(pw.TableRow(children: [
                    _tc(item.label),
                    _tc(''),
                    _tc(''),
                    _tc(currencyFmt.format(item.amount),
                        align: pw.TextAlign.right),
                  ]));
                  if (item.metadata != null &&
                      item.metadata!['detail'] != null) {
                    duesRows.add(pw.TableRow(children: [
                      _tc('  ${item.metadata!['detail']}',
                          fontSize: 8, textColor: PdfColors.grey600),
                      _tc(''),
                      _tc(''),
                      _tc(''),
                    ]));
                  }
                }

                w.add(pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: bw),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: duesRows,
                ));
              } else {
                w.add(pw.Center(
                  child: pw.Text(
                    'DETAILS',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ));
                w.add(pw.SizedBox(height: 3));

                final rows = <pw.TableRow>[];
                for (final item in lineItems) {
                  rows.add(pw.TableRow(children: [
                    _tc(item.label),
                    _tc(currencyFmt.format(item.amount),
                        align: pw.TextAlign.right),
                  ]));
                }
                w.add(pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: bw),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: rows,
                ));
              }
            }
          }

          // ── Notes ──
          if (invoice.notes != null && invoice.notes!.isNotEmpty) {
            w.add(pw.SizedBox(height: 4));
            w.add(pw.Text('Others:', style: boldS));
            w.add(pw.Text(invoice.notes!, style: normalS));
          }

          w.add(pw.SizedBox(height: 6));

          // ═══════════════════════════════════
          // TOTAL PAYMENT
          // ═══════════════════════════════════
          w.add(pw.Row(
            children: [
              pw.Text(
                'Total Payment',
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 24),
              pw.Text(
                currencyFmt.format(invoice.amount),
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ));

          w.add(pw.SizedBox(height: 6));
          w.add(pw.Divider(color: borderColor, thickness: 0.5));
          w.add(pw.SizedBox(height: 4));

          // ═══════════════════════════════════
          // PAYMENT INSTRUCTIONS
          // ═══════════════════════════════════
          if (orConfig.paymentInstructions != null) {
            w.add(pw.Text(orConfig.paymentInstructions!, style: smallS));
          } else {
            w.add(pw.Text(
              'Please make check payable to ${community.name} / Bank transfer to:',
              style: smallS,
            ));
            w.add(pw.Text('   Account no:', style: smallS));
            w.add(pw.Text(
              'For bank transfer please provide proof of payment',
              style: smallS,
            ));
          }

          w.add(pw.SizedBox(height: 10));

          // ═══════════════════════════════════
          // SIGNATURE LINES
          // ═══════════════════════════════════
          final sigWidgets = <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(orConfig.signatureLabel, style: normalS),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: 180,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                    ),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(preparedBy ?? '', style: boldS),
                    ),
                  ),
                ],
              ),
            ),
          ];
          if (orConfig.secondSignatureLabel != null) {
            sigWidgets.add(
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(orConfig.secondSignatureLabel!, style: normalS),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      width: 180,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                      ),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(approvedBy ?? '', style: boldS),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          w.add(pw.Row(children: sigWidgets));

          w.add(pw.Spacer());

          // Footer
          w.add(pw.Divider(color: PdfColors.grey300));
          w.add(pw.Center(
            child: pw.Text(
              '${community.name} • Generated on ${dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ));

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: w,
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build a simple acknowledgement receipt matching a physical receipt pad
  /// layout (like the Elevé Homes form in the image).
  Future<Uint8List> _buildAcknowledgementReceipt({
    required Community community,
    required ORTemplateConfig orConfig,
    required Invoice invoice,
    required List<InvoiceLineItem> lineItems,
    required String unitNo,
    String? ownerName,
    String? receivedBy,
    String? arNumber,
    String? paymentType,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final currencyFmt = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('MMMM d, yyyy');
    final brandColor = PdfColor.fromHex(community.primaryColor);
    final borderColor = PdfColors.grey400;

    // Map invoice category to the matching payment category label
    String invoiceCategoryLabel;
    switch (invoice.category) {
      case InvoiceCategory.water:
        invoiceCategoryLabel = 'Water Bill';
        break;
      case InvoiceCategory.dues:
        invoiceCategoryLabel = 'Monthly dues';
        break;
      case InvoiceCategory.amenity:
        invoiceCategoryLabel = 'Pool Reservation';
        break;
      default:
        invoiceCategoryLabel = 'Others';
    }

    // Determine billing month
    final billingMonth = invoice.periodStart != null
        ? DateFormat('MMMM').format(invoice.periodStart!)
        : DateFormat('MMMM').format(invoice.dueDate);

    // Determine "Others" description if category is other/insurance
    String? othersDescription;
    if (invoice.category == InvoiceCategory.other ||
        invoice.category == InvoiceCategory.insurance) {
      othersDescription =
          invoice.description ?? _categoryName(invoice.category).toUpperCase();
    }

    // Receipt ID — use user-supplied AR number or fall back to invoice ID
    final receiptId = arNumber ?? invoice.id.substring(0, 8).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── HEADER: Logo centered ──
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (logoBytes != null)
                        pw.Image(
                          pw.MemoryImage(logoBytes),
                          height: 50,
                          fit: pw.BoxFit.contain,
                        )
                      else
                        pw.Text(
                          community.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: brandColor,
                            letterSpacing: 3,
                          ),
                        ),
                      if (orConfig.showAddress &&
                          community.address != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          community.address!.toUpperCase(),
                          style: const pw.TextStyle(
                              fontSize: 9, letterSpacing: 0.5),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ── AR No. ──
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${orConfig.receiptNumberLabel} ',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Container(
                      width: 80,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                      ),
                      child: pw.Text(
                        receiptId,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),

                // ── DATE ──
                pw.Row(children: [
                  pw.Text('DATE: ',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Container(
                    width: 200,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                    ),
                    child: pw.Text(
                      dateFmt.format(invoice.createdAt),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ]),

                pw.SizedBox(height: 12),

                // ── TITLE ──
                pw.Center(
                  child: pw.Text(
                    orConfig.title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 10),

                // ── Receiving from ──
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 10),
                    children: [
                      const pw.TextSpan(
                          text: 'This is to acknowledge receiving from '),
                      pw.TextSpan(
                        text: ownerName ?? '________________',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ── Cluster / Condo Unit ── (unit info + community + amount)
                pw.Row(
                  children: [
                    _pdfCheckbox(checked: false),
                    pw.Text('Cluster     ',
                        style: const pw.TextStyle(fontSize: 10)),
                    _pdfCheckbox(checked: true),
                    pw.Text('${orConfig.unitLabel} ',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Container(
                      width: 60,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                      ),
                      child: pw.Text(unitNo,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.Text('  at ${community.name}, the amount of',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),

                pw.SizedBox(height: 8),

                // ── Amount line ──
                pw.Wrap(children: [
                  pw.Text(
                    _amountToWords(invoice.amount),
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(' pesos only (PHP ',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    currencyFmt.format(invoice.amount),
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('), as', style: const pw.TextStyle(fontSize: 10)),
                ]),

                pw.SizedBox(height: 10),

                // ── Payment for (checkboxes) ──
                pw.Row(
                  children: [
                    pw.Text('payment for  ',
                        style: const pw.TextStyle(fontSize: 10)),
                    ...orConfig.paymentCategories.map((cat) {
                      final isChecked = cat.toLowerCase() ==
                              invoiceCategoryLabel.toLowerCase() ||
                          (cat == 'Others' &&
                              (invoice.category == InvoiceCategory.other ||
                                  invoice.category ==
                                      InvoiceCategory.insurance));
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            _pdfCheckbox(checked: isChecked),
                            pw.Text(cat,
                                style: const pw.TextStyle(fontSize: 9)),
                            if (cat == 'Others' &&
                                isChecked &&
                                othersDescription != null) ...[
                              pw.Text(' ',
                                  style: const pw.TextStyle(fontSize: 9)),
                              pw.Text(othersDescription,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ],
                        ),
                      );
                    }),
                    pw.Text(' for', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),

                pw.SizedBox(height: 6),

                // ── Month line ──
                pw.Row(children: [
                  pw.Text('the month of  ',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                    ),
                    child: pw.Text(
                      billingMonth.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text('.', style: const pw.TextStyle(fontSize: 10)),
                ]),

                pw.SizedBox(height: 16),

                // ── Payment method checkboxes ──
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: orConfig.paymentMethods.map((method) {
                    final isChecked = paymentType != null &&
                        method.toUpperCase() == paymentType.toUpperCase();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          _pdfCheckbox(checked: isChecked),
                          pw.Text(method,
                              style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                pw.SizedBox(height: 20),

                // ── Signature line ──
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Received by,',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          width: 200,
                          decoration: const pw.BoxDecoration(
                            border:
                                pw.Border(bottom: pw.BorderSide(width: 0.5)),
                          ),
                          child: pw.Text(
                            receivedBy ?? '',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Signature over printed name',
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Draws a small checkbox (8×8 square with optional check mark).
  static pw.Widget _pdfCheckbox({bool checked = false, double size = 8}) {
    return pw.Container(
      width: size,
      height: size,
      margin: const pw.EdgeInsets.only(right: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.8),
      ),
      alignment: pw.Alignment.center,
      child: checked
          ? pw.Text('X',
              style: pw.TextStyle(
                  fontSize: size - 2, fontWeight: pw.FontWeight.bold))
          : pw.SizedBox(),
    );
  }

  /// Table cell helper for the OR layout
  static pw.Widget _tc(
    String text, {
    bool bold = false,
    PdfColor? bg,
    PdfColor? textColor,
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 7,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: textColor,
        ),
      ),
    );
  }

  static String _categoryName(InvoiceCategory cat) {
    switch (cat) {
      case InvoiceCategory.dues:
        return 'Monthly Dues';
      case InvoiceCategory.water:
        return 'Water';
      case InvoiceCategory.amenity:
        return 'Amenity';
      case InvoiceCategory.insurance:
        return 'Insurance';
      case InvoiceCategory.other:
        return 'Other';
    }
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

  /// Convert a numeric amount to English words (e.g. 2910.50 → "Two Thousand Nine Hundred Ten and 50/100").
  String _amountToWords(double amount) {
    final wholePart = amount.truncate();
    final centsPart = ((amount - wholePart) * 100).round();

    final words = _intToWords(wholePart);
    if (centsPart > 0) {
      return '$words and $centsPart/100';
    }
    return words;
  }

  String _intToWords(int n) {
    if (n == 0) return 'Zero';

    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convert(int num) {
      if (num == 0) return '';
      if (num < 20) return ones[num];
      if (num < 100) {
        final t = tens[num ~/ 10];
        final o = ones[num % 10];
        return o.isEmpty ? t : '$t-$o';
      }
      if (num < 1000) {
        final rest = convert(num % 100);
        return '${ones[num ~/ 100]} Hundred${rest.isEmpty ? '' : ' $rest'}';
      }
      if (num < 1000000) {
        final rest = convert(num % 1000);
        return '${convert(num ~/ 1000)} Thousand${rest.isEmpty ? '' : ' $rest'}';
      }
      if (num < 1000000000) {
        final rest = convert(num % 1000000);
        return '${convert(num ~/ 1000000)} Million${rest.isEmpty ? '' : ' $rest'}';
      }
      final rest = convert(num % 1000000000);
      return '${convert(num ~/ 1000000000)} Billion${rest.isEmpty ? '' : ' $rest'}';
    }

    return convert(n);
  }
}
