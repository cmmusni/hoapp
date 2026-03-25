import 'package:flutter/material.dart';
import '../widgets/amenities_calendar.dart';

/// Amenities page with calendar reservation picker.
class AmenitiesPage extends StatelessWidget {
  const AmenitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const AmenitiesCalendar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReservationDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Request Reservation'),
      ),
    );
  }
}
