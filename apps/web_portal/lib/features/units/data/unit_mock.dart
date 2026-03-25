/// Mock data for Unit management demo.

enum UnitStatus { occupied, vacant, maintenance }

class UnitMock {
  final String id;
  final String address;
  final UnitStatus status;
  final double balance;
  final String type;

  const UnitMock({
    required this.id,
    required this.address,
    required this.status,
    required this.balance,
    required this.type,
  });
}

final List<UnitMock> mockUnits = [
  UnitMock(
      id: 'U-101',
      address: 'Tower A, Unit 101',
      status: UnitStatus.occupied,
      balance: 0,
      type: '1BR'),
  UnitMock(
      id: 'U-102',
      address: 'Tower A, Unit 102',
      status: UnitStatus.occupied,
      balance: 2500,
      type: '2BR'),
  UnitMock(
      id: 'U-103',
      address: 'Tower A, Unit 103',
      status: UnitStatus.vacant,
      balance: 0,
      type: 'Studio'),
  UnitMock(
      id: 'U-201',
      address: 'Tower A, Unit 201',
      status: UnitStatus.occupied,
      balance: 1200,
      type: '3BR'),
  UnitMock(
      id: 'U-202',
      address: 'Tower A, Unit 202',
      status: UnitStatus.maintenance,
      balance: 0,
      type: '2BR'),
  UnitMock(
      id: 'U-203',
      address: 'Tower A, Unit 203',
      status: UnitStatus.occupied,
      balance: 0,
      type: '1BR'),
  UnitMock(
      id: 'U-301',
      address: 'Tower B, Unit 301',
      status: UnitStatus.occupied,
      balance: 4800,
      type: '2BR'),
  UnitMock(
      id: 'U-302',
      address: 'Tower B, Unit 302',
      status: UnitStatus.vacant,
      balance: 0,
      type: 'Studio'),
  UnitMock(
      id: 'U-303',
      address: 'Tower B, Unit 303',
      status: UnitStatus.occupied,
      balance: 0,
      type: '1BR'),
  UnitMock(
      id: 'U-401',
      address: 'Tower B, Unit 401',
      status: UnitStatus.occupied,
      balance: 750,
      type: '3BR'),
  UnitMock(
      id: 'U-402',
      address: 'Tower B, Unit 402',
      status: UnitStatus.maintenance,
      balance: 0,
      type: '2BR'),
  UnitMock(
      id: 'U-403',
      address: 'Tower B, Unit 403',
      status: UnitStatus.occupied,
      balance: 0,
      type: '1BR'),
  UnitMock(
      id: 'U-501',
      address: 'Tower C, Unit 501',
      status: UnitStatus.vacant,
      balance: 0,
      type: 'Studio'),
  UnitMock(
      id: 'U-502',
      address: 'Tower C, Unit 502',
      status: UnitStatus.occupied,
      balance: 3200,
      type: '2BR'),
  UnitMock(
      id: 'U-503',
      address: 'Tower C, Unit 503',
      status: UnitStatus.occupied,
      balance: 0,
      type: '1BR'),
];

String statusLabel(UnitStatus s) {
  switch (s) {
    case UnitStatus.occupied:
      return 'Occupied';
    case UnitStatus.vacant:
      return 'Vacant';
    case UnitStatus.maintenance:
      return 'Maintenance';
  }
}
