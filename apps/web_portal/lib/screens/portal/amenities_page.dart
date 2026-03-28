import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class AmenitiesPage extends StatefulWidget {
  const AmenitiesPage({super.key});

  @override
  State<AmenitiesPage> createState() => _AmenitiesPageState();
}

class _AmenitiesPageState extends State<AmenitiesPage> {
  Future<List<Amenity>>? _amenitiesFuture;
  // Calendar state
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
      setState(() {
        _amenitiesFuture = repo.getAmenities(appState.activeCommunityId!);
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
        setState(() {
          _bookingsByDate = byDate;
        });
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Amenity>>(
              future: _amenitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(
                      message: 'Loading amenities...');
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAmenities,
                          child: const Text('Retry'),
                        ),
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
                        Icon(Icons.pool_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No amenities yet',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Amenities allow residents to book common areas'),
                        if (isStaff) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateAmenityDialog(),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;

                      if (isWide) {
                        // Side-by-side: calendar left, list right
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _buildCalendar(theme),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 2,
                              child: _buildAmenityList(amenities),
                            ),
                          ],
                        );
                      }

                      // Stacked: calendar on top, list below
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildCalendar(theme),
                          ),
                          const Divider(height: 1),
                          // Selected day bookings
                          if (_selectedDay != null) ...[
                            _buildSelectedDayBookings(theme),
                            const Divider(height: 1),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('Available Amenities',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          ...amenities.map((a) => _buildAmenityTile(a)),
                          const SizedBox(height: 80), // FAB clearance
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _showCreateAmenityDialog(),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                final amenities = _amenitiesFuture;
                if (amenities != null) {
                  amenities.then((list) {
                    if (list.isNotEmpty) {
                      _showRequestBookingDialog(list);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No amenities available')),
                      );
                    }
                  });
                }
              },
              icon: const Icon(Icons.event_available),
              label: const Text('Request Booking'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TableCalendar<AmenityBooking>(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2027, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getBookingsForDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: theme.colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            markerSize: 6,
            markersMaxCount: 3,
          ),
          headerStyle: HeaderStyle(
            formatButtonShowsNext: false,
            titleCentered: true,
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          onPageChanged: (focused) {
            _focusedDay = focused;
          },
        ),
      ),
    );
  }

  Widget _buildSelectedDayBookings(ThemeData theme) {
    final bookings = _selectedDay != null
        ? _getBookingsForDay(_selectedDay!)
        : <AmenityBooking>[];
    final dateStr = _selectedDay != null
        ? DateFormat('MMMM d, yyyy').format(_selectedDay!)
        : '';
    final isStaff = context.read<AppState>().isStaff;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bookings for $dateStr',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (bookings.isEmpty)
            Text('No bookings on this date',
                style: TextStyle(color: Colors.grey[500]))
          else
            ...bookings.map((b) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        Icon(Icons.event, color: theme.colorScheme.primary),
                    title: Text(_formatBookingTime(b)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_bookingStatusLabel(b.status)),
                        if (b.status == BookingStatus.confirmed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Invoice has been created for this booking.',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xff215e3f),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _bookingStatusChip(b.status, theme),
                        if (isStaff && b.status == BookingStatus.pending) ...[
                          const SizedBox(width: 8),
                          _buildApproveButton(b),
                        ],
                        if (b.status == BookingStatus.pending) ...[
                          const SizedBox(width: 4),
                          _buildCancelButton(b),
                        ],
                      ],
                    ),
                    isThreeLine: b.status == BookingStatus.confirmed,
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildApproveButton(AmenityBooking booking) {
    return IconButton(
      icon: const Icon(Icons.check_circle_outline, color: Color(0xff215e3f)),
      tooltip: 'Approve booking',
      onPressed: () => _approveBooking(booking),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildCancelButton(AmenityBooking booking) {
    return IconButton(
      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
      tooltip: 'Cancel booking',
      onPressed: () => _cancelBooking(booking),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Future<void> _approveBooking(AmenityBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Booking'),
        content: const Text(
          'Approve this booking request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff215e3f),
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
          const SnackBar(
            content: Text('Booking approved.'),
          ),
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

  Widget _bookingStatusChip(BookingStatus status, ThemeData theme) {
    Color color;
    switch (status) {
      case BookingStatus.pending:
        color = Colors.orange;
      case BookingStatus.confirmed:
        color = const Color(0xff215e3f);
      case BookingStatus.cancelled:
        color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildAmenityList(List<Amenity> amenities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Available Amenities',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: amenities.length,
            itemBuilder: (context, index) =>
                _buildAmenityTile(amenities[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityTile(Amenity amenity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.pool, color: Theme.of(context).colorScheme.primary),
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
        onTap: () => _showAmenityDetails(amenity),
      ),
    );
  }

  void _showAmenityDetails(Amenity amenity) {
    final isStaff = context.read<AppState>().isStaff;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outlined, color: Color(0xff215e3f), size: 24),
            const SizedBox(width: 12),
            Expanded(
                child: Text(amenity.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amenity.description != null) ...[
              Text(amenity.description!),
              const SizedBox(height: 16),
            ],
            if (amenity.price != null)
              _InfoRow(
                label: 'Price',
                value: '₱${amenity.price} ${amenity.currency ?? 'PHP'}',
              ),
            if (amenity.capacity != null)
              _InfoRow(label: 'Capacity', value: '${amenity.capacity} people'),
            if (amenity.openTime != null && amenity.closeTime != null)
              _InfoRow(
                label: 'Hours',
                value: '${amenity.openTime} - ${amenity.closeTime}',
              ),
            _InfoRow(
              label: 'Same-day booking',
              value: amenity.allowSameDay ? 'Allowed' : 'Not allowed',
            ),
            _InfoRow(
              label: 'Advance booking',
              value: 'Up to ${amenity.maxDaysAhead} days',
            ),
          ],
        ),
        actions: isStaff
            ? null
            : [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRequestBookingDialog([amenity],
                        preselectedAmenity: amenity);
                  },
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Request Booking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff215e3f),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
      ),
    );
  }

  void _showRequestBookingDialog(List<Amenity> amenities,
      {Amenity? preselectedAmenity}) {
    Amenity? selectedAmenity = preselectedAmenity ?? amenities.first;
    DateTime? selectedDate = _selectedDay;
    final notesController = TextEditingController();
    bool isLoading = false;
    List<Unit> userUnits = [];
    Unit? selectedUnit;
    bool loadingUnits = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Load user's units on first build
            if (loadingUnits) {
              loadingUnits = false;
              final appState = context.read<AppState>();
              final householdRepo = context.read<HouseholdRepository>();
              final communityId = appState.activeCommunityId;
              if (communityId != null) {
                householdRepo.getMyHouseholds(communityId).then((members) {
                  final units = <String, Unit>{};
                  for (final m in members) {
                    units.putIfAbsent(
                      m.unitId,
                      () => Unit(
                        id: m.unitId,
                        communityId: m.communityId,
                        unitNo: m.unitId.substring(0, 8),
                        createdAt: DateTime.now(),
                      ),
                    );
                  }
                  if (ctx.mounted) {
                    setDialogState(() {
                      userUnits = units.values.toList();
                      if (userUnits.length == 1) {
                        selectedUnit = userUnits.first;
                      }
                    });
                  }
                }).catchError((_) {
                  if (ctx.mounted) {
                    setDialogState(() => userUnits = []);
                  }
                });

                householdRepo.getUnits(communityId).then((allUnits) {
                  householdRepo.getMyHouseholds(communityId).then((members) {
                    final myUnitIds = members.map((m) => m.unitId).toSet();
                    final myUnits = allUnits
                        .where((u) => myUnitIds.contains(u.id))
                        .toList();
                    if (ctx.mounted && myUnits.isNotEmpty) {
                      setDialogState(() {
                        userUnits = myUnits;
                        if (userUnits.length == 1) {
                          selectedUnit = userUnits.first;
                        }
                      });
                    }
                  });
                }).catchError((_) {});
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                decoration: const BoxDecoration(
                  color: Color(0xff215e3f),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                child: Row(
                  children: [
                    const Icon(Icons.event_available,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Text('Request Booking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (amenities.length > 1) ...[
                        DropdownButtonFormField<Amenity>(
                          value: selectedAmenity,
                          decoration: const InputDecoration(
                            labelText: 'Amenity',
                            border: OutlineInputBorder(),
                          ),
                          items: amenities.map((a) {
                            return DropdownMenuItem(
                              value: a,
                              child: Text(a.name),
                            );
                          }).toList(),
                          onChanged: (a) =>
                              setDialogState(() => selectedAmenity = a),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Text('Amenity',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            )),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pool,
                                  size: 18, color: const Color(0xff215e3f)),
                              const SizedBox(width: 10),
                              Text(selectedAmenity?.name ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Unit selector
                      if (userUnits.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (userUnits.length == 1) ...[
                        Text('Unit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            )),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                              Text('Unit ${userUnits.first.unitNo}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        DropdownButtonFormField<Unit>(
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: userUnits.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text('Unit ${u.unitNo}'),
                            );
                          }).toList(),
                          onChanged: (u) =>
                              setDialogState(() => selectedUnit = u),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Date picker
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final maxDays = selectedAmenity?.maxDaysAhead ?? 60;
                          // Minimum 3 days in advance required
                          final minDate = now.add(const Duration(days: 3));
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? minDate,
                            firstDate: minDate,
                            lastDate: now.add(Duration(days: maxDays)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Booking Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            selectedDate != null
                                ? DateFormat('MMMM d, yyyy')
                                    .format(selectedDate!)
                                : 'Select a date',
                            style: TextStyle(
                              color: selectedDate != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Booking details row
                      Row(
                        children: [
                          // Operating hours
                          if (selectedAmenity != null &&
                              selectedAmenity!.openTime != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
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
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${selectedAmenity!.openTime} – ${selectedAmenity!.closeTime}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Price
                          if (selectedAmenity != null &&
                              selectedAmenity!.openTime != null &&
                              selectedAmenity?.price != null)
                            const SizedBox(width: 12),
                          if (selectedAmenity?.price != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff215e3f)
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xff215e3f)
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.payments_outlined,
                                            size: 14, color: Color(0xff215e3f)),
                                        const SizedBox(width: 6),
                                        Text('Rate',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: const Color(0xff215e3f)
                                                    .withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${selectedAmenity!.price} ${selectedAmenity!.currency ?? 'PHP'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff215e3f),
                                      ),
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
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          hintText: 'Any special requests...',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                HOAppButton(
                  label: isLoading ? 'Submitting...' : 'Submit Request',
                  icon: Icons.send_rounded,
                  onPressed: isLoading ||
                          selectedAmenity == null ||
                          selectedDate == null ||
                          selectedUnit == null
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);
                          try {
                            final repo = context.read<AmenityRepository>();
                            final dateStr =
                                DateFormat('yyyy-MM-dd').format(selectedDate!);
                            await repo.bookAmenity(
                              amenityId: selectedAmenity!.id,
                              targetDate: dateStr,
                              unitId: selectedUnit!.id,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Booking request submitted! An invoice has been created for your unit with payment due 3 days before the booking date.',
                                  ),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              _loadBookings();
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  isLoading: isLoading,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateAmenityDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '6000');
    final openTimeController = TextEditingController(text: '08:00');
    final closeTimeController = TextEditingController(text: '22:00');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_business_outlined,
                color: Color(0xff215e3f), size: 24),
            const SizedBox(width: 12),
            const Text('Create Amenity',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Pool + Function Room',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (PHP)',
                  prefixText: '₱',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: openTimeController,
                decoration: const InputDecoration(
                  labelText: 'Opening Time',
                  hintText: 'HH:MM',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: closeTimeController,
                decoration: const InputDecoration(
                  labelText: 'Closing Time',
                  hintText: 'HH:MM',
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final appState = context.read<AppState>();
              final repo = context.read<AmenityRepository>();

              try {
                await repo.createAmenity(
                  communityId: appState.activeCommunityId!,
                  name: name,
                  rules: {
                    'price': int.tryParse(priceController.text) ?? 6000,
                    'currency': 'PHP',
                    'open': openTimeController.text.trim(),
                    'close': closeTimeController.text.trim(),
                    'allow_same_day': false,
                    'max_days_ahead': 60,
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amenity created')),
                  );
                  _loadAmenities();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

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
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
