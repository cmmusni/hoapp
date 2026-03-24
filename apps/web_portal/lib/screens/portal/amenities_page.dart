import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class AmenitiesPage extends StatefulWidget {
  const AmenitiesPage({super.key});

  @override
  State<AmenitiesPage> createState() => _AmenitiesPageState();
}

class _AmenitiesPageState extends State<AmenitiesPage> {
  Future<List<Amenity>>? _amenitiesFuture;

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
    }
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
            return const LoadingIndicator(message: 'Loading amenities...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
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
                  Icon(
                    Icons.pool_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No amenities yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Amenities allow residents to book common areas'),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: amenities.length,
              itemBuilder: (context, index) {
                final amenity = amenities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.pool,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(amenity.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (amenity.price != null)
                          Text(
                              '₱${amenity.price} ${amenity.currency ?? 'PHP'}'),
                        if (amenity.openTime != null &&
                            amenity.closeTime != null)
                          Text('${amenity.openTime} - ${amenity.closeTime}'),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAmenityDetails(amenity),
                  ),
                );
              },
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

  void _showAmenityDetails(Amenity amenity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outlined, color: Color(0xFF2E7D32), size: 24),
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
                color: Color(0xFF2E7D32), size: 24),
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
