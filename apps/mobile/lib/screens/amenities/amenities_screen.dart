import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

class AmenitiesScreen extends StatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen> {
  Future<List<Amenity>>? _amenitiesFuture;
  List<Amenity> _cachedAmenities = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AmenityBooking>> _bookingsByDate = {};

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  void _loadAmenities() {
    final appState = context.read<AppState>();
    final repo = context.read<AmenityRepository>();

    if (appState.activeCommunityId != null) {
      final future = repo.getAmenities(appState.activeCommunityId!);
      future.then((list) {
        if (mounted) setState(() => _cachedAmenities = list);
      });
      setState(() {
        _amenitiesFuture = future;
      });
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final appState = context.read<AppState>();
    final repo = context.read<AmenityRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    try {
      final isStaff = appState.isStaff;
      final bookings = isStaff
          ? await repo.getAllBookings(communityId)
          : await repo.getUserBookings(communityId);
      final byDate = <DateTime, List<AmenityBooking>>{};
      for (final b in bookings) {
        final date = b.bookingDate;
        if (date != null) {
          final key = DateTime.utc(date.year, date.month, date.day);
          byDate.putIfAbsent(key, () => []).add(b);
        }
      }
      if (mounted) {
        setState(() => _bookingsByDate = byDate);
      }
    } catch (_) {}
  }

  List<AmenityBooking> _getBookingsForDay(DateTime day) {
    return _bookingsByDate[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      body: FutureBuilder<List<Amenity>>(
        future: _amenitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _loadAmenities, child: const Text('Retry')),
                ],
              ),
            );
          }

          final amenities = snapshot.data ?? [];

          if (amenities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pool_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No amenities yet',
                      style: TextStyle(fontSize: 18)),
                  if (isStaff) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateAmenitySheet(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Amenity'),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadAmenities(),
            child: ListView(
              children: [
                // Calendar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getBookingsForDay,
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: _brand,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: _brand,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: _brand.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Selected day bookings
                if (_selectedDay != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Bookings for ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ..._getBookingsForDay(_selectedDay!).map(
                    (booking) => _BookingTile(
                      booking: booking,
                      isStaff: isStaff,
                      onApprove: () => _approveBooking(booking),
                      onCancel: () => _cancelBooking(booking),
                    ),
                  ),
                  if (_getBookingsForDay(_selectedDay!).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No bookings on this day',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  const Divider(),
                ],

                // Amenity list
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Available Amenities',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ...amenities.map((a) => _AmenityTile(
                      amenity: a,
                      onTap: () => _showAmenityDetails(a),
                    )),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _showCreateAmenitySheet(),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                if (_cachedAmenities.isNotEmpty) {
                  _showBookingSheet(_cachedAmenities.first, _cachedAmenities);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No amenities available')),
                  );
                }
              },
              icon: const Icon(Icons.event_available),
              label: const Text('Request Booking'),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
    );
  }

  // ─── Amenity Details Bottom Sheet ──────────────────────────────────

  void _showAmenityDetails(Amenity amenity) {
    final isStaff = context.read<AppState>().isStaff;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _brand.withOpacity(0.1),
                    child: Icon(_getAmenityIcon(amenity.name), color: _brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(amenity.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (amenity.description != null) ...[
                Text(amenity.description!,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700], height: 1.4)),
                const SizedBox(height: 16),
              ],
              // Details
              if (amenity.price != null)
                _InfoRow(
                    label: 'Price',
                    value: '₱${amenity.price} ${amenity.currency ?? 'PHP'}'),
              if (amenity.capacity != null)
                _InfoRow(
                    label: 'Capacity', value: '${amenity.capacity} people'),
              if (amenity.openTime != null && amenity.closeTime != null)
                _InfoRow(
                    label: 'Hours',
                    value: '${amenity.openTime} - ${amenity.closeTime}'),
              _InfoRow(
                  label: 'Same-day booking',
                  value: amenity.allowSameDay ? 'Allowed' : 'Not allowed'),
              _InfoRow(
                  label: 'Advance booking',
                  value: 'Up to ${amenity.maxDaysAhead} days'),
              if (!isStaff) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showBookingSheet(amenity, _cachedAmenities);
                    },
                    icon: const Icon(Icons.event_available),
                    label: const Text('Request Booking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Booking Request Bottom Sheet ─────────────────────────────────

  void _showBookingSheet(Amenity amenity, List<Amenity> allAmenities) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BookingRequestSheet(
          amenity: amenity,
          allAmenities: allAmenities,
          onBooked: () {
            _loadBookings();
            _loadAmenities();
          },
        ),
      ),
    );
  }

  // ─── Create Amenity Bottom Sheet ──────────────────────────────────

  void _showCreateAmenitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateAmenitySheet(onCreated: _loadAmenities),
      ),
    );
  }

  // ─── Approve Booking (with confirmation) ──────────────────────────

  Future<void> _approveBooking(AmenityBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Booking'),
        content: const Text('Approve this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = context.read<AmenityRepository>();
      await repo.approveBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking approved.')),
        );
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving booking: $e')),
        );
      }
    }
  }

  // ─── Cancel Booking (with confirmation) ───────────────────────────

  Future<void> _cancelBooking(AmenityBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = context.read<AmenityRepository>();
      await repo.cancelBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling booking: $e')),
        );
      }
    }
  }

  IconData _getAmenityIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('pool')) return Icons.pool;
    if (n.contains('gym')) return Icons.fitness_center;
    if (n.contains('hall')) return Icons.event;
    if (n.contains('court')) return Icons.sports_tennis;
    return Icons.place;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Amenity Tile
