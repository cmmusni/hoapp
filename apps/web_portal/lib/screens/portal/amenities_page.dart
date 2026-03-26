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
      final bookings = await repo.getUserBookings(communityId);
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.construction_rounded,
                    size: 20, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This feature is still under development. You may book the amenities from the admin office.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          : null,
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
                    subtitle: Text(_bookingStatusLabel(b.status)),
                    trailing: _bookingStatusChip(b.status, theme),
                  ),
                )),
        ],
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
      ),
    );
  }

  void _showCreateAmenityDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '8000');
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
                    'price': int.tryParse(priceController.text) ?? 8000,
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
