import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

/// Calendar-based amenity reservation picker.
class AmenitiesCalendar extends StatefulWidget {
  const AmenitiesCalendar({super.key});

  @override
  State<AmenitiesCalendar> createState() => _AmenitiesCalendarState();
}

class _AmenitiesCalendarState extends State<AmenitiesCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _selectedDay;

  // Demo events
  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2026, 3, 25): ['Pool – Dela Cruz (2pm-4pm)'],
    DateTime.utc(2026, 3, 26): [
      'Clubhouse – Santos (10am-12pm)',
      'Gym – Reyes (3pm-5pm)'
    ],
    DateTime.utc(2026, 3, 28): ['BBQ Area – Garcia (5pm-8pm)'],
    DateTime.utc(2026, 3, 30): ['Pool – Owner Meet (1pm-3pm)'],
  };

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  List<String> _getEventsForRange(DateTime start, DateTime end) {
    final days = <String>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.addAll(_getEventsForDay(d));
    }
    return days;
  }

  List<String> get _selectedEvents {
    if (_rangeStart != null && _rangeEnd != null) {
      return _getEventsForRange(_rangeStart!, _rangeEnd!);
    }
    if (_selectedDay != null) {
      return _getEventsForDay(_selectedDay!);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        TableCalendar<String>(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2027, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          rangeSelectionMode: RangeSelectionMode.toggledOn,
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            rangeStartDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            rangeEndDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            rangeHighlightColor: theme.colorScheme.primary.withOpacity(0.15),
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
              _rangeStart = null;
              _rangeEnd = null;
            });
          },
          onRangeSelected: (start, end, focused) {
            setState(() {
              _rangeStart = start;
              _rangeEnd = end;
              _selectedDay = null;
              _focusedDay = focused;
            });
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          onPageChanged: (focused) => _focusedDay = focused,
        ),
        const SizedBox(height: 8),
        // Events list
        Expanded(
          child: _selectedEvents.isEmpty
              ? Center(
                  child: Text(
                    'No reservations for selected date(s)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedEvents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    return ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.event, color: theme.colorScheme.primary),
                      title: Text(_selectedEvents[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Dialog for requesting a new reservation.
Future<void> showReservationDialog(BuildContext context) {
  final formKey = GlobalKey<FormBuilderState>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.event_available, color: Colors.green),
          SizedBox(width: 8),
          Text('Request Reservation'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: FormBuilder(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderDropdown<String>(
                name: 'amenity',
                decoration: const InputDecoration(labelText: 'Amenity'),
                validator: FormBuilderValidators.required(),
                items: const [
                  DropdownMenuItem(value: 'pool', child: Text('Swimming Pool')),
                  DropdownMenuItem(
                      value: 'clubhouse', child: Text('Clubhouse')),
                  DropdownMenuItem(value: 'gym', child: Text('Gym')),
                  DropdownMenuItem(value: 'bbq', child: Text('BBQ Area')),
                ],
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'date',
                inputType: InputType.date,
                decoration: const InputDecoration(labelText: 'Date'),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'time_slot',
                decoration: const InputDecoration(labelText: 'Time Slot'),
                validator: FormBuilderValidators.required(),
                items: const [
                  DropdownMenuItem(
                      value: '8am-10am', child: Text('8:00 AM – 10:00 AM')),
                  DropdownMenuItem(
                      value: '10am-12pm', child: Text('10:00 AM – 12:00 PM')),
                  DropdownMenuItem(
                      value: '1pm-3pm', child: Text('1:00 PM – 3:00 PM')),
                  DropdownMenuItem(
                      value: '3pm-5pm', child: Text('3:00 PM – 5:00 PM')),
                  DropdownMenuItem(
                      value: '5pm-8pm', child: Text('5:00 PM – 8:00 PM')),
                ],
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'notes',
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.saveAndValidate() ?? false) {
              final values = formKey.currentState!.value;
              debugPrint('Reservation payload: $values');
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(
                  content: Text('Reservation requested!'),
                  behavior: SnackBarBehavior.floating,
                ));
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}