// ═══════════════════════════════════════════════════════════════════════

class _AmenityTile extends StatelessWidget {
  final Amenity amenity;
  final VoidCallback onTap;

  const _AmenityTile({required this.amenity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _brand.withOpacity(0.1),
          child: Icon(_iconFor(amenity.name), color: _brand),
        ),
        title: Text(amenity.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amenity.price != null)
              Text('₱${amenity.price} ${amenity.currency ?? 'PHP'}'),
            if (amenity.openTime != null && amenity.closeTime != null)
              Text('${amenity.openTime} - ${amenity.closeTime}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('pool')) return Icons.pool;
    if (n.contains('gym')) return Icons.fitness_center;
    if (n.contains('hall')) return Icons.event;
    if (n.contains('court')) return Icons.sports_tennis;
    return Icons.place;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Booking Tile  (shows time, status chip, confirms before actions)
// ═══════════════════════════════════════════════════════════════════════

class _BookingTile extends StatelessWidget {
  final AmenityBooking booking;
  final bool isStaff;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const _BookingTile({
    required this.booking,
    required this.isStaff,
    required this.onApprove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    final statusStr = status.toString().split('.').last;
    final statusColor = status == BookingStatus.confirmed
        ? _brand
        : status == BookingStatus.pending
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.event, color: _brand),
        title: Text(_formatBookingTime(booking)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bookingStatusLabel(status)),
            if (status == BookingStatus.confirmed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Invoice has been created for this booking.',
                  style: TextStyle(
                      fontSize: 12, color: _brand, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
        isThreeLine: status == BookingStatus.confirmed,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(statusStr.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor)),
            ),
            if (isStaff && status == BookingStatus.pending) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: _brand),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onApprove,
              ),
            ],
            if (status == BookingStatus.pending) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBookingTime(AmenityBooking b) {
    final start = b.startTime;
    final end = b.endTime;
    if (start != null && end != null) {
      return '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';
    }
    final date = b.bookingDate;
    if (date != null) return DateFormat('MMM d, yyyy').format(date);
    return 'Booked';
  }

  String _bookingStatusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending confirmation';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Booking Request Sheet (unit selector, notes, info banner, noVerify)
// ═══════════════════════════════════════════════════════════════════════

class _BookingRequestSheet extends StatefulWidget {
  final Amenity amenity;
  final List<Amenity> allAmenities;
  final VoidCallback onBooked;

  const _BookingRequestSheet({
    required this.amenity,
    required this.allAmenities,
    required this.onBooked,
  });

  @override
  State<_BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<_BookingRequestSheet> {
  late Amenity _selectedAmenity;
  DateTime? _selectedDate;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // Unit selection
  List<Unit> _userUnits = [];
  Unit? _selectedUnit;
  bool _loadingUnits = true;

  @override
  void initState() {
    super.initState();
    _selectedAmenity = widget.amenity;
    _loadUnits();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    final appState = context.read<AppState>();
    final householdRepo = context.read<HouseholdRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    try {
      final allUnits = await householdRepo.getUnits(communityId);
      final members = await householdRepo.getMyHouseholds(communityId);
      final myUnitIds = members.map((m) => m.unitId).toSet();
      final myUnits = allUnits.where((u) => myUnitIds.contains(u.id)).toList();
      if (mounted) {
        setState(() {
          _userUnits = myUnits;
          if (myUnits.length == 1) _selectedUnit = myUnits.first;
          _loadingUnits = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUnits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Request Booking',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'An invoice will be automatically created for your unit with a due date 3 days before the booking date. Booking must be made at least 3 days in advance.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amenity selector
            if (widget.allAmenities.length > 1) ...[
              DropdownButtonFormField<Amenity>(
                value: _selectedAmenity,
                decoration: const InputDecoration(
                  labelText: 'Amenity',
                  border: OutlineInputBorder(),
                ),
                items: widget.allAmenities.map((a) {
                  return DropdownMenuItem(value: a, child: Text(a.name));
                }).toList(),
                onChanged: (a) {
                  if (a != null) setState(() => _selectedAmenity = a);
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text('Amenity',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700])),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(_selectedAmenity.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              const SizedBox(height: 16),
            ],

            // Unit selector
            if (_loadingUnits)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_userUnits.length == 1) ...[
              Text('Unit',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700])),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home_outlined,
                        size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Text('Unit ${_userUnits.first.unitNo}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_userUnits.length > 1) ...[
              DropdownButtonFormField<Unit>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: _userUnits.map((u) {
                  return DropdownMenuItem(
                      value: u, child: Text('Unit ${u.unitNo}'));
                }).toList(),
                onChanged: (u) => setState(() => _selectedUnit = u),
              ),
              const SizedBox(height: 16),
            ],

            // Date picker
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final maxDays = _selectedAmenity.maxDaysAhead;
                final minDate = now.add(const Duration(days: 3));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? minDate,
                  firstDate: minDate,
                  lastDate: now.add(Duration(days: maxDays)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Booking Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(
                  _selectedDate != null
                      ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
                      : 'Select a date',
                  style: TextStyle(
                      color: _selectedDate != null ? null : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hours + Price info cards
            Row(
              children: [
                if (_selectedAmenity.openTime != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text('Hours',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedAmenity.openTime} – ${_selectedAmenity.closeTime}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectedAmenity.openTime != null &&
                    _selectedAmenity.price != null)
                  const SizedBox(width: 12),
                if (_selectedAmenity.price != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _brand.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _brand.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  size: 14, color: _brand),
                              const SizedBox(width: 6),
                              Text('Rate',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _brand.withOpacity(0.7))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_selectedAmenity.price} ${_selectedAmenity.currency ?? 'PHP'}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _brand),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Any special requests...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading || _selectedDate == null || _selectedUnit == null
                        ? null
                        : _handleBook,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Request',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _brand.withOpacity(0.4),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBook() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<AmenityRepository>();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      await repo.bookAmenity(
        amenityId: _selectedAmenity.id,
        targetDate: dateStr,
        unitId: _selectedUnit!.id,
        noVerify: true,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking request submitted! An invoice has been created for your unit with payment due 3 days before the booking date.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        widget.onBooked();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Create Amenity Sheet (with price, opening/closing time)
// ═══════════════════════════════════════════════════════════════════════

class _CreateAmenitySheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateAmenitySheet({required this.onCreated});

  @override
  State<_CreateAmenitySheet> createState() => _CreateAmenitySheetState();
}

class _CreateAmenitySheetState extends State<_CreateAmenitySheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '6000');
  final _openTimeController = TextEditingController(text: '08:00');
  final _closeTimeController = TextEditingController(text: '22:00');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Create Amenity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Pool + Function Room',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (PHP)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openTimeController,
              decoration: const InputDecoration(
                labelText: 'Opening Time',
                hintText: 'HH:MM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _closeTimeController,
              decoration: const InputDecoration(
                labelText: 'Closing Time',
                hintText: 'HH:MM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleCreate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_business),
                label: Text(_isLoading ? 'Creating...' : 'Create Amenity',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<AmenityRepository>();
      await repo.createAmenity(
        communityId: appState.activeCommunityId!,
        name: _nameController.text.trim(),
        rules: {
          'price': int.tryParse(_priceController.text) ?? 6000,
          'currency': 'PHP',
          'open': _openTimeController.text.trim(),
          'close': _closeTimeController.text.trim(),
          'allow_same_day': false,
          'max_days_ahead': 60,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amenity created')),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Info Row helper
// ═══════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
