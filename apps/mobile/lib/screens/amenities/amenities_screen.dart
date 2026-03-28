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
                  ..._getBookingsForDay(_selectedDay!)
                      .map((booking) => _BookingTile(
                            booking: booking,
                            isStaff: isStaff,
                            onAction: _loadBookings,
                          )),
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
                      onBook: () => _showBookingDialog(a, amenities),
                    )),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _showCreateAmenityDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showBookingDialog(Amenity amenity, List<Amenity> allAmenities) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BookingRequestSheet(
          amenity: amenity,
          onBooked: () {
            _loadBookings();
            _loadAmenities();
          },
        ),
      ),
    );
  }

  void _showCreateAmenityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateAmenitySheet(onCreated: _loadAmenities),
      ),
    );
  }
}

class _AmenityTile extends StatelessWidget {
  final Amenity amenity;
  final VoidCallback onBook;

  const _AmenityTile({required this.amenity, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _brand.withOpacity(0.1),
          child: Icon(_getAmenityIcon(amenity.name), color: _brand),
        ),
        title: Text(amenity.name),
        subtitle: amenity.description != null
            ? Text(amenity.description!,
                maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: ElevatedButton(
          onPressed: onBook,
          style: ElevatedButton.styleFrom(
              backgroundColor: _brand, foregroundColor: Colors.white),
          child: const Text('Book'),
        ),
      ),
    );
  }

  IconData _getAmenityIcon(String name) {
    final typeStr = name.toLowerCase();
    if (typeStr.contains('pool')) return Icons.pool;
    if (typeStr.contains('gym')) return Icons.fitness_center;
    if (typeStr.contains('hall')) return Icons.event;
    if (typeStr.contains('court')) return Icons.sports_tennis;
    return Icons.place;
  }
}

class _BookingTile extends StatelessWidget {
  final AmenityBooking booking;
  final bool isStaff;
  final VoidCallback onAction;

  const _BookingTile({
    required this.booking,
    required this.isStaff,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = booking.status.toString().split('.').last;
    final statusColor = statusStr == 'confirmed'
        ? _brand
        : statusStr == 'pending'
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text('Booking #${booking.id.substring(0, 8)}'),
        subtitle: Text('Status: ${statusStr.toUpperCase()}'),
        trailing: isStaff && statusStr == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      final repo = context.read<AmenityRepository>();
                      await repo.approveBooking(booking.id);
                      onAction();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      final repo = context.read<AmenityRepository>();
                      await repo.cancelBooking(booking.id);
                      onAction();
                    },
                  ),
                ],
              )
            : Chip(
                label: Text(statusStr.toUpperCase(),
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: statusColor.withOpacity(0.15),
              ),
      ),
    );
  }
}

class _BookingRequestSheet extends StatefulWidget {
  final Amenity amenity;
  final VoidCallback onBooked;

  const _BookingRequestSheet({required this.amenity, required this.onBooked});

  @override
  State<_BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<_BookingRequestSheet> {
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book ${widget.amenity.name}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_selectedDate != null
                  ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                  : 'Select date'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 3)),
                  firstDate: DateTime.now().add(const Duration(days: 3)),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading || _selectedDate == null ? null : _handleBook,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Booking Request'),
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
      await repo.bookAmenity(
        amenityId: widget.amenity.id,
        targetDate: _selectedDate!.toIso8601String().split('T').first,
        unitId: '',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request submitted')),
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

class _CreateAmenitySheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateAmenitySheet({required this.onCreated});

  @override
  State<_CreateAmenitySheet> createState() => _CreateAmenitySheetState();
}

class _CreateAmenitySheetState extends State<_CreateAmenitySheet> {
  final _nameController = TextEditingController();
  final _rulesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Amenity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rulesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rules / Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Amenity'),
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
        rules: _rulesController.text.trim().isNotEmpty
            ? {'description': _rulesController.text.trim()}
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
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
