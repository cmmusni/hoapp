/// Configuration for community-specific Official Receipt templates.
///
/// Stored in `community.settings['or_template']` as JSON.
/// If absent, the default "detailed" style is used.
class ORTemplateConfig {
  /// Template style: 'detailed' (full billing statement) or 'acknowledgement'
  /// (simple checkbox-style like the Elevé physical form).
  final String style;

  /// Document title shown at the top (e.g. "ACKNOWLEDGEMENT RECEIPT",
  /// "OFFICIAL RECEIPT", "BILLING STATEMENT").
  final String title;

  /// Label for the receipt/AR number (e.g. "AR NO.", "OR NO.").
  final String receiptNumberLabel;

  /// Whether to display the community address below the logo/name.
  final bool showAddress;

  /// Payment category labels for the acknowledgement-style checkboxes
  /// (e.g. ["Water Bill", "Monthly dues", "Pool Reservation", "Others"]).
  final List<String> paymentCategories;

  /// Payment method labels for the acknowledgement-style checkboxes
  /// (e.g. ["CASH PAYMENT", "ONLINE PAYMENT", "BANK OR CHECK"]).
  final List<String> paymentMethods;

  /// Label for the primary signature line (e.g. "Received by", "Prepared by").
  final String signatureLabel;

  /// Optional second signature label (e.g. "Approved by"). Null hides it.
  final String? secondSignatureLabel;

  /// Custom payment instructions text. Null uses the default.
  final String? paymentInstructions;

  /// Unit label used on the form (e.g. "Condo Unit number", "Unit No.").
  final String unitLabel;

  const ORTemplateConfig({
    this.style = 'detailed',
    this.title = 'ACKNOWLEDGEMENT RECEIPT',
    this.receiptNumberLabel = 'AR NO.',
    this.showAddress = false,
    this.paymentCategories = const [
      'Water Bill',
      'Monthly dues',
      'Pool Reservation',
      'Others',
    ],
    this.paymentMethods = const [
      'CASH PAYMENT',
      'ONLINE PAYMENT',
      'BANK OR CHECK',
    ],
    this.signatureLabel = 'Prepared by',
    this.secondSignatureLabel = 'Approved by',
    this.paymentInstructions,
    this.unitLabel = 'Unit No.',
  });

  /// Parse from the JSON map stored in community settings.
  factory ORTemplateConfig.fromJson(Map<String, dynamic> json) {
    return ORTemplateConfig(
      style: json['style'] as String? ?? 'detailed',
      title: json['title'] as String? ?? 'OFFICIAL RECEIPT',
      receiptNumberLabel: json['receipt_number_label'] as String? ?? 'OR NO.',
      showAddress: json['show_address'] as bool? ?? false,
      paymentCategories: (json['payment_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['Water Bill', 'Monthly dues', 'Pool Reservation', 'Others'],
      paymentMethods: (json['payment_methods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['CASH PAYMENT', 'ONLINE PAYMENT', 'BANK OR CHECK'],
      signatureLabel: json['signature_label'] as String? ?? 'Prepared by',
      secondSignatureLabel: json['second_signature_label'] as String?,
      paymentInstructions: json['payment_instructions'] as String?,
      unitLabel: json['unit_label'] as String? ?? 'Unit No.',
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style,
        'title': title,
        'receipt_number_label': receiptNumberLabel,
        'show_address': showAddress,
        'payment_categories': paymentCategories,
        'payment_methods': paymentMethods,
        'signature_label': signatureLabel,
        if (secondSignatureLabel != null)
          'second_signature_label': secondSignatureLabel,
        if (paymentInstructions != null)
          'payment_instructions': paymentInstructions,
        'unit_label': unitLabel,
      };

  /// Default config — returns the detailed billing statement style.
  static const defaultConfig = ORTemplateConfig();

  /// Elevé Homes Camarin acknowledgement receipt style.
  static const eleveAcknowledgement = ORTemplateConfig(
    style: 'acknowledgement',
    title: 'ACKNOWLEDGEMENT RECEIPT',
    receiptNumberLabel: 'AR NO.',
    showAddress: true,
    unitLabel: 'Condo Unit number',
    paymentCategories: [
      'Water Bill',
      'Monthly dues',
      'Pool Reservation',
      'Others',
    ],
    paymentMethods: [
      'CASH PAYMENT',
      'ONLINE PAYMENT',
      'BANK OR CHECK',
    ],
    signatureLabel: 'Received by',
    secondSignatureLabel: null,
  );
}
