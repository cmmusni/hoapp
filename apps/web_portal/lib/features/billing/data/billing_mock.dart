/// Mock data for billing demo.

enum InvoiceStatus { unpaid, paid, overdue }

class InvoiceMock {
  final String id;
  final String period;
  final double amount;
  final InvoiceStatus status;

  const InvoiceMock({
    required this.id,
    required this.period,
    required this.amount,
    required this.status,
  });
}

final List<InvoiceMock> mockInvoices = [
  InvoiceMock(
      id: 'INV-2026-03',
      period: 'Mar 2026',
      amount: 5500,
      status: InvoiceStatus.unpaid),
  InvoiceMock(
      id: 'INV-2026-02',
      period: 'Feb 2026',
      amount: 5500,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2026-01',
      period: 'Jan 2026',
      amount: 5500,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-12',
      period: 'Dec 2025',
      amount: 5200,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-11',
      period: 'Nov 2025',
      amount: 5200,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-10',
      period: 'Oct 2025',
      amount: 5200,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-09',
      period: 'Sep 2025',
      amount: 5200,
      status: InvoiceStatus.overdue),
  InvoiceMock(
      id: 'INV-2025-08',
      period: 'Aug 2025',
      amount: 5000,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-07',
      period: 'Jul 2025',
      amount: 5000,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-06',
      period: 'Jun 2025',
      amount: 5000,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-05',
      period: 'May 2025',
      amount: 5000,
      status: InvoiceStatus.paid),
  InvoiceMock(
      id: 'INV-2025-04',
      period: 'Apr 2025',
      amount: 4800,
      status: InvoiceStatus.paid),
];

/// Monthly charges vs. paid amounts for the chart.
class MonthlyData {
  final String month;
  final double charged;
  final double paid;

  const MonthlyData(this.month, this.charged, this.paid);
}

final List<MonthlyData> mockMonthly = const [
  MonthlyData('Apr', 4800, 4800),
  MonthlyData('May', 5000, 5000),
  MonthlyData('Jun', 5000, 5000),
  MonthlyData('Jul', 5000, 5000),
  MonthlyData('Aug', 5000, 5000),
  MonthlyData('Sep', 5200, 0),
  MonthlyData('Oct', 5200, 5200),
  MonthlyData('Nov', 5200, 5200),
  MonthlyData('Dec', 5200, 5200),
  MonthlyData('Jan', 5500, 5500),
  MonthlyData('Feb', 5500, 5500),
  MonthlyData('Mar', 5500, 0),
];

String invoiceStatusLabel(InvoiceStatus s) {
  switch (s) {
    case InvoiceStatus.unpaid:
      return 'Unpaid';
    case InvoiceStatus.paid:
      return 'Paid';
    case InvoiceStatus.overdue:
      return 'Overdue';
  }
}
